// test/models_test.dart
//
// AGENT_APP_TESTS_V1 — the parsing tolerance the backend forces on us.
//
// The API is PHP. A numeric column arrives as 5000 from one endpoint and as
// "5000" from another, and as null wherever a join missed. AGENT_APP_F1 made
// every fromJson read those three shapes the same way; before it, a single
// bad row threw inside fromJson and blanked the whole page. These are the
// tests for exactly that, because it is the bug class that took a screen down.
//
// Pure unit tests: no binding, no network, no plugins.
import 'package:flutter_test/flutter_test.dart';

import 'package:vpn_agent_app/features/agent_management/models/agent_model.dart';
import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';
import 'package:vpn_agent_app/features/history/models/renewal_request_model.dart';
import 'package:vpn_agent_app/features/profit_loss/models/profit_loss_model.dart';
import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';

void main() {
  group('VpnUser.fromJson', () {
    // The same row three ways. The list endpoint sends ints, the detail
    // endpoint sends the same columns as strings, and a removed plan leaves
    // the join null.
    const asInt = <String, dynamic>{
      'id': 41,
      'username': 'mt_0041',
      'status': 'active',
      'plan': {'plan_name': 'Private 1 Month'},
      'subscription_expiry_date': '2026-10-24',
      'is_online': true,
      'extra_device_slots': 2,
      'business_plan_id': 7,
      'business_plan': {
        'plan_name': 'Business 5',
        'price_per_month_credits': 5000,
      },
    };

    const asString = <String, dynamic>{
      'id': '41',
      'username': 'mt_0041',
      'status': 'active',
      'plan': {'plan_name': 'Private 1 Month'},
      'subscription_expiry_date': '2026-10-24',
      'is_online': '1',
      'extra_device_slots': '2',
      'business_plan_id': '7',
      'business_plan': {
        'plan_name': 'Business 5',
        'price_per_month_credits': '5000',
      },
    };

    const asNull = <String, dynamic>{
      'id': 41,
      'username': null,
      'status': null,
      'plan': null,
      'subscription_expiry_date': null,
      'is_online': null,
      'extra_device_slots': null,
      'business_plan_id': null,
      'business_plan': null,
    };

    test('an int field and its String twin parse to the same value', () {
      final a = VpnUser.fromJson(asInt);
      final b = VpnUser.fromJson(asString);

      expect(a.id, 41);
      expect(b.id, 41);
      expect(a.extraDeviceSlots, 2);
      expect(b.extraDeviceSlots, 2);
      expect(a.businessPlanId, 7);
      expect(b.businessPlanId, 7);
      expect(a.businessPlanPrice, 5000);
      expect(b.businessPlanPrice, 5000);
      expect(a.isOnline, isTrue);
      expect(b.isOnline, isTrue);
      expect(a.planName, 'Private 1 Month');
      expect(b.planName, 'Private 1 Month');
      expect(a.businessPlanName, 'Business 5');
      expect(b.businessPlanName, 'Business 5');
    });

    test('a missing join falls back rather than throwing', () {
      final user = VpnUser.fromJson(asNull);

      expect(user.username, 'N/A');
      expect(user.status, 'inactive');
      expect(user.planName, isNull);
      expect(user.expiryDate, isNull);
      expect(user.isOnline, isFalse);
      expect(user.extraDeviceSlots, 0);
      expect(user.businessPlanId, isNull);
      expect(user.businessPlanName, isNull);
      expect(user.businessPlanPrice, isNull);
    });

    test('has_business_plan is inferred from the id when it is absent', () {
      expect(VpnUser.fromJson(asInt).hasBusinessPlan, isTrue);
      expect(VpnUser.fromJson(asNull).hasBusinessPlan, isFalse);
    });

    test('has_business_plan is trusted when the endpoint sends one', () {
      final user = VpnUser.fromJson(const <String, dynamic>{
        'id': 9,
        'business_plan_id': 12,
        'has_business_plan': false,
      });

      expect(user.businessPlanId, 12);
      expect(user.hasBusinessPlan, isFalse);
    });
  });

  group('VpnUserResponse.fromJson', () {
    test('the out-of-range error envelope keeps its paging state', () {
      // `json['data'] as List` threw on this shape and lost the page with it.
      final page = VpnUserResponse.fromJson(const <String, dynamic>{
        'current_page': '3',
        'last_page': '3',
        'total': '359',
      });

      expect(page.users, isEmpty);
      expect(page.currentPage, 3);
      expect(page.lastPage, 3);
      expect(page.total, 359);
    });

    test('total falls back to the page length, and paging to page one', () {
      final page = VpnUserResponse.fromJson(const <String, dynamic>{
        'data': [
          {'id': 1, 'username': 'a'},
          {'id': 2, 'username': 'b'},
        ],
      });

      expect(page.users.length, 2);
      expect(page.users.first.username, 'a');
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.total, 2);
    });
  });

  group('AgentModel.fromJson', () {
    test('credit_balance is a SUM on the list and an int on the update', () {
      expect(
        AgentModel.fromJson(const <String, dynamic>{
          'credit_balance': '25000',
        }).creditBalance,
        25000,
      );
      expect(
        AgentModel.fromJson(const <String, dynamic>{
          'credit_balance': 25000,
        }).creditBalance,
        25000,
      );
      expect(
        AgentModel.fromJson(const <String, dynamic>{
          'credit_balance': null,
        }).creditBalance,
        0,
      );
    });

    test('topup_bonus_percent reads as a String, a num, or not at all', () {
      expect(
        AgentModel.fromJson(const <String, dynamic>{
          'topup_bonus_percent': '20.00',
        }).topupBonusPercent,
        20.0,
      );
      expect(
        AgentModel.fromJson(const <String, dynamic>{
          'topup_bonus_percent': 20,
        }).topupBonusPercent,
        20.0,
      );
      expect(
        AgentModel.fromJson(const <String, dynamic>{}).topupBonusPercent,
        0.0,
      );
    });

    test('plans parse whether they are objects or bare ids', () {
      // toJson sends bare ids, so the app has to read back its own shape.
      expect(
        AgentModel.fromJson(const <String, dynamic>{
          'plans': [
            {'id': 3},
            {'id': '4'},
          ],
        }).planIds,
        [3, 4],
      );
      expect(
        AgentModel.fromJson(const <String, dynamic>{
          'plans': [3, '4'],
        }).planIds,
        [3, 4],
      );
      expect(AgentModel.fromJson(const <String, dynamic>{}).planIds, isEmpty);
    });

    test('anything that does not parse to a positive id is dropped', () {
      expect(
        AgentModel.fromJson(const <String, dynamic>{
          'plans': [3, null, 'x', 0],
        }).planIds,
        [3],
      );
    });

    test('the documented defaults hold for an empty row', () {
      final agent = AgentModel.fromJson(const <String, dynamic>{});

      expect(agent.id, 0);
      expect(agent.name, '');
      expect(agent.email, '');
      expect(agent.status, 'inactive');
      expect(agent.canSendNotifications, isFalse);
      expect(agent.canAccessChat, isFalse);
      expect(agent.canManageAgents, isFalse);
      expect(agent.createdAt, '');
      expect(agent.parentName, isNull);
      expect(agent.parentId, isNull);
      expect(agent.userCount, 0);
    });

    test('permission flags read 1 and "1" the same as true', () {
      final agent = AgentModel.fromJson(const <String, dynamic>{
        'can_send_notifications': 1,
        'can_access_chat': '1',
        'can_manage_agents': true,
      });

      expect(agent.canSendNotifications, isTrue);
      expect(agent.canAccessChat, isTrue);
      expect(agent.canManageAgents, isTrue);
    });

    test('toJson round trips the fields it writes, and only those', () {
      final original = AgentModel(
        id: 16,
        name: 'Ko Zaw',
        email: 'zaw@example.com',
        creditBalance: 25000,
        status: 'active',
        canSendNotifications: true,
        canAccessChat: true,
        canManageAgents: true,
        topupBonusPercent: 20,
        createdAt: '2026-01-04 09:00:00',
        planIds: const [3, 4],
        parentName: 'Super Admin',
        parentId: 1,
        userCount: 42,
      );
      final restored = AgentModel.fromJson(original.toJson());

      expect(restored.id, 16);
      expect(restored.name, 'Ko Zaw');
      expect(restored.email, 'zaw@example.com');
      expect(restored.creditBalance, 25000);
      expect(restored.status, 'active');
      expect(restored.canSendNotifications, isTrue);
      expect(restored.canAccessChat, isTrue);
      expect(restored.canManageAgents, isTrue);
      expect(restored.topupBonusPercent, 20.0);
      expect(restored.planIds, [3, 4]);

      // toJson is a request payload, not a cache format: created_at,
      // parent_name, parent_id and user_count are server-owned and are not
      // written. Asserted so a future change to toJson has to be deliberate.
      expect(restored.createdAt, '');
      expect(restored.parentName, isNull);
      expect(restored.parentId, isNull);
      expect(restored.userCount, 0);
    });
  });

  group('RenewalRequest.fromJson', () {
    // payment_screenshot_url is null or host-less in every row here on
    // purpose. ApiConfig.resolveMediaUrl returns early for both; any other
    // value reaches RemoteConfigService, whose field initialiser is
    // FirebaseRemoteConfig.instance and throws without a Firebase app.

    test('duration and cost read as int or String, and default to zero', () {
      expect(
        RenewalRequest.fromJson(const <String, dynamic>{
          'duration_months': 3,
          'estimated_cost': 5000,
        }).durationMonths,
        3,
      );
      expect(
        RenewalRequest.fromJson(const <String, dynamic>{
          'duration_months': '3',
          'estimated_cost': '5000',
        }).estimatedCost,
        5000,
      );

      final empty = RenewalRequest.fromJson(const <String, dynamic>{});
      expect(empty.durationMonths, 0);
      expect(empty.estimatedCost, 0);
    });

    test('a missing vpn_user or plan join shows fallback text', () {
      final request = RenewalRequest.fromJson(const <String, dynamic>{
        'id': '881',
        'vpn_user': null,
        'plan': null,
        'payment_screenshot_url': null,
      });

      expect(request.id, 881);
      expect(request.vpnUserName, 'N/A');
      expect(request.planName, 'Device Slot');
      expect(request.screenshotUrl, '');
      expect(request.status, '');
      expect(request.createdAt, '');
    });

    test('the joins are read when they are there', () {
      final request = RenewalRequest.fromJson(const <String, dynamic>{
        'id': 881,
        'vpn_user': {'username': 'mt_0041'},
        'plan': {'plan_name': 'Private 1 Month'},
        'status': 'pending',
        'created_at': '2026-09-24 10:15:00',
        'payment_screenshot_url': 'storage/receipts/881.jpg',
      });

      expect(request.vpnUserName, 'mt_0041');
      expect(request.planName, 'Private 1 Month');
      expect(request.status, 'pending');
      // Host-less, so it is handed back untouched.
      expect(request.screenshotUrl, 'storage/receipts/881.jpg');
    });

    test('the UI strings have defaults so a row is never blank', () {
      final request = RenewalRequest.fromJson(const <String, dynamic>{});

      expect(request.type, 'plan_renewal');
      expect(request.title, 'Request');
      expect(request.subtitle, 'Details');
    });

    test('an empty reject_reason is null, not an empty banner', () {
      expect(
        RenewalRequest.fromJson(const <String, dynamic>{
          'reject_reason': '',
        }).rejectReason,
        isNull,
      );
      expect(
        RenewalRequest.fromJson(const <String, dynamic>{
          'reject_reason': '   ',
        }).rejectReason,
        isNull,
      );
      expect(
        RenewalRequest.fromJson(const <String, dynamic>{
          'reject_reason': 'Screenshot unreadable',
        }).rejectReason,
        'Screenshot unreadable',
      );
    });
  });

  group('RenewalRequestResponse.fromJson', () {
    test('the counts block is a GROUP BY, so every total is a String', () {
      final page = RenewalRequestResponse.fromJson(const <String, dynamic>{
        'data': [],
        'current_page': '2',
        'last_page': '157',
        'total': '3138',
        'counts': {'pending': '109', 'approved': '2900', 'rejected': 129},
      });

      expect(page.currentPage, 2);
      expect(page.lastPage, 157);
      expect(page.total, 3138);
      expect(page.counts['pending'], 109);
      expect(page.counts['approved'], 2900);
      expect(page.counts['rejected'], 129);
    });

    test('no counts block at all leaves an empty map, not a crash', () {
      final page = RenewalRequestResponse.fromJson(const <String, dynamic>{});

      expect(page.requests, isEmpty);
      expect(page.counts, isEmpty);
      expect(page.currentPage, 1);
      expect(page.lastPage, 1);
      expect(page.total, 0);
    });
  });

  group('ProfitLossSummary.fromJson', () {
    test('PHP encodes an empty associative array as [], and that is zero', () {
      final summary = ProfitLossSummary.fromJson(const <String, dynamic>{
        'revenue': [],
        'expense': [],
      });

      expect(summary.topupCash, 0);
      expect(summary.directSale, 0);
      expect(summary.manualRevenue, 0);
      expect(summary.revenueTotal, 0);
      expect(summary.expenseTotal, 0);
      expect(summary.profit, 0);
      expect(summary.revenueLines, isEmpty);
      expect(summary.expenseLines, isEmpty);
      // No income is no margin, not a division by zero.
      expect(summary.margin, 0);
    });

    test('every total arrives as a String and every one of them parses', () {
      final summary = ProfitLossSummary.fromJson(const <String, dynamic>{
        'revenue': {
          'topup_cash': '150000',
          'direct_sale': '50000',
          'total': '250000',
          'manual': {
            'total': '50000',
            'by_category': {'Reseller top-up': '50000'},
          },
        },
        'expense': {
          'total': '100000',
          'by_category': {'Server': '70000', 'Ads': '30000'},
        },
        'profit': '150000',
      });

      expect(summary.topupCash, 150000);
      expect(summary.directSale, 50000);
      expect(summary.manualRevenue, 50000);
      expect(summary.revenueTotal, 250000);
      expect(summary.expenseTotal, 100000);
      expect(summary.profit, 150000);
      expect(summary.margin, closeTo(60.0, 0.0001));
    });

    test('the two computed lines are listed with the manual ones', () {
      final summary = ProfitLossSummary.fromJson(const <String, dynamic>{
        'revenue': {
          'topup_cash': 150000,
          'direct_sale': 50000,
          'total': 250000,
          'manual': {
            'total': 50000,
            'by_category': {'Reseller top-up': 50000},
          },
        },
      });

      expect(
        summary.revenueLines.map((line) => line.name).toList(),
        ['Agent top-up cash', 'Direct sale (Super Admin)', 'Reseller top-up'],
      );
      expect(summary.revenueLines.first.total, 150000);
    });

    test('a zero line is left out rather than shown as nothing', () {
      final summary = ProfitLossSummary.fromJson(const <String, dynamic>{
        'revenue': {'topup_cash': 0, 'direct_sale': 4000, 'total': 4000},
      });

      expect(summary.revenueLines.length, 1);
      expect(summary.revenueLines.single.name, 'Direct sale (Super Admin)');
    });
  });

  group('PlLine.listFrom', () {
    test('by_category is a map, and the biggest line comes first', () {
      final lines = PlLine.listFrom(const <String, dynamic>{
        'Ads': '30000',
        'Server': '70000',
        'Support': 5000,
      });

      expect(lines.map((line) => line.name).toList(), [
        'Server',
        'Ads',
        'Support',
      ]);
      expect(lines.first.total, 70000);
    });

    test('anything that is not a map is an empty breakdown', () {
      expect(PlLine.listFrom(null), isEmpty);
      expect(PlLine.listFrom(const <dynamic>[]), isEmpty);
    });
  });

  group('DirectSale.fromJson', () {
    test('the username is read back out of the description', () {
      final sale = DirectSale.fromJson(const <String, dynamic>{
        'id': 8801,
        'amount': '12000',
        'description': 'Approved renewal for mt_0041 to 2026-11-24',
        'created_at': '2026-09-24 10:15:00',
      }, const <int>{8801});

      expect(sale.id, 8801);
      expect(sale.amount, 12000);
      expect(sale.username, 'mt_0041');
      expect(sale.action, 'Renewal approved');
      expect(sale.excluded, isTrue);
    });

    test('a sentence shape nobody wrote falls back to the raw text', () {
      final sale = DirectSale.fromJson(const <String, dynamic>{
        'id': 2,
        'amount': 500,
        'description': 'Something else entirely',
      }, const <int>{});

      expect(sale.username, isNull);
      expect(sale.action, 'Something else entirely');
      expect(sale.createdAt, '');
      expect(sale.excluded, isFalse);
    });
  });

  group('TopupRow.fromJson', () {
    test('cash, credit and bonus read whatever shape they arrive in', () {
      final topup = TopupRow.fromJson(const <String, dynamic>{
        'id': '55',
        'amount': '60000',
        'cash_received': '50000',
        'bonus_percent': '20.00',
        'agent_name': 'Ko Zaw',
        'counts_as_revenue': true,
        'created_at': '2026-09-01',
      });

      expect(topup.id, 55);
      expect(topup.amount, 60000);
      expect(topup.cashReceived, 50000);
      expect(topup.bonusPercent, 20.0);
      expect(topup.agentName, 'Ko Zaw');
      expect(topup.countsAsRevenue, isTrue);
      expect(topup.createdAt, '2026-09-01');
    });

    test('an empty row is zeroes and nulls, not an exception', () {
      final topup = TopupRow.fromJson(const <String, dynamic>{});

      expect(topup.id, 0);
      expect(topup.amount, 0);
      expect(topup.cashReceived, 0);
      expect(topup.bonusPercent, 0.0);
      expect(topup.agentName, isNull);
      expect(topup.countsAsRevenue, isFalse);
      expect(topup.createdAt, '');
    });
  });

  group('FinanceEntry.fromJson', () {
    test('amount_mmk parses and direction decides isExpense', () {
      final expense = FinanceEntry.fromJson(const <String, dynamic>{
        'id': 3,
        'direction': 'expense',
        'category': 'Server',
        'name': 'Gcore KL',
        'amount_mmk': '70000',
        'entry_date': '2026-09-02',
      });

      expect(expense.id, 3);
      expect(expense.amount, 70000);
      expect(expense.category, 'Server');
      expect(expense.name, 'Gcore KL');
      expect(expense.entryDate, '2026-09-02');
      expect(expense.isExpense, isTrue);
    });

    test('direction defaults to expense and the text fields to empty', () {
      final entry = FinanceEntry.fromJson(const <String, dynamic>{
        'amount_mmk': 1000,
      });

      expect(entry.direction, 'expense');
      expect(entry.isExpense, isTrue);
      expect(entry.category, '');
      expect(entry.name, '');
      expect(entry.entryDate, isNull);

      final revenue = FinanceEntry.fromJson(const <String, dynamic>{
        'direction': 'revenue',
      });
      expect(revenue.isExpense, isFalse);
    });
  });

  group('ProfitLossReport.fromJson', () {
    test('an empty response still carries usable paging', () {
      final report = ProfitLossReport.fromJson(const <String, dynamic>{});

      expect(report.month, '');
      expect(report.months, isEmpty);
      expect(report.summary.revenueTotal, 0);
      expect(report.directSales, isEmpty);
      expect(report.directSalesTotal, 0);
      expect(report.directSalesPage, 1);
      expect(report.directSalesLastPage, 1);
      expect(report.topups, isEmpty);
      expect(report.entries, isEmpty);
    });

    test('excluded_ids mark the rows they name, String ids included', () {
      final report = ProfitLossReport.fromJson(const <String, dynamic>{
        'month': '2026-09',
        'months': ['2026-08', '2026-09'],
        'direct_sales': {
          'data': [
            {'id': 1, 'amount': 1000, 'description': 'Activated user: a'},
            {'id': 2, 'amount': 2000, 'description': 'Activated user: b'},
          ],
          'excluded_ids': ['2'],
          'total': '2',
          'current_page': '1',
          'last_page': '1',
        },
      });

      expect(report.month, '2026-09');
      expect(report.months, ['2026-08', '2026-09']);
      expect(report.directSales.length, 2);
      expect(report.directSales[0].excluded, isFalse);
      expect(report.directSales[1].excluded, isTrue);
      expect(report.directSalesTotal, 2);
      expect(report.directSalesPage, 1);
      expect(report.directSalesLastPage, 1);
    });
  });

  group('DashboardStats', () {
    const stats = DashboardStats(
      agentName: 'Ko Myo Thura',
      activeUserCount: 318,
      totalUserCount: 359,
      expiringSoonCount: 12,
      businessUserCount: 7,
      onlineUserCount: 41,
      subAgentCount: 5,
      creditBalance: 1250000,
      creditsSpent: 430000,
      recentRequests: ['mt_0041', 'mt_0042'],
      pendingRequestCount: 109,
      unreadChatCount: 3,
      unreadNotificationCount: 6,
    );

    test('a cache round trip keeps every field, bell badge included', () {
      // toJson was missing unread_notification_count, so a Hive round trip
      // came back with the bell at zero and a cold start showed no unread
      // notifications until the network answered.
      final restored = DashboardStats.fromJson(stats.toJson());

      expect(restored, stats);
      expect(restored.unreadNotificationCount, 6);
      expect(restored.pendingRequestCount, 109);
      expect(restored.unreadChatCount, 3);
      expect(restored.recentRequests, ['mt_0041', 'mt_0042']);
      expect(restored.agentName, 'Ko Myo Thura');
      expect(restored.creditBalance, 1250000);
      expect(restored.creditsSpent, 430000);
    });

    test('an absent field falls back to the documented default', () {
      final empty = DashboardStats.fromJson(const <String, dynamic>{});

      expect(empty.agentName, 'Agent');
      expect(empty.activeUserCount, 0);
      expect(empty.totalUserCount, 0);
      expect(empty.expiringSoonCount, 0);
      expect(empty.businessUserCount, 0);
      expect(empty.onlineUserCount, 0);
      expect(empty.subAgentCount, 0);
      expect(empty.creditBalance, 0);
      expect(empty.creditsSpent, 0);
      expect(empty.recentRequests, isEmpty);
      expect(empty.pendingRequestCount, 0);
      expect(empty.unreadChatCount, 0);
      expect(empty.unreadNotificationCount, 0);
    });

    test('credits_spent_this_month reads as an int or as a String', () {
      expect(
        DashboardStats.fromJson(const <String, dynamic>{
          'credits_spent_this_month': 430000,
        }).creditsSpent,
        430000,
      );
      expect(
        DashboardStats.fromJson(const <String, dynamic>{
          'credits_spent_this_month': '430000',
        }).creditsSpent,
        430000,
      );
    });

    test('the formatted getters go through Fmt', () {
      expect(stats.formattedCreditBalance, '1,250,000');
      expect(stats.formattedCreditsSpent, '430,000');
      expect(stats.firstName, 'Ko');
    });

    test('value equality is what stops the 30s poll rebuilding the screen', () {
      final same = DashboardStats.fromJson(stats.toJson());
      final moved = DashboardStats.fromJson(const <String, dynamic>{
        'agent_name': 'Ko Myo Thura',
        'unread_notification_count': 7,
      });

      expect(same == stats, isTrue);
      expect(moved == stats, isFalse);
    });
  });
}
