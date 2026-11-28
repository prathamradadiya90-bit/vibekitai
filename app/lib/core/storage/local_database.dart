import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';
import '../../models/history_item.dart';
import 'preferences_service.dart';

class LocalDatabase {
  static const String _tableName = 'creations_history';
  static const int _maxFallbackItems = 200;
  final PreferencesService? _prefs;
  Database? _db;
  final List<HistoryItem> _fallbackMemoryStore = [];

  LocalDatabase({PreferencesService? prefs}) : _prefs = prefs;

  Future<void> init() async {
    if (kIsWeb) {
      _loadFallbackFromPrefs();
      return;
    }
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'vibekit_ai.db');

      _db = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE $_tableName (
              id TEXT PRIMARY KEY,
              title TEXT NOT NULL,
              content TEXT NOT NULL,
              type TEXT NOT NULL,
              category TEXT NOT NULL,
              created_at TEXT NOT NULL,
              is_favorite INTEGER NOT NULL DEFAULT 0,
              extra_data TEXT
            )
          ''');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_history_created_at ON $_tableName (created_at DESC)');
          await db
              .execute('CREATE INDEX IF NOT EXISTS idx_history_type ON $_tableName (type)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_history_type_created ON $_tableName (type, created_at DESC)');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_history_favorite ON $_tableName (is_favorite)');
        },
      );
    } catch (e) {
      debugPrint(
          'LocalDatabase: SQLite native init failed ($e). Using persistent prefs fallback.');
      _db = null;
      _loadFallbackFromPrefs();
    }
  }

  void _loadFallbackFromPrefs() {
    final raw = _prefs?.getWebHistoryJson();
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        _fallbackMemoryStore.clear();
        for (final entry in decoded) {
          if (entry is Map) {
            try {
              _fallbackMemoryStore.add(
                HistoryItem.fromMap(Map<String, dynamic>.from(entry)),
              );
            } catch (_) {
              // Skip malformed record
            }
          }
        }
      }
    } catch (e) {
      debugPrint('LocalDatabase: Failed to restore web history fallback: $e');
    }
  }

  Future<void> _persistFallback() async {
    if (_prefs == null) return;
    if (_fallbackMemoryStore.isEmpty) {
      await _prefs.setWebHistoryJson(null);
      return;
    }
    final capped = _fallbackMemoryStore.take(_maxFallbackItems).map((i) => i.toMap()).toList();
    try {
      await _prefs.setWebHistoryJson(jsonEncode(capped));
    } catch (e) {
      debugPrint('LocalDatabase: Failed to persist web history fallback: $e');
    }
  }

  Future<void> insertItem(HistoryItem item) async {
    if (_db != null) {
      await _db!.insert(
        _tableName,
        item.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } else {
      _fallbackMemoryStore.removeWhere((i) => i.id == item.id);
      _fallbackMemoryStore.insert(0, item);
      if (_fallbackMemoryStore.length > _maxFallbackItems) {
        _fallbackMemoryStore.removeRange(_maxFallbackItems, _fallbackMemoryStore.length);
      }
      await _persistFallback();
    }
  }

  Future<List<HistoryItem>> getItems({
    String? type,
    bool? onlyFavorites,
    String? query,
    int limit = 50,
    int offset = 0,
  }) async {
    if (_db != null) {
      final whereClauses = <String>[];
      final whereArgs = <dynamic>[];

      if (type != null && type.isNotEmpty && type != 'all') {
        whereClauses.add('type = ?');
        whereArgs.add(type);
      }

      if (onlyFavorites == true) {
        whereClauses.add('is_favorite = 1');
      }

      if (query != null && query.trim().isNotEmpty) {
        final escaped = query
            .trim()
            .replaceAll(r'\', r'\\')
            .replaceAll('%', r'\%')
            .replaceAll('_', r'\_');
        whereClauses.add(r"(title LIKE ? ESCAPE '\' OR content LIKE ? ESCAPE '\')");
        whereArgs.add('%$escaped%');
        whereArgs.add('%$escaped%');
      }

      final whereString =
          whereClauses.isNotEmpty ? whereClauses.join(' AND ') : null;

      final results = await _db!.query(
        _tableName,
        where: whereString,
        whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
        orderBy: 'created_at DESC',
        limit: limit,
        offset: offset,
      );

      return results.map((m) => HistoryItem.fromMap(m)).toList();
    } else {
      var list = List<HistoryItem>.from(_fallbackMemoryStore);
      if (type != null && type.isNotEmpty && type != 'all') {
        list = list.where((i) => i.type == type).toList();
      }
      if (onlyFavorites == true) {
        list = list.where((i) => i.isFavorite).toList();
      }
      if (query != null && query.trim().isNotEmpty) {
        final q = query.trim().toLowerCase();
        list = list
            .where((i) =>
                i.title.toLowerCase().contains(q) ||
                i.content.toLowerCase().contains(q))
            .toList();
      }
      if (offset >= list.length) return [];
      return list.skip(offset).take(limit).toList();
    }
  }

  Future<HistoryItem?> findItemByContent(String content) async {
    if (_db != null) {
      final results = await _db!.query(
        _tableName,
        where: 'content = ?',
        whereArgs: [content],
        limit: 1,
      );
      if (results.isNotEmpty) {
        return HistoryItem.fromMap(results.first);
      }
      return null;
    } else {
      final idx = _fallbackMemoryStore.indexWhere((i) => i.content == content);
      if (idx != -1) return _fallbackMemoryStore[idx];
      return null;
    }
  }

  /// Toggles favorite on an existing item matching [content], or inserts a single
  /// new favorited record if none exists yet. Returns the new favorite status.
  Future<bool> toggleFavoriteByContent({
    required String content,
    String? title,
    String? type,
    String? category,
  }) async {
    final existing = await findItemByContent(content);
    if (existing != null) {
      final newFav = !existing.isFavorite;
      await toggleFavorite(existing.id, newFav);
      return newFav;
    } else {
      final newItem = HistoryItem(
        id: const Uuid().v4(),
        title: title ?? 'Saved Favorite',
        content: content,
        type: type ?? 'general',
        category: category ?? 'general',
        createdAt: DateTime.now(),
        isFavorite: true,
      );
      await insertItem(newItem);
      return true;
    }
  }

  Future<void> toggleFavorite(String id, bool isFavorite) async {
    if (_db != null) {
      await _db!.update(
        _tableName,
        {'is_favorite': isFavorite ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      final index = _fallbackMemoryStore.indexWhere((i) => i.id == id);
      if (index != -1) {
        _fallbackMemoryStore[index] =
            _fallbackMemoryStore[index].copyWith(isFavorite: isFavorite);
        await _persistFallback();
      }
    }
  }

  Future<void> deleteItem(String id) async {
    if (_db != null) {
      await _db!.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    } else {
      _fallbackMemoryStore.removeWhere((i) => i.id == id);
      await _persistFallback();
    }
  }

  Future<void> clearAll() async {
    if (_db != null) {
      await _db!.delete(_tableName);
    }
    _fallbackMemoryStore.clear();
    await _persistFallback();
  }
}
