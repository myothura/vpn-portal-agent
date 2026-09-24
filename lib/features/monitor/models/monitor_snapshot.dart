// lib/features/monitor/models/monitor_snapshot.dart
//
// MONITOR_SNAPSHOT_V1 — the fleet snapshot, as the phone holds it.
//
// Every field is parsed defensively. The audit of 2026-09-24 found four models
// in this app that throw on a backend type change and take their whole screen
// down with them — a user list stuck on its skeleton for ever, a request page
// that renders "nothing waiting" because one row had a null. That is the worst
// possible failure for a page whose entire job is to tell the truth about the
// fleet, so nothing here casts, and a malformed row is dropped rather than
// allowed to throw.

import 'package:vpn_agent_app/core/utils/app_time.dart';

int _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.round();
  if (v is String) return int.tryParse(v) ?? double.tryParse(v)?.round() ?? 0;
  return 0;
}

double _double(dynamic v) {
  if (v is double) return v;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

String _str(dynamic v, [String fallback = '-']) {
  if (v == null) return fallback;
  final s = v.toString().trim();
  return s.isEmpty ? fallback : s;
}

bool _bool(dynamic v) => v == true || v == 1 || v == '1';

List<Map<String, dynamic>> _rows(dynamic v) {
  if (v is! List) return const [];
  return v.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
}

class MonitorSnapshot {
  final DateTime? generatedAt;
  final int windowHours;
  final int compareDays;
  final Overview overview;
  final List<BoxRow> boxes;
  final List<SharedHost> sharedHosts;

  /// False when avg_latency_ms holds the same value on every box — meaning it
  /// was never measured. The screen says so rather than printing a column of
  /// identical numbers that look like data.
  final bool latencyMeasured;

  final List<KillGroup> kills;
  final List<EndReasonRow> endReasons;
  final List<VersionRow> versions;
  final List<FailureRow> failures;
  final Map<String, int> verdicts;
  final List<StageRow> stages;
  final List<ErrorUserRow> errorUsers;
  final List<GapRow> gaps;

  const MonitorSnapshot({
    required this.generatedAt,
    required this.windowHours,
    required this.compareDays,
    required this.overview,
    required this.boxes,
    required this.sharedHosts,
    required this.latencyMeasured,
    required this.kills,
    required this.endReasons,
    required this.versions,
    required this.failures,
    required this.verdicts,
    required this.stages,
    required this.errorUsers,
    required this.gaps,
  });

  factory MonitorSnapshot.fromJson(Map<String, dynamic> j) {
    final stagesNow = j['stages_now'];
    final stagesMap = stagesNow is Map ? stagesNow.cast<String, dynamic>() : const <String, dynamic>{};

    final rawVerdicts = stagesMap['verdicts'];
    final verdicts = <String, int>{};
    if (rawVerdicts is Map) {
      rawVerdicts.forEach((k, v) => verdicts[k.toString()] = _int(v));
    }

    return MonitorSnapshot(
      // AGENT_APP_Q1_MS — the snapshot's own clock.
      generatedAt: AppTime.parse(j['generated_at']),
      windowHours: _int(j['window_hours']),
      compareDays: _int(j['compare_days']),
      overview: Overview.fromJson(
        j['overview'] is Map ? (j['overview'] as Map).cast<String, dynamic>() : const {},
      ),
      boxes: _rows(j['boxes']).map(BoxRow.fromJson).toList(),
      sharedHosts: _rows(j['shared_hosts']).map(SharedHost.fromJson).toList(),
      latencyMeasured: _bool(j['latency_measured']),
      kills: _rows(j['kills']).map(KillGroup.fromJson).toList(),
      endReasons: _rows(j['end_reasons']).map(EndReasonRow.fromJson).toList(),
      versions: _rows(j['versions']).map(VersionRow.fromJson).toList(),
      failures: _rows(j['failures']).map(FailureRow.fromJson).toList(),
      verdicts: verdicts,
      stages: _rows(stagesMap['stages']).map(StageRow.fromJson).toList(),
      errorUsers: _rows(j['error_users']).map(ErrorUserRow.fromJson).toList(),
      gaps: _rows(j['gaps']).map(GapRow.fromJson).toList(),
    );
  }
}

class Overview {
  final int serversActive;
  final int serversUnhealthy;
  final int online;
  final int capacity;
  final int sessions;
  final double gb;
  final int failures;
  final int failureDevices;

  const Overview({
    required this.serversActive,
    required this.serversUnhealthy,
    required this.online,
    required this.capacity,
    required this.sessions,
    required this.gb,
    required this.failures,
    required this.failureDevices,
  });

  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
        serversActive: _int(j['servers_active']),
        serversUnhealthy: _int(j['servers_unhealthy']),
        online: _int(j['online']),
        capacity: _int(j['capacity']),
        sessions: _int(j['sessions']),
        gb: _double(j['gb']),
        failures: _int(j['failures']),
        failureDevices: _int(j['failure_devices']),
      );

  /// Failures per device. The raw count is meaningless on its own: a busy day
  /// has more of everything.
  double get failuresPerDevice =>
      failureDevices > 0 ? failures / failureDevices : 0;
}

class BoxRow {
  final String name;
  final String security;
  final int online;
  final int max;
  final int pct;
  final int sessions;
  final double gb;
  final bool healthy;

  const BoxRow({
    required this.name,
    required this.security,
    required this.online,
    required this.max,
    required this.pct,
    required this.sessions,
    required this.gb,
    required this.healthy,
  });

  factory BoxRow.fromJson(Map<String, dynamic> j) => BoxRow(
        name: _str(j['name']),
        security: _str(j['security'], ''),
        online: _int(j['online']),
        max: _int(j['max']),
        pct: _int(j['pct']),
        sessions: _int(j['sessions']),
        gb: _double(j['gb']),
        healthy: _bool(j['healthy']),
      );

  /// A box carrying users is working, whatever its session count looks like.
  /// Deliberately NOT called "full" or "overloaded": max_users is set at a
  /// level the box handles comfortably, so a high percentage is not a warning.
  bool get carryingUsers => online > 0;
}

class SharedHost {
  final String host;
  final List<String> boxes;

  const SharedHost({required this.host, required this.boxes});

  factory SharedHost.fromJson(Map<String, dynamic> j) => SharedHost(
        host: _str(j['host']),
        boxes: (j['boxes'] is List)
            ? (j['boxes'] as List).map((e) => _str(e)).toList()
            : const [],
      );
}

class KillGroup {
  final String platform;
  final int total;

  /// Keys: under_1min, min_1_5, min_5_60, hr_1_3, hr_3_plus, unknown.
  final Map<String, int> buckets;

  const KillGroup({
    required this.platform,
    required this.total,
    required this.buckets,
  });

  factory KillGroup.fromJson(Map<String, dynamic> j) {
    final b = <String, int>{};
    final raw = j['buckets'];
    if (raw is Map) raw.forEach((k, v) => b[k.toString()] = _int(v));
    return KillGroup(
      platform: _str(j['platform']),
      total: _int(j['total']),
      buckets: b,
    );
  }

  /// The only bucket that indicates a fault. Everything above a minute is the
  /// OS reclaiming a long-lived service, which no code change prevents.
  int get startPathFaults => buckets['under_1min'] ?? 0;
}

class EndReasonRow {
  final String platform;
  final String endReason;
  final String startedBy;
  final int n;
  final double avgMin;

  const EndReasonRow({
    required this.platform,
    required this.endReason,
    required this.startedBy,
    required this.n,
    required this.avgMin,
  });

  factory EndReasonRow.fromJson(Map<String, dynamic> j) => EndReasonRow(
        platform: _str(j['platform']),
        endReason: _str(j['end_reason']),
        startedBy: _str(j['started_by']),
        n: _int(j['n']),
        avgMin: _double(j['avg_min']),
      );
}

class VersionRow {
  final String platform;
  final String version;
  final int ids;
  final int days;
  final int sessions;
  final double avgMin;
  final double hours;
  final double gb;
  final int kills;
  final double killsPerId;
  final int shortKills;

  /// False when the build has been out for under two calendar days. One day
  /// against eight is not a comparison, and the screen labels it rather than
  /// drawing a bar that invites one.
  final bool comparable;

  const VersionRow({
    required this.platform,
    required this.version,
    required this.ids,
    required this.days,
    required this.sessions,
    required this.avgMin,
    required this.hours,
    required this.gb,
    required this.kills,
    required this.killsPerId,
    required this.shortKills,
    required this.comparable,
  });

  factory VersionRow.fromJson(Map<String, dynamic> j) => VersionRow(
        platform: _str(j['platform']),
        version: _str(j['version']),
        ids: _int(j['ids']),
        days: _int(j['days']),
        sessions: _int(j['sessions']),
        avgMin: _double(j['avg_min']),
        hours: _double(j['hours']),
        gb: _double(j['gb']),
        kills: _int(j['kills']),
        killsPerId: _double(j['kills_per_id']),
        shortKills: _int(j['short_kills']),
        comparable: _bool(j['comparable']),
      );
}

class FailureRow {
  final String platform;
  final String version;
  final String stage;
  final int reports;
  final int devices;
  final double perDevice;

  const FailureRow({
    required this.platform,
    required this.version,
    required this.stage,
    required this.reports,
    required this.devices,
    required this.perDevice,
  });

  factory FailureRow.fromJson(Map<String, dynamic> j) => FailureRow(
        platform: _str(j['platform']),
        version: _str(j['version']),
        stage: _str(j['stage']),
        reports: _int(j['reports']),
        devices: _int(j['devices']),
        perDevice: _double(j['per_device']),
      );
}

class StageRow {
  final String stage;
  final int n;
  final int devices;
  final double perDevice;

  const StageRow({
    required this.stage,
    required this.n,
    required this.devices,
    required this.perDevice,
  });

  factory StageRow.fromJson(Map<String, dynamic> j) => StageRow(
        stage: _str(j['stage']),
        n: _int(j['n']),
        devices: _int(j['devices']),
        perDevice: _double(j['per_device']),
      );
}

class ErrorUserRow {
  final String platform;
  final int users;
  final int carried;
  final double gb;

  const ErrorUserRow({
    required this.platform,
    required this.users,
    required this.carried,
    required this.gb,
  });

  factory ErrorUserRow.fromJson(Map<String, dynamic> j) => ErrorUserRow(
        platform: _str(j['platform']),
        users: _int(j['users']),
        carried: _int(j['carried']),
        gb: _double(j['gb']),
      );

  /// Share of the users who filed a failure and still carried traffic. This is
  /// what separates "noisy" from "broken".
  int get carriedPct => users > 0 ? (carried / users * 100).round() : 0;
}

class GapRow {
  final String platform;
  final String field;

  const GapRow({required this.platform, required this.field});

  factory GapRow.fromJson(Map<String, dynamic> j) => GapRow(
        platform: _str(j['platform']),
        field: _str(j['field']),
      );
}
