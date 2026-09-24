import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/features/profit_loss/models/profit_loss_model.dart';

/// Profit & Loss, super-admin only.
///
/// The server refuses any other account with 403, so a failure here is either
/// that or the network; neither is worth distinguishing in the UI beyond
/// "could not load".
class ProfitLossService {
  final Dio _dio = ApiClient().dio;

  /// PL_PAGESIZE_V1 - [perPage] asks the paginator for a usable page.
  ///
  /// The direct-sales block is a paginator and this call left it on the
  /// endpoint's default, which is 15. A real month is several hundred
  /// sales, so scrolling one end to end was around thirty round trips, and
  /// every one of them is a stall the agent sees. 50 is the same list in
  /// nine.
  ///
  /// It is sent on every call, the first page and the totals refetch
  /// included, and that is deliberate: current_page and last_page come back
  /// from the paginator and the screen compares them to decide whether more
  /// exists. If two calls counted in different page sizes those two numbers
  /// would disagree about where the end is.
  ///
  /// If the endpoint fixes its own page size and ignores per_page this is
  /// inert - an unknown query parameter, not an error - and the screen is
  /// no worse off than before.
  Future<ProfitLossReport?> getReport({
    String? month,
    int page = 1,
    int perPage = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/agent/profit-loss',
        queryParameters: {
          // AGENT_APP_P1 — null-aware element; same meaning as the `if`.
          'month': ?month,
          'page': page,
          'per_page': perPage,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        return ProfitLossReport.fromJson(
          Map<String, dynamic>.from(response.data),
        );
      }
    } catch (e) {
      debugPrint('P&L load failed: $e');
    }
    return null;
  }

  Future<bool> addEntry({
    required String direction,
    required String category,
    required String name,
    required int amount,
    required String periodMonth,
    String? notes,
  }) async {
    try {
      final response = await _dio.post(
        '/agent/profit-loss/entry',
        data: {
          'direction': direction,
          'category': category,
          'name': name,
          'amount_mmk': amount,
          'period_month': periodMonth,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
      );
      return response.statusCode == 201 || response.statusCode == 200;
    } catch (e) {
      debugPrint('P&L add entry failed: $e');
      return false;
    }
  }

  Future<bool> deleteEntry(int id) async {
    try {
      final response = await _dio.delete('/agent/profit-loss/entry/$id');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('P&L delete entry failed: $e');
      return false;
    }
  }

  /// Copies last month's expenses into this one. Recurring costs — VPS boxes,
  /// domains — are the same every month, and re-entering six of them by hand
  /// is how a month ends up under-costed.
  Future<int?> copyExpenses(String month) async {
    try {
      final response = await _dio.post(
        '/agent/profit-loss/copy-expenses',
        data: {'month': month},
      );
      if (response.statusCode == 200) {
        return response.data['copied'] ?? 0;
      }
    } catch (e) {
      debugPrint('P&L copy expenses failed: $e');
    }
    return null;
  }

  /// Excludes a sale from revenue, or restores it. Reversible by design: a row
  /// wrongly excluded should not need a database edit to put back.
  Future<bool?> toggleExclude(int creditTransactionId, {String? reason}) async {
    try {
      final response = await _dio.post(
        '/agent/profit-loss/toggle-exclude',
        data: {
          'credit_transaction_id': creditTransactionId,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        },
      );
      if (response.statusCode == 200) {
        return response.data['excluded'] == true;
      }
    } catch (e) {
      debugPrint('P&L toggle exclude failed: $e');
    }
    return null;
  }
}
