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

  Future<ProfitLossReport?> getReport({String? month, int page = 1}) async {
    try {
      final response = await _dio.get(
        '/agent/profit-loss',
        queryParameters: {if (month != null) 'month': month, 'page': page},
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
