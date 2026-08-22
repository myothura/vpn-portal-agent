import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:vpn_agent_app/core/navigation/app_transitions.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/agent_management/models/agent_model.dart';
import 'package:vpn_agent_app/features/agent_management/screens/create_edit_agent_screen.dart';
import 'package:vpn_agent_app/features/agent_management/services/agent_management_service.dart';

class AgentListScreen extends StatefulWidget {
  const AgentListScreen({super.key});

  @override
  State<AgentListScreen> createState() => _AgentListScreenState();
}

class _AgentListScreenState extends State<AgentListScreen> {
  final _service = AgentManagementService();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  List<AgentModel> _agents = [];
  bool _loading = true;
  bool _searchOpen = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final agents = await _service.getAllAgents();
    if (!mounted) return;
    setState(() {
      _agents = agents;
      _loading = false;
    });
  }

  /// Groups the list by who created each agent.
  ///
  /// Only the super-admin sees a mixed list: everyone else's index() is
  /// already filtered to their own children, which would be one group and no
  /// grouping at all. Agents directly under the super-admin come first as a
  /// flat run; the rest follow under the agent that created them, which is the
  /// only place a sub-agent's ownership is visible.
  ///
  /// Rows with no parent are kept in their own group rather than dropped —
  /// there are two in the table, and an agent absent from a management screen
  /// is worse than one under an awkward heading.
  List<({String? title, List<AgentModel> agents})> get _grouped {
    final agents = _filtered;
    if (agents.isEmpty) return const [];

    final ids = {for (final a in _agents) a.id};
    // "Top level" means the parent is not itself in this list — the
    // super-admin, or an account that is not an agent.
    final top = agents.where((a) => !ids.contains(a.parentId)).toList();

    final byParent = <int, List<AgentModel>>{};
    for (final a in agents) {
      if (ids.contains(a.parentId)) {
        byParent.putIfAbsent(a.parentId!, () => []).add(a);
      }
    }

    if (byParent.isEmpty) return [(title: null, agents: top)];

    final nameOf = {for (final a in _agents) a.id: a.name};
    final groups = <({String? title, List<AgentModel> agents})>[
      if (top.isNotEmpty) (title: null, agents: top),
    ];

    final parentIds = byParent.keys.toList()
      ..sort((a, b) => byParent[b]!.length.compareTo(byParent[a]!.length));

    for (final pid in parentIds) {
      groups.add((
        title: '${nameOf[pid] ?? 'Unknown'}\'s agents',
        agents: byParent[pid]!,
      ));
    }

    return groups;
  }

  /// Filtered in Dart, unlike the user and request lists: the endpoint returns
  /// every agent in one response and there are 36 of them, so a round trip per
  /// keystroke would be the slower option.
  List<AgentModel> get _filtered {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _agents;
    return _agents
        .where(
          (a) =>
              a.name.toLowerCase().contains(query) ||
              a.email.toLowerCase().contains(query),
        )
        .toList();
  }

  void _toggleSearch() {
    HapticFeedback.selectionClick();
    setState(() => _searchOpen = !_searchOpen);

    if (_searchOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchFocus.requestFocus();
      });
      return;
    }
    _searchFocus.unfocus();
    _searchController.clear();
  }

  Future<void> _openEditor([AgentModel? agent]) async {
    // rootNavigator: a form with a docked action bar owns the screen. Pushed
    // inside the tab, the bar had to clear the nav bar underneath it, which
    // left it floating rather than sitting on the bottom edge.
    final changed = await Navigator.of(
      context,
      rootNavigator: true,
    ).push<bool>(AppTransitions.slide(CreateEditAgentScreen(agent: agent)));
    if (changed == true) _load();
  }

  Future<void> _confirmDelete(AgentModel agent) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const AppIconBadge(
          icon: Iconsax.trash,
          color: AppColors.danger,
          background: AppColors.dangerWash,
          size: 22,
          padding: 12,
        ),
        title: Text('Delete ${agent.name}?'),
        content: Text(
          agent.userCount > 0
              // Named rather than implied: an agent with users is not an
              // account you delete casually, and the count is the reason.
              ? '${agent.name} has ${agent.userCount} '
                    'user${agent.userCount == 1 ? '' : 's'}. Deleting the agent '
                    'does not delete them.'
              : 'This cannot be undone.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final success = await _service.deleteAgent(agent.id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(success ? 'Agent deleted.' : 'Could not delete.')),
    );
    if (success) _load();
  }

  /// The grouped list flattened into headings and cards, in draw order.
  List<({String? heading, AgentModel? agent})> get _rows {
    final out = <({String? heading, AgentModel? agent})>[];
    for (final group in _grouped) {
      if (group.title != null) {
        out.add((heading: group.title, agent: null));
      }
      for (final a in group.agents) {
        out.add((heading: null, agent: a));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final agents = _filtered;
    final rows = _rows;
    final totalCredit = _agents.fold<int>(0, (sum, a) => sum + a.creditBalance);
    final totalUsers = _agents.fold<int>(0, (sum, a) => sum + a.userCount);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('My agents')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _SummaryCard(
              agentCount: _agents.length,
              totalUsers: totalUsers,
              totalCredit: totalCredit,
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_searchOpen
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocus,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Search by name or email',
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        prefixIconConstraints: const BoxConstraints(
                          minWidth: 38,
                          minHeight: 38,
                        ),
                        prefixIcon: const Icon(
                          Iconsax.search_normal_1,
                          size: 17,
                          color: AppColors.textTertiary,
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(
                            Iconsax.close_circle,
                            size: 18,
                            color: AppColors.textTertiary,
                          ),
                          onPressed: _toggleSearch,
                        ),
                      ),
                    ),
                  ),
          ),
          Expanded(
            child: _loading
                ? const _ListSkeleton()
                : agents.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: _load,
                    color: AppColors.accentInk,
                    backgroundColor: AppColors.surface,
                    // Flattened into one list rather than nested ListViews:
                    // a section heading is just another row among the cards,
                    // and nesting would cost the outer list its ability to
                    // build them lazily.
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      itemCount: rows.length,
                      itemBuilder: (context, i) {
                        final row = rows[i];
                        if (row.heading != null) {
                          return Padding(
                            padding: EdgeInsets.only(
                              top: i == 0 ? 0 : 18,
                              bottom: 10,
                            ),
                            child: AppSectionHeader(title: row.heading!),
                          );
                        }
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AgentCard(
                            key: ValueKey(row.agent!.id),
                            agent: row.agent!,
                            onEdit: () => _openEditor(row.agent!),
                            onDelete: () => _confirmDelete(row.agent!),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton.small(
            heroTag: 'agent-search',
            onPressed: _toggleSearch,
            backgroundColor: AppColors.surface,
            foregroundColor: _searchOpen
                ? AppColors.accentInk
                : AppColors.textSecondary,
            elevation: 2,
            shape: const CircleBorder(
              side: BorderSide(color: AppColors.border),
            ),
            child: Icon(
              _searchOpen ? Iconsax.close_circle : Iconsax.search_normal_1,
              size: 20,
            ),
          ),
          const SizedBox(height: 12),
          FloatingActionButton(
            heroTag: 'agent-add',
            onPressed: () => _openEditor(),
            backgroundColor: AppColors.accentInk,
            foregroundColor: AppColors.textOnAccent,
            shape: const CircleBorder(),
            child: const Icon(Iconsax.add, size: 26),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    if (_searchController.text.isNotEmpty) {
      return AppEmptyState(
        icon: Iconsax.search_status,
        title: 'No match for "${_searchController.text}"',
      );
    }
    return const AppEmptyState(
      icon: Iconsax.user_octagon,
      title: 'No agents yet',
      subtitle: 'Agents you create can sell to their own users.',
    );
  }
}

// ── Summary ───────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final int agentCount;
  final int totalUsers;
  final int totalCredit;

  const _SummaryCard({
    required this.agentCount,
    required this.totalUsers,
    required this.totalCredit,
  });

  @override
  Widget build(BuildContext context) {
    final money = NumberFormat('#,##0');

    return AppCard(
      tone: SurfaceTone.ink,
      texture: CardTexture.rings,
      showShadow: false,
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: _Figure(label: 'Agents', value: '$agentCount'),
          ),
          _Divider(),
          Expanded(
            child: _Figure(label: 'Their users', value: '$totalUsers'),
          ),
          _Divider(),
          Expanded(
            // Credit held by agents is money already paid for but not yet
            // spent — worth seeing next to the headcount.
            child: _Figure(
              label: 'Credit held',
              value: money.format(totalCredit),
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 30,
    color: AppColors.textOnInk.withValues(alpha: 0.12),
  );
}

class _Figure extends StatelessWidget {
  final String label;
  final String value;

  const _Figure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: t.bodySmall?.copyWith(
            color: AppColors.textOnInk.withValues(alpha: 0.65),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.titleMedium?.copyWith(
            color: AppColors.textOnInk,
            fontSize: 15,
          ),
        ),
      ],
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────

class _AgentCard extends StatelessWidget {
  final AgentModel agent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AgentCard({
    super.key,
    required this.agent,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');
    final active = agent.status == 'active';

    return AppCard(
      onTap: onEdit,
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: active ? AppColors.accentWash : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  agent.name.isEmpty ? '?' : agent.name[0].toUpperCase(),
                  style: t.titleMedium?.copyWith(
                    color: active
                        ? AppColors.accentInk
                        : AppColors.textTertiary,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            agent.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: t.titleMedium?.copyWith(fontSize: 14.5),
                          ),
                        ),
                        // The top-up bonus, against the name it belongs to.
                        // Shown only when set — most agents are on 0, and a
                        // "+0%" badge on three quarters of the list would say
                        // nothing.
                        if (agent.topupBonusPercent > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentWash,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              '+${agent.topupBonusPercent.toStringAsFixed(0)}%',
                              style: t.bodySmall?.copyWith(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppColors.accentInk,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      agent.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!active)
                const AppPill(
                  label: 'PAUSED',
                  color: AppColors.neutral,
                  background: AppColors.neutralWash,
                ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Iconsax.trash, size: 17),
                color: AppColors.textTertiary,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _Stat(
                icon: Iconsax.profile_2user,
                value: '${agent.userCount}',
                label: 'users',
              ),
              const SizedBox(width: 16),
              _Stat(
                icon: Iconsax.wallet_2,
                value: money.format(agent.creditBalance),
                label: 'credit',
              ),
              const Spacer(),
              // Permissions as three marks rather than three chips: they are
              // read as a set, and an agent with none should occupy no more
              // room than one with all three.
              _PermissionDots(agent: agent),
            ],
          ),
          if (agent.parentName != null) ...[
            const SizedBox(height: 8),
            Text(
              'Under ${agent.parentName}',
              style: t.bodySmall?.copyWith(fontSize: 11),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const _Stat({required this.icon, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 5),
        Text(
          value,
          style: t.bodyLarge?.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 3),
        Text(label, style: t.bodySmall?.copyWith(fontSize: 11)),
      ],
    );
  }
}

/// The three permissions, granted ones filled and the rest outlined.
class _PermissionDots extends StatelessWidget {
  final AgentModel agent;

  const _PermissionDots({required this.agent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Dot(
          icon: Iconsax.message_text,
          granted: agent.canAccessChat,
          tooltip: 'Support chat',
          color: AppColors.info,
        ),
        const SizedBox(width: 6),
        _Dot(
          icon: Iconsax.send_2,
          granted: agent.canSendNotifications,
          tooltip: 'Send notifications',
          color: AppColors.violet,
        ),
        const SizedBox(width: 6),
        _Dot(
          icon: Iconsax.user_octagon,
          granted: agent.canManageAgents,
          tooltip: 'Manage sub-agents',
          color: AppColors.orange,
        ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  final IconData icon;
  final bool granted;
  final String tooltip;
  final Color color;

  const _Dot({
    required this.icon,
    required this.granted,
    required this.tooltip,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: granted ? tooltip : '$tooltip — not granted',
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: granted ? color.withValues(alpha: 0.14) : Colors.transparent,
          shape: BoxShape.circle,
          border: granted ? null : Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 12,
          color: granted ? color : AppColors.borderStrong,
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const AppCard(
        padding: EdgeInsets.all(14),
        radius: AppTheme.radiusMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppSkeleton(width: 40, height: 40, radius: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(width: 120, height: 13),
                      SizedBox(height: 7),
                      AppSkeleton(width: 170, height: 11),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 14),
            AppSkeleton(width: 200, height: 14),
          ],
        ),
      ),
    );
  }
}
