import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/agent_management/models/agent_model.dart';
import 'package:vpn_agent_app/features/agent_management/screens/create_edit_agent_screen.dart';
import 'package:vpn_agent_app/features/agent_management/services/agent_management_service.dart';

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
        HapticFeedback.lightImpact();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(scale: _scaleAnimation, child: widget.child),
    );
  }
}

class AgentListScreen extends StatefulWidget {
  const AgentListScreen({super.key});

  @override
  State<AgentListScreen> createState() => _AgentListScreenState();
}

class _AgentListScreenState extends State<AgentListScreen> {
  final AgentManagementService _service = AgentManagementService();
  final TextEditingController _searchController = TextEditingController();
  List<AgentModel> _agents = [];
  List<AgentModel> _filteredAgents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAgents();
    _searchController.addListener(_filterAgents);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAgents() async {
    setState(() => _isLoading = true);
    final agents = await _service.getAllAgents();
    if (mounted) {
      setState(() {
        _agents = agents;
        _filterAgents();
        _isLoading = false;
      });
    }
  }

  void _filterAgents() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredAgents = List.from(_agents);
      } else {
        _filteredAgents = _agents
            .where(
              (a) =>
                  a.name.toLowerCase().contains(query) ||
                  a.email.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Future<void> _confirmDelete(AgentModel agent) async {
    final confirm = await showDialog<bool>(
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
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Iconsax.trash,
                    color: Colors.redAccent,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Delete Agent?",
                  style: GoogleFonts.exo2(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Remove '${agent.name}'?\nThis agent has ${agent.userCount} user(s).",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.6),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ScaleButton(
                        onTap: () => Navigator.pop(ctx, false),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
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
                        onTap: () => Navigator.pop(ctx, true),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.redAccent.withOpacity(0.5),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              "Delete",
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

    if (confirm == true) {
      final success = await _service.deleteAgent(agent.id);
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Agent deleted successfully"),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _loadAgents();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _agents.where((a) => a.status == 'active').length;
    final totalCredits = _agents.fold<int>(
      0,
      (sum, a) => sum + a.creditBalance,
    );

    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Agent Management",
          style: GoogleFonts.exo2(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: Colors.white,
            letterSpacing: 1.0,
          ),
        ),
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
                child: Row(
                  children: [
                    const Icon(
                      Iconsax.people,
                      size: 14,
                      color: Color(0xFFA78BFA),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      "${_agents.length}",
                      style: GoogleFonts.ibmPlexSans(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: ScaleButton(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEditAgentScreen()),
          );
          if (result == true) _loadAgents();
        },
        child: LiquidGlassContainer(
          opacity: 0.2,
          tintColor: AppColors.accentGreen,
          borderRadius: BorderRadius.circular(30),
          padding: const EdgeInsets.all(16),
          child: const Icon(Iconsax.add, color: Colors.white, size: 28),
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
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 10),
                if (!_isLoading && _agents.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        _buildMiniStat(
                          "Active",
                          "$activeCount",
                          AppColors.accentGreen,
                        ),
                        const SizedBox(width: 10),
                        _buildMiniStat(
                          "Total Cr",
                          NumberFormat.compact().format(totalCredits),
                          Colors.orangeAccent,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: LiquidGlassContainer(
                    borderRadius: BorderRadius.circular(16),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    opacity: 0.06,
                    child: SizedBox(
                      height: 46,
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.search_normal,
                            color: Colors.white.withOpacity(0.4),
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              style: GoogleFonts.ibmPlexSans(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              cursorColor: AppColors.accentGreen,
                              decoration: InputDecoration(
                                hintText: "Search by name or email...",
                                hintStyle: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withOpacity(0.3),
                                  fontSize: 13,
                                ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (_searchController.text.isNotEmpty)
                            ScaleButton(
                              onTap: () {
                                _searchController.clear();
                              },
                              child: Icon(
                                Iconsax.close_circle,
                                size: 18,
                                color: Colors.white.withOpacity(0.4),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.accentGreen,
                          ),
                        )
                      : _filteredAgents.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.03),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _searchController.text.isEmpty
                                      ? Iconsax.people
                                      : Iconsax.search_status,
                                  size: 48,
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchController.text.isEmpty
                                    ? "No agents found"
                                    : "No results for '${_searchController.text}'",
                                style: GoogleFonts.exo2(
                                  color: Colors.white.withOpacity(0.5),
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: () async => _loadAgents(),
                          color: AppColors.accentGreen,
                          backgroundColor: const Color(0xFF2C2C2E),
                          child: ListView.builder(
                            physics: const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                            itemCount: _filteredAgents.length,
                            itemBuilder: (context, index) {
                              return _buildAgentCard(_filteredAgents[index]);
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

  Widget _buildMiniStat(String label, String value, Color color) {
    return Expanded(
      child: LiquidGlassContainer(
        borderRadius: BorderRadius.circular(14),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        opacity: 0.05,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.ibmPlexSans(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.spaceMono(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentCard(AgentModel agent) {
    bool isActive = agent.status == 'active';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: ScaleButton(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CreateEditAgentScreen(agent: agent),
            ),
          );
          if (result == true) _loadAgents();
        },
        scaleAmount: 0.98,
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(20),
          padding: const EdgeInsets.all(16),
          opacity: 0.06,
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isActive
                            ? [
                                const Color(0xFFA78BFA).withOpacity(0.25),
                                const Color(0xFF7C3AED).withOpacity(0.1),
                              ]
                            : [
                                Colors.grey.withOpacity(0.15),
                                Colors.grey.withOpacity(0.08),
                              ],
                      ),
                      border: Border.all(
                        color: isActive
                            ? const Color(0xFFA78BFA).withOpacity(0.4)
                            : Colors.white.withOpacity(0.08),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        agent.name.isNotEmpty
                            ? agent.name[0].toUpperCase()
                            : 'A',
                        style: GoogleFonts.exo2(
                          color: isActive
                              ? const Color(0xFFA78BFA)
                              : Colors.white38,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                agent.name,
                                style: GoogleFonts.exo2(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppColors.accentGreen.withOpacity(0.12)
                                    : Colors.redAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                isActive ? "Active" : "Inactive",
                                style: GoogleFonts.ibmPlexSans(
                                  color: isActive
                                      ? AppColors.accentGreen
                                      : Colors.redAccent,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (agent.canSendNotifications) ...[
                              const SizedBox(width: 6),
                              Icon(
                                Iconsax.notification,
                                size: 12,
                                color: Colors.orangeAccent.withOpacity(0.7),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          agent.email,
                          style: GoogleFonts.ibmPlexSans(
                            color: Colors.white.withOpacity(0.4),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (agent.parentName != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Iconsax.hierarchy,
                                size: 10,
                                color: Colors.white.withOpacity(0.25),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                agent.parentName!,
                                style: GoogleFonts.ibmPlexSans(
                                  color: Colors.white.withOpacity(0.25),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: Colors.white.withOpacity(0.05), height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    icon: Iconsax.wallet_2,
                    value: NumberFormat('#,##0').format(agent.creditBalance),
                    color: Colors.orangeAccent,
                  ),
                  const SizedBox(width: 10),
                  _buildInfoChip(
                    icon: Iconsax.people,
                    value: "${agent.userCount} users",
                    color: Colors.blueAccent,
                  ),
                  const Spacer(),
                  ScaleButton(
                    onTap: () => _confirmDelete(agent),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.redAccent.withOpacity(0.15),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Iconsax.trash,
                            size: 12,
                            color: Colors.redAccent,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            "Remove",
                            style: GoogleFonts.ibmPlexSans(
                              color: Colors.redAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildInfoChip({
    required IconData icon,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withOpacity(0.7)),
          const SizedBox(width: 6),
          Text(
            value,
            style: GoogleFonts.ibmPlexSans(
              color: Colors.white.withOpacity(0.7),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
