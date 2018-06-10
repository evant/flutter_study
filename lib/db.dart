import 'dart:async';

import 'package:sqflite/sqflite.dart';

class LiveTable {
  final Future<Database> db;
  final List<LiveTable> dependents;
  final String sql;
  final List<dynamic> args;
  StreamController<List<Map<String, dynamic>>> _streamController;
  bool _dirty;

  LiveTable(this.db, this.sql, [this.args, this.dependents]) {
    _streamController =
        StreamController(onListen: _load, onResume: _loadIfDirty);
  }

  get stream => _streamController.stream;

  _load() async {
    var result = await (await db).rawQuery(sql, args);
    _streamController.add(result);
  }

  _loadIfDirty() async {
    if (_dirty) {
      _dirty = false;
      await _load();
    }
  }

  _notify() async {
    if (_streamController.isPaused) {
      _dirty = true;
    } else {
      await _load();
    }
    if (dependents != null) {
      for (var value in dependents) {
        value._notify();
      }
    }
  }

  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic> args]) async {
    return await (await db).rawQuery(sql, args);
  }

  Future<int> insert(String sql, [List<dynamic> args]) async {
    var result = await (await db).rawInsert(sql, args);
    await _notify();
    return result;
  }

  Future<int> delete(String sql, [List<dynamic> args]) async {
    var result = await (await db).rawDelete(sql, args);
    await _notify();
    return result;
  }
}
