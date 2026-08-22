// lib/shared_widgets/glass_dropdown_button.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';

class GlassDropdownButton<T> extends StatefulWidget {
  final String label;
  final String hintText;
  final IconData icon;
  final T? value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final String Function(T) displayItem;
  final Color? pillColor;

  const GlassDropdownButton({
    super.key,
    required this.label,
    required this.hintText,
    required this.icon,
    this.value,
    required this.items,
    required this.onChanged,
    required this.displayItem,
    this.pillColor,
  });

  @override
  State<GlassDropdownButton<T>> createState() => _GlassDropdownButtonState<T>();
}

class _GlassDropdownButtonState<T> extends State<GlassDropdownButton<T>> {
  final GlobalKey _key = GlobalKey();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown();
    } else {
      _openDropdown();
    }
  }

  void _openDropdown() {
    // ⭐️ UPDATE: Button ရဲ့ position ကို တွက်ချက်နေစရာမလိုတော့ပါ
    // final RenderBox renderBox = _key.currentContext!.findRenderObject() as RenderBox;
    // final size = renderBox.size;
    // final offset = renderBox.localToGlobal(Offset.zero);

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: GestureDetector(
                  onTap: _closeDropdown,
                  child: Container(color: Colors.black.withOpacity(0.2)),
                ),
              ),
            ),
            // ⭐️ UPDATE: Positioned အစား Center ကိုသုံးပြီး Menu ကို အလယ်မှာထားပါ
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 80.0,
              ),
              child: Center(
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: ListView.separated(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: widget.items.length,
                      separatorBuilder: (context, index) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.white.withOpacity(0.1),
                      ),
                      itemBuilder: (context, index) {
                        final item = widget.items[index];
                        return InkWell(
                          onTap: () {
                            widget.onChanged(item);
                            _closeDropdown();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 16,
                            ),
                            child: Text(
                              widget.displayItem(item),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _isOpen = true);
  }

  void _closeDropdown() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() => _isOpen = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 8.0),
          child: Text(
            widget.label,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        GestureDetector(
          key: _key,
          onTap: _toggleDropdown,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isOpen
                    ? AppColors.accentGreen
                    : Colors.white.withOpacity(0.2),
                width: _isOpen ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              children: [
                FaIcon(widget.icon, size: 16, color: Colors.white70),
                const SizedBox(width: 12),
                Expanded(
                  child: (widget.value != null)
                      ? Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: (widget.pillColor ?? AppColors.accentGreen)
                                  .withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              widget.displayItem(widget.value as T),
                              style: TextStyle(
                                color:
                                    widget.pillColor ?? AppColors.accentGreen,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          widget.hintText,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                ),
                Icon(
                  _isOpen
                      ? Icons.arrow_drop_up_rounded
                      : Icons.arrow_drop_down_rounded,
                  color: Colors.white70,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
