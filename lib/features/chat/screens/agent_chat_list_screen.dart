import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/chat/services/agent_chat_service.dart';
import 'package:vpn_agent_app/features/chat/screens/agent_chat_detail_screen.dart';

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final bool withBorder;
  final VoidCallback? onTap;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.blurSigma = 20.0,
    this.opacity = 0.1,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding = EdgeInsets.zero,
    this.tintColor,
    this.withBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tintColor ?? Colors.white).withOpacity(opacity * 0.5),
            borderRadius: borderRadius,
            border: withBorder
                ? Border.all(color: Colors.white.withOpacity(0.2), width: 0.5)
                : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tintColor ?? Colors.white).withOpacity(opacity + 0.1),
                (tintColor ?? Colors.white).withOpacity(opacity * 0.3),
              ],
              stops: const [0.0, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 30,
                spreadRadius: -2,
                offset: const Offset(0, 15),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
    return onTap != null
        ? GestureDetector(onTap: onTap, child: content)
        : content;
  }
}

class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Duration duration;
  final double scaleAmount;

  const ScaleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.duration = const Duration(milliseconds: 150),
    this.scaleAmount = 0.95,
  });

  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleAmount,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // UX ကို ပိုမိုကောင်းမွန်စေရန် opaque ထည့်ထားသည်
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: () {
        widget.onTap?.call();
        HapticFeedback.lightImpact();
      },
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class AgentChatListScreen extends StatefulWidget {
  const AgentChatListScreen({super.key});

  @override
  State<AgentChatListScreen> createState() => _AgentChatListScreenState();
}

class _AgentChatListScreenState extends State<AgentChatListScreen>
    with TickerProviderStateMixin {
  final AgentChatService _chatService = AgentChatService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _selfRenewal = false;
  bool _isAdmin = false;
  bool _searchActive = false;

  int _totalUnread = 0;
  int _totalConversations = 0;
  int _totalOnline = 0;
  int _activeUserCount = 0;
  int _expiringSoonCount = 0;
  int _currentPage = 1;
  int _lastPage = 1;

  Timer? _pollingTimer;
  Timer? _debounceTimer;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _scrollController.addListener(_onScroll);
    _loadData();

    // Background polling ချိန်တွင် UI မခုန်စေရန် isPolling: true ကို သုံးမည်
    _pollingTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => _loadData(silent: true, isPolling: true),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollingTimer?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _currentPage >= _lastPage) return;
    setState(() => _loadingMore = true);

    final result = await _chatService.getUsers(
      search: _searchController.text.trim(),
      page: _currentPage + 1,
    );

    if (!mounted) return;

    if (result != null && result['data'] != null) {
      setState(() {
        _users.addAll(
          (result['data'] as List)
              .map((e) => Map<String, dynamic>.from(e))
              .toList(),
        );
        _currentPage = result['current_page'] ?? _currentPage + 1;
        _lastPage = result['last_page'] ?? _lastPage;
        _loadingMore = false;
      });
    } else {
      setState(() => _loadingMore = false);
    }
  }

  // isPolling parameter အသစ်ထည့်ထားပြီး Scroll Jump မဖြစ်အောင် Merge လုပ်မည့် နေရာ
  Future<void> _loadData({bool silent = false, bool isPolling = false}) async {
    if (!silent) setState(() => _loading = true);

    final statusResult = await _chatService.getSelfRenewalStatus();
    final result = await _chatService.getUsers(
      search: _searchController.text.trim(),
      page: 1, // ပုံမှန်အားဖြင့် Polling က Page 1 ကိုသာ လှမ်းယူမည်
    );

    ApiClient().dio
        .get('${ApiConfig.baseUrl}/agent/dashboard')
        .then((dash) {
          if (dash.statusCode == 200 && dash.data is Map && mounted) {
            setState(() {
              _activeUserCount = dash.data['active_user_count'] ?? 0;
              _expiringSoonCount = dash.data['expiring_soon_count'] ?? 0;
            });
          }
        })
        .catchError((_) {});

    if (!mounted) return;

    setState(() {
      _selfRenewal = statusResult['allow_self_renewal'] == true;
      _isAdmin = statusResult['is_admin'] == true;

      if (result != null && result['data'] != null) {
        final fetchedUsers = (result['data'] as List)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();

        // Polling ဖြစ်ပြီး အရင်က Data တွေရှိနေရင် List ကို အသစ်မဖျက်ဘဲ Update သာလုပ်မည်
        if (isPolling && _users.isNotEmpty) {
          for (var fetched in fetchedUsers) {
            final index = _users.indexWhere((u) => u['id'] == fetched['id']);
            if (index != -1) {
              // ရှိပြီးသားဆိုလျှင် Content ကိုသာ In-place အစားထိုးမည်
              _users[index] = fetched;
            } else {
              // အသစ်ရောက်လာသည့် Chat ဆိုလျှင် အပေါ်ဆုံးကို ထည့်မည်
              _users.insert(0, fetched);
            }
          }
          // Scroll အောက်ရောက်နေချိန် List မပျက်သွားစေရန် Pagination (Page Number) ကို မထိပါ
        } else {
          // Polling မဟုတ်တဲ့ Normal Load (Search သို့မဟုတ် Pull to refresh) ချိန်တွင်သာ အသစ် အစားထိုးမည်
          _users = fetchedUsers;
          _currentPage = result['current_page'] ?? 1;
          _lastPage = result['last_page'] ?? 1;
        }

        _totalConversations = result['total'] ?? _users.length;
        _totalOnline = result['total_online'] ?? 0;
      }

      _totalUnread = _users.fold(
        0,
        (sum, u) => sum + ((u['unread_count'] ?? 0) as int),
      );
      _loading = false;
    });
  }

  void _onSearchChanged(String query) {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      // Search သည့်အခါ အသစ်ဖြစ်အောင် isPolling: false ထားမည်
      _loadData(silent: true, isPolling: false);
    });
  }

  Future<void> _toggleSelfRenewal(bool val) async {
    HapticFeedback.selectionClick();
    setState(() => _selfRenewal = val);
    await _chatService.toggleSelfRenewal(val);
  }

  void _openChat(Map<String, dynamic> user) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AgentChatDetailScreen(
          userId: user['id'],
          username: user['username'] ?? '',
        ),
      ),
    );
    // Chat ထဲမှ ပြန်ထွက်လာချိန်တွင် အစကတည်းကအတိုင်း List မပျက်စေရန် isPolling: true သုံးမည်
    if (mounted) _loadData(silent: true, isPolling: true);
  }

  void _openSearch() {
    setState(() => _searchActive = true);
    _searchFocusNode.requestFocus();
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    _searchController.clear();
    setState(() => _searchActive = false);
    _loadData(silent: true, isPolling: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050508),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF050508), Color(0xFF09090C)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                AnimatedCrossFade(
                  firstChild: _buildHeader(),
                  secondChild: _buildSearchOverlay(),
                  crossFadeState: _searchActive
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  duration: const Duration(milliseconds: 200),
                ),
                Expanded(
                  child: _loading && _users.isEmpty
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentGreen,
                            strokeWidth: 2,
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () => _loadData(),
                          color: AppColors.accentGreen,
                          backgroundColor: const Color(0xFF0A0A0E),
                          child: _users.isEmpty
                              ? ListView(
                                  children: [
                                    SizedBox(height: 120.h),
                                    Center(
                                      child: LiquidGlassContainer(
                                        opacity: 0.05,
                                        blurSigma: 10,
                                        borderRadius: BorderRadius.circular(50),
                                        padding: EdgeInsets.all(24.w),
                                        child: Icon(
                                          Iconsax.message_text_1,
                                          size: 40.sp,
                                          color: Colors.white24,
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 16.h),
                                    Center(
                                      child: Text(
                                        "No conversations yet",
                                        style: GoogleFonts.exo2(
                                          color: Colors.white38,
                                          fontSize: 14.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  controller: _scrollController,
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  itemCount:
                                      _users.length +
                                      3 +
                                      (_loadingMore ? 1 : 0),
                                  padding: EdgeInsets.only(
                                    top: 4.h,
                                    bottom: _searchActive ? 8.h : 70.h,
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index == 0) {
                                      return _buildBroadcastTile(
                                        'all',
                                        'Broadcast All',
                                        '$_activeUserCount active users',
                                        Iconsax.send_2,
                                        const Color(0xFFA855F7),
                                      );
                                    }
                                    if (index == 1) {
                                      return _buildBroadcastTile(
                                        'expiring',
                                        'Expiring Soon',
                                        '$_expiringSoonCount within 7 days',
                                        Iconsax.timer_1,
                                        Colors.amberAccent,
                                      );
                                    }
                                    if (index == 2) {
                                      return Padding(
                                        padding: EdgeInsets.fromLTRB(
                                          18.w,
                                          14.h,
                                          16.w,
                                          6.h,
                                        ),
                                        child: Text(
                                          "CONVERSATIONS",
                                          style: GoogleFonts.exo2(
                                            color: Colors.white24,
                                            fontSize: 10.sp,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    final userIndex = index - 3;
                                    if (userIndex == _users.length) {
                                      return Padding(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 16.h,
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: AppColors.accentGreen,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    }
                                    return _buildUserTile(_users[userIndex]);
                                  },
                                ),
                        ),
                ),
              ],
            ),
          ),
          if (!_searchActive)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 12.h,
              left: 0,
              right: 0,
              child: Center(
                child: ScaleButton(
                  onTap: _openSearch,
                  child: LiquidGlassContainer(
                    opacity: 0.15,
                    blurSigma: 20,
                    tintColor: AppColors.accentGreen,
                    borderRadius: BorderRadius.circular(50),
                    withBorder: true,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 12.h,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.search_normal,
                          size: 16.sp,
                          color: AppColors.accentGreen,
                        ),
                        SizedBox(width: 8.w),
                        Text(
                          "Search",
                          style: GoogleFonts.exo2(
                            color: AppColors.accentGreen,
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Padding(
      padding: EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 6.h),
      child: Row(
        children: [
          ScaleButton(
            onTap: _closeSearch,
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Iconsax.arrow_left_2,
                color: Colors.white70,
                size: 20.sp,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Container(
              height: 40.h,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: _onSearchChanged,
                style: GoogleFonts.exo2(color: Colors.white, fontSize: 14.sp),
                decoration: InputDecoration(
                  hintText: "Search users...",
                  hintStyle: GoogleFonts.exo2(
                    color: Colors.white30,
                    fontSize: 14.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? ScaleButton(
                          onTap: () {
                            _searchController.clear();
                            _loadData(silent: true, isPolling: false);
                            setState(() {});
                          },
                          child: Icon(
                            Icons.close,
                            size: 16.sp,
                            color: Colors.white38,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      child: Row(
        children: [
          ScaleButton(
            onTap: () => Navigator.pop(context),
            child: Padding(
              padding: EdgeInsets.all(4.w),
              child: Icon(
                Iconsax.arrow_left_2,
                color: Colors.white70,
                size: 22.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          FadeTransition(
            opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
              CurvedAnimation(
                parent: _pulseController,
                curve: Curves.easeInOut,
              ),
            ),
            child: Container(
              padding: EdgeInsets.all(10.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AppColors.accentGreen.withOpacity(0.25),
                    AppColors.accentGreen.withOpacity(0.08),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.accentGreen.withOpacity(0.2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Icon(
                Iconsax.message_text_1,
                color: AppColors.accentGreen,
                size: 20.sp,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Support Chat",
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      "$_totalOnline",
                      style: GoogleFonts.exo2(
                        color: AppColors.accentGreen,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      " online",
                      style: GoogleFonts.exo2(
                        color: Colors.white38,
                        fontSize: 11.sp,
                      ),
                    ),
                    Text(
                      "  ·  ",
                      style: GoogleFonts.exo2(
                        color: Colors.white24,
                        fontSize: 11.sp,
                      ),
                    ),
                    Text(
                      "$_totalConversations",
                      style: GoogleFonts.exo2(
                        color: Colors.blueAccent,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      " total",
                      style: GoogleFonts.exo2(
                        color: Colors.white38,
                        fontSize: 11.sp,
                      ),
                    ),
                    if (_totalUnread > 0) ...[
                      Text(
                        "  ·  ",
                        style: GoogleFonts.exo2(
                          color: Colors.white24,
                          fontSize: 11.sp,
                        ),
                      ),
                      Text(
                        "$_totalUnread",
                        style: GoogleFonts.exo2(
                          color: Colors.redAccent,
                          fontSize: 11.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        " unread",
                        style: GoogleFonts.exo2(
                          color: Colors.white38,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (_isAdmin) ...[
            SizedBox(width: 8.w),
            SizedBox(
              height: 24.h,
              width: 40.w,
              child: Switch(
                value: _selfRenewal,
                onChanged: _toggleSelfRenewal,
                activeColor: AppColors.accentGreen,
                activeTrackColor: AppColors.accentGreen.withOpacity(0.3),
                inactiveTrackColor: Colors.white.withOpacity(0.1),
                inactiveThumbColor: Colors.white54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBroadcastTile(
    String target,
    String title,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return ScaleButton(
      onTap: () => _showBroadcastInput(target, title, color),
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        child: LiquidGlassContainer(
          opacity: 0.06,
          blurSigma: 12,
          tintColor: color,
          borderRadius: BorderRadius.circular(16),
          withBorder: true,
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                ),
                child: Icon(icon, color: color, size: 20.sp),
              ),
              SizedBox(width: 12.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.exo2(
                      color: color,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.exo2(
                      color: Colors.white38,
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBroadcastInput(String target, String title, Color color) {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (ctx) => _BroadcastDialog(
        chatService: _chatService,
        target: target,
        title: title,
        color: color,
        onDone: () {
          Navigator.pop(ctx);
          _showGlassSnackBar("Broadcast sent!", isSuccess: true);
        },
      ),
    );
  }

  void _showGlassSnackBar(
    String message, {
    bool isError = false,
    bool isSuccess = false,
  }) {
    final Color iconColor = isError ? Colors.redAccent : AppColors.accentGreen;
    final IconData icon = isError ? Icons.error_outline : Icons.check_circle;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          content: LiquidGlassContainer(
            opacity: 0.2,
            blurSigma: 10,
            tintColor: Colors.black,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            borderRadius: BorderRadius.circular(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: iconColor.withOpacity(0.2),
                  ),
                  child: Icon(icon, color: iconColor, size: 20.sp),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    message,
                    style: GoogleFonts.exo2(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final unread = (user['unread_count'] ?? 0) as int;
    final isOnline = user['is_online'] == true;
    final username = user['username'] ?? '';
    final planName = user['plan_name'] ?? '';
    final lastMsg = user['last_message'] ?? '';
    final lastMsgType = user['last_message_type'] ?? 'text';
    final lastMsgSender = user['last_message_sender'] ?? '';
    final lastAt = user['last_message_at'] ?? '';

    String timeAgo = '';
    if (lastAt.isNotEmpty) {
      try {
        final dt = DateTime.parse(lastAt);
        final diff = DateTime.now().difference(dt);
        if (diff.inMinutes < 1) {
          timeAgo = 'now';
        } else if (diff.inMinutes < 60) {
          timeAgo = '${diff.inMinutes}m';
        } else if (diff.inHours < 24) {
          timeAgo = '${diff.inHours}h';
        } else {
          timeAgo = '${diff.inDays}d';
        }
      } catch (_) {}
    }

    String preview = lastMsg;
    if (lastMsgType == 'plan_card') preview = '💳 Plan Card';
    if (lastMsgType == 'broadcast') preview = '📣 Broadcast';
    if (lastMsgType == 'renewal_request') preview = '🧾 Renewal Request';
    if (lastMsgSender == 'admin' && preview.isNotEmpty) {
      preview = 'You: $preview';
    }
    if (preview.length > 50) preview = '${preview.substring(0, 50)}...';

    return ScaleButton(
      onTap: () => _openChat(user),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.accentGreen.withOpacity(
                          unread > 0 ? 0.35 : 0.18,
                        ),
                        AppColors.accentGreen.withOpacity(
                          unread > 0 ? 0.12 : 0.06,
                        ),
                      ],
                    ),
                    border: Border.all(
                      color: AppColors.accentGreen.withOpacity(
                        unread > 0 ? 0.4 : 0.15,
                      ),
                      width: 1.2,
                    ),
                    boxShadow: unread > 0
                        ? [
                            BoxShadow(
                              color: AppColors.accentGreen.withOpacity(0.15),
                              blurRadius: 8,
                              spreadRadius: 0,
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      username.isNotEmpty ? username[0].toUpperCase() : '?',
                      style: GoogleFonts.exo2(
                        color: AppColors.accentGreen,
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                      ),
                    ),
                  ),
                ),
                if (isOnline)
                  Positioned(
                    bottom: 1,
                    right: 1,
                    child: Container(
                      width: 13.w,
                      height: 13.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.accentGreen,
                        border: Border.all(
                          color: const Color(0xFF09090C),
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          username,
                          style: GoogleFonts.exo2(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: unread > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (planName.isNotEmpty) ...[
                        SizedBox(width: 4.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 5.w,
                            vertical: 1.h,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: Colors.blueAccent.withOpacity(0.12),
                          ),
                          child: Text(
                            planName,
                            style: GoogleFonts.exo2(
                              color: Colors.blueAccent,
                              fontSize: 8.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          style: GoogleFonts.exo2(
                            color: unread > 0 ? Colors.white70 : Colors.white38,
                            fontSize: 12.sp,
                            fontWeight: unread > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (timeAgo.isNotEmpty)
                        Text(
                          " · $timeAgo",
                          style: GoogleFonts.exo2(
                            color: unread > 0
                                ? AppColors.accentGreen
                                : Colors.white38,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (unread > 0) ...[
              SizedBox(width: 8.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.accentGreen,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.accentGreen.withOpacity(0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Text(
                  '$unread',
                  style: GoogleFonts.exo2(
                    color: Colors.black,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BroadcastDialog extends StatefulWidget {
  final AgentChatService chatService;
  final String target;
  final String title;
  final Color color;
  final VoidCallback onDone;

  const _BroadcastDialog({
    required this.chatService,
    required this.target,
    required this.title,
    required this.color,
    required this.onDone,
  });

  @override
  State<_BroadcastDialog> createState() => _BroadcastDialogState();
}

class _BroadcastDialogState extends State<_BroadcastDialog> {
  final TextEditingController _msgController = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    final msg = _msgController.text.trim();
    if (msg.isEmpty) return;
    setState(() => _sending = true);
    final success = await widget.chatService.broadcastMessage(
      msg,
      widget.target,
    );
    if (mounted) {
      setState(() => _sending = false);
      if (success) widget.onDone();
    }
  }

  @override
  void dispose() {
    _msgController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 24.h),
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.color.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.color.withOpacity(0.15),
                    ),
                    child: Icon(
                      Iconsax.send_2,
                      color: widget.color,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: GoogleFonts.exo2(
                        color: widget.color,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ScaleButton(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      color: Colors.white30,
                      size: 20.sp,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
                child: TextField(
                  controller: _msgController,
                  minLines: 3,
                  maxLines: 5,
                  autofocus: true,
                  style: GoogleFonts.exo2(
                    color: Colors.white.withOpacity(0.95),
                    fontSize: 14.sp,
                  ),
                  decoration: InputDecoration(
                    hintText: "Type your message...",
                    hintStyle: GoogleFonts.exo2(
                      color: Colors.white24,
                      fontSize: 14.sp,
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              ScaleButton(
                onTap: _sending ? null : _send,
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 13.h),
                  decoration: BoxDecoration(
                    color: widget.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: widget.color.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: _sending
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.color,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.send_1,
                                size: 16.sp,
                                color: widget.color,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                "Send",
                                style: GoogleFonts.exo2(
                                  color: widget.color,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
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
