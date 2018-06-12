import 'dart:async';

import 'package:sqflite/sqflite.dart';

class Query {
  final String sql;
  final List args;

  Query(this.sql, this.args);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Query &&
          runtimeType == other.runtimeType &&
          sql == other.sql &&
          args == other.args;

  @override
  int get hashCode => sql.hashCode ^ args.hashCode;
}

class TableStream {
  bool _dirty;
  final Future<Database> db;
  final Query query;
  StreamController<List<Map<String, dynamic>>> controller;

  TableStream(this.db, this.query) {
    controller = StreamController(onListen: _load, onResume: _loadIfDirty);
  }

  _load() async {
    var result = await (await db).rawQuery(query.sql, query.args);
    controller.add(result);
  }

  _loadIfDirty() async {
    if (_dirty) {
      _dirty = false;
      await _load();
    }
  }

  notify() async {
    if (controller.isPaused) {
      _dirty = true;
    } else {
      await _load();
    }
  }
}

class LiveTable {
  final Future<Database> db;
  final List<LiveTable> dependents;
  Map<Query, TableStream> streams = Map();

  LiveTable(this.db, [this.dependents]);

  Stream<List<Map<String, dynamic>>> query(String sql, [List args]) {
    var query = Query(sql, args);
    var stream = streams.putIfAbsent(query, () => TableStream(db, query));
    return stream.controller.stream;
  }

  notify() async {
    for (var stream in streams.values) {
      stream.notify();
    }
    if (dependents != null) {
      for (var value in dependents) {
        value.notify();
      }
    }
  }

  Future<int> insert(String sql, [List<dynamic> args]) async {
    var result = await (await db).rawInsert(sql, args);
    await notify();
    return result;
  }

  Future<int> update(String sql, [List<dynamic> args]) async {
    var result = await (await db).rawUpdate(sql, args);
    await notify();
    return result;
  }

  Future<int> delete(String sql, [List<dynamic> args]) async {
    var result = await (await db).rawDelete(sql, args);
    await notify();
    return result;
  }
}
