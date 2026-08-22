import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/features/profile/models/payment_method_model.dart';
import 'package:vpn_agent_app/features/profile/services/profile_service.dart';

// --- Reusable UI Components (Consistent with Dashboard) ---

class LiquidGlassContainer extends StatelessWidget {
  final Widget child;
  final double blurSigma;
  final double opacity;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry padding;
  final Color? tintColor;
  final bool withBorder;
  final VoidCallback? onTap;
  final LinearGradient? gradient; // Added custom gradient support

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
    this.gradient,
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
                ? Border.all(color: Colors.white.withOpacity(0.15), width: 1.0)
                : null,
            gradient:
                gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (tintColor ?? Colors.white).withOpacity(opacity + 0.1),
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

// --- Main Screen ---

class ManagePaymentScreen extends StatefulWidget {
  final List<PaymentMethod> initialMethods;
  const ManagePaymentScreen({super.key, required this.initialMethods});

  @override
  State<ManagePaymentScreen> createState() => _ManagePaymentScreenState();
}

class _ManagePaymentScreenState extends State<ManagePaymentScreen> {
  final ProfileService _profileService = ProfileService();
  late List<PaymentMethod> _methods;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _methods = List.from(widget.initialMethods);
  }

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    final success = await _profileService.updatePaymentMethods(_methods);
    setState(() => _isSaving = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Wallet updated successfully!"),
          backgroundColor: AppColors.accentGreen,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Update failed. Please check connection."),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // --- GLASS ADD / EDIT SHEET ---
  void _showAddEditSheet({PaymentMethod? existingItem, int? index}) {
    final bankController = TextEditingController(text: existingItem?.bankName);
    final nameController = TextEditingController(
      text: existingItem?.accountName,
    );
    final numController = TextEditingController(
      text: existingItem?.accountNumber,
    );
    String? localImagePath = existingItem?.localImagePath;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          // Full Screen Glass Effect
          return Stack(
            children: [
              // Blur Background
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(color: Colors.black.withOpacity(0.6)),
                ),
              ),

              // Content
              Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.85,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.2)),
                    ),
                  ),
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 30,
                    left: 24,
                    right: 24,
                    top: 20,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              existingItem == null ? "New Card" : "Edit Card",
                              style: GoogleFonts.exo2(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            ScaleButton(
                              onTap: () => Navigator.pop(context),
                              child: LiquidGlassContainer(
                                borderRadius: BorderRadius.circular(12),
                                padding: const EdgeInsets.all(8),
                                opacity: 0.1,
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white70,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 30),

                        // QR Uploader (Glass)
                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(
                              source: ImageSource.gallery,
                            );
                            if (picked != null) {
                              setModalState(() => localImagePath = picked.path);
                            }
                          },
                          child: LiquidGlassContainer(
                            borderRadius: BorderRadius.circular(24),
                            opacity: 0.05,
                            withBorder: true,
                            child: Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                image: localImagePath != null
                                    ? DecorationImage(
                                        image: FileImage(File(localImagePath!)),
                                        fit: BoxFit.cover,
                                      )
                                    : (existingItem?.qrCodeUrl != null
                                          ? DecorationImage(
                                              image: NetworkImage(
                                                existingItem!.qrCodeUrl!,
                                              ),
                                              fit: BoxFit.cover,
                                            )
                                          : null),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  if (localImagePath == null &&
                                      existingItem?.qrCodeUrl == null)
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Iconsax.scan,
                                          color: Colors.white54,
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          "Tap to upload QR",
                                          style: GoogleFonts.ibmPlexSans(
                                            color: Colors.white38,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),

                                  if (localImagePath != null ||
                                      existingItem?.qrCodeUrl != null)
                                    Positioned(
                                      bottom: 12,
                                      right: 12,
                                      child: LiquidGlassContainer(
                                        borderRadius: BorderRadius.circular(12),
                                        padding: const EdgeInsets.all(8),
                                        opacity: 0.3,
                                        tintColor: Colors.black,
                                        child: const Icon(
                                          Iconsax.edit,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        _buildGlassTextField(
                          bankController,
                          "BANK NAME",
                          "KBZ Pay, Wave...",
                          Iconsax.bank,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassTextField(
                          nameController,
                          "ACCOUNT HOLDER",
                          "U Mya",
                          Iconsax.user,
                        ),
                        const SizedBox(height: 16),
                        _buildGlassTextField(
                          numController,
                          "ACCOUNT NUMBER",
                          "09xxxxxxxxx",
                          Iconsax.card,
                          isNumber: true,
                        ),

                        const SizedBox(height: 32),

                        // Save Button (Glass Gradient)
                        ScaleButton(
                          onTap: () {
                            if (bankController.text.isEmpty ||
                                numController.text.isEmpty)
                              return;

                            final newItem = PaymentMethod(
                              id: existingItem?.id ?? const Uuid().v4(),
                              bankName: bankController.text,
                              accountName: nameController.text,
                              accountNumber: numController.text,
                              localImagePath: localImagePath,
                              qrCodeUrl: existingItem?.qrCodeUrl,
                            );

                            setState(() {
                              if (index != null) {
                                _methods[index] = newItem;
                              } else {
                                _methods.add(newItem);
                              }
                            });

                            Navigator.pop(context);
                            _saveChanges();
                          },
                          child: LiquidGlassContainer(
                            borderRadius: BorderRadius.circular(20),
                            opacity: 0.2,
                            tintColor: AppColors.accentGreen,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            child: Center(
                              child: Text(
                                "SAVE CARD",
                                style: GoogleFonts.exo2(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.0,
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
            ],
          );
        },
      ),
    );
  }

  Widget _buildGlassTextField(
    TextEditingController controller,
    String label,
    String hint,
    IconData icon, {
    bool isNumber = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.exo2(
            color: Colors.white.withOpacity(0.5),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        LiquidGlassContainer(
          borderRadius: BorderRadius.circular(16),
          opacity: 0.05,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextFormField(
            controller: controller,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
            style: GoogleFonts.spaceMono(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.ibmPlexSans(
                color: Colors.white.withOpacity(0.2),
                fontWeight: FontWeight.normal,
              ),
              prefixIcon: Icon(
                icon,
                color: Colors.white.withOpacity(0.5),
                size: 20,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBackground,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
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
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          "My Payment",
          style: GoogleFonts.exo2(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: Stack(
        children: [
          // 1. Background
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

          // 2. Content
          SafeArea(
            child: _methods.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(30),
                          padding: const EdgeInsets.all(24),
                          opacity: 0.05,
                          child: Icon(
                            Iconsax.card_slash,
                            size: 48,
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "No cards in wallet",
                          style: GoogleFonts.exo2(
                            color: Colors.white.withOpacity(0.3),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 150),
                    physics: const BouncingScrollPhysics(),
                    itemCount: _methods.length,
                    itemBuilder: (context, index) {
                      final item = _methods[index];
                      return _buildGlassCreditCard(item, index);
                    },
                  ),
          ),

          // 3. Glass Bottom Dock
          Positioned(
            left: 20,
            right: 20,
            bottom: 30,
            child: LiquidGlassContainer(
              borderRadius: BorderRadius.circular(24),
              opacity: 0.15, // Higher opacity for dock
              blurSigma: 25,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              withBorder: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "TOTAL CARDS",
                        style: GoogleFonts.exo2(
                          color: Colors.white54,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        "${_methods.length}",
                        style: GoogleFonts.spaceMono(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  ScaleButton(
                    onTap: () => _showAddEditSheet(),
                    child: LiquidGlassContainer(
                      borderRadius: BorderRadius.circular(16),
                      opacity: 0.2,
                      tintColor: AppColors.accentGreen,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Iconsax.add,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Add Card",
                            style: GoogleFonts.exo2(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (_isSaving)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.accentGreen),
              ),
            ),
        ],
      ),
    );
  }

  // --- GLASS CREDIT CARD ---
  Widget _buildGlassCreditCard(PaymentMethod item, int index) {
    // Glass Tints for Cards
    final List<Color> tints = [
      Colors.blueAccent,
      Colors.orangeAccent,
      Colors.purpleAccent,
      AppColors.accentGreen,
    ];
    final tintColor = tints[index % tints.length];

    return ScaleButton(
      onTap: () => _showAddEditSheet(existingItem: item, index: index),
      scaleAmount: 0.98,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        height: 210,
        child: LiquidGlassContainer(
          borderRadius: BorderRadius.circular(24),
          opacity: 0.15, // Glass Card Opacity
          tintColor: tintColor,
          blurSigma: 20,
          withBorder: true,
          padding: const EdgeInsets.all(24),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Iconsax.bank,
                            color: Colors.white.withOpacity(0.9),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            item.bankName.toUpperCase(),
                            style: GoogleFonts.exo2(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                      if (item.qrCodeUrl != null || item.localImagePath != null)
                        LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          opacity: 0.2,
                          child: const Row(
                            children: [
                              Icon(Iconsax.scan, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text(
                                "QR",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),

                  // Number
                  Text(
                    _formatCardNumber(item.accountNumber),
                    style: GoogleFonts.spaceMono(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.0,
                      shadows: [
                        Shadow(
                          color: tintColor.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),

                  // Bottom Info
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "CARD HOLDER",
                            style: GoogleFonts.exo2(
                              color: Colors.white54,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            item.accountName.toUpperCase(),
                            style: GoogleFonts.exo2(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Delete Action in Glass Bubble
                      ScaleButton(
                        onTap: () => _showDeleteConfirm(index, item.bankName),
                        child: LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(20),
                          padding: const EdgeInsets.all(8),
                          opacity: 0.2,
                          tintColor: Colors.redAccent,
                          child: const Icon(
                            Iconsax.trash,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirm(int index, String bankName) {
    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: LiquidGlassContainer(
            borderRadius: BorderRadius.circular(24),
            padding: const EdgeInsets.all(24),
            opacity: 0.15,
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
                    size: 32,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  "Remove Card?",
                  style: GoogleFonts.exo2(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "Are you sure you want to remove '$bankName'?",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.ibmPlexSans(color: Colors.white70),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ScaleButton(
                        onTap: () => Navigator.pop(ctx),
                        child: LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          opacity: 0.1,
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
                          setState(() => _methods.removeAt(index));
                          _saveChanges();
                        },
                        child: LiquidGlassContainer(
                          borderRadius: BorderRadius.circular(12),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          opacity: 0.2,
                          tintColor: Colors.redAccent,
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
  }

  String _formatCardNumber(String number) {
    if (number.length > 4) {
      return number.replaceAllMapped(
        RegExp(r".{4}"),
        (match) => "${match.group(0)} ",
      );
    }
    return number;
  }
}
