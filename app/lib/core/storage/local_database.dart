import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../models/history_item.dart';

class LocalDatabase {
  static const String _tableName = 'creations_history';
  Database? _db;
  final List<HistoryItem> _fallbackMemoryStore = [];

  Future<void> init() async {
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
          'LocalDatabase: SQLite native init failed ($e). Using secure memory fallback.');
      _db = null;
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
        whereClauses.add('(title LIKE ? OR content LIKE ?)');
        whereArgs.add('%${query.trim()}%');
        whereArgs.add('%${query.trim()}%');
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
    }
  }

  Future<void> clearAll() async {
    if (_db != null) {
      await _db!.delete(_tableName);
    }
    _fallbackMemoryStore.clear();
  }
}
