import '../../core/money.dart';

enum ProjectStatus {
  active,
  completed,
  cancelled;

  static ProjectStatus fromString(String val) => switch (val.toLowerCase()) {
        'completed' => ProjectStatus.completed,
        'cancelled' => ProjectStatus.cancelled,
        _ => ProjectStatus.active,
      };
}

class Project {
  const Project({
    required this.id,
    required this.title,
    required this.clientName,
    required this.stream,
    required this.quoteAmount,
    this.dueDate,
    this.note,
    required this.status,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String clientName;
  final String stream; // e.g. 'Freelancing', 'Teaching', 'Consulting'
  final Money quoteAmount;
  final DateTime? dueDate;
  final String? note;
  final ProjectStatus status;
  final DateTime createdAt;

  factory Project.fromMap(Map<String, Object?> map) {
    return Project(
      id: map['id'] as int,
      title: map['title'] as String,
      clientName: map['client_name'] as String,
      stream: map['stream'] as String,
      quoteAmount: Money(map['quote_amount'] as int),
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      note: map['note'] as String?,
      status: ProjectStatus.fromString(map['status'] as String? ?? 'active'),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() => {
        'title': title,
        'client_name': clientName,
        'stream': stream,
        'quote_amount': quoteAmount.paise,
        'due_date': dueDate?.toIso8601String(),
        'note': note,
        'status': status.name,
        'created_at': createdAt.toIso8601String(),
      };
}

class ProjectPayment {
  const ProjectPayment({
    required this.id,
    required this.projectId,
    this.transactionId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  final int id;
  final int projectId;
  final int? transactionId;
  final Money amount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  factory ProjectPayment.fromMap(Map<String, Object?> map) {
    return ProjectPayment(
      id: map['id'] as int,
      projectId: map['project_id'] as int,
      transactionId: map['transaction_id'] as int?,
      amount: Money(map['amount'] as int),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  Map<String, Object?> toMap() => {
        'project_id': projectId,
        'transaction_id': transactionId,
        'amount': amount.paise,
        'date': date.toIso8601String(),
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };
}
