// lib/features/monitor/screens/connect_monitor_screen.dart
//
// CONNECT_MONITOR_V1 (2026-09-24) — the fleet, read correctly.
//
// This screen exists because the same data was misread twice in one session by
// someone who had all of it in front of them: three live boxes were called
// dead, and a healthy reconnect path was called broken. Neither was a missing
// number. Both were a number read without the number that gives it meaning.
//
// So every table here is built to make that mistake hard rather than possible:
//   - a box's session count is never shown without its online count
//   - a kill count is never shown without how long those sessions had been up
//   - a per-device rate always shows the device count it was divided by
//   - a version too new to compare says so instead of showing a difference
//   - a column that was never measured says so instead of printing numbers
//   - a failed request says it failed; it never renders as an empty fleet
//
// The short notes under each heading are part of the feature, not decoration.
// They are the sentence that was missing the day the numbers were misread.

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/features/monitor/models/monitor_snapshot.dart';
import 'package:vpn_agent_app/features/monitor/services/monitor_service.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

/// Hoisted out of build(). Each construction parses a pattern and does an ICU
/// locale lookup, and these are read inside list rows.
final NumberFormat _n = NumberFormat('#,##0');
final NumberFormat _n1 = NumberFormat('#,##0.0');
final DateFormat _time = DateFormat('d MMM, h:mm a');

class ConnectMonitorScreen extends StatefulWidget {
  const ConnectMonitorScreen({super.key});

  @override
  State<ConnectMonitorScreen> createState() => _ConnectMonitorScreenState();
}

class _ConnectMonitorScreenState extends State<ConnectMonitorScreen> {
  final _service = MonitorService();

  MonitorSnapshot? _snap;
  String? _error;
  bool _loading = true;
  int _hours = 24;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    final res = await _service.snapshot(hours: _hours);
    if (!mounted) return;

    setState(() {
      _loading = false;
      if (res.ok) {
        _snap = res.data;
        _error = null;
      } else {
        // The previous snapshot is kept. Stale numbers with a visible warning
        // are more use than a blank page, and the banner says how old they are.
        _error = res.error;
      }
    });
  }

  Future<void> _setHours(int h) async {
    if (h == _hours) return;
    setState(() => _hours = h);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Connect Monitor'),
          bottom: const TabBar(
            // Material 3 draws a full-width divider under the tab bar by
            // default. The app bar already closes the region, so a second
            // line under it reads as a table rule rather than a boundary.
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: 'ဂဏန်းများ'),
              Tab(text: 'AI သုံးသပ်ချက်'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'ပြန်ဆွဲမယ်',
              onPressed: _loading ? null : () => _load(),
              icon: const Icon(Iconsax.refresh),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _TablesTab(
              snap: _snap,
              error: _error,
              loading: _loading,
              hours: _hours,
              onHours: _setHours,
              onRetry: _load,
            ),
            _AssistantTab(service: _service, hours: _hours),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Tables
// ══════════════════════════════════════════════════════════════════════════

class _TablesTab extends StatelessWidget {
  final MonitorSnapshot? snap;
  final String? error;
  final bool loading;
  final int hours;
  final ValueChanged<int> onHours;
  final Future<void> Function({bool silent}) onRetry;

  const _TablesTab({
    required this.snap,
    required this.error,
    required this.loading,
    required this.hours,
    required this.onHours,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (loading && snap == null) return const _Skeleton();

    // A failure with nothing cached is an error page, never an empty state.
    // "No data" on a monitoring screen reads as "the fleet is gone".
    if (snap == null) {
      return AppEmptyState(
        icon: Iconsax.warning_2,
        title: 'ဆွဲလို့ မရပါ',
        subtitle: error ?? 'အကြောင်းရင်း မသိရပါ။',
        actionLabel: 'ပြန်စမ်းမယ်',
        onAction: () => onRetry(),
      );
    }

    final s = snap!;

    return RefreshIndicator(
      onRefresh: () => onRetry(silent: true),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          if (error != null) ...[
            _Warning(
              text: 'အသစ် မဆွဲနိုင်ပါ — အောက်က ဂဏန်းတွေက '
                  '${s.generatedAt == null ? 'အဟောင်း' : _time.format(s.generatedAt!)} ကပါ။\n$error',
            ),
            const SizedBox(height: 14),
          ],
          _WindowPicker(hours: hours, onPick: onHours, busy: loading),
          const SizedBox(height: 16),
          _OverviewSection(s: s),
          const SizedBox(height: 22),
          _BoxSection(s: s),
          const SizedBox(height: 22),
          if (s.sharedHosts.isNotEmpty) ...[
            _SharedHostSection(hosts: s.sharedHosts),
            const SizedBox(height: 22),
          ],
          _KillSection(groups: s.kills),
          const SizedBox(height: 22),
          _VersionSection(rows: s.versions, days: s.compareDays),
          const SizedBox(height: 22),
          _FailureSection(s: s),
          const SizedBox(height: 22),
          _ErrorUserSection(rows: s.errorUsers),
          const SizedBox(height: 22),
          _GapSection(gaps: s.gaps, latencyMeasured: s.latencyMeasured),
          const SizedBox(height: 18),
          if (s.generatedAt != null)
            Center(
              child: Text(
                'နောက်ဆုံး ဆွဲချိန် — ${_time.format(s.generatedAt!)}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textTertiary),
              ),
            ),
        ],
      ),
    );
  }
}

class _WindowPicker extends StatelessWidget {
  final int hours;
  final ValueChanged<int> onPick;
  final bool busy;

  const _WindowPicker({
    required this.hours,
    required this.onPick,
    required this.busy,
  });

  static const _options = <int, String>{
    6: '၆ နာရီ',
    24: '၂၄ နာရီ',
    72: '၃ ရက်',
    168: '၇ ရက်',
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'ကြည့်မယ့် ကာလ',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in _options.entries) ...[
                  _Chip(
                    label: e.value,
                    selected: e.key == hours,
                    onTap: busy ? null : () => onPick(e.key),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _Chip({required this.label, required this.selected, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentInk : AppColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        // 48dp: these sit next to each other and the audit found every
        // similar strip in this app below the Material minimum.
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 64),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppColors.accentInk : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: selected
                      ? AppColors.textOnAccent
                      : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

// ── Overview ──────────────────────────────────────────────────────────────

class _OverviewSection extends StatelessWidget {
  final MonitorSnapshot s;

  const _OverviewSection({required this.s});

  @override
  Widget build(BuildContext context) {
    final o = s.overview;

    return _Section(
      title: 'ခြုံငုံ',
      note: 'Box တစ်ခုရဲ့ max က ဝန်မပိပဲ ခံနိုင်တဲ့ အရေအတွက် — '
          'အပြည့်နီးနေတာ ပြဿနာ မဟုတ်ပါ။',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'အွန်လိုင်း',
                  value: '${_n.format(o.online)} / ${_n.format(o.capacity)}',
                  icon: Iconsax.user,
                  color: AppColors.accentInk,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Figure(
                  label: 'Server',
                  value: o.serversUnhealthy == 0
                      ? '${o.serversActive} လုံး'
                      : '${o.serversActive} လုံး · ${o.serversUnhealthy} မကောင်း',
                  icon: Iconsax.cloud,
                  color: o.serversUnhealthy == 0
                      ? AppColors.info
                      : AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Session (${s.windowHours} နာရီ)',
                  value: _n.format(o.sessions),
                  icon: Iconsax.timer_1,
                  color: AppColors.violet,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Figure(
                  label: 'Data',
                  value: '${_n1.format(o.gb)} GB',
                  icon: Iconsax.chart_2,
                  color: AppColors.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _Figure(
            label: 'ချိတ်မရမှု (device တစ်ခုလျှင်)',
            value: o.failureDevices == 0
                ? '၀'
                : '${_n1.format(o.failuresPerDevice)}  '
                    '(စုစုပေါင်း ${_n.format(o.failures)} / device ${_n.format(o.failureDevices)})',
            icon: Iconsax.warning_2,
            color: AppColors.orange,
            wide: true,
          ),
        ],
      ),
    );
  }
}

// ── Boxes ─────────────────────────────────────────────────────────────────

class _BoxSection extends StatelessWidget {
  final MonitorSnapshot s;

  const _BoxSection({required this.s});

  @override
  Widget build(BuildContext context) {
    final boxes = s.boxes;

    return _Section(
      title: 'Box အလိုက်',
      note: 'Session နည်းတာနဲ့ box သေတယ်လို့ မထင်ပါနဲ့ — '
          'အွန်လိုင်း user ရှိနေရင် အလုပ်လုပ်နေတာပါ။',
      child: boxes.isEmpty
          ? const _EmptyNote('Box data မရှိပါ။')
          : AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  const _BoxHeader(),
                  for (var i = 0; i < boxes.length; i++)
                    _BoxRowTile(row: boxes[i], striped: i.isOdd),
                ],
              ),
            ),
    );
  }
}

class _BoxHeader extends StatelessWidget {
  const _BoxHeader();

  @override
  Widget build(BuildContext context) {
    final st = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppColors.textTertiary,
          fontWeight: FontWeight.w700,
        );

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppTheme.radiusLg)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('Box', style: st)),
          Expanded(flex: 3, child: Text('အွန်လိုင်း', style: st, textAlign: TextAlign.end)),
          Expanded(flex: 2, child: Text('၂ နာရီ', style: st, textAlign: TextAlign.end)),
          Expanded(flex: 2, child: Text('GB', style: st, textAlign: TextAlign.end)),
        ],
      ),
    );
  }
}

class _BoxRowTile extends StatelessWidget {
  final BoxRow row;
  final bool striped;

  const _BoxRowTile({required this.row, required this.striped});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      color: striped ? AppColors.background.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.name,
                  style: t.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  row.security.isEmpty ? '-' : row.security,
                  style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${row.online} / ${row.max}',
                  style: t.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                // Neutral colour at every percentage. Colouring a full box red
                // would restate the exact mistake this screen guards against.
                Text(
                  '${row.pct}%',
                  style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _n.format(row.sessions),
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.end,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              row.gb == 0 ? '—' : _n1.format(row.gb),
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared hosts ──────────────────────────────────────────────────────────

class _SharedHostSection extends StatelessWidget {
  final List<SharedHost> hosts;

  const _SharedHostSection({required this.hosts});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return _Section(
      title: 'Host တူတဲ့ Box',
      note: 'ဒီ box တွေက စက်တစ်လုံးတည်းမှာ — တစ်ခုကျလို့ '
          'နောက်တစ်ခုကို ပြောင်းရင် လမ်းကြောင်း အတူတူပါပဲ။',
      child: AppCard(
        tone: SurfaceTone.wash,
        washColor: AppColors.warningWash,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < hosts.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              Text(
                hosts[i].boxes.join('  +  '),
                style: t.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                hosts[i].host,
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Kills ─────────────────────────────────────────────────────────────────

class _KillSection extends StatelessWidget {
  final List<KillGroup> groups;

  const _KillSection({required this.groups});

  /// Order matters: the fault bucket is first so it is read first, and the
  /// normal one is labelled as normal so a large number there is not alarming.
  static const _buckets = <String, String>{
    'under_1min': '၁ မိနစ်အောက် — စတင်ချိန် ချွတ်ယွင်းမှု',
    'min_1_5': '၁ – ၅ မိနစ်',
    'min_5_60': '၅ – ၆၀ မိနစ်',
    'hr_1_3': '၁ – ၃ နာရီ',
    'hr_3_plus': '၃ နာရီအထက် — OS က ပြန်သိမ်းတာ (ပုံမှန်)',
    'unknown': 'မသိ',
  };

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'ပြုတ်ကျမှု — ဘယ်လောက်ကြာပြီးမှ',
      note: 'နာရီနဲ့ချီ ချိတ်ပြီးမှ ပြုတ်တာက ပုံမှန်ပါ။ '
          '၁ မိနစ်အောက်ကပဲ တကယ့် ပြဿနာပါ။',
      child: groups.isEmpty
          ? const _EmptyNote('ဒီကာလအတွင်း ပြုတ်ကျမှု မရှိပါ။')
          : Column(
              children: [
                for (final g in groups) ...[
                  _KillCard(group: g, labels: _buckets),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _KillCard extends StatelessWidget {
  final KillGroup group;
  final Map<String, String> labels;

  const _KillCard({required this.group, required this.labels});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final total = group.total == 0 ? 1 : group.total;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                group.platform.toUpperCase(),
                style: t.titleSmall?.copyWith(color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                'စုစုပေါင်း ${_n.format(group.total)}',
                style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final e in labels.entries)
            if ((group.buckets[e.key] ?? 0) > 0) ...[
              _Bar(
                label: e.value,
                value: group.buckets[e.key]!,
                fraction: group.buckets[e.key]! / total,
                color: e.key == 'under_1min'
                    ? AppColors.danger
                    : (e.key == 'hr_3_plus'
                        ? AppColors.success
                        : AppColors.neutral),
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int value;
  final double fraction;
  final Color color;

  const _Bar({
    required this.label,
    required this.value,
    required this.fraction,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _n.format(value),
              style: t.bodySmall?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: AppColors.surfaceAlt,
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }
}

// ── Versions ──────────────────────────────────────────────────────────────

class _VersionSection extends StatelessWidget {
  final List<VersionRow> rows;
  final int days;

  const _VersionSection({required this.rows, required this.days});

  @override
  Widget build(BuildContext context) {
    final byPlatform = <String, List<VersionRow>>{};
    for (final r in rows) {
      byPlatform.putIfAbsent(r.platform, () => []).add(r);
    }

    return _Section(
      title: 'Version နှိုင်းယှဉ် ($days ရက်)',
      note: 'Android ကို vpn_user_id နဲ့ ရေတွက်ထားပါတယ် — '
          '3.3.7 အောက်မှာ device_hash က ထပ်နေလို့ပါ။',
      child: byPlatform.isEmpty
          ? const _EmptyNote('နှိုင်းယှဉ်စရာ version မရှိပါ။')
          : Column(
              children: [
                for (final e in byPlatform.entries) ...[
                  _VersionCard(platform: e.key, rows: e.value),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

class _VersionCard extends StatelessWidget {
  final String platform;
  final List<VersionRow> rows;

  const _VersionCard({required this.platform, required this.rows});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            platform.toUpperCase(),
            style: t.titleSmall?.copyWith(color: AppColors.textPrimary),
          ),
          for (final r in rows) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.version,
                    style: t.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                if (!r.comparable)
                  const AppPill(
                    label: 'ရက် မလုံလောက်သေး',
                    color: AppColors.warning,
                    background: AppColors.warningWash,
                  )
                else
                  Text(
                    '${_n.format(r.ids)} ယောက် · ${r.days} ရက်',
                    style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Metric(label: 'ပျမ်းမျှ session', value: '${_n1.format(r.avgMin)} မိနစ်'),
                _Metric(label: 'Kill / ယောက်', value: _n1.format(r.killsPerId)),
                _Metric(label: '၁ မိနစ်အောက် kill', value: _n.format(r.shortKills)),
                _Metric(label: 'Data', value: '${_n1.format(r.gb)} GB'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final String value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: t.bodyMedium?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Failures ──────────────────────────────────────────────────────────────

class _FailureSection extends StatelessWidget {
  final MonitorSnapshot s;

  const _FailureSection({required this.s});

  static const _stageLabels = <String, String>{
    'clean_ip_bad': 'Clean IP စစ် မအောင်',
    'engine_connected_no_internet': 'ချိတ်ပြီး အင်တာနက် မရ',
    'all_servers_failed': 'Server အားလုံး မရ',
    'zombie_reconnect': 'Zombie — ပြန်ချိတ်',
    'engine_not_connected': 'Engine မတက်',
    'connect_exception': 'Connect error',
  };

  static const _verdictLabels = <String, String>{
    'budget_exhausted': 'စောင့်ချိန် ကုန် — Box ပြဿနာ မဟုတ်လောက်ပါ',
    'refused_fast': 'Box က ငြင်းတာ — ဂရုစိုက်ရန်',
    'no_probe_data': 'Probe data မရှိ',
    'other': 'အခြား',
  };

  static String stageLabel(String s) => _stageLabels[s] ?? s;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return _Section(
      title: 'ချိတ်ဆက် မရမှု',
      note: 'Device နဲ့ စားထားပါတယ် — နာရီနဲ့ မစားပါ။ '
          'ချိတ်လို့မရတဲ့သူက ချိတ်ချိန် နည်းလို့ နာရီနှုန်းက အလိုလို တက်သွားပါတယ်။',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (s.verdicts.isNotEmpty) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Probe က ဘာပြောလဲ (${s.windowHours} နာရီ)',
                    style: t.titleSmall?.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 10),
                  for (final e in s.verdicts.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _verdictLabels[e.key] ?? e.key,
                              style: t.bodySmall
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _n.format(e.value),
                            style: t.bodyMedium?.copyWith(
                              color: e.key == 'refused_fast'
                                  ? AppColors.danger
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (s.failures.isEmpty)
            const _EmptyNote('ဒီကာလအတွင်း ချိတ်မရတဲ့ report မရှိပါ။')
          else
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                    decoration: const BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(AppTheme.radiusLg),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 5,
                          child: Text(
                            'အဆင့်',
                            style: t.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            'Device တစ်ခုလျှင်',
                            style: t.bodySmall?.copyWith(
                              color: AppColors.textTertiary,
                              fontWeight: FontWeight.w700,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < s.failures.length; i++)
                    _FailureTile(row: s.failures[i], striped: i.isOdd),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FailureTile extends StatelessWidget {
  final FailureRow row;
  final bool striped;

  const _FailureTile({required this.row, required this.striped});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      color: striped ? AppColors.background.withValues(alpha: 0.5) : null,
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _FailureSection.stageLabel(row.stage),
                  style: t.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${row.platform} · ${row.version}',
                  style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _n1.format(row.perDevice),
                  style: t.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                // The denominator travels with the rate. Without it, 3.2 and
                // 32.4 look like the same kind of number.
                Text(
                  '${_n.format(row.reports)} / ${_n.format(row.devices)}',
                  style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error users ───────────────────────────────────────────────────────────

class _ErrorUserSection extends StatelessWidget {
  final List<ErrorUserRow> rows;

  const _ErrorUserSection({required this.rows});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return _Section(
      title: 'Error တင်တဲ့ User တွေ သုံးလို့ရလား',
      note: 'Error report က ချိတ်ရန် ကြိုးစားပြီး မရတာပါ — '
          'ဝန်ဆောင်မှု ပြတ်သွားတာ မဟုတ်ပါ။',
      child: rows.isEmpty
          ? const _EmptyNote('Error တင်တဲ့ user မရှိပါ။')
          : Column(
              children: [
                for (final r in rows) ...[
                  AppCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                r.platform.toUpperCase(),
                                style: t.titleSmall
                                    ?.copyWith(color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${_n.format(r.users)} ယောက် error တင်၊ '
                                '${_n.format(r.carried)} ယောက် data သုံးနိုင်ခဲ့',
                                style: t.bodySmall
                                    ?.copyWith(color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${r.carriedPct}%',
                              style: t.titleMedium?.copyWith(
                                color: r.carriedPct >= 70
                                    ? AppColors.success
                                    : AppColors.warning,
                              ),
                            ),
                            Text(
                              '${_n1.format(r.gb)} GB',
                              style: t.bodySmall
                                  ?.copyWith(color: AppColors.textTertiary),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }
}

// ── Gaps ──────────────────────────────────────────────────────────────────

class _GapSection extends StatelessWidget {
  final List<GapRow> gaps;
  final bool latencyMeasured;

  const _GapSection({required this.gaps, required this.latencyMeasured});

  static const _fieldLabels = <String, String>{
    'min_avail_mem_mb': 'Memory watermark',
    'net_type_start': 'စတင်ချိန် ကွန်ရက် အမျိုးအစား',
    'handover_stalls': 'Handover ပိတ်ဆို့မှု',
    't2s_dead': 'tun2socks သေမှု',
  };

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    if (gaps.isEmpty && latencyMeasured) {
      return _Section(
        title: 'မပို့တဲ့ တိုင်းတာချက်',
        note: '',
        child: const _EmptyNote('အားလုံး ပြည့်စုံပါတယ်။'),
      );
    }

    return _Section(
      title: 'မပို့တဲ့ တိုင်းတာချက်',
      note: 'ဒါတွေက ၀ မဟုတ်ပါ — App ကနေ လုံးဝ မပို့တာပါ။ '
          '"မဖြစ်ဘူး" လို့ မယူဆရပါ။',
      child: AppCard(
        tone: SurfaceTone.wash,
        washColor: AppColors.infoWash,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final g in gaps)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${g.platform} · ',
                      style: t.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${_fieldLabels[g.field] ?? g.field}  (${g.field})',
                        style: t.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            if (!latencyMeasured)
              Padding(
                padding: EdgeInsets.only(top: gaps.isEmpty ? 0 : 6),
                child: Text(
                  'avg_latency_ms က box တိုင်းမှာ တူနေပါတယ် — '
                  'တကယ် မတိုင်းထားပါ။ Latency လို့ မဖတ်ရပါ။',
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// AI tab
// ══════════════════════════════════════════════════════════════════════════

class _AssistantTab extends StatefulWidget {
  final MonitorService service;
  final int hours;

  const _AssistantTab({required this.service, required this.hours});

  @override
  State<_AssistantTab> createState() => _AssistantTabState();
}

class _Msg {
  final bool fromUser;
  final String text;
  final bool failed;

  const _Msg(this.fromUser, this.text, {this.failed = false});
}

class _AssistantTabState extends State<_AssistantTab>
    with AutomaticKeepAliveClientMixin {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  final List<_Msg> _log = [];

  /// Sent to the model as the conversation so far. Kept separate from [_log]
  /// because a failed turn must not enter the history — replaying an error
  /// message back as the assistant's own words teaches it to repeat them.
  final List<Map<String, String>> _history = [];

  bool _busy = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  static const _suggestions = <String>[
    'အခု fleet အခြေအနေ ဘယ်လိုလဲ',
    '၁ မိနစ်အောက် kill ဘယ်လောက်ရှိလဲ',
    'ချိတ်မရတာတွေ ဘယ် box မှာ စုနေလဲ',
    'Version အသစ်က အဟောင်းထက် ကောင်းလား',
  ];

  Future<void> _overall() => _run(
        label: 'Overall အခြေအနေ စစ်မယ်',
        call: () => widget.service.overall(hours: widget.hours),
      );

  Future<void> _send([String? preset]) async {
    final q = (preset ?? _input.text).trim();
    if (q.isEmpty) return;
    _input.clear();
    await _run(
      label: q,
      call: () => widget.service.ask(q, hours: widget.hours, history: _history.length > 8
          ? _history.sublist(_history.length - 8)
          : _history),
    );
  }

  /// One in-flight guard for both entry points. The audit found approve and
  /// extend in this app with no guard at all, and a second tap there costs
  /// money; here it only costs an API call, but the same discipline keeps the
  /// log from interleaving two answers.
  Future<void> _run({
    required String label,
    required Future<MonitorResult<String>> Function() call,
  }) async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _log.add(_Msg(true, label));
    });
    _toBottom();

    final res = await call();
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (res.ok) {
        _log.add(_Msg(false, res.data!));
        _history
          ..add({'role': 'user', 'text': label})
          ..add({'role': 'model', 'text': res.data!});
      } else {
        _log.add(_Msg(false, res.error ?? 'အဖြေ မရပါ။', failed: true));
      }
    });
    _toBottom();
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Column(
      children: [
        // OVERALL_BUTTON_HIDE_V2 — the button is only on the empty screen.
        //
        // V1 hid it while the answer was being built, because a greyed-out
        // "စစ်နေပါတယ်…" said what the typing dots below already said. This
        // goes further: once there is a conversation the button is a 52pt bar
        // sitting on top of the thing the agent came to read. The first
        // suggestion chip asks the same question, and the composer is always
        // there, so nothing is lost by taking it off the answer screen.
        if (!_busy && _log.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _overall,
                icon: const Icon(Iconsax.search_status),
                label: const Text('Overall အခြေအနေ စစ်မယ်'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
              ),
            ),
          ),
        Expanded(
          child: _log.isEmpty
              ? _Suggestions(
                  items: _suggestions,
                  onTap: _busy ? null : _send,
                )
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  itemCount: _log.length + (_busy ? 1 : 0),
                  itemBuilder: (context, i) {
                    if (i >= _log.length) return const _Typing();
                    return _Bubble(msg: _log[i]);
                  },
                ),
        ),
        _Composer(
          controller: _input,
          busy: _busy,
          onSend: () => _send(),
        ),
      ],
    );
  }
}

class _Suggestions extends StatelessWidget {
  final List<String> items;
  final ValueChanged<String>? onTap;

  const _Suggestions({required this.items, this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      children: [
        Text(
          'မေးလို့ရတာတွေ',
          style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
        ),
        const SizedBox(height: 10),
        for (final s in items) ...[
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            onTap: onTap == null ? null : () => onTap!(s),
            child: Row(
              children: [
                const Icon(Iconsax.message_text,
                    size: 18, color: AppColors.textTertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    s,
                    style: t.bodyMedium?.copyWith(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  final _Msg msg;

  const _Bubble({required this.msg});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final user = msg.fromUser;

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.86,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: user
              ? AppColors.accentInk
              : (msg.failed ? AppColors.dangerWash : AppColors.surface),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: user
              ? null
              : Border.all(
                  color: msg.failed ? AppColors.danger : AppColors.border,
                ),
        ),
        child: SelectableText(
          msg.text,
          style: t.bodyMedium?.copyWith(
            height: 1.55,
            color: user
                ? AppColors.textOnAccent
                : (msg.failed ? AppColors.danger : AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// TYPING_DOTS_V1 — the three dots a chat shows while the other side writes.
///
/// A spinner in a message bubble reads as "loading", and on a reply that takes
/// most of a minute that becomes "stuck". Dots read as "still writing", which
/// is what is actually happening, and they cost one ticker.
class _Typing extends StatefulWidget {
  const _Typing();

  @override
  State<_Typing> createState() => _TypingState();
}

class _TypingState extends State<_Typing>
    with SingleTickerProviderStateMixin {
  static const int _dots = 3;

  /// One cycle for the whole group; each dot reads its own slice of it, so
  /// three dots need one controller rather than three.
  late final AnimationController _cycle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _cycle.dispose();
    super.dispose();
  }

  /// 0 at rest, 1 at the top of the hop. Linear up then down over the first
  /// half of the dot's slice, flat for the rest, so the group has a gap
  /// between passes instead of rippling continuously.
  double _lift(int index) {
    final t = (_cycle.value - index * 0.16) % 1.0;
    if (t >= 0.45) return 0;
    final p = t / 0.45;
    return p < 0.5 ? p * 2 : (1 - p) * 2;
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: SizedBox(
          height: 10,
          child: AnimatedBuilder(
            animation: _cycle,
            builder: (context, _) => Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (var i = 0; i < _dots; i++) ...[
                  if (i > 0) const SizedBox(width: 6),
                  Transform.translate(
                    offset: Offset(0, -3 * _lift(i)),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.lerp(
                          AppColors.textTertiary,
                          AppColors.accentInk,
                          _lift(i),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !busy,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => busy ? null : onSend(),
                  decoration: const InputDecoration(
                    hintText: 'မေးခွန်း ရေးပါ',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 52,
                height: 48,
                child: FilledButton(
                  onPressed: busy ? null : onSend,
                  style: FilledButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(52, 48),
                  ),
                  child: const Icon(Iconsax.send_1, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════
// Shared bits
// ══════════════════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final String title;
  final String note;
  final Widget child;

  const _Section({
    required this.title,
    required this.note,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: t.titleMedium),
        if (note.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            note,
            style: t.bodySmall?.copyWith(
              color: AppColors.textTertiary,
              height: 1.5,
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool wide;

  const _Figure({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.wide = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                  maxLines: wide ? 1 : 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: t.titleSmall?.copyWith(color: AppColors.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Warning extends StatelessWidget {
  final String text;

  const _Warning({required this.text});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      tone: SurfaceTone.wash,
      washColor: AppColors.warningWash,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.warning_2, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  final String text;

  const _EmptyNote(this.text);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: AppColors.textTertiary),
      ),
    );
  }
}

/// Skeleton shaped like what replaces it, so the layout does not jump.
class _Skeleton extends StatelessWidget {
  const _Skeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        const AppSkeleton(width: 160, height: 18),
        const SizedBox(height: 16),
        Row(
          children: const [
            Expanded(child: AppSkeleton(height: 62, radius: 14)),
            SizedBox(width: 10),
            Expanded(child: AppSkeleton(height: 62, radius: 14)),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: const [
            Expanded(child: AppSkeleton(height: 62, radius: 14)),
            SizedBox(width: 10),
            Expanded(child: AppSkeleton(height: 62, radius: 14)),
          ],
        ),
        const SizedBox(height: 24),
        const AppSkeleton(width: 120, height: 18),
        const SizedBox(height: 12),
        const AppSkeleton(height: 260, radius: 14),
      ],
    );
  }
}
