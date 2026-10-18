import 'dart:convert';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Petit stockage local écrit dans un fichier JSON du dossier privé de l'app.
/// Il remplace le plugin shared_preferences (qui plante au démarrage avec les versions récentes).
class FileStore {
  static File? _file;
  static final Map<String, String> _data = {};

  static Future<Directory> _dir() async {
    var pkg = 'dz.nqata.nqata_merchant';
    try {
      final raw = utf8.decode(await File('/proc/self/cmdline').readAsBytes(), allowMalformed: true);
      final n = raw.split('\u0000').first.trim();
      if (n.contains('.')) pkg = n;
    } catch (_) {}
    for (final base in ['/data/user/0/$pkg/app_flutter', '/data/data/$pkg/app_flutter', '/data/user/0/$pkg/files', '/data/data/$pkg/files']) {
      try {
        final d = Directory(base);
        if (await d.exists()) return d;
      } catch (_) {}
    }
    return Directory.systemTemp;
  }

  static Future<void> init() async {
    try {
      final d = await _dir();
      _file = File('${d.path}/nqata_pro_store.json');
      if (await _file!.exists()) {
        final m = jsonDecode(await _file!.readAsString());
        if (m is Map) m.forEach((k, v) => _data['$k'] = '$v');
      }
    } catch (_) {}
  }

  static String? get(String key) => _data[key];

  static void _save() {
    try {
      _file?.writeAsStringSync(jsonEncode(_data), flush: true);
    } catch (_) {}
  }

  static void set(String key, String value) {
    _data[key] = value;
    _save();
  }

  static void remove(String key) {
    _data.remove(key);
    _save();
  }
}

/// Session Supabase conservée dans ce fichier (pour rester connecté entre deux ouvertures).
class FileLocalStorage extends LocalStorage {
  FileLocalStorage();
  static const _k = 'supabase_session';
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => FileStore.get(_k) != null;
  @override
  Future<String?> accessToken() async => FileStore.get(_k);
  @override
  Future<void> removePersistedSession() async => FileStore.remove(_k);
  @override
  Future<void> persistSession(String persistSessionString) async => FileStore.set(_k, persistSessionString);
}

class FileAsyncStorage extends GotrueAsyncStorage {
  FileAsyncStorage();
  @override
  Future<String?> getItem({required String key}) async => FileStore.get('async_$key');
  @override
  Future<void> setItem({required String key, required String value}) async => FileStore.set('async_$key', value);
  @override
  Future<void> removeItem({required String key}) async => FileStore.remove('async_$key');
}
