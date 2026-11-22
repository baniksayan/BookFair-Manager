/// Base exception class for all database-related errors in BookFair Manager.
class DatabaseException implements Exception {
  const DatabaseException(this.message, [this.cause]);

  final String message;
  final dynamic cause;

  @override
  String toString() {
    if (cause != null) {
      return 'DatabaseException: $message (Cause: $cause)';
    }
    return 'DatabaseException: $message';
  }
}

/// Thrown when an expected entity record cannot be located in the database.
class RecordNotFoundException extends DatabaseException {
  const RecordNotFoundException(String entityName, String id)
    : super('$entityName with ID "$id" was not found.');
}

/// Thrown when an operation violates referential integrity constraints
/// (e.g. deleting a partner that has recorded investments, or referencing a non-existent fair).
class ReferentialIntegrityException extends DatabaseException {
  const ReferentialIntegrityException(super.message, [super.cause]);
}

/// Thrown when an operation attempts to create a duplicate record where uniqueness is required.
class DuplicateRecordException extends DatabaseException {
  const DuplicateRecordException(super.message, [super.cause]);
}

/// Thrown when Hive initialization or box opening fails.
class DatabaseInitializationException extends DatabaseException {
  const DatabaseInitializationException(super.message, [super.cause]);
}

/// Thrown when entity data fails domain validation prior to persistence.
class ValidationException extends DatabaseException {
  const ValidationException(super.message);
}

/// Thrown when an idempotency key is submitted with differing financial details.
class IdempotencyConflictException extends DatabaseException {
  const IdempotencyConflictException(super.message);
}

/// Thrown when an account is locked due to an unresolved financial recovery failure.
class AccountQuarantinedException extends DatabaseException {
  const AccountQuarantinedException(super.message);
}
