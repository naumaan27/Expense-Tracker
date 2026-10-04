import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/money.dart';
import '../../core/theme/app_colors.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Health status category based on credit card limit utilization.
enum CreditHealthStatus {
  healthy, // < 30%
  moderate, // 30% - 50%
  extensivelyUsed, // 50% - 100% (High / Extensively utilized warning)
  overLimit, // >= 100%
  unknown,
}

/// Helper model computing utilization metrics, remaining balance, and warning status.
class CreditCardUtilization {
  CreditCardUtilization({
    required this.limit,
    required this.utilized,
  })  : available = (limit.paise - utilized.paise) > 0
            ? Money.fromPaise(limit.paise - utilized.paise)
            : const Money.zero(),
        ratio = limit.paise > 0 ? (utilized.paise / limit.paise) : 0.0,
        percentage = limit.paise > 0
            ? ((utilized.paise / limit.paise) * 100).clamp(0.0, 999.0)
            : 0.0,
        status = _determineStatus(limit, utilized);

  final Money limit;
  final Money utilized;
  final Money available;
  final double ratio;
  final double percentage;
  final CreditHealthStatus status;

  static CreditHealthStatus _determineStatus(Money limit, Money utilized) {
    if (limit.paise <= 0) return CreditHealthStatus.unknown;
    final r = utilized.paise / limit.paise;
    if (r >= 1.0) return CreditHealthStatus.overLimit;
    if (r >= 0.50) return CreditHealthStatus.extensivelyUsed;
    if (r >= 0.30) return CreditHealthStatus.moderate;
    return CreditHealthStatus.healthy;
  }

  Color get statusColor => switch (status) {
        CreditHealthStatus.healthy => AppColors.income,
        CreditHealthStatus.moderate => const Color(0xFFF59E0B), // amber
        CreditHealthStatus.extensivelyUsed => const Color(0xFFF97316), // deep orange
        CreditHealthStatus.overLimit => AppColors.expense,
        CreditHealthStatus.unknown => Colors.grey,
      };

  IconData get statusIcon => switch (status) {
        CreditHealthStatus.healthy => Icons.check_circle_outline_rounded,
        CreditHealthStatus.moderate => Icons.info_outline_rounded,
        CreditHealthStatus.extensivelyUsed => Icons.warning_amber_rounded,
        CreditHealthStatus.overLimit => Icons.report_problem_rounded,
        CreditHealthStatus.unknown => Icons.credit_card_rounded,
      };

  String get statusBadgeLabel => switch (status) {
        CreditHealthStatus.healthy => 'Healthy (${percentage.toStringAsFixed(0)}%)',
        CreditHealthStatus.moderate => 'Moderate (${percentage.toStringAsFixed(0)}%)',
        CreditHealthStatus.extensivelyUsed => '⚠️ Extensively Used (${percentage.toStringAsFixed(0)}%)',
        CreditHealthStatus.overLimit => '🚨 Over Limit (${percentage.toStringAsFixed(0)}%)',
        CreditHealthStatus.unknown => '',
      };

  String get warningMessage => switch (status) {
        CreditHealthStatus.healthy =>
          'Healthy usage — spending is well below the recommended 30% threshold.',
        CreditHealthStatus.moderate =>
          'Moderate utilization — financial experts suggest keeping balance below 30% for a stronger credit score.',
        CreditHealthStatus.extensivelyUsed =>
          'Extensively Utilized — High card usage (>${percentage.toStringAsFixed(0)}%) may hurt your credit score and incur steep finance charges.',
        CreditHealthStatus.overLimit =>
          'Critical Warning: You have exceeded your card limit! Over-limit fees and penalty interest may apply.',
        CreditHealthStatus.unknown => '',
      };
}

/// Service managing credit card limits in a dedicated SQLite table.
class CreditCardLimitService {
  CreditCardLimitService(this._db);

  final AppDatabase _db;
  bool _initialized = false;
  final _streamController = StreamController<void>.broadcast();

  Future<void> _ensureTable() async {
    if (_initialized) return;
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS credit_card_limits (
        account_id INTEGER PRIMARY KEY,
        credit_limit_paise INTEGER NOT NULL,
        created_at TEXT NOT NULL
      );
    ''');
    _initialized = true;
  }

  void _notify() => _streamController.add(null);

  Future<Money?> getCreditLimit(int accountId) async {
    await _ensureTable();
    final rows = await _db.customSelect(
      'SELECT credit_limit_paise FROM credit_card_limits WHERE account_id = ?',
      variables: [Variable.withInt(accountId)],
    ).get();
    if (rows.isEmpty) return null;
    final paise = rows.first.data['credit_limit_paise'] as int;
    return Money.fromPaise(paise);
  }

  Stream<Money?> watchCreditLimit(int accountId) async* {
    await _ensureTable();
    yield await getCreditLimit(accountId);
    yield* _streamController.stream.asyncMap((_) => getCreditLimit(accountId));
  }

  Future<void> setCreditLimit(int accountId, Money limit) async {
    await _ensureTable();
    await _db.customStatement(
      '''
      INSERT INTO credit_card_limits (account_id, credit_limit_paise, created_at)
      VALUES (?, ?, ?)
      ON CONFLICT(account_id) DO UPDATE SET
        credit_limit_paise = excluded.credit_limit_paise;
      ''',
      [accountId, limit.paise, DateTime.now().toIso8601String()],
    );
    _notify();
  }

  Future<void> deleteCreditLimit(int accountId) async {
    await _ensureTable();
    await _db.customStatement(
      'DELETE FROM credit_card_limits WHERE account_id = ?',
      [accountId],
    );
    _notify();
  }

  Stream<Map<int, Money>> watchAllLimits() async* {
    await _ensureTable();
    yield await getAllLimits();
    yield* _streamController.stream.asyncMap((_) => getAllLimits());
  }

  Future<Map<int, Money>> getAllLimits() async {
    await _ensureTable();
    final rows = await _db.customSelect('SELECT account_id, credit_limit_paise FROM credit_card_limits').get();
    final map = <int, Money>{};
    for (final row in rows) {
      final accountId = row.data['account_id'] as int;
      final paise = row.data['credit_limit_paise'] as int;
      map[accountId] = Money.fromPaise(paise);
    }
    return map;
  }
}

final creditCardLimitServiceProvider = Provider<CreditCardLimitService>((ref) {
  final db = ref.watch(dbProvider);
  return CreditCardLimitService(db);
});

final creditCardLimitProvider = StreamProvider.family<Money?, int>((ref, accountId) {
  final service = ref.watch(creditCardLimitServiceProvider);
  return service.watchCreditLimit(accountId);
});

final allCreditCardLimitsProvider = StreamProvider<Map<int, Money>>((ref) {
  final service = ref.watch(creditCardLimitServiceProvider);
  return service.watchAllLimits();
});
