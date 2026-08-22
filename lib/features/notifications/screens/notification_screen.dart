import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:vpn_agent_app/core/api/api_client.dart';
import 'package:vpn_agent_app/core/api/api_config.dart';
import '../models/notification_model.dart';
import '../services/notification_list_service.dart';
import 'send_notification_screen.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/shared_widgets/theme_helpers.dart';

// --- Reusable UI Components ---

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin; // Added margin support
  final Color? tintColor;
  final bool withBorder;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.blurSigma = 20.0,
    this.opacity = 0.08,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.margin,
    this.tintColor,
    this.withBorder = true,
    this.onTap,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(20);
    Widget content = Container(
      margin: margin, // Apply margin outside the clip
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: (tintColor ?? Colors.white).withOpacity(opacity),
              borderRadius: radius,
              border: withBorder
                  ? Border.all(
                      color: Colors.white.withOpacity(0.12),
                      width: 1.0,
                    )
                  : null,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  (tintColor ?? Colors.white).withOpacity(opacity + 0.05),
                  (tintColor ?? Colors.white).withOpacity(opacity),
                ],
              ),
              boxShadow: boxShadow,
            ),
            child: child,
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

class ScaleButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double scaleAmount;
  const ScaleButton({
    super.key,
    required this.child,
    required this.onTap,
    this.scaleAmount = 0.95,
  });
  @override
  State<ScaleButton> createState() => _ScaleButtonState();
}

class _ScaleButtonState extends State<ScaleButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
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
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap?.call();
        HapticFeedback.lightImpact();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// --- Particle System ---
class Particle {
  Offset position;
  final Color color;
  final double radius;
  final Offset velocity;
  Particle({
    required this.position,
    required this.color,
    required this.radius,
    required this.velocity,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Animation<double> animation;

  ParticlePainter({required this.particles, required this.animation})
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var particle in particles) {
      particle.position += particle.velocity;
      if (particle.position.dx < 0) {
        particle.position = Offset(size.width, particle.position.dy);
      }
      if (particle.position.dx > size.width) {
        particle.position = Offset(0, particle.position.dy);
      }
      if (particle.position.dy < 0) {
        particle.position = Offset(particle.position.dx, size.height);
      }
      if (particle.position.dy > size.height) {
        particle.position = Offset(particle.position.dx, 0);
      }
      paint.color = particle.color;
      canvas.drawCircle(particle.position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// --- Main Notification Screen ---

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen>
    with TickerProviderStateMixin {
  final NotificationListService _notificationService =
      NotificationListService();
  List<NotificationModel> _notifications = [];
  bool _isLoading = true;
  bool _canSendNoti = false;

  late AnimationController _particleController;
  List<Particle> _particles = [];
  final Random _random = Random();

  @override
  void initState() {
    super.initState();

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.of(context).size;
      _particles = List.generate(40, (index) {
        return Particle(
          position: Offset(
            _random.nextDouble() * size.width,
            _random.nextDouble() * size.height,
          ),
          color: Colors.white.withOpacity(_random.nextDouble() * 0.15),
          radius: _random.nextDouble() * 2.0,
          velocity: Offset(
            (_random.nextDouble() - 0.5) * 0.3,
            (_random.nextDouble() - 0.5) * 0.3,
          ),
        );
      });
      if (mounted) setState(() {});
    });

    _checkPermissionFromServer();
    _loadNotifications();
  }

  @override
  void dispose() {
    _particleController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionFromServer() async {
    try {
      // Routed through ApiClient so this inherits the RemoteConfig domain
      // fallback chain. As a raw http.get on a hard-coded host it bypassed
      // _FallbackInterceptor entirely and died on the DPI-blocked domain.
      final response = await ApiClient().dio.get(ApiConfig.agentProfile);

      if (response.statusCode == 200) {
        final data = response.data;
        bool permission = false;
        if (data['can_send_notifications'] == true ||
            data['can_send_notifications'] == 1) {
          permission = true;
        }
        if (mounted) setState(() => _canSendNoti = permission);
      }
    } catch (e) {
      debugPrint("Permission Check Error: $e");
    }
  }

  Future<void> _loadNotifications() async {
    final data = await _notificationService.getNotifications();
    if (mounted) {
      setState(() {
        final uniqueNotifications = <String, NotificationModel>{};
        for (var notification in data) {
          uniqueNotifications[notification.id] = notification;
        }
        _notifications = uniqueNotifications.values.toList();
        _notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        _isLoading = false;
      });
    }
  }

  Future<void> _markAsRead(NotificationModel item, int index) async {
    if (!item.isRead) {
      setState(() {
        final updatedItem = item.copyWith(readAt: DateTime.now());
        _notifications[index] = updatedItem;
      });
    }
  }

  Future<void> _deleteNotification(int index) async {
    HapticFeedback.mediumImpact();
    setState(() {
      _notifications.removeAt(index);
    });
  }

  void _markAllAsRead() {
    HapticFeedback.lightImpact();
    setState(() {
      _notifications = _notifications.map((n) {
        if (!n.isRead) return n.copyWith(readAt: DateTime.now());
        return n;
      }).toList();
    });
  }

  String _timeAgo(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
    if (diff.inHours < 24) return "${diff.inHours}h ago";
    if (diff.inDays < 7) return "${diff.inDays}d ago";
    return "${date.day}/${date.month}/${date.year}";
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.arrow_left_2,
              color: Colors.white,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Notifications",
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: ScaleButton(
                  onTap: _markAllAsRead,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.accentGreen.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.accentGreen.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.tick_circle,
                          size: 12,
                          color: AppColors.accentGreen.withOpacity(0.7),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          "Read All",
                          style: GoogleFonts.ibmPlexSans(
                            color: AppColors.accentGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (!_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  opacity: unreadCount > 0 ? 0.12 : 0.06,
                  tintColor: unreadCount > 0 ? AppColors.accentGreen : null,
                  child: Text(
                    "${_notifications.length}",
                    style: GoogleFonts.spaceMono(
                      color: unreadCount > 0
                          ? AppColors.accentGreen
                          : Colors.white.withOpacity(0.5),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: _canSendNoti ? _buildGlassFAB() : null,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0F0F10), Color(0xFF18181C)],
                ),
              ),
            ),
          ),
          CustomPaint(
            painter: ParticlePainter(
              particles: _particles,
              animation: _particleController,
            ),
          ),
          Positioned.fill(
            child: SafeArea(
              child: _isLoading
                  ? _buildShimmer()
                  : _notifications.isEmpty
                  ? _buildEmptyState()
                  : Column(
                      children: [
                        if (unreadCount > 0)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                            child: Row(
                              children: [
                                _buildMiniChip(
                                  "Unread",
                                  "$unreadCount",
                                  AppColors.accentGreen,
                                ),
                                const SizedBox(width: 8),
                                _buildMiniChip(
                                  "Total",
                                  "${_notifications.length}",
                                  Colors.white.withOpacity(0.5),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: RefreshIndicator(
                            onRefresh: () async {
                              await _loadNotifications();
                            },
                            color: AppColors.accentGreen,
                            backgroundColor: const Color(0xFF2C2C2E),
                            child: ListView.builder(
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                10,
                                16,
                                100,
                              ),
                              itemCount: _notifications.length,
                              itemBuilder: (context, index) {
                                final item = _notifications[index];
                                return FadeInUp(
                                  delay: Duration(
                                    milliseconds: (index * 60).clamp(0, 400),
                                  ),
                                  child: _buildDismissibleCard(item, index),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniChip(String label, String value, Color color) {
    return LiquidGlassContainer(
      borderRadius: BorderRadius.circular(10),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      opacity: 0.04,
      withBorder: false,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(
            label,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.35),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            value,
            style: GoogleFonts.spaceMono(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
      children: List.generate(
        5,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(20),
            opacity: 0.04,
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.04),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 14,
                        width: 140,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        height: 10,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 180,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Glass Floating Action Button
  Widget _buildGlassFAB() {
    return ScaleButton(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const SendNotificationScreen(),
          ),
        );
      },
      child: LiquidGlassContainer(
        opacity: 0.15,
        blurSigma: 20,
        tintColor: AppColors.accentGreen,
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentGreen.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Iconsax.send_1, color: Colors.white, size: 22),
            const SizedBox(width: 10),
            Text(
              "Compose",
              style: GoogleFonts.exo2(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: FadeInUp(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.accentGreen.withOpacity(0.05),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.accentGreen.withOpacity(0.08),
                ),
              ),
              child: Icon(
                Iconsax.notification_status,
                size: 44,
                color: AppColors.accentGreen.withOpacity(0.3),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "No Notifications",
              style: GoogleFonts.exo2(
                color: Colors.white.withOpacity(0.5),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              "You're all caught up",
              style: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.25),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDismissibleCard(NotificationModel item, int index) {
    return Dismissible(
      key: Key(item.id + index.toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.redAccent.withOpacity(0.2)),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Delete",
              style: GoogleFonts.ibmPlexSans(
                color: Colors.redAccent.withOpacity(0.7),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Iconsax.trash, color: Colors.redAccent, size: 22),
          ],
        ),
      ),
      onDismissed: (direction) {
        _deleteNotification(index);
      },
      child: _buildGlassNotificationCard(item, index),
    );
  }

  Widget _buildGlassNotificationCard(NotificationModel item, int index) {
    bool isRead = item.isRead;
    String timeText = _timeAgo(item.createdAt);

    return GestureDetector(
      onTap: () => _markAsRead(item, index),
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(20),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        opacity: isRead ? 0.03 : 0.07,
        tintColor: isRead ? null : AppColors.accentGreen,
        withBorder: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isRead
                        ? Colors.white.withOpacity(0.04)
                        : AppColors.accentGreen.withOpacity(0.15),
                    border: Border.all(
                      color: isRead
                          ? Colors.white.withOpacity(0.06)
                          : AppColors.accentGreen.withOpacity(0.25),
                    ),
                  ),
                  child: Icon(
                    isRead ? Iconsax.notification : Iconsax.notification5,
                    color: isRead
                        ? Colors.white.withOpacity(0.25)
                        : AppColors.accentGreen,
                    size: 20,
                  ),
                ),
                if (!isRead)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.accentGreen,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF0F0F10),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accentGreen.withOpacity(0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: GoogleFonts.exo2(
                            color: isRead
                                ? Colors.white.withOpacity(0.6)
                                : Colors.white,
                            fontSize: 14,
                            fontWeight: isRead
                                ? FontWeight.w600
                                : FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        timeText,
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.body,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(isRead ? 0.3 : 0.65),
                      fontSize: 12,
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
