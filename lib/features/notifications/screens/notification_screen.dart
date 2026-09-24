import 'dart:async'; // AGENT_APP_K1_IMPORT — the post-send re-check timer.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

// C_LISTS_NS_IMPORTS — Fmt replaces a DateFormat built per row; AppLog carries
// the page-fetch failure this screen now has to tell apart from an empty page.
import '../../../core/utils/app_log.dart';
import '../../../core/utils/formatters.dart';

import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/core/navigation/app_transitions.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/scaffold/main_scaffold.dart';
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

  /// C_LISTS_NS_STATE — cleared only when the server has answered with an
  /// empty page. A failed request no longer clears it: a timeout is not the
  /// end of the list, and treating it as one is what stopped older
  /// notifications arriving for the rest of the session.
  bool _hasMore = true;

  /// The first page could not be fetched. A different screen from "there is
  /// nothing here", with a different thing to offer.
  bool _loadFailed = false;

  /// A later page could not be fetched. The cursor is kept and the end of the
  /// list carries a retry, rather than the list quietly going still.
  bool _pageFailed = false;

  /// AGENT_APP_K1_FIELD — the second look after a send.
  ///
  /// The send screen no longer waits for its POST, so the refresh fired when
  /// it pops can beat the server to the record.
  Timer? _afterSend;

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
    // AGENT_APP_K1_DISPOSE
    _afterSend?.cancel();
    _scrollController.removeListener(_onScroll);
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

  /// C_LISTS_NS_FETCH — one page, or null when the request failed.
  ///
  /// NotificationListService.getNotifications returns an empty list for both
  /// "the server has no more rows" and "the call threw", which is exactly the
  /// distinction this screen needs and cannot recover afterwards. The read is
  /// made here, next to the profile request already being made directly above.
  /// Every write still goes through the service.
  Future<List<NotificationModel>?> _fetchPage(int page) async {
    try {
      final response = await ApiClient().dio.get(
        '/agent/notifications?page=$page',
      );
      if (response.statusCode != 200) return null;

      final body = response.data;
      List<dynamic> raw = const [];
      if (body is Map && body['data'] is List) {
        raw = body['data'] as List<dynamic>;
      } else if (body is List) {
        raw = body;
      }
      return raw
          .map((e) => NotificationModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (error) {
      AppLog.e('NotificationScreen._fetchPage', error);
      return null;
    }
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _loading = true;
        _page = 1;
        _hasMore = true;
        _loadFailed = false;
        _pageFailed = false;
        _items = [];
      });
    }

    final data = await _fetchPage(_page);
    if (!mounted) return;

    setState(() {
      if (data == null) {
        // Nothing already loaded is dropped and _hasMore is left alone, so the
        // page that failed can be asked for again. Which flag is set decides
        // whether the agent gets a whole-screen retry or one at the end of the
        // rows already on screen.
        if (_items.isEmpty) {
          _loadFailed = true;
        } else {
          _pageFailed = true;
        }
      } else {
        _loadFailed = false;
        _pageFailed = false;
        // Deduplicated by id: a row arriving while paging can otherwise appear
        // on two pages and the list would carry it twice.
        final merged = <String, NotificationModel>{
          for (final n in refresh ? <NotificationModel>[] : _items) n.id: n,
          for (final n in data) n.id: n,
        };
        _items = merged.values.toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        // Only a successful, empty page ends pagination.
        _hasMore = data.isNotEmpty;
      }
      _loading = false;
      _loadingMore = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || !_hasMore || _pageFailed) return;
    setState(() => _loadingMore = true);
    _page++;
    await _load();
    // The cursor goes back to the page that failed, so a retry asks for that
    // page rather than the one after it.
    if (mounted && _pageFailed) _page--;
  }

  /// Asks for the failed page again, from the button at the end of the list.
  void _retryPage() {
    HapticFeedback.selectionClick();
    setState(() => _pageFailed = false);
    _loadMore();
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

  /// Marks the notification read, then goes where its payload points.
  ///
  /// The server writes a `screen` key for exactly this. Without it a renewal
  /// notification was a dead end — the agent read "Renewal Request" and then
  /// navigated to the Requests tab by hand.
  Future<void> _openNotification(NotificationModel item) async {
    await _markRead(item);
    if (!mounted) return;

    final shell = MainShell.of(context);
    final destination = switch (item.screen) {
      'renewal_requests' => 'Requests',
      'chat' || 'home' => 'Chat',
      _ => null,
    };

    // No destination in the payload, or no shell above this route: reading it
    // is all there is to do.
    if (destination == null || shell == null) return;

    // Popped first — the tab lives in the shell underneath, and pushing over
    // this screen would leave two ways back to the same place.
    Navigator.of(context).pop();
    shell.goToTab(destination);
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
          // C_LISTS_NS_BODY — the failed request gets its own panel, with a
          // way out of it. The empty one still says nothing has arrived yet,
          // and is now only shown when that is true.
          ? (_loadFailed
                ? AppEmptyState(
                    icon: Iconsax.warning_2,
                    title: 'အကြောင်းကြားချက်များ ဆွဲယူ၍ မရပါ',
                    subtitle:
                        'အင်တာနက် ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်မံကြိုးစားပါ။',
                    actionLabel: 'ပြန်ကြိုးစားမည်',
                    onAction: () => _load(refresh: true),
                  )
                : const AppEmptyState(
                    icon: Iconsax.notification,
                    title: 'Nothing here yet',
                    subtitle: 'Renewal requests and alerts will appear here.',
                  ))
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
                    // C_LISTS_NS_FOOTER — the end of the list is where a failed
                    // page is reported and where it is asked for again. Before
                    // this it reported nothing at all and the list simply
                    // stopped growing.
                    if (_loadingMore) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: AppLoader(compact: true),
                      );
                    }
                    if (_pageFailed) return _PageRetry(onRetry: _retryPage);
                    return const SizedBox(height: 16);
                  }
                  final item = _items[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _NotificationCard(
                      key: ValueKey(item.id),
                      item: item,
                      onTap: () => _openNotification(item),
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
                // AGENT_APP_K1_REFRESH — ask twice, briefly apart.
                if (sent == true && mounted) {
                  _load(refresh: true);
                  _afterSend?.cancel();
                  _afterSend = Timer(const Duration(seconds: 2), () {
                    if (mounted) _load(refresh: true);
                  });
                }
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

/// Emoji the server writes into notification titles.
///
/// C_LISTS_NS_PATTERN — compiled once, at first use. This was constructed
/// inside _NotificationCard.build, so once per visible card per frame, and a
/// RegExp compiles its source when it is constructed.
final RegExp _emojiPattern = RegExp(
  r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\uFE0F]',
  unicode: true,
);

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
    // C_LISTS_NS_REGEX — the server writes emoji into the title; they
    // duplicate the icon beside them and break the line height. The pattern
    // that strips them is at the top of this file now, not built here.
    final title = item.title.replaceAll(_emojiPattern, '').trim();
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
    // C_LISTS_NS_RELATIVE — Fmt.dateTime is the same pattern, built once.
    return Fmt.dateTime.format(local);
  }
}

/// C_LISTS_NS_RETRYWIDGET — the end of the list after a page failed to load.
///
/// The flag this replaces ended pagination for the life of the screen: one
/// timeout and no older notification was ever fetched again, with nothing on
/// screen to say so. The cursor is kept now, and this is how it is asked for.
class _PageRetry extends StatelessWidget {
  final VoidCallback onRetry;

  const _PageRetry({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'နောက်ထပ် အကြောင်းကြားချက်များ ဆွဲယူ၍ မရပါ',
            textAlign: TextAlign.center,
            style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Iconsax.refresh_circle, size: 16),
            label: const Text('ထပ်မံကြိုးစားမည်'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(148, 48),
              foregroundColor: AppColors.accentInk,
              side: const BorderSide(color: AppColors.border),
              shape: const StadiumBorder(),
            ),
          ),
        ],
      ),
    );
  }
}

/// C_LISTS_NS_SKELETON — one ticker for the whole placeholder list.
///
/// AppSkeleton owns an AnimationController each; six rows of four bars meant
/// twenty-four of them, all running the same 1200ms sweep while the screen
/// waited for its first page. One controller lives here and every bar listens
/// to it.
class _ListSkeleton extends StatefulWidget {
  const _ListSkeleton();

  @override
  State<_ListSkeleton> createState() => _ListSkeletonState();
}

class _ListSkeletonState extends State<_ListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shimmer;

  @override
  void initState() {
    super.initState();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, _) => AppCard(
        padding: const EdgeInsets.all(14),
        radius: AppTheme.radiusMd,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBar(
              _shimmer,
              width: 35,
              height: 35,
              radius: AppTheme.radiusSm,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBar(_shimmer, width: 150, height: 13),
                  const SizedBox(height: 7),
                  _SkeletonBar(_shimmer, width: 210, height: 11),
                  const SizedBox(height: 7),
                  _SkeletonBar(_shimmer, width: 70, height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One placeholder bar, painting from an animation it does not own.
class _SkeletonBar extends StatelessWidget {
  final Animation<double> shimmer;
  final double? width;
  final double height;
  final double radius;

  const _SkeletonBar(
    this.shimmer, {
    this.width,
    this.height = 14,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: shimmer,
        builder: (context, _) {
          // The gradient slides across a fixed box rather than the box moving,
          // so nothing is laid out again per frame.
          final t = shimmer.value * 2 - 1;
          return Container(
            width: width,
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              gradient: LinearGradient(
                begin: Alignment(-1 + t, 0),
                end: Alignment(1 + t, 0),
                colors: const [
                  AppColors.surfaceAlt,
                  AppColors.border,
                  AppColors.surfaceAlt,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
