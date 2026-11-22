import 'dart:io';

import 'package:bookfair_manager/core/database/app_database.dart';
import 'package:bookfair_manager/core/database/database_initializer.dart';

/// Test utility for setting up and clearing isolated Hive environments.
abstract final class TestDatabaseHelper {
  static Directory? _currentTempDir;

  /// Initializes the isolated database once for a test file/suite.
  static Future<Directory> setUpSuiteDatabase() async {
    final tempDir = await Directory.systemTemp.createTemp('bookfair_test_db_');
    _currentTempDir = tempDir;
    await DatabaseInitializer.initTest(path: tempDir.path);
    return tempDir;
  }

  /// Closes Hive and removes the temporary directory at the end of a test suite.
  static Future<void> tearDownSuiteDatabase() async {
    await DatabaseInitializer.close();
    final target = _currentTempDir;
    if (target != null && target.existsSync()) {
      try {
        await target.delete(recursive: true);
      } catch (_) {}
    }
    _currentTempDir = null;
  }

  /// Clears all tables to ensure clean, isolated state between individual test cases.
  static Future<void> resetDatabase() async {
    const db = AppDatabase();
    await db.clearAll();
  }
}
