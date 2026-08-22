import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';
import 'package:vpn_agent_app/features/dashboard/services/dashboard_service.dart';
import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';
import 'package:vpn_agent_app/features/users/services/user_management_service.dart';

class DeviceSlotManagementScreen extends StatefulWidget {
  const DeviceSlotManagementScreen({super.key});

  @override
  State<DeviceSlotManagementScreen> createState() =>
      _DeviceSlotManagementScreenState();
}

class _DeviceSlotManagementScreenState
    extends State<DeviceSlotManagementScreen> {
  final _userService = UserManagementService();
  final _dashboardService = DashboardService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchFocus = FocusNode();

  List<VpnUser> _users = [];

  /// Ids mid-request, so a row shows its own progress instead of an overlay
  /// over the whole list.
  final Set<int> _busyIds = {};

  int _slotPrice = 1000;
  int _maxSlots = 5;
  int? _balance;

  bool _loading = true;
  bool _loadingMore = false;
  bool _searchOpen = false;
  int _page = 1;
  int _lastPage = 1;

  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _fetchSettings();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _fetchSettings() async {
    try {
      final settings = await _userService.getSlotSettings();
      final stats = await _dashboardService.getDashboardStats();
      if (!mounted) return;

      setState(() {
        if (settings != null) {
          _slotPrice = settings.price;
          _maxSlots = settings.maxSlots;
        }
        if (stats is DashboardStats) _balance = stats.creditBalance;
      });
    } catch (_) {
      // Falls back to the default price; the server is the authority on the
      // charge either way and will refuse if the balance is short.
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 600) _loadMore();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _page = 1;
        _users = [];
      });
    }

    final response = await _userService.getVpnUsers(
      page: _page,
      search: _searchController.text.trim(),
    );
    if (!mounted) return;

    setState(() {
      if (response != null) {
        _users = refresh ? response.users : [..._users, ...response.users];
        _lastPage = response.lastPage;
      }
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    _page++;
    await _load();
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(refresh: true),
    );
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
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
    _load(refresh: true);
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _addSlot(VpnUser user) async {
    final money = NumberFormat('#,##0');
    final affordable = _balance == null || _slotPrice <= _balance!;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const AppIconBadge(
          icon: Iconsax.mobile,
          color: AppColors.info,
          background: AppColors.infoWash,
          size: 22,
          padding: 12,
        ),
        title: const Text('Add a device slot?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${user.username} goes from ${user.extraDeviceSlots + 1} to '
              '${user.extraDeviceSlots + 2} devices.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('Cost', style: Theme.of(ctx).textTheme.bodyMedium),
                const Spacer(),
                Text(
                  money.format(_slotPrice),
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                    color: affordable
                        ? AppColors.textPrimary
                        : AppColors.danger,
                  ),
                ),
              ],
            ),
            if (!affordable) ...[
              const SizedBox(height: 4),
              Text(
                'Over your balance',
                style: Theme.of(
                  ctx,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: affordable ? () => Navigator.pop(ctx, true) : null,
            child: const Text('Add slot'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyIds.add(user.id));
    final success = await _userService.addDeviceSlots(user.id, 1);
    if (!mounted) return;
    setState(() => _busyIds.remove(user.id));

    _toast(
      success
          ? 'Slot added for ${user.username}.'
          : 'Could not add the slot. Check your balance.',
    );
    if (success) {
      _load(refresh: true);
      _fetchSettings();
    }
  }

  Future<void> _removeSlot(VpnUser user) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const AppIconBadge(
          icon: Iconsax.mobile_programming,
          color: AppColors.warning,
          background: AppColors.warningWash,
          size: 22,
          padding: 12,
        ),
        title: const Text('Remove a device slot?'),
        content: Text(
          '${user.username} goes from ${user.extraDeviceSlots + 1} to '
          '${user.extraDeviceSlots} devices.\n\n'
          // Stated outright: the server issues no refund, and an agent who
          // assumed otherwise would only find out by checking their balance.
          'No credit is refunded for removing a slot.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.warning),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busyIds.add(user.id));
    final success = await _userService.removeDeviceSlots(user.id, 1);
    if (!mounted) return;
    setState(() => _busyIds.remove(user.id));

    _toast(success ? 'Slot removed.' : 'Could not remove the slot.');
    if (success) _load(refresh: true);
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Device slots')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _PriceBar(price: _slotPrice, balance: _balance),
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
                      textInputAction: TextInputAction.search,
                      onChanged: _onSearchChanged,
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        hintText: 'Search by username',
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
                : _users.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    onRefresh: () => _load(refresh: true),
                    color: AppColors.accentInk,
                    backgroundColor: AppColors.surface,
                    child: Material(
                      color: AppColors.surface,
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.only(bottom: 96),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: _users.length + 1,
                        itemBuilder: (context, i) {
                          if (i == _users.length) return _buildFooter();
                          final user = _users[i];
                          return _SlotRow(
                            key: ValueKey(user.id),
                            user: user,
                            busy: _busyIds.contains(user.id),
                            maxSlots: _maxSlots,
                            onAdd: () => _addSlot(user),
                            onRemove: () => _removeSlot(user),
                          );
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'slot-search',
        onPressed: _toggleSearch,
        backgroundColor: AppColors.surface,
        foregroundColor: _searchOpen
            ? AppColors.accentInk
            : AppColors.textSecondary,
        elevation: 2,
        shape: const CircleBorder(side: BorderSide(color: AppColors.border)),
        child: Icon(
          _searchOpen ? Iconsax.close_circle : Iconsax.search_normal_1,
          size: 20,
        ),
      ),
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: AppLoader(compact: true),
      );
    }
    return const SizedBox(height: 20);
  }

  Widget _buildEmpty() {
    if (_searchController.text.isNotEmpty) {
      return AppEmptyState(
        icon: Iconsax.search_status,
        title: 'No match for "${_searchController.text}"',
      );
    }
    return const AppEmptyState(
      icon: Iconsax.profile_2user,
      title: 'No users yet',
      subtitle: 'Device slots are added per user.',
    );
  }
}

// ── Price bar ─────────────────────────────────────────────────────────────

class _PriceBar extends StatelessWidget {
  final int price;
  final int? balance;

  const _PriceBar({required this.price, required this.balance});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');

    return AppCard(
      tone: SurfaceTone.ink,
      texture: CardTexture.rings,
      showShadow: false,
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Iconsax.mobile,
            color: AppColors.accentInk,
            background: AppColors.surface,
            size: 16,
            padding: 8,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${money.format(price)} per slot',
                  style: t.bodyLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textOnInk,
                  ),
                ),
                Text(
                  // Charged per month, not once — worth saying next to the
                  // price, since a slot recurs at every renewal.
                  'Charged monthly at renewal',
                  style: t.bodySmall?.copyWith(
                    color: AppColors.textOnInk.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          if (balance != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Balance',
                  style: t.bodySmall?.copyWith(
                    color: AppColors.textOnInk.withValues(alpha: 0.6),
                  ),
                ),
                Text(
                  money.format(balance),
                  style: t.titleMedium?.copyWith(
                    fontSize: 14,
                    color: AppColors.textOnInk,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────

class _SlotRow extends StatelessWidget {
  final VpnUser user;
  final bool busy;

  /// From app-config, not a constant: the ceiling is an admin setting, and
  /// hard-coding 5 would let the app offer a slot the server then refuses.
  final int maxSlots;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _SlotRow({
    super.key,
    required this.user,
    required this.busy,
    required this.maxSlots,
    required this.onAdd,
    required this.onRemove,
  });

  static const _avatars = [
    'assets/images/avatars/a1.png',
    'assets/images/avatars/a2.png',
  ];

  static String _avatarFor(String username) {
    if (username.isEmpty) return _avatars.first;
    var hash = 0;
    for (final code in username.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _avatars[hash % _avatars.length];
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // One device comes with the plan; extra_device_slots is what was bought
    // on top, so the total the user actually gets is one more.
    final extra = user.extraDeviceSlots;
    final total = extra + 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
      child: Row(
        children: [
          ClipOval(
            child: Image.asset(
              _avatarFor(user.username),
              width: 42,
              height: 42,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.titleMedium?.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      '$total device${total == 1 ? '' : 's'}',
                      style: t.bodySmall?.copyWith(
                        color: extra > 0
                            ? AppColors.info
                            : AppColors.textTertiary,
                        fontWeight: extra > 0
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                    if (extra > 0)
                      Text(' · +$extra bought', style: t.bodySmall),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (busy)
            const SizedBox(
              width: 40,
              height: 32,
              child: Padding(
                padding: EdgeInsets.all(8),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SlotButton(
                  icon: Icons.remove_rounded,
                  // Nothing to remove when the user is on the plan default.
                  enabled: extra > 0,
                  onTap: onRemove,
                ),
                const SizedBox(width: 6),
                _SlotButton(
                  icon: Icons.add_rounded,
                  enabled: extra < maxSlots,
                  onTap: onAdd,
                  filled: true,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _SlotButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
  final bool filled;

  const _SlotButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = !enabled
        ? AppColors.background
        : filled
        ? AppColors.accentInk
        : AppColors.surfaceAlt;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(9),
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 18,
            color: !enabled
                ? AppColors.textTertiary
                : filled
                ? AppColors.textOnAccent
                : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 8,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 10, 12, 10),
        child: Row(
          children: [
            AppSkeleton(width: 42, height: 42, radius: 21),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 130, height: 13),
                  SizedBox(height: 7),
                  AppSkeleton(width: 90, height: 11),
                ],
              ),
            ),
            SizedBox(width: 8),
            AppSkeleton(width: 74, height: 34, radius: 9),
          ],
        ),
      ),
    );
  }
}
