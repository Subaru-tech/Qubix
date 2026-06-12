
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/message.dart';

final dbServiceProvider = Provider<DbService>((ref) => DbService());

class DbService {
  static Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB('qubix.db');
    return _db!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE pending_messages (
        id TEXT PRIMARY KEY,
        threadId TEXT NOT NULL,
        content TEXT NOT NULL,
        createdAt TEXT NOT NULL
      )
    ''');
  }

  Future<void> savePendingMessage(Message message) async {
    final db = await database;
    await db.insert(
      'pending_messages',
      {
        'id': message.id,
        'threadId': message.threadId,
        'content': message.content,
        'createdAt': message.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Message>> getPendingMessages(String threadId) async {
    final db = await database;
    final maps = await db.query(
      'pending_messages',
      where: 'threadId = ?',
      whereArgs: [threadId],
      orderBy: 'createdAt ASC',
    );

    return maps.map((map) {
      return Message(
        id: map['id'] as String,
        threadId: map['threadId'] as String,
        role: 'user',
        content: map['content'] as String,
        status: MessageStatus.pending,
        createdAt: DateTime.parse(map['createdAt'] as String),
        isLocalPending: true,
      );
    }).toList();
  }

  Future<void> deletePendingMessage(String id) async {
    final db = await database;
    await db.delete(
      'pending_messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
