import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:vpn_agent_app/core/navigation/app_transitions.dart';
import 'package:vpn_agent_app/core/services/agent_realtime_service.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/core/utils/app_time.dart';
import 'package:vpn_agent_app/core/widgets/confirm_dialog.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/chat/screens/agent_chat_detail_screen.dart';
import 'package:vpn_agent_app/features/chat/services/agent_chat_service.dart';

class AgentChatListScreen extends StatefulWidget {
  const AgentChatListScreen({super.key});

  @override
  State<AgentChatListScreen> createState() => _AgentChatListScreenState();
}

class _AgentChatListScreenState extends State<AgentChatListScreen> {
  final _chatService = AgentChatService();
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final _searchFocus = FocusNode();

  List<Map<String, dynamic>> _users = [];

  bool _loading = true;
  bool _loadingMore = false;

  /// LIST_FAILURE_STATE_V1 — the last load came back empty-handed and there
  /// is nothing on screen. Distinct from having no conversations at all.
  bool _failed = false;
  bool _selfRenewal = false;
  bool _isAdmin = false;
  bool _searchOpen = false;

  int _page = 1;
  int _lastPage = 1;

  Timer? _pollTimer;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Live updates come from the Reverb socket the app already runs for the
    // detail screen. The list previously polled every 8 seconds — three
    // requests each time, including a dashboard call the shell already makes —
    // which is roughly 1,300 requests an hour for a screen that is usually
    // idle.
    AgentRealtimeService.instance.start();
    AgentRealtimeService.instance.addListener(_onRealtimeMessage);

    // A slow poll remains as a safety net: it reconciles reads made from
    // another device and anything missed while the socket was reconnecting.
    _pollTimer = Timer.periodic(
      const Duration(seconds: 45),
      (_) => _load(silent: true),
    );

    _load();
  }

  @override
  void dispose() {
    AgentRealtimeService.instance.removeListener(_onRealtimeMessage);
    _pollTimer?.cancel();
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ── Data ──

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final p = _scrollController.position;
    if (p.pixels >= p.maxScrollExtent - 400) _loadMore();
  }

  /// Moves a conversation to the top and bumps its unread count when a message
  /// arrives, rather than refetching the page.
  void _onRealtimeMessage(Map<String, dynamic> msg) {
    if (!mounted || msg['sender_type'] != 'user') return;

    final raw = msg['vpn_user_id'];
    final userId = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (userId == null) return;

    final index = _users.indexWhere((u) => u['id'] == userId);
    if (index == -1) {
      // A conversation not on this page — the poll will pick it up rather than
      // this guessing at a row it has never seen.
      return;
    }

    setState(() {
      final user = Map<String, dynamic>.from(_users[index]);
      user['unread_count'] = ((user['unread_count'] ?? 0) as int) + 1;
      user['last_message'] = msg['message'] ?? user['last_message'];
      user['last_message_type'] = msg['type'] ?? 'text';
      user['last_message_sender'] = 'user';
      user['last_message_at'] = DateTime.now().toIso8601String();

      _users.removeAt(index);
      _users.insert(0, user);
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);

    final results = await Future.wait([
      _chatService.getSelfRenewalStatus(),
      _chatService.getUsers(search: _searchController.text.trim(), page: 1),
    ]);
    if (!mounted) return;

    final status = results[0] as Map<String, dynamic>;
    final result = results[1];

    setState(() {
      _selfRenewal = status['allow_self_renewal'] == true;
      _isAdmin = status['is_admin'] == true;

      if (result?['data'] != null) {
        // Replaced outright, not merged. The old merge only ever added or
        // updated rows, so a conversation that had gone from the server —
        // deleted, or reassigned to another agent — stayed on screen forever.
        _users = (result!['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _page = result['current_page'] ?? 1;
        _lastPage = result['last_page'] ?? 1;
        _failed = false;
      } else {
        // A failed 45-second poll leaves the rows it has; only a screen with
        // nothing on it reports the failure.
        _failed = _users.isEmpty;
      }
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loading || _page >= _lastPage) return;
    setState(() => _loadingMore = true);

    final result = await _chatService.getUsers(
      search: _searchController.text.trim(),
      page: _page + 1,
    );
    if (!mounted) return;

    setState(() {
      if (result?['data'] != null) {
        _users.addAll(
          (result!['data'] as List).map((e) => Map<String, dynamic>.from(e)),
        );
        _page = result['current_page'] ?? _page + 1;
        _lastPage = result['last_page'] ?? _lastPage;
      }
      _loadingMore = false;
    });
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 400),
      () => _load(silent: true),
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
    _load(silent: true);
  }

  // ── Actions ──

  Future<void> _openChat(Map<String, dynamic> user) async {
    // Cleared optimistically: opening the thread marks it read server-side,
    // and waiting for the next poll left a badge on a conversation the agent
    // had just finished reading.
    final index = _users.indexWhere((u) => u['id'] == user['id']);
    if (index != -1) {
      setState(() => _users[index]['unread_count'] = 0);
    }

    // rootNavigator: pushed over the whole shell, not inside the tab. A chat
    // thread owns the screen — the nav bar underneath it is a row of controls
    // the agent cannot use while typing a reply, and it costs the keyboard
    // 60px it needs.
    await Navigator.of(context, rootNavigator: true).push(
      AppTransitions.slide(
        AgentChatDetailScreen(
          userId: user['id'],
          username: user['username'] ?? '',
        ),
      ),
    );
    if (mounted) _load(silent: true);
  }

  Future<void> _toggleSelfRenewal(bool value) async {
    HapticFeedback.selectionClick();
    setState(() => _selfRenewal = value);
    final ok = await _chatService.toggleSelfRenewal(value);
    if (!mounted || ok) return;

    // Reverted on failure: leaving the switch where the agent put it implies
    // a setting that is not actually in force.
    setState(() => _selfRenewal = !value);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not change the setting.')),
    );
  }

  /// BROADCAST_CONFIRM_V1 — asks before writing into every thread.
  ///
  /// This is the least recallable action in the app: each conversation gets a
  /// real message row and each user gets a push, and the sheet sent all of it
  /// on one tap of a button labelled "Send". The dialog says how many
  /// conversations are loaded here, shows the opening of the message, and says
  /// in as many words that it cannot be taken back.
  Future<void> _broadcast() async {
    final result =
        await showModalBottomSheet<({String target, String message})>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _BroadcastSheet(isAdmin: _isAdmin),
        );
    if (result == null || !mounted) return;

    final body = result.message;
    final preview = body.length > 90 ? '${body.substring(0, 90)}…' : body;

    final confirmed = await confirmAction(
      context,
      title: 'စကားပြောခန်းအားလုံးသို့ ပို့မလား',
      message:
          'ဤစာကို စကားပြောခန်းတိုင်းသို့ တစ်ပြိုင်နက် ပို့ပါမည်။ '
          'ဤစာရင်းတွင် မပါသေးသော စကားပြောခန်းများသို့လည်း ရောက်ပါမည်။ '
          'ပို့ပြီးပါက ပြန်လည် ရုပ်သိမ်း၍ မရပါ။',
      confirmLabel: 'ပို့မည်',
      destructive: true,
      details: [
        ConfirmDetail(
          'ဤစာရင်းတွင် ရှိသော စကားပြောခန်း',
          '${_users.length} ခု',
          emphasise: true,
        ),
        if (result.target == 'expiring')
          const ConfirmDetail('ရွေးချယ်မှု', 'သက်တမ်းကုန်ခါနီး အသုံးပြုသူများ')
        else
          const ConfirmDetail('ရွေးချယ်မှု', 'အသုံးပြုသူအားလုံး'),
        ConfirmDetail('စာသား', preview),
      ],
    );
    if (!confirmed || !mounted) return;

    final ok = await _chatService.broadcastMessage(
      result.message,
      result.target,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? 'Broadcast sent.' : 'Could not send.')),
    );
    if (ok) _load(silent: true);
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    final unread = _users.fold<int>(
      0,
      (sum, u) => sum + ((u['unread_count'] ?? 0) as int),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          const _ChatHeroBackdrop(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const SizedBox(height: 10),
                _Header(
                  unread: unread,
                  selfRenewal: _selfRenewal,
                  onToggleSelfRenewal: _toggleSelfRenewal,
                  onBroadcast: _broadcast,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.topCenter,
                  child: !_searchOpen
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
                const SizedBox(height: 12),
                Expanded(
                  child: _loading
                      ? const _ListSkeleton()
                      : _users.isEmpty
                      ? (_failed ? _buildFailed() : _buildEmpty())
                      : RefreshIndicator(
                          onRefresh: () => _load(silent: true),
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
                              itemExtent: _ChatRow.height,
                              itemCount: _users.length + 1,
                              itemBuilder: (context, i) {
                                if (i == _users.length) return _buildFooter();
                                final user = _users[i];
                                return _ChatRow(
                                  key: ValueKey(user['id']),
                                  user: user,
                                  onTap: () => _openChat(user),
                                );
                              },
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        heroTag: 'chat-search',
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
      icon: Iconsax.message_text,
      title: 'No conversations yet',
      subtitle: 'Messages from your users will appear here.',
    );
  }

  /// The list did not load. "No conversations yet" said the opposite, on a
  /// screen whose whole purpose is telling the agent who is waiting.
  Widget _buildFailed() => AppEmptyState(
    icon: Iconsax.cloud_cross,
    title: 'စကားပြောခန်းများ ဆွဲယူ၍ မရပါ',
    subtitle: 'အင်တာနက် ချိတ်ဆက်မှုကို စစ်ဆေးပြီး ထပ်မံ ကြိုးစားပါ။',
    actionLabel: 'ထပ်မံကြိုးစားမည်',
    onAction: () => _load(),
  );
}

// ── Header ────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int unread;
  final bool selfRenewal;
  final ValueChanged<bool> onToggleSelfRenewal;
  final VoidCallback onBroadcast;

  const _Header({
    required this.unread,
    required this.selfRenewal,
    required this.onToggleSelfRenewal,
    required this.onBroadcast,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // One line. The self-renewal setting had a full card of its own with two
    // lines of explanation, which spent a third of the screen above the list
    // on a switch that is set once and then left alone. It is now a toggle
    // beside broadcast, with its meaning in the tooltip and a long-press.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
      child: Row(
        children: [
          Text('Support', style: t.headlineMedium?.copyWith(fontSize: 22)),
          const SizedBox(width: 8),
          if (unread > 0)
            AppPill(
              label: '$unread',
              color: AppColors.textOnAccent,
              background: AppColors.danger,
            ),
          const Spacer(),
          _SelfRenewalToggle(
            enabled: selfRenewal,
            onChanged: onToggleSelfRenewal,
          ),
          IconButton(
            onPressed: onBroadcast,
            icon: const Icon(Iconsax.send_2, size: 20),
            color: AppColors.textSecondary,
            tooltip: 'Broadcast to users',
          ),
        ],
      ),
    );
  }
}

/// Self-renewal, as an icon toggle.
///
/// Tapping flips it; the tooltip and a long-press explain what it does, since
/// the label it replaced was the only thing saying so.
class _SelfRenewalToggle extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SelfRenewalToggle({required this.enabled, required this.onChanged});

  void _explain(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: AppIconBadge(
          icon: enabled ? Iconsax.tick_circle : Iconsax.close_circle,
          color: enabled ? AppColors.accentInk : AppColors.textTertiary,
          background: enabled ? AppColors.accentWash : AppColors.surfaceAlt,
          size: 22,
          padding: 12,
        ),
        title: Text(enabled ? 'Self-renewal is on' : 'Self-renewal is off'),
        content: Text(
          enabled
              ? 'Your users can submit renewal requests from their own app. '
                    'They arrive in the Requests tab for you to approve.'
              : 'Your users cannot submit renewals themselves. They have to '
                    'message you here and you renew on their behalf.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onChanged(!enabled);
            },
            child: Text(enabled ? 'Turn off' : 'Turn on'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: enabled
          ? 'Users can renew themselves'
          : 'Users cannot renew themselves',
      child: InkWell(
        onTap: () => onChanged(!enabled),
        onLongPress: () => _explain(context),
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.refresh_circle,
                size: 18,
                color: enabled ? AppColors.accentInk : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              // A small track rather than a full Switch: at this size a
              // Material switch is taller than the row it sits in.
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: 30,
                height: 17,
                padding: const EdgeInsets.all(2),
                alignment: enabled
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: enabled ? AppColors.accentInk : AppColors.borderStrong,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: const BoxDecoration(
                    color: AppColors.surface,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Row ───────────────────────────────────────────────────────────────────

class _ChatRow extends StatelessWidget {
  static const double height = 74;

  final Map<String, dynamic> user;
  final VoidCallback onTap;

  const _ChatRow({super.key, required this.user, required this.onTap});

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

  /// IMG_L_LISTAVATAR_FN — the 46-point circle, in device pixels.
  ///
  /// a1.png and a2.png are 256x256 — 0.26 MB each once decoded — and both land
  /// in the image cache as soon as this list paints, which is the first thing
  /// this tab shows. Nothing on screen draws them wider than 46 points, so
  /// every pixel past that was decoded and then thrown away at paint time.
  ///
  /// Rounded up to a multiple of 64 — 128 on a 2x screen, 192 on a 3x one — so
  /// a rotation or a text-scale change lands on the same cache key instead of
  /// decoding a second copy.
  static int _avatarCachePx(BuildContext context) {
    final px = (46 * MediaQuery.of(context).devicePixelRatio).ceil();
    return px < 64 ? 64 : ((px + 63) ~/ 64) * 64;
  }

  static String _timeAgo(String raw) {
    if (raw.isEmpty) return '';
    // AGENT_APP_Q1_CL_AGO — every thread read 6h30m older than it was,
    // so a message from a minute ago showed as 6h.
    final parsed = AppTime.parse(raw);
    if (parsed == null) return '';
    final diff = DateTime.now().difference(parsed);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${(diff.inDays / 7).floor()}w';
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final username = (user['username'] ?? '') as String;
    final unread = (user['unread_count'] ?? 0) as int;
    final isOnline = user['is_online'] == true;
    final planName = (user['plan_name'] ?? '') as String;
    final lastType = (user['last_message_type'] ?? 'text') as String;
    final lastSender = (user['last_message_sender'] ?? '') as String;

    var preview = (user['last_message'] ?? '') as String;
    preview = switch (lastType) {
      'plan_card' => 'Plan card',
      'broadcast' => 'Broadcast',
      'renewal_request' => 'Renewal request',
      'image' => 'Photo',
      _ => preview,
    };
    if (lastSender == 'admin' && preview.isNotEmpty) preview = 'You: $preview';
    if (preview.isEmpty) preview = planName.isEmpty ? 'No messages' : planName;

    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 11, 14, 11),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 46,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipOval(
                    child: Image.asset(
                      _avatarFor(username),
                      width: 46,
                      height: 46,
                      // IMG_L_LISTAVATAR_USE — decoded at the size of the
                      // circle it is drawn into. No RepaintBoundary: this row
                      // is built by a ListView.builder, which already wraps
                      // every child in one, and a second inside it would only
                      // add a layer.
                      cacheWidth: _avatarCachePx(context),
                      fit: BoxFit.cover,
                    ),
                  ),
                  if (isOnline)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.surface,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    username,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.titleMedium?.copyWith(
                      fontSize: 14,
                      // Unread threads carry more weight, as in any mail or
                      // messaging client.
                      fontWeight: unread > 0
                          ? FontWeight.w800
                          : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodySmall?.copyWith(
                      color: unread > 0
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                      fontWeight: unread > 0
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _timeAgo((user['last_message_at'] ?? '') as String),
                  style: t.bodySmall?.copyWith(
                    fontSize: 11,
                    color: unread > 0
                        ? AppColors.danger
                        : AppColors.textTertiary,
                    fontWeight: unread > 0 ? FontWeight.w700 : null,
                  ),
                ),
                const SizedBox(height: 5),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    constraints: const BoxConstraints(minWidth: 20),
                    decoration: BoxDecoration(
                      // Red, not brand green: this is the one thing on the row
                      // that means "someone is waiting", and green reads as a
                      // status that is fine.
                      color: AppColors.danger,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      unread > 99 ? '99+' : '$unread',
                      textAlign: TextAlign.center,
                      style: t.bodySmall?.copyWith(
                        color: AppColors.textOnAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 18),
              ],
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(child: row),
        // ROW_DIVIDER_V1 — a SizedBox has no colour, so the separator meant to
        // sit under each row was a 1px blank gap and the rows ran together.
        const ColoredBox(
          color: AppColors.border,
          child: SizedBox(height: 1, width: double.infinity),
        ),
      ],
    );
  }
}

// ── Broadcast ─────────────────────────────────────────────────────────────

class _BroadcastSheet extends StatefulWidget {
  final bool isAdmin;

  const _BroadcastSheet({required this.isAdmin});

  @override
  State<_BroadcastSheet> createState() => _BroadcastSheetState();
}

class _BroadcastSheetState extends State<_BroadcastSheet> {
  final _controller = TextEditingController();
  String _target = 'all';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 8,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Broadcast', style: t.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Sent as a message into every matching conversation.',
            style: t.bodyMedium,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _TargetChip(
                  label: 'All users',
                  selected: _target == 'all',
                  onTap: () => setState(() => _target = 'all'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TargetChip(
                  label: 'Expiring soon',
                  selected: _target == 'expiring',
                  onTap: () => setState(() => _target = 'expiring'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            maxLines: 4,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Your message'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            // Disabled until there is something to send: an empty broadcast
            // still reaches every conversation.
            onPressed: _controller.text.trim().isEmpty
                ? null
                : () => Navigator.pop(context, (
                    target: _target,
                    message: _controller.text.trim(),
                  )),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }
}

class _TargetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TargetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.accentInk : AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected ? AppColors.accentInk : AppColors.border,
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: selected
                  ? AppColors.textOnAccent
                  : AppColors.textSecondary,
            ),
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
      itemExtent: _ChatRow.height,
      itemCount: 8,
      itemBuilder: (_, _) => const Padding(
        padding: EdgeInsets.fromLTRB(16, 11, 14, 11),
        child: Row(
          children: [
            AppSkeleton(width: 46, height: 46, radius: 23),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppSkeleton(width: 120, height: 13),
                  SizedBox(height: 7),
                  AppSkeleton(width: 180, height: 11),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hero behind the header, faded out before the list starts.
///
/// The composition leaves its middle empty, which is where the title and
/// controls sit; the artwork occupies the margins the screen was not using.
/// Not a banner in the column — that would push the first conversation down
/// the screen on a list whose whole job is showing conversations.
class _ChatHeroBackdrop extends StatelessWidget {
  const _ChatHeroBackdrop();

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    // IMG_L_CHATHERO — chat_hero.png is 1200x671, which is 3.1 MB once the
    // engine has decoded it, and it is painted at the screen's width. On a
    // 720p Android — the phones this app is mostly installed on — that width
    // is 720 pixels, so two thirds of the decode was being thrown away at
    // paint time and kept in the cache anyway.
    //
    // The same computation as _DashboardBackdrop: the painted width in device
    // pixels, rounded up to a multiple of 64 so a rotation or a split-screen
    // resize lands on the same cache key instead of decoding a second copy.
    final heroPixelWidth = (media.size.width * media.devicePixelRatio).ceil();
    final heroCacheWidth = heroPixelWidth < 64
        ? 64
        : ((heroPixelWidth + 63) ~/ 64) * 64;

    // RepaintBoundary: this sits behind a scrolling ListView inside a Stack
    // and the ShaderMask below is a saveLayer, so without a layer of its own
    // the masked image was re-composited on every scroll frame.
    return RepaintBoundary(
      child: IgnorePointer(
        // Below the status bar, not under it: the artwork was running up
        // behind the clock and the battery icon, which is neither legible nor
        // intended.
        child: SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0.0, 0.6, 1.0],
                colors: [Colors.black, Colors.black26, Colors.transparent],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Opacity(
                opacity: 0.35,
                child: Image.asset(
                  'assets/images/chat_hero.png',
                  width: double.infinity,
                  cacheWidth: heroCacheWidth,
                  // contain, not cover: cover cropped the artwork to the
                  // band's height and took the figure's head with it. The
                  // whole illustration is shown, scaled to the screen width,
                  // and the gradient fades its lower half into the list.
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
