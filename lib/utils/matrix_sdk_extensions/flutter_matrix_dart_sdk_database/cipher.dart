import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:flutter_gen/gen_l10n/l10n.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/utils/client_manager.dart';

const _passwordStorageKey = 'database_password';

Future<String?> getDatabaseCipher() async {
  String? password;

  try {
    const secureStorage = FlutterSecureStorage();
    final containsEncryptionKey = await secureStorage.read(key: _passwordStorageKey) != null;
    if (!containsEncryptionKey) {
      final rng = Random.secure();
      final list = Uint8List(32);
      list.setAll(0, Iterable.generate(list.length, (i) => rng.nextInt(256)));
      final newPassword = base64UrlEncode(list);
      await secureStorage.write(
        key: _passwordStorageKey,
        value: newPassword,
      );
    }
    // workaround for if we just wrote to the key and it still doesn't exist
    password = await secureStorage.read(key: _passwordStorageKey);
    if (password == null) throw MissingPluginException();
  } on MissingPluginException catch (e) {
    const FlutterSecureStorage().delete(key: _passwordStorageKey).catchError((_) {});
    Logs().w('Database encryption is not supported on this platform', e);
    _sendNoEncryptionWarning(e);
  } catch (e, s) {
    const FlutterSecureStorage().delete(key: _passwordStorageKey).catchError((_) {});
    Logs().w('Unable to init database encryption', e, s);
    _sendNoEncryptionWarning(e);
  }

  return password;
}

void _sendNoEncryptionWarning(Object exception) async {
  final store = await SharedPreferences.getInstance();

  final isStored = store.getBool(SettingKeys.noEncryptionWarningShown);

  if (isStored == true) return;

  final l10n = lookupL10n(PlatformDispatcher.instance.locale);
  ClientManager.sendInitNotification(
    l10n.noDatabaseEncryption,
    exception.toString(),
  );

  await store.setBool(SettingKeys.noEncryptionWarningShown, true);
}

class UserPreferences {
  static const String _userKey = 'dashboard_rooms_user';

  static Future<SharedPreferences> get _instance async => await SharedPreferences.getInstance();

  static Future<List<String>> getRooms() async {
    final prefs = await _instance;
    return prefs.getStringList(_userKey) ?? [];
  }

  static Future<void> addRoom(String room) async {
    final prefs = await _instance;
    final rooms = prefs.getStringList(_userKey) ?? [];
    bool alreadyExists = false;
    for (final r in rooms) {
      if (r == room) {
        alreadyExists = true;
        break;
      }
    }
    if (alreadyExists) return;
    rooms.add(room);
    await prefs.setStringList(_userKey, rooms);
  }

  static Future<void> updateRoom(int index, String newRoom) async {
    final prefs = await _instance;
    final rooms = prefs.getStringList(_userKey) ?? [];
    if (index >= 0 && index < rooms.length) {
      rooms[index] = newRoom;
      await prefs.setStringList(_userKey, rooms);
    }
  }

  static Future<void> deleteRoom(int index) async {
    final prefs = await _instance;
    final rooms = prefs.getStringList(_userKey) ?? [];
    if (index >= 0 && index < rooms.length) {
      rooms.removeAt(index);
      await prefs.setStringList(_userKey, rooms);
    }
  }

  static Future<void> clearRooms() async {
    final prefs = await _instance;
    await prefs.remove(_userKey);
  }
}
