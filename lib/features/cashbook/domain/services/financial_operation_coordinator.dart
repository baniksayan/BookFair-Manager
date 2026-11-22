import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/database/database_exceptions.dart';
import '../../data/datasources/financial_operation_local_datasource.dart';
import '../../data/models/financial_operation_model.dart';

/// Orchestrates multi-box financial transactions with Write-Ahead Logging (WAL),
/// account-level mutex concurrency locks, stable idempotency, and asynchronous durability.
class FinancialOperationCoordinator {
  FinancialOperationCoordinator({required this.journalDataSource, Uuid? uuid})
    : _uuid = uuid ?? const Uuid();

  final FinancialOperationLocalDataSource journalDataSource;
  final Uuid _uuid;

  // Unified mutex queue to serialize concurrent operations on accounts and financial entities
  static final Map<String, Completer<void>> _resourceLocks = {};

  // Registry of accounts quarantined due to recovery failures
  static final Set<String> _quarantinedAccountIds = {};

  /// Check whether an account is currently quarantined.
  static bool isAccountQuarantined(String accountId) =>
      _quarantinedAccountIds.contains(accountId);

  /// Quarantine an account to prevent further financial mutations until resolved.
  static void quarantineAccount(String accountId) {
    _quarantinedAccountIds.add(accountId);
  }

  /// Remove an account from quarantine after successful reconciliation.
  static void releaseQuarantine(String accountId) {
    _quarantinedAccountIds.remove(accountId);
  }

  /// Clears all quarantined accounts (for testing only).
  static void clearQuarantineForTesting() {
    _quarantinedAccountIds.clear();
  }

  /// Computes a deterministic canonical fingerprint from financial details.
  String computeFingerprint({
    required int amountPaise,
    String? sourceAccountId,
    String? targetAccountId,
    required String primaryEntityId,
    String? secondaryEntityId,
  }) {
    final canonicalString =
        '$amountPaise|${sourceAccountId ?? ''}|${targetAccountId ?? ''}|$primaryEntityId|${secondaryEntityId ?? ''}';
    return base64Url.encode(utf8.encode(canonicalString));
  }

  /// Acquires async locks for all specified resource keys in deterministic alphabetical order to avoid deadlocks.
  Future<void> _acquireResourceLocks(List<String> resourceKeys) async {
    final sortedKeys = resourceKeys.where((k) => k.isNotEmpty).toSet().toList()
      ..sort();
    for (final key in sortedKeys) {
      while (_resourceLocks.containsKey(key)) {
        try {
          await _resourceLocks[key]!.future;
        } catch (_) {}
      }
      _resourceLocks[key] = Completer<void>();
    }
  }

  /// Releases locks for all specified resource keys.
  void _releaseResourceLocks(List<String> resourceKeys) {
    final sortedKeys = resourceKeys.where((k) => k.isNotEmpty).toSet().toList()
      ..sort();
    for (final key in sortedKeys) {
      final lock = _resourceLocks.remove(key);
      if (lock != null && !lock.isCompleted) {
        lock.complete();
      }
    }
  }

  /// Executes an action holding locks on the specified resource keys in deterministic order.
  Future<T> withResourceLocks<T>({
    required List<String> resourceKeys,
    required Future<T> Function() action,
  }) async {
    final currentHeldLocks =
        (Zone.current[#heldResourceLocks] as Set<String>?) ?? <String>{};
    final newLocksToAcquire =
        resourceKeys
            .where((k) => k.isNotEmpty && !currentHeldLocks.contains(k))
            .toSet()
            .toList()
          ..sort();

    await _acquireResourceLocks(newLocksToAcquire);

    return runZoned(
      () async {
        try {
          return await action();
        } finally {
          _releaseResourceLocks(newLocksToAcquire);
        }
      },
      zoneValues: {
        #heldResourceLocks: {...currentHeldLocks, ...newLocksToAcquire},
      },
    );
  }

  /// Executes a multi-box financial operation with the 7-step durability protocol.
  Future<T> runCoordinatedOperation<T>({
    required String fairId,
    required String operationType,
    required String idempotencyKey,
    required int amountPaise,
    required String primaryEntityId,
    String? secondaryEntityId,
    String? sourceAccountId,
    String? targetAccountId,
    List<String>? additionalLockKeys,
    required Map<String, dynamic> payload,
    required List<Box<dynamic>> affectedBoxes,
    required Future<T> Function(String operationId) executeWrites,
    required Future<void> Function(String operationId) rollbackWrites,
    required void Function() validateInvariants,
    required Future<T> Function(FinancialOperationModel existing)
    onAlreadyCommitted,
  }) async {
    final allAccountIds = <String>{
      if (sourceAccountId != null && sourceAccountId.isNotEmpty)
        sourceAccountId,
      if (targetAccountId != null && targetAccountId.isNotEmpty)
        targetAccountId,
      if (additionalLockKeys != null)
        for (final k in additionalLockKeys)
          if (k.startsWith('account:')) k.substring('account:'.length),
    };

    // Verify no involved account is quarantined
    for (final accId in allAccountIds) {
      if (isAccountQuarantined(accId)) {
        throw AccountQuarantinedException(
          'Account "$accId" is quarantined due to an unresolved financial recovery failure.',
        );
      }
    }

    // Assemble all resource lock keys (both account and entity level)
    final resourceKeys = <String>{
      for (final accId in allAccountIds) 'account:$accId',
      if (operationType == 'standalone_expense_payment' ||
          operationType == 'expense_refund_reversal' ||
          operationType == 'expense_write_off')
        'expense:$primaryEntityId',
      if (operationType == 'purchase_batch_payment')
        'purchase_batch:$primaryEntityId',
      if (operationType == 'sales_settlement' ||
          operationType == 'sale_return_refund')
        'sale:$primaryEntityId',
      ...?additionalLockKeys,
    };

    final currentHeldLocks =
        (Zone.current[#heldResourceLocks] as Set<String>?) ?? <String>{};
    final newLocksToAcquire =
        resourceKeys
            .where((k) => k.isNotEmpty && !currentHeldLocks.contains(k))
            .toSet()
            .toList()
          ..sort();

    await _acquireResourceLocks(newLocksToAcquire);

    return runZoned(
      () async {
        try {
          final fingerprint = computeFingerprint(
            amountPaise: amountPaise,
            sourceAccountId: sourceAccountId,
            targetAccountId: targetAccountId,
            primaryEntityId: primaryEntityId,
            secondaryEntityId: secondaryEntityId,
          );

          // Check for existing operation with the same idempotency key
          final existing = journalDataSource.getOperationByIdempotencyKey(
            idempotencyKey,
          );

          if (existing != null) {
            if (existing.requestFingerprint != fingerprint) {
              throw IdempotencyConflictException(
                'Idempotency key "$idempotencyKey" was already used with differing financial parameters.',
              );
            }

            if (existing.isCommitted) {
              // Idempotent return without duplicate writes
              return await onAlreadyCommitted(existing);
            }

            if (existing.isProcessing) {
              throw ValidationException(
                'Operation with key "$idempotencyKey" is currently in-flight or recovering. Please wait.',
              );
            }
          }

          final now = DateTime.now().millisecondsSinceEpoch;
          final operationId = _uuid.v4();
          final attemptNumber = existing != null
              ? existing.attemptNumber + 1
              : 1;
          final parentOperationId = existing?.id;

          var operationModel = FinancialOperationModel(
            id: operationId,
            fairId: fairId,
            idempotencyKey: idempotencyKey,
            requestFingerprint: fingerprint,
            operationType: operationType,
            status: 'prepared',
            amountPaise: amountPaise,
            primaryEntityId: primaryEntityId,
            secondaryEntityId: secondaryEntityId,
            sourceAccountId: sourceAccountId,
            targetAccountId: targetAccountId,
            payloadJson: jsonEncode(payload),
            attemptNumber: attemptNumber,
            parentOperationId: parentOperationId,
            createdAtEpoch: now,
            updatedAtEpoch: now,
          );

          // Step 1: Persist prepared journal intent
          await journalDataSource.saveOperation(operationModel);

          // Step 2: Asynchronously flush journal box to OS buffer
          await journalDataSource.flush();

          // Transition to processing state
          operationModel = operationModel.copyWith(
            status: 'processing',
            updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
          );
          await journalDataSource.saveOperation(operationModel);

          T result;
          try {
            // Step 3: Apply sequential target writes across boxes
            result = await executeWrites(operationId);

            // Step 4: Asynchronously flush all affected target boxes
            await Future.wait(affectedBoxes.map((b) => b.flush()));

            // Step 5: Validate in-memory logical consistency and financial invariants
            validateInvariants();

            // Step 6: Persist committed journal status
            operationModel = operationModel.copyWith(
              status: 'committed',
              updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
            );
            await journalDataSource.saveOperation(operationModel);

            // Step 7: Flush journal box again
            await journalDataSource.flush();

            return result;
          } catch (e, stack) {
            // In-process failure: execute compensating rollback
            try {
              await rollbackWrites(operationId);
            } catch (rollbackErr) {
              if (kDebugMode) {
                debugPrint('Error during compensating rollback: $rollbackErr');
              }
            }

            final errorMap = {
              'error': e.toString(),
              'stack': stack.toString(),
              ...payload,
            };
            operationModel = operationModel.copyWith(
              status: 'rolled_back',
              payloadJson: jsonEncode(errorMap),
              updatedAtEpoch: DateTime.now().millisecondsSinceEpoch,
            );
            try {
              await journalDataSource.saveOperation(operationModel);
              await journalDataSource.flush();
            } catch (_) {}

            rethrow;
          }
        } finally {
          _releaseResourceLocks(newLocksToAcquire);
        }
      },
      zoneValues: {
        #heldResourceLocks: {...currentHeldLocks, ...newLocksToAcquire},
      },
    );
  }
}
