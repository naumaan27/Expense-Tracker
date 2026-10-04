import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/tables.dart' show TxType;
import 'project_model.dart';

class ProjectsRepository {
  ProjectsRepository(this._db);

  final AppDatabase _db;
  bool _initialized = false;
  final _changeController = StreamController<void>.broadcast();

  void _notify() => _changeController.add(null);

  Future<void> _ensureTables() async {
    if (_initialized) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        client_name TEXT NOT NULL,
        stream TEXT NOT NULL,
        quote_amount INTEGER NOT NULL,
        due_date TEXT,
        note TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at TEXT NOT NULL
      );
    ''');
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS project_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL REFERENCES projects(id) ON DELETE CASCADE,
        transaction_id INTEGER,
        amount INTEGER NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        created_at TEXT NOT NULL
      );
    ''');
    _initialized = true;
  }

  Stream<List<Project>> watchProjects() async* {
    await _ensureTables();
    yield await getProjects();
    yield* _changeController.stream.asyncMap((_) => getProjects());
  }

  Future<List<Project>> getProjects() async {
    await _ensureTables();
    final rows = await _db.customSelect('SELECT * FROM projects ORDER BY created_at DESC').get();
    return rows.map((r) => Project.fromMap(r.data)).toList();
  }

  Stream<Project?> watchProject(int id) async* {
    await _ensureTables();
    yield await getProject(id);
    yield* _changeController.stream.asyncMap((_) => getProject(id));
  }

  Future<Project?> getProject(int id) async {
    await _ensureTables();
    final row = await _db
        .customSelect(
          'SELECT * FROM projects WHERE id = ?',
          variables: [Variable.withInt(id)],
        )
        .getSingleOrNull();
    return row != null ? Project.fromMap(row.data) : null;
  }

  Stream<List<ProjectPayment>> watchPaymentsForProject(int projectId) async* {
    await _ensureTables();
    yield await getPaymentsForProject(projectId);
    yield* _changeController.stream.asyncMap((_) => getPaymentsForProject(projectId));
  }

  Future<List<ProjectPayment>> getPaymentsForProject(int projectId) async {
    await _ensureTables();
    final rows = await _db
        .customSelect(
          'SELECT * FROM project_payments WHERE project_id = ? ORDER BY date DESC, created_at DESC',
          variables: [Variable.withInt(projectId)],
        )
        .get();
    return rows.map((r) => ProjectPayment.fromMap(r.data)).toList();
  }

  Stream<List<ProjectPayment>> watchAllPayments() async* {
    await _ensureTables();
    yield await getAllPayments();
    yield* _changeController.stream.asyncMap((_) => getAllPayments());
  }

  Future<List<ProjectPayment>> getAllPayments() async {
    await _ensureTables();
    final rows = await _db
        .customSelect('SELECT * FROM project_payments ORDER BY date DESC')
        .get();
    return rows.map((r) => ProjectPayment.fromMap(r.data)).toList();
  }

  Future<int> createProject({
    required String title,
    required String clientName,
    required String stream,
    required Money quoteAmount,
    DateTime? dueDate,
    String? note,
  }) async {
    await _ensureTables();
    final now = DateTime.now();
    await _db.customInsert(
      '''
      INSERT INTO projects (title, client_name, stream, quote_amount, due_date, note, status, created_at)
      VALUES (?, ?, ?, ?, ?, ?, 'active', ?)
      ''',
      variables: [
        Variable.withString(title.trim()),
        Variable.withString(clientName.trim()),
        Variable.withString(stream.trim()),
        Variable.withInt(quoteAmount.paise),
        Variable.withString(dueDate?.toIso8601String() ?? ''),
        Variable.withString(note?.trim() ?? ''),
        Variable.withString(now.toIso8601String()),
      ],
    );
    final row = await _db.customSelect('SELECT last_insert_rowid() AS id').getSingle();
    final id = row.data['id'] as int;
    _notify();
    return id;
  }

  Future<void> updateProjectStatus(int projectId, ProjectStatus status) async {
    await _ensureTables();
    await _db.customUpdate(
      'UPDATE projects SET status = ? WHERE id = ?',
      variables: [
        Variable.withString(status.name),
        Variable.withInt(projectId),
      ],
    );
    _notify();
  }

  Future<void> updateProject({
    required int id,
    required String title,
    required String clientName,
    required String stream,
    required Money quoteAmount,
    DateTime? dueDate,
    String? note,
  }) async {
    await _ensureTables();
    await _db.customUpdate(
      '''
      UPDATE projects 
      SET title = ?, client_name = ?, stream = ?, quote_amount = ?, due_date = ?, note = ?
      WHERE id = ?
      ''',
      variables: [
        Variable.withString(title.trim()),
        Variable.withString(clientName.trim()),
        Variable.withString(stream.trim()),
        Variable.withInt(quoteAmount.paise),
        Variable.withString(dueDate?.toIso8601String() ?? ''),
        Variable.withString(note?.trim() ?? ''),
        Variable.withInt(id),
      ],
    );
    _notify();
  }

  Future<void> deleteProject(int projectId) async {
    await _ensureTables();
    await _db.customStatement(
      'DELETE FROM projects WHERE id = ?',
      [projectId],
    );
    _notify();
  }

  /// Records an actual received payment for a project:
  /// 1. Posts an Income transaction into the selected account (e.g. Bank).
  /// 2. Records the payment in `project_payments` linked to that transaction.
  /// 3. If total payments meet or exceed the quote, optionally marks project completed.
  Future<void> recordPayment({
    required Project project,
    required Money amount,
    required int accountId,
    int? categoryId,
    required DateTime date,
    String? note,
  }) async {
    await _ensureTables();

    final txNote = note != null && note.trim().isNotEmpty
        ? 'Project: ${project.title} (${note.trim()})'
        : 'Project: ${project.title}';

    // 1. Post real income transaction
    final txId = await _db.addTransaction(
      type: TxType.income,
      amount: amount,
      accountId: accountId,
      categoryId: categoryId,
      date: date,
      payee: project.clientName,
      note: txNote,
    );

    // 2. Link payment
    final now = DateTime.now();
    await _db.customInsert(
      '''
      INSERT INTO project_payments (project_id, transaction_id, amount, date, note, created_at)
      VALUES (?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withInt(project.id),
        Variable.withInt(txId),
        Variable.withInt(amount.paise),
        Variable.withString(date.toIso8601String()),
        Variable.withString(note?.trim() ?? ''),
        Variable.withString(now.toIso8601String()),
      ],
    );

    // Check if fully paid
    final existing = await getPaymentsForProject(project.id);
    final totalReceived = existing.fold<int>(0, (sum, p) => sum + p.amount.paise);
    if (totalReceived >= project.quoteAmount.paise && project.status == ProjectStatus.active) {
      await updateProjectStatus(project.id, ProjectStatus.completed);
    } else {
      _notify();
    }
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  final db = ref.watch(dbProvider);
  return ProjectsRepository(db);
});

final allProjectsStreamProvider = StreamProvider<List<Project>>((ref) {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.watchProjects();
});

final allProjectPaymentsStreamProvider = StreamProvider<List<ProjectPayment>>((ref) {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.watchAllPayments();
});

final projectPaymentsStreamProvider = StreamProvider.family<List<ProjectPayment>, int>((ref, projectId) {
  final repo = ref.watch(projectsRepositoryProvider);
  return repo.watchPaymentsForProject(projectId);
});
