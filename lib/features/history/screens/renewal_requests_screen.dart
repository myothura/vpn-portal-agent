import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/history/models/renewal_request_model.dart';
import 'package:vpn_agent_app/features/history/services/renewal_service.dart';

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final bool withBorder;
  final VoidCallback? onTap;

  const LiquidGlassContainer({
    super.key,
    required this.child,
    this.blurSigma = 20.0,
    this.opacity = 0.08,
    this.borderRadius,
    this.padding = EdgeInsets.zero,
    this.tintColor,
    this.withBorder = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(24);
    Widget content = ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (tintColor ?? Colors.white).withOpacity(opacity),
            borderRadius: radius,
            border: withBorder
                ? Border.all(color: Colors.white.withOpacity(0.12), width: 1.0)
                : null,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (tintColor ?? Colors.white).withOpacity(opacity + 0.05),
                (tintColor ?? Colors.white).withOpacity(opacity),
              ],
            ),
          ),
          child: child,
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

class RenewalRequestsScreen extends StatefulWidget {
  const RenewalRequestsScreen({super.key});

  @override
  State<RenewalRequestsScreen> createState() => _RenewalRequestsScreenState();
}

class _RenewalRequestsScreenState extends State<RenewalRequestsScreen> {
  Completer<void>? _refreshCompleter;
  Future<RenewalRequestResponse?>? _requestsFuture;
  final RenewalRequestService _renewalService = RenewalRequestService();

  bool _isProcessing = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    if (!mounted) return;
    setState(() {
      _requestsFuture = _renewalService.getRenewalRequests();
    });
    await _requestsFuture;
    if (mounted &&
        _refreshCompleter != null &&
        !_refreshCompleter!.isCompleted) {
      _refreshCompleter!.complete();
      _refreshCompleter = null;
    }
  }

  Future<void> _onRefresh() async {
    _refreshCompleter = Completer<void>();
    _loadRequests();
    return _refreshCompleter!.future;
  }

  List<RenewalRequest> _applyFilter(List<RenewalRequest> requests) {
    if (_filter == 'all') return requests;
    return requests.where((r) => r.status == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
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
          "Renewal Requests",
          style: GoogleFonts.exo2(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: 1.0,
          ),
        ),
      ),
      body: Stack(
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
          Positioned.fill(
            child: SafeArea(
              child: FutureBuilder<RenewalRequestResponse?>(
                future: _requestsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildFilterTabs(0, 0, 0),
                        const SizedBox(height: 12),
                        Expanded(child: _buildShimmer()),
                      ],
                    );
                  }
                  if (snapshot.hasError ||
                      !snapshot.hasData ||
                      snapshot.data!.requests.isEmpty) {
                    return Column(
                      children: [
                        const SizedBox(height: 10),
                        _buildFilterTabs(0, 0, 0),
                        Expanded(child: _buildEmptyState()),
                      ],
                    );
                  }

                  final allRequests = snapshot.data!.requests;
                  final pendingCount = allRequests
                      .where((r) => r.status == 'pending')
                      .length;
                  final approvedCount = allRequests
                      .where((r) => r.status == 'approved')
                      .length;
                  final rejectedCount = allRequests
                      .where((r) => r.status == 'rejected')
                      .length;
                  final filtered = _applyFilter(allRequests);

                  return Column(
                    children: [
                      const SizedBox(height: 10),
                      _buildFilterTabs(
                        pendingCount,
                        approvedCount,
                        rejectedCount,
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? _buildEmptyState()
                            : RefreshIndicator(
                                onRefresh: _onRefresh,
                                color: AppColors.accentGreen,
                                backgroundColor: const Color(0xFF2C2C2E),
                                child: ListView.builder(
                                  physics: const AlwaysScrollableScrollPhysics(
                                    parent: BouncingScrollPhysics(),
                                  ),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    40,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    return _buildGlassRequestCard(
                                      filtered[index],
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          if (_isProcessing)
            Container(
              color: Colors.black.withOpacity(0.6),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.accentGreen,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(int pending, int approved, int rejected) {
    final filters = [
      {
        'key': 'all',
        'label': 'All',
        'icon': Iconsax.receipt_1,
        'color': Colors.blueAccent,
        'count': pending + approved + rejected,
      },
      {
        'key': 'pending',
        'label': 'Pending',
        'icon': Iconsax.timer_1,
        'color': Colors.orangeAccent,
        'count': pending,
      },
      {
        'key': 'approved',
        'label': 'Approved',
        'icon': Iconsax.verify,
        'color': AppColors.accentGreen,
        'count': approved,
      },
      {
        'key': 'rejected',
        'label': 'Rejected',
        'icon': Iconsax.close_circle,
        'color': Colors.redAccent,
        'count': rejected,
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: filters.map((f) {
            final key = f['key'] as String;
            final label = f['label'] as String;
            final icon = f['icon'] as IconData;
            final color = f['color'] as Color;
            final count = f['count'] as int;
            final isSelected = _filter == key;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ScaleButton(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _filter = key);
                },
                scaleAmount: 0.95,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? color.withOpacity(0.18)
                        : Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? color.withOpacity(0.5)
                          : Colors.white.withOpacity(0.06),
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? color
                            : Colors.white.withOpacity(0.3),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        style: GoogleFonts.ibmPlexSans(
                          color: isSelected
                              ? color
                              : Colors.white.withOpacity(0.45),
                          fontSize: 12,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      if (count > 0 && isSelected) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "$count",
                            style: GoogleFonts.spaceMono(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildShimmer() {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      children: List.generate(
        3,
        (i) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(22),
            opacity: 0.04,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.04),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 14,
                            width: 100,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            height: 10,
                            width: 140,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.03),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 70,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  height: 56,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.02),
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.03),
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isFiltered = _filter != 'all';
    return Center(
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
              isFiltered ? Iconsax.filter_search : Iconsax.tick_circle,
              size: 44,
              color: AppColors.accentGreen.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered ? "No ${_filter} requests" : "All caught up!",
            style: GoogleFonts.exo2(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? "Try a different filter"
                : "No renewal requests at the moment",
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.25),
              fontSize: 13,
            ),
          ),
          if (isFiltered) ...[
            const SizedBox(height: 16),
            ScaleButton(
              onTap: () => setState(() => _filter = 'all'),
              child: LiquidGlassContainer(
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                opacity: 0.06,
                child: Text(
                  "Show All",
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGlassRequestCard(RenewalRequest request) {
    Color statusColor;
    IconData statusIcon;
    String statusText = request.status.toUpperCase();

    switch (request.status) {
      case 'approved':
        statusColor = AppColors.accentGreen;
        statusIcon = Iconsax.verify;
        break;
      case 'rejected':
        statusColor = Colors.redAccent;
        statusIcon = Iconsax.close_circle;
        break;
      default:
        statusColor = Colors.orangeAccent;
        statusIcon = Iconsax.timer_1;
    }

    final bool isPending = request.status == 'pending';
    final bool isDeviceSlot = request.type == 'device_slot';
    final IconData typeIcon = isDeviceSlot ? Iconsax.mobile : Iconsax.box;
    final Color typeColor = isDeviceSlot
        ? Colors.blueAccent
        : AppColors.accentGreen;

    final String displayTitle = request.title.isNotEmpty
        ? request.title
        : (isDeviceSlot ? "Device Slot" : "Plan Renewal");
    final String displaySubtitle = request.subtitle.isNotEmpty
        ? request.subtitle
        : (isDeviceSlot ? "Extra Device" : request.planName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(22),
        padding: const EdgeInsets.all(18),
        opacity: isPending ? 0.06 : 0.04,
        tintColor: isPending ? Colors.orangeAccent : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.2),
                        statusColor.withOpacity(0.08),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      request.vpnUserName.isNotEmpty
                          ? request.vpnUserName[0].toUpperCase()
                          : "U",
                      style: GoogleFonts.exo2(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.vpnUserName,
                        style: GoogleFonts.exo2(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        DateFormat(
                          'dd MMM, hh:mm a',
                        ).format(DateTime.parse(request.createdAt)),
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: statusColor.withOpacity(0.25),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 10, color: statusColor),
                      const SizedBox(width: 5),
                      Text(
                        statusText,
                        style: GoogleFonts.ibmPlexSans(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.025),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: typeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(typeIcon, color: typeColor, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayTitle,
                          style: GoogleFonts.exo2(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          displaySubtitle,
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (isPending)
              Row(
                children: [
                  Expanded(
                    child: ScaleButton(
                      onTap: () => _showScreenshot(request),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Iconsax.image,
                              color: Colors.blueAccent,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                "Proof",
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.blueAccent,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ScaleButton(
                      onTap: () => _showGlassRejectDialog(request.id),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.redAccent.withOpacity(0.2),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "Reject",
                            style: GoogleFonts.exo2(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ScaleButton(
                      onTap: () => _handleApprove(request.id),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.accentGreen.withOpacity(0.8),
                              AppColors.accentGreen,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accentGreen.withOpacity(0.25),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            "Approve",
                            style: GoogleFonts.exo2(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              ScaleButton(
                onTap: () => _showScreenshot(request),
                child: Container(
                  width: double.infinity,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Iconsax.image,
                        color: Colors.blueAccent,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "View Payment Proof",
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.blueAccent,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showScreenshot(RenewalRequest request) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: LiquidGlassContainer(
            opacity: 0.12,
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            const Icon(
                              Iconsax.image,
                              color: Colors.blueAccent,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Flexible(
                              child: Text(
                                "Payment Proof",
                                style: GoogleFonts.exo2(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ScaleButton(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Iconsax.close_circle,
                            color: Colors.white.withOpacity(0.5),
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 400,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                    child: InteractiveViewer(
                      child: Image.network(
                        request.screenshotUrl,
                        fit: BoxFit.contain,
                        loadingBuilder: (_, child, p) => p == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.accentGreen,
                                ),
                              ),
                        errorBuilder: (_, __, ___) => Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image,
                                color: Colors.white.withOpacity(0.2),
                                size: 48,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Failed to load",
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleApprove(int id) async {
    setState(() => _isProcessing = true);
    final success = await _renewalService.approveRequest(id);
    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        _loadRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request Approved Successfully!"),
            backgroundColor: AppColors.accentGreen,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Approval Failed."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _showGlassRejectDialog(int id) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: LiquidGlassContainer(
            opacity: 0.15,
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.close_circle,
                    color: Colors.redAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Reject Request",
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(14),
                  opacity: 0.05,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: controller,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    cursorColor: Colors.redAccent,
                    maxLines: 3,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: "Reason for rejection...",
                      hintStyle: GoogleFonts.ibmPlexSans(
                        color: Colors.white.withOpacity(0.25),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ScaleButton(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              "Cancel",
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white70,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ScaleButton(
                        onTap: () {
                          Navigator.pop(ctx);
                          if (controller.text.isNotEmpty)
                            _handleReject(id, controller.text);
                        },
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.5),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Reject",
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleReject(int id, String reason) async {
    setState(() => _isProcessing = true);
    final success = await _renewalService.rejectRequest(id, reason);
    if (mounted) {
      setState(() => _isProcessing = false);
      if (success) {
        _loadRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Request Rejected."),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Failed to reject."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
