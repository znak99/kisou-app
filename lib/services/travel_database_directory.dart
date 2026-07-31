import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

const _travelStorageChannel = MethodChannel('jp.kisou/travel_storage');

/// Returns a platform-private directory for the travel SQLite database.
///
/// iOS preparation is native and fail-closed: the directory is excluded from
/// backup and protected while the device is locked before SQLite may open it.
Future<String> prepareTravelDatabaseDirectory() async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    final path = await _travelStorageChannel.invokeMethod<String>(
      'prepareTravelDatabaseDirectory',
    );
    if (path == null || path.isEmpty) {
      throw StateError('iOS travel database protection was not applied.');
    }
    return path;
  }
  return getDatabasesPath();
}
