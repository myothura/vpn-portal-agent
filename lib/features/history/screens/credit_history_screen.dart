import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/history/models/credit_history_model.dart';
import 'package:vpn_agent_app/features/history/services/credit_history_service.dart';

// --- Reusable UI Components (Glass & Animations) ---

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
    final radius = borderRadius ?? BorderRadius.circular(20);
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
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

// --- Main Screen ---

class CreditHistoryScreen extends StatefulWidget {
  const CreditHistoryScreen({super.key});

  @override
  State<CreditHistoryScreen> createState() => _CreditHistoryScreenState();
}

class _CreditHistoryScreenState extends State<CreditHistoryScreen> {
  final CreditHistoryService _historyService = CreditHistoryService();

  List<CreditTransaction> _transactions = [];
  int _currentPage = 1;
  int _lastPage = 1;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _loadInitialHistory();
  }

  Future<void> _loadInitialHistory() async {
    setState(() => _isLoading = true);
    final response = await _historyService.getCreditHistory(page: 1);
    if (mounted) {
      setState(() {
        if (response != null) {
          _transactions = response.transactions;
          _currentPage = response.currentPage;
          _lastPage = response.lastPage;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreHistory() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;
    setState(() => _isLoadingMore = true);

    final nextPage = _currentPage + 1;
    final response = await _historyService.getCreditHistory(page: nextPage);

    if (response != null && mounted) {
      setState(() {
        _transactions.addAll(response.transactions);
        _currentPage = nextPage;
        _lastPage = response.lastPage;
        _isLoadingMore = false;
      });
    } else {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  List<CreditTransaction> get _filteredTransactions {
    if (_filter == 'all') return _transactions;
    if (_filter == 'credit')
      return _transactions.where((t) => t.type == 'add').toList();
    return _transactions.where((t) => t.type != 'add').toList();
  }

  Map<String, dynamic> _getTransactionStyle(String description, String type) {
    final text = description.toLowerCase();
    final isCredit = type == 'add';

    if (isCredit) {
      return {
        'color': AppColors.accentGreen,
        'icon': Iconsax.arrow_down_2,
        'bg_color': AppColors.accentGreen.withOpacity(0.15),
      };
    }

    if (text.contains('business') || text.contains('upgrade')) {
      return {
        'color': const Color(0xFFF97316),
        'icon': Iconsax.briefcase,
        'bg_color': const Color(0xFFF97316).withOpacity(0.15),
      };
    } else if (text.contains('slot') || text.contains('device')) {
      return {
        'color': Colors.blueAccent,
        'icon': Iconsax.mobile,
        'bg_color': Colors.blueAccent.withOpacity(0.15),
      };
    } else if (text.contains('private')) {
      return {
        'color': const Color(0xFFFF2D55),
        'icon': Iconsax.shield_security,
        'bg_color': const Color(0xFFFF2D55).withOpacity(0.15),
      };
    } else if (text.contains('gold')) {
      return {
        'color': const Color(0xFFFFD700),
        'icon': Iconsax.crown_1,
        'bg_color': const Color(0xFFFFD700).withOpacity(0.15),
      };
    } else if (text.contains('renew')) {
      return {
        'color': Colors.blueAccent,
        'icon': Iconsax.refresh,
        'bg_color': Colors.blueAccent.withOpacity(0.15),
      };
    } else {
      return {
        'color': Colors.orangeAccent,
        'icon': Iconsax.arrow_up_2,
        'bg_color': Colors.orangeAccent.withOpacity(0.15),
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTransactions;
    final totalIn = _transactions
        .where((t) => t.type == 'add')
        .fold<int>(0, (s, t) => s + t.amount);
    final totalOut = _transactions
        .where((t) => t.type != 'add')
        .fold<int>(0, (s, t) => s + t.amount);

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
          "Transaction History",
          style: GoogleFonts.exo2(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: LiquidGlassContainer(
                borderRadius: BorderRadius.circular(12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                opacity: 0.1,
                child: Text(
                  "${filtered.length}",
                  style: GoogleFonts.spaceMono(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
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
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildFilterRow(),
                if (!_isLoading && _transactions.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                    child: Row(
                      children: [
                        _buildMiniStat(
                          "In",
                          "+${NumberFormat.compact().format(totalIn)}",
                          AppColors.accentGreen,
                        ),
                        const SizedBox(width: 8),
                        _buildMiniStat(
                          "Out",
                          "-${NumberFormat.compact().format(totalOut)}",
                          Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 4),
                Expanded(
                  child: _isLoading
                      ? _buildShimmer()
                      : filtered.isEmpty
                      ? _buildEmptyState()
                      : RefreshIndicator(
                          onRefresh: _loadInitialHistory,
                          color: AppColors.accentGreen,
                          backgroundColor: const Color(0xFF2C2C2E),
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 6,
                            ),
                            itemCount: filtered.length + 1,
                            itemBuilder: (context, index) {
                              if (index == filtered.length) {
                                if (_currentPage < _lastPage) {
                                  return _buildLoadMore();
                                }
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    top: 8,
                                    bottom: 20,
                                  ),
                                  child: Center(
                                    child: Text(
                                      "${filtered.length} transactions",
                                      style: GoogleFonts.ibmPlexSans(
                                        color: Colors.white.withOpacity(0.2),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                );
                              }

                              Widget card = _buildGlassTransactionCard(
                                filtered[index],
                              );

                              final current = filtered[index];
                              final currentDate = DateFormat('dd MMM yyyy')
                                  .format(
                                    DateTime.parse(current.createdAt).toLocal(),
                                  );
                              bool showDate = true;
                              if (index > 0) {
                                final prev = filtered[index - 1];
                                final prevDate = DateFormat('dd MMM yyyy')
                                    .format(
                                      DateTime.parse(prev.createdAt).toLocal(),
                                    );
                                showDate = currentDate != prevDate;
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showDate)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 12,
                                        bottom: 8,
                                        left: 4,
                                      ),
                                      child: Text(
                                        currentDate,
                                        style: GoogleFonts.ibmPlexSans(
                                          color: Colors.white.withOpacity(0.25),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  card,
                                ],
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    final filters = [
      {'key': 'all', 'label': 'All', 'color': Colors.blueAccent},
      {'key': 'credit', 'label': 'Credits In', 'color': AppColors.accentGreen},
      {'key': 'spend', 'label': 'Spent', 'color': Colors.orangeAccent},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: filters.map((f) {
          final isSelected = _filter == f['key'];
          final Color color = f['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ScaleButton(
              onTap: () => setState(() => _filter = f['key'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withOpacity(0.18)
                      : Colors.white.withOpacity(0.03),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? color.withOpacity(0.5)
                        : Colors.white.withOpacity(0.06),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Text(
                  f['label'] as String,
                  style: GoogleFonts.ibmPlexSans(
                    color: isSelected ? color : Colors.white.withOpacity(0.4),
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(
          6,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LiquidGlassContainer(
              borderRadius: BorderRadius.circular(20),
              opacity: 0.04,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  const SizedBox(width: 14),
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
                          width: 150,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    height: 20,
                    width: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadMore() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: _isLoadingMore
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentGreen,
                ),
              )
            : ScaleButton(
                onTap: _loadMoreHistory,
                child: LiquidGlassContainer(
                  borderRadius: BorderRadius.circular(14),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 10,
                  ),
                  opacity: 0.06,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.arrow_down_1,
                        size: 14,
                        color: Colors.white70,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "Load More",
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        "($_currentPage/$_lastPage)",
                        style: GoogleFonts.spaceMono(
                          color: Colors.white38,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.05),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.blueAccent.withOpacity(0.08)),
            ),
            child: Icon(
              Iconsax.receipt_1,
              size: 44,
              color: Colors.blueAccent.withOpacity(0.3),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            _filter == 'all'
                ? "No transactions yet"
                : "No ${_filter == 'credit' ? 'credit' : 'spending'} transactions",
            style: GoogleFonts.exo2(
              color: Colors.white.withOpacity(0.5),
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Transactions will appear here",
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.25),
              fontSize: 13,
            ),
          ),
          if (_filter != 'all') ...[
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

  Widget _buildGlassTransactionCard(CreditTransaction transaction) {
    final style = _getTransactionStyle(
      transaction.description,
      transaction.type,
    );
    final Color themeColor = style['color'];
    final Color bgColor = style['bg_color'];
    final IconData icon = style['icon'];

    final isCredit = transaction.type == 'add';
    final String sign = isCredit ? '+' : '-';
    final String formattedTime = DateFormat(
      'hh:mm a',
    ).format(DateTime.parse(transaction.createdAt).toLocal());

    String title = transaction.description;
    if (isCredit) {
      title = "Credit Added";
    } else if (title.toLowerCase().contains("activated") ||
        title.toLowerCase().contains("create")) {
      title = "User Activated";
    } else if (title.toLowerCase().contains("renew")) {
      title = "Plan Renewal";
    } else if (title.toLowerCase().contains("business") ||
        title.toLowerCase().contains("upgrade")) {
      title = "Business Upgrade";
    } else if (title.toLowerCase().contains("slot") ||
        title.toLowerCase().contains("device")) {
      title = "Device Slots";
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(18),
        padding: const EdgeInsets.all(14),
        opacity: 0.05,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: themeColor.withOpacity(0.25),
                  width: 1,
                ),
              ),
              child: Center(child: Icon(icon, color: themeColor, size: 20)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.exo2(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    transaction.description,
                    style: GoogleFonts.ibmPlexSans(
                      color: Colors.white.withOpacity(0.4),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        formattedTime,
                        style: GoogleFonts.ibmPlexSans(
                          color: Colors.white.withOpacity(0.2),
                          fontSize: 10,
                        ),
                      ),
                      if (transaction.runningBalance > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            "Bal: ${NumberFormat.compact().format(transaction.runningBalance)}",
                            style: GoogleFonts.spaceMono(
                              color: Colors.white.withOpacity(0.25),
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  "$sign${NumberFormat('#,##0').format(transaction.amount)}",
                  style: GoogleFonts.spaceMono(
                    color: isCredit ? AppColors.accentGreen : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCredit ? "IN" : "OUT",
                    style: GoogleFonts.spaceMono(
                      color: themeColor,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
