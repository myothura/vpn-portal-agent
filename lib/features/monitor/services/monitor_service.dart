// lib/features/monitor/services/monitor_service.dart
import 'package:dio/dio.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/features/monitor/models/monitor_snapshot.dart';

/// The outcome of a call, with the failure kept rather than flattened.
///
/// Every other list service in this app returns null or an empty list on
/// error, and five screens consequently tell the agent "nothing here yet" when
/// the request failed. On a monitoring screen that is worse than useless: an
/// empty fleet table reads as an outage. So the result carries which of the
/// two happened, and the screen is forced to choose a different message.
class MonitorResult<T> {
  final T? data;
  final String? error;

  const MonitorResult.ok(this.data) : error = null;
  const MonitorResult.failed(this.error) : data = null;

  bool get ok => error == null;
}

class MonitorService {
  final Dio _dio = ApiClient().dio;

  /// MONITOR_ASYNC_V1 — no request waits for the model any more.
  ///
  /// Raising the timeout was the wrong fix and the second failure proved it:
  /// at 15 seconds the app reported a receive timeout, and at 120 seconds it
  /// reported a dropped connection instead. A minute-long foreground request
  /// does not survive a mobile network, however long you are willing to wait
  /// for it.
  ///
  /// So the server queues the work and answers immediately with a key, and
  /// this service polls for the result. Each call is short: a poll that is
  /// lost costs one retry, not the whole answer, and the worker keeps going
  /// either way.
  static final Options _shortOptions = Options(
    receiveTimeout: const Duration(seconds: 20),
    sendTimeout: const Duration(seconds: 20),
  );

  /// How often to ask, and how long to keep asking. The server holds a
  /// finished answer in Redis for 15 minutes, so stopping here loses nothing
  /// — the next attempt starts a new read rather than waiting on a dead one.
  static const Duration _pollEvery = Duration(seconds: 2);
  static const Duration _pollFor = Duration(minutes: 3);

  /// Consecutive failed polls before giving up. A dropped poll is not a
  /// dropped job, so one is not a reason to stop.
  static const int _maxMisses = 8;

  /// The snapshot is several aggregate queries over the session table, which
  /// is slower than a page of rows but nothing like the model call.
  static final Options _snapshotOptions = Options(
    receiveTimeout: const Duration(seconds: 60),
  );

  Future<MonitorResult<MonitorSnapshot>> snapshot({
    int hours = 24,
    int days = 7,
  }) async {
    try {
      final res = await _dio.get(
        ApiConfig.agentMonitorSnapshot,
        queryParameters: {'hours': hours, 'days': days},
        options: _snapshotOptions,
      );

      final body = res.data;
      if (res.statusCode == 404) {
        return const MonitorResult.failed(
          'ဒီစာမျက်နှာက Main Account အတွက်သာ ဖွင့်ထားပါတယ်။',
        );
      }
      if (body is! Map) {
        return const MonitorResult.failed('Server ကနေ မမျှော်လင့်တဲ့ အဖြေ ပြန်လာပါတယ်။');
      }
      if (body['success'] != true) {
        return MonitorResult.failed(
          _str(body['message']) ?? 'Data မရယူနိုင်ပါ။',
        );
      }

      final data = body['data'];
      if (data is! Map) {
        return const MonitorResult.failed('Data ပုံစံ မမှန်ပါ။');
      }

      return MonitorResult.ok(
        MonitorSnapshot.fromJson(data.cast<String, dynamic>()),
      );
    } on DioException catch (e) {
      return MonitorResult.failed(_network(e));
    } catch (e) {
      // A parse failure must not read as an empty fleet.
      return MonitorResult.failed('Data ဖတ်လို့ မရပါ — $e');
    }
  }

  /// The fixed overall read. The question lives on the server so this one and
  /// the admin web page ask exactly the same thing.
  Future<MonitorResult<String>> overall({int hours = 24}) =>
      _answer(ApiConfig.agentMonitorOverall, {'hours': hours});

  Future<MonitorResult<String>> ask(
    String question, {
    int hours = 24,
    List<Map<String, String>> history = const [],
  }) =>
      _answer(ApiConfig.agentMonitorAsk, {
        'question': question,
        'hours': hours,
        if (history.isNotEmpty) 'history': history,
      });

  /// MONITOR_ASYNC_V1 — start the job, then collect it.
  ///
  /// The POST returns in well under a second because it only writes a row and
  /// dispatches. Everything after that is polling.
  Future<MonitorResult<String>> _answer(
    String path,
    Map<String, dynamic> body,
  ) async {
    final String job;

    try {
      final res = await _dio.post(path, data: body, options: _shortOptions);

      if (res.statusCode == 404) {
        return const MonitorResult.failed(
          'ဒီစာမျက်နှာက Main Account အတွက်သာ ဖွင့်ထားပါတယ်။',
        );
      }

      final data = res.data;
      if (data is! Map) {
        return const MonitorResult.failed('Server ကနေ မမျှော်လင့်တဲ့ အဖြေ ပြန်လာပါတယ်။');
      }

      if (data['success'] != true) {
        return MonitorResult.failed(
          _str(data['answer']) ??
              _str(data['message']) ??
              'AI က အဖြေ မပြန်နိုင်ပါ။',
        );
      }

      final queued = _str(data['job']);
      if (queued == null) {
        // A server that still answers inline. Kept so the app works against
        // either version rather than breaking on whichever is deployed first.
        final answer = _str(data['answer']);
        return answer == null
            ? const MonitorResult.failed('အဖြေ ဗလာ ပြန်လာပါတယ်။')
            : MonitorResult.ok(answer);
      }

      job = queued;
    } on DioException catch (e) {
      return MonitorResult.failed(_network(e));
    } catch (e) {
      return MonitorResult.failed('အဖြေ ဖတ်လို့ မရပါ — $e');
    }

    return _collect(job);
  }

  /// MONITOR_ASYNC_V1 — ask for the answer until it is there.
  ///
  /// The four states the server reports are all acted on differently:
  /// `pending` waits, `done` returns, and `failed` or `expired` stop with the
  /// server's own sentence rather than a generic one.
  Future<MonitorResult<String>> _collect(String job) async {
    final deadline = DateTime.now().add(_pollFor);
    var misses = 0;

    while (DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(_pollEvery);

      try {
        final res = await _dio.get(
          '${ApiConfig.agentMonitorResult}$job',
          options: _shortOptions,
        );

        final data = res.data;
        if (data is! Map) {
          misses++;
          if (misses >= _maxMisses) {
            return const MonitorResult.failed(
              'Server ကနေ မမျှော်လင့်တဲ့ အဖြေ ပြန်လာပါတယ်။',
            );
          }
          continue;
        }

        final status = _str(data['status']) ?? 'pending';

        if (status == 'done') {
          final answer = _str(data['answer']);
          return answer == null
              ? const MonitorResult.failed('အဖြေ ဗလာ ပြန်လာပါတယ်။')
              : MonitorResult.ok(answer);
        }

        if (status == 'failed' || status == 'expired') {
          return MonitorResult.failed(
            _str(data['answer']) ?? 'AI က အဖြေ မပြန်နိုင်ပါ။',
          );
        }

        misses = 0;
      } on DioException catch (e) {
        // The radio dropping does not stop the worker, and the answer waits
        // in Redis. Only a run of failures means the phone is really offline.
        misses++;
        if (misses >= _maxMisses) return MonitorResult.failed(_network(e));
      } catch (_) {
        misses++;
        if (misses >= _maxMisses) {
          return const MonitorResult.failed('အဖြေ ဖတ်လို့ မရပါ။');
        }
      }
    }

    return const MonitorResult.failed(
      'AI က အခုထိ မပြီးသေးပါ — ခဏနေ ပြန်စမ်းကြည့်ပါ။',
    );
  }

  /// Named causes rather than one "network error". The agent can act on
  /// "လိုင်း မကောင်းပါ" and cannot act on "failed".
  String _network(DioException e) {
    final body = e.response?.data;
    if (body is Map) {
      final m = _str(body['message']);
      if (m != null) return m;
    }

    return switch (e.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout =>
        'Server ကို ဆက်သွယ်လို့ မရပါ — လိုင်း စစ်ကြည့်ပါ။',
      // MONITOR_ASYNC_V1 — every request here is short now, so a receive
      // timeout means the server did not answer a quick call, not that the
      // model is slow.
      DioExceptionType.receiveTimeout =>
        'Server က အချိန်မီ မဖြေပါ — ပြန်စမ်းကြည့်ပါ။',
      DioExceptionType.badResponse =>
        'Server က ${e.response?.statusCode ?? '-'} ပြန်ပါတယ်။',
      _ => 'ဆက်သွယ်မှု ပြတ်သွားပါတယ် — ပြန်စမ်းကြည့်ပါ။',
    };
  }

  static String? _str(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
