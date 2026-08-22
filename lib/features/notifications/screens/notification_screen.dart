import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/core/navigation/app_transitions.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/notifications/models/notification_model.dart';
import 'package:vpn_agent_app/features/notifications/screens/send_notification_screen.dart';
import 'package:vpn_agent_app/features/notifications/services/notification_list_service.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  final _service = NotificationListService();
  final _scrollController = ScrollController();

  List<NotificationModel> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _canSendNoti = false;
  int _page = 1;
  bool _hasMore = true;

  int get _unread => _items.where((n) => !n.isRead).length;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _checkPermission();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkPermission() async {
    try {
      final response = await ApiClient().dio.get(ApiConfig.agentProfile);
      if (response.statusCode == 200 && mounted) {
        final data = response.data;
        setState(
          () => _canSendNoti =
              data['can_send_notifications'] == true ||
              data['can_send_notifications'] == 1,
        );
      }
    } catch (_) {
      // Leaves the compose button hidden. Offering it and having the server
      // refuse is worse than not offering it.
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
        _hasMore = true;
        _items = [];
      });
    }

    final data = await _service.getNotifications(page: _page);
    if (!mounted) return;

    setState(() {
      // Deduplicated by id: a row arriving while paging can otherwise appear
      // on two pages and the list would carry it twice.
      final merged = <String, NotificationModel>{
        for (final n in refresh ? <NotificationModel>[] : _items) n.id: n,
        for (final n in data) n.id: n,
      };
      _items = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _hasMore = data.isNotEmpty;
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore) return;
    setState(() => _loadingMore = true);
    _page++;
    await _load();
  }

  // ── Actions ─────────────────────────────────────────────────────────────

  Future<void> _markRead(NotificationModel item) async {
    if (item.isRead) return;

    final index = _items.indexWhere((n) => n.id == item.id);
    if (index == -1) return;

    // Optimistic, then reverted on failure. These were previously local-only:
    // the list was mutated in setState and nothing was sent, so a notification
    // read yesterday came back unread today.
    setState(() => _items[index] = item.copyWith(readAt: DateTime.now()));

    final ok = await _service.markAsRead(item.id);
    if (ok || !mounted) return;

    setState(() {
      final i = _items.indexWhere((n) => n.id == item.id);
      if (i != -1) _items[i] = item;
    });
  }

  Future<void> _markAllRead() async {
    if (_unread == 0) return;
    HapticFeedback.lightImpact();

    final previous = List<NotificationModel>.from(_items);
    setState(() {
      _items = _items
          .map((n) => n.isRead ? n : n.copyWith(readAt: DateTime.now()))
          .toList();
    });

    final ok = await _service.markAllAsRead();
    if (ok || !mounted) return;

    setState(() => _items = previous);
    _toast('Could not mark them read.');
  }

  Future<void> _delete(NotificationModel item) async {
    final index = _items.indexWhere((n) => n.id == item.id);
    if (index == -1) return;

    HapticFeedback.mediumImpact();
    setState(() => _items.removeAt(index));

    final ok = await _service.deleteNotification(item.id);
    if (ok || !mounted) return;

    // Restored at its original index, not appended: putting it back at the
    // bottom of a list sorted by date would look like a different row.
    setState(() => _items.insert(index, item));
    _toast('Could not delete it.');
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
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (_unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: _loading
          ? const _ListSkeleton()
          : _items.isEmpty
          ? const AppEmptyState(
              icon: Iconsax.notification,
              title: 'Nothing here yet',
              subtitle: 'Renewal requests and alerts will appear here.',
            )
          : RefreshIndicator(
              onRefresh: () => _load(refresh: true),
              color: AppColors.accentInk,
              backgroundColor: AppColors.surface,
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                itemCount: _items.length + 1,
                itemBuilder: (context, i) {
                  if (i == _items.length) {
                    return _loadingMore
                        ? const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: AppLoader(compact: true),
                          )
                        : const SizedBox(height: 16);
                  }
                  final item = _items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationCard(
                      key: ValueKey(item.id),
                      item: item,
                      onTap: () => _markRead(item),
                      onDelete: () => _delete(item),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: _canSendNoti
          ? FloatingActionButton(
              onPressed: () async {
                final sent = await Navigator.of(context, rootNavigator: true)
                    .push<bool>(
                      AppTransitions.slide(const SendNotificationScreen()),
                    );
                if (sent == true && mounted) _load(refresh: true);
              },
              backgroundColor: AppColors.accentInk,
              foregroundColor: AppColors.textOnAccent,
              shape: const CircleBorder(),
              child: const Icon(Iconsax.send_1, size: 22),
            )
          : null,
    );
  }
}

// ── Card ──────────────────────────────────────────────────────────────────

/// How a notification is presented, from the type in its payload.
class _NotificationKind {
  final IconData icon;
  final Color color;
  final Color wash;

  const _NotificationKind(this.icon, this.color, this.wash);

  /// Read from the title, since the list endpoint returns no parsed type.
  /// Crude, but the titles are generated server-side from a fixed set.
  static _NotificationKind of(String title) {
    final t = title.toLowerCase();
    if (t.contains('renewal')) {
      return const _NotificationKind(
        Iconsax.refresh_circle,
        AppColors.accentInk,
        AppColors.accentWash,
      );
    }
    if (t.contains('device') || t.contains('slot')) {
      return const _NotificationKind(
        Iconsax.mobile,
        AppColors.info,
        AppColors.infoWash,
      );
    }
    if (t.contains('business')) {
      return const _NotificationKind(
        Iconsax.briefcase,
        AppColors.orange,
        AppColors.orangeWash,
      );
    }
    return const _NotificationKind(
      Iconsax.notification,
      AppColors.violet,
      AppColors.violetWash,
    );
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationCard({
    super.key,
    required this.item,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    // The server writes emoji into the title; they duplicate the icon beside
    // them and break the line height.
    final title = item.title
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\uFE0F]',
            unicode: true,
          ),
          '',
        )
        .trim();
    final kind = _NotificationKind.of(title);

    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      direction: DismissDirection.endToStart,
      // confirmDismiss returns false always: the delete is optimistic and
      // restores the row on failure, so letting Dismissible also remove it
      // would leave nothing to restore.
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: const Icon(
          Iconsax.trash,
          size: 18,
          color: AppColors.textOnAccent,
        ),
      ),
      child: AppCard(
        onTap: onTap,
        radius: AppTheme.radiusMd,
        padding: const EdgeInsets.all(14),
        // Unread carries a tint; read is plain. The dot alone was too small to
        // scan a list by.
        tone: item.isRead ? SurfaceTone.plain : SurfaceTone.wash,
        washColor: kind.wash,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppIconBadge(
              icon: kind.icon,
              color: kind.color,
              background: item.isRead
                  ? AppColors.surfaceAlt
                  : AppColors.surface,
              size: 17,
              padding: 9,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isEmpty ? 'Notification' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyLarge?.copyWith(
                            fontSize: 14,
                            fontWeight: item.isRead
                                ? FontWeight.w600
                                : FontWeight.w800,
                          ),
                        ),
                      ),
                      if (!item.isRead) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: kind.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      item.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(
                        color: item.isRead
                            ? AppColors.textTertiary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 5),
                  Text(
                    _relative(item.createdAt),
                    style: t.bodySmall?.copyWith(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relative(DateTime raw) {
    final local = raw.toLocal();
    final diff = DateTime.now().difference(local);

    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('dd MMM yyyy, h:mm a').format(local);
  }
}

class _ListSkeleton extends StatelessWidget {
  const _ListSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const AppCard(
        padding: EdgeInsets.all(14),
        radius: AppTheme.radiusMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSkeleton(width: 35, height: 35, radius: AppTheme.radiusSm),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 150, height: 13),
                  SizedBox(height: 7),
                  AppSkeleton(width: 210, height: 11),
                  SizedBox(height: 7),
                  AppSkeleton(width: 70, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
