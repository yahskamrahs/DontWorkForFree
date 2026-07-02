import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/shift_record_model.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = join(dir, 'dwff_shifts.db');
    try {
      return await _openAt(path);
    } catch (_) {
      // The DB file may be corrupted (e.g. the process was killed mid-write).
      // Nuke it and start fresh rather than blocking app startup forever.
      await deleteDatabase(path);
      return await _openAt(path);
    }
  }

  Future<Database> _openAt(String path) => openDatabase(
        path,
        version: 1,
        onCreate: (db, _) => db.execute('''
        CREATE TABLE shift_records (
          id                         INTEGER PRIMARY KEY AUTOINCREMENT,
          date                       TEXT    NOT NULL,
          punch_in                   TEXT    NOT NULL,
          punch_out                  TEXT,
          total_break_seconds        INTEGER NOT NULL DEFAULT 0,
          scheduled_duration_minutes INTEGER NOT NULL,
          profile_id                 TEXT    NOT NULL,
          profile_name               TEXT    NOT NULL
        )
      '''),
      );

  Future<int> insertRecord(ShiftRecordModel record) async =>
      (await db).insert('shift_records', record.toMap());

  Future<void> updateRecord(ShiftRecordModel record) async {
    if (record.id == null) return;
    await (await db).update(
      'shift_records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  Future<ShiftRecordModel?> getOpenRecord() async {
    final rows = await (await db).query(
      'shift_records',
      where: 'punch_out IS NULL',
      limit: 1,
    );
    return rows.isEmpty ? null : ShiftRecordModel.fromMap(rows.first);
  }

  Future<List<ShiftRecordModel>> getRecentRecords({int limit = 90}) async {
    final rows = await (await db).query(
      'shift_records',
      where: 'punch_out IS NOT NULL',
      orderBy: 'date DESC, punch_in DESC',
      limit: limit,
    );
    return rows.map(ShiftRecordModel.fromMap).toList();
  }

  Future<List<ShiftRecordModel>> getWeekRecords(DateTime weekStart) async {
    final end = weekStart.add(const Duration(days: 7));
    final rows = await (await db).query(
      'shift_records',
      where: 'date >= ? AND date < ? AND punch_out IS NOT NULL',
      whereArgs: [ShiftRecordModel.dateKey(weekStart), ShiftRecordModel.dateKey(end)],
    );
    return rows.map(ShiftRecordModel.fromMap).toList();
  }

  Future<void> deleteRecord(int id) async =>
      (await db).delete('shift_records', where: 'id = ?', whereArgs: [id]);

  Future<void> clearAll() async => (await db).delete('shift_records');
}
