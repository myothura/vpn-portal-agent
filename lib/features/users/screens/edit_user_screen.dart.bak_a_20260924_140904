import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/users/models/plan_model.dart';
import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';
import 'package:vpn_agent_app/features/users/services/user_management_service.dart';

class EditUserScreen extends StatefulWidget {
  final VpnUser user;

  const EditUserScreen({super.key, required this.user});

  @override
  State<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends State<EditUserScreen> {
  final _userService = UserManagementService();
  final _password = TextEditingController();

  List<Plan> _plans = [];
  Plan? _plan;

  List<BusinessPlan> _businessPlans = [];
  BusinessPlan? _businessPlan;
  late bool _hasBusinessPlan;
  String? _businessPlanName;

  /// Extension to add, in months and days. Both default to zero: editing a
  /// user is usually about status or password, and silently extending a
  /// subscription because a field defaulted to 1 would cost the agent credit.
  int _months = 0;
  int _days = 0;

  late String _status;
  bool _saving = false;
  bool _businessBusy = false;
  bool _loading = true;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _status = widget.user.status;
    _hasBusinessPlan = widget.user.hasBusinessPlan;
    _businessPlanName = widget.user.businessPlanName;
    _fetchData();
  }

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    final results = await Future.wait([
      _userService.getAvailablePlans(),
      _userService.getBusinessPlans(),
    ]);
    if (!mounted) return;

    setState(() {
      _plans = results[0] as List<Plan>;
      _businessPlans = results[1] as List<BusinessPlan>;

      // Matched by name: VpnUser carries plan_name, not plan_id. If the plan
      // was renamed server-side this falls back to the first rather than
      // leaving the selection empty and blocking save.
      _plan = _plans.isEmpty
          ? null
          : _plans.firstWhere(
              (p) => p.planName == widget.user.planName,
              orElse: () => _plans.first,
            );

      _businessPlan = _businessPlans.isEmpty ? null : _businessPlans.first;
      _loading = false;
    });
  }

  // ── Derived ──

  int get _addedDays => _months * 30 + _days;

  bool get _statusChanged => _status != widget.user.status;
  bool get _planChanged =>
      _plan != null && _plan!.planName != widget.user.planName;
  bool get _passwordChanged => _password.text.isNotEmpty;

  /// Save is enabled only when something would actually change. The old screen
  /// let an agent submit a no-op, which still cost a round-trip and re-synced
  /// the user across every server on their plan.
  bool get _hasChanges =>
      _addedDays > 0 || _statusChanged || _planChanged || _passwordChanged;

  DateTime? get _currentExpiry {
    final raw = widget.user.expiryDate;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  DateTime? get _newExpiry {
    if (_addedDays == 0) return null;
    // Extending an expired account starts from today, not from the lapsed
    // date — otherwise adding a month to something three months dead grants
    // nothing and the agent has no way to see that before paying.
    final base = _currentExpiry;
    final now = DateTime.now();
    final from = (base == null || base.isBefore(now)) ? now : base;
    return from.add(Duration(days: _addedDays));
  }

  int get _cost => ((_plan?.price ?? 0) / 30 * _addedDays).ceil();

  // ── Actions ──

  Future<void> _save() async {
    if (_plan == null || !_hasChanges) return;
    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    final ok = await _userService.updateUser(
      userId: widget.user.id,
      planId: _plan!.id,
      months: _months,
      days: _days,
      status: _status,
      password: _passwordChanged ? _password.text : null,
    );

    if (!mounted) return;
    setState(() => _saving = false);

    if (!ok) {
      _toast('Could not save. Check your balance and try again.');
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(const SnackBar(content: Text('User updated.')));
  }

  Future<void> _assignBusiness() async {
    if (_businessPlan == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _businessBusy = true);

    final result = await _userService.assignBusinessPlan(
      widget.user.id,
      _businessPlan!.id,
    );

    if (!mounted) return;
    setState(() {
      _businessBusy = false;
      // Stay on the screen and reflect the change in place. Popping on assign
      // meant an agent adding a business plan and then wanting to extend the
      // subscription had to find the user and open them again.
      if (result['success'] == true) {
        _hasBusinessPlan = true;
        _businessPlanName = _businessPlan!.planName;
      }
    });
    _toast(result['message']?.toString() ?? 'Business plan updated.');
  }

  Future<void> _removeBusiness() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const AppIconBadge(
          icon: Iconsax.briefcase,
          color: AppColors.orange,
          background: AppColors.orangeWash,
          size: 22,
          padding: 12,
        ),
        title: const Text('Remove business plan?'),
        content: Text(
          "${widget.user.username} will lose access to the business servers.",
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    setState(() => _businessBusy = true);
    final result = await _userService.removeBusinessPlan(widget.user.id);

    if (!mounted) return;
    setState(() {
      _businessBusy = false;
      if (result['success'] == true) {
        _hasBusinessPlan = false;
        _businessPlanName = null;
      }
    });
    _toast(result['message']?.toString() ?? 'Business plan removed.');
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.user.username)),
      body: _loading
          ? const AppLoader()
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: Stack(
                children: [
                  const _HeroBackdrop(),
                  SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _SubscriptionCard(
                                  user: widget.user,
                                  currentExpiry: _currentExpiry,
                                  newExpiry: _newExpiry,
                                ),
                                const SizedBox(height: 22),
                                const AppSectionHeader(title: 'Status'),
                                const SizedBox(height: 10),
                                _StatusToggle(
                                  status: _status,
                                  onChanged: (v) => setState(() => _status = v),
                                ),
                                const SizedBox(height: 22),
                                const AppSectionHeader(title: 'Plan'),
                                const SizedBox(height: 10),
                                _PlanRow(
                                  plans: _plans,
                                  selected: _plan,
                                  onChanged: (p) => setState(() => _plan = p),
                                ),
                                const SizedBox(height: 22),
                                const AppSectionHeader(
                                  title: 'Extend subscription',
                                ),
                                const SizedBox(height: 10),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _Stepper(
                                        label: 'Months',
                                        value: _months,
                                        max: 36,
                                        onChanged: (v) =>
                                            setState(() => _months = v),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: _Stepper(
                                        label: 'Days',
                                        value: _days,
                                        max: 29,
                                        onChanged: (v) =>
                                            setState(() => _days = v),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 22),
                                const AppSectionHeader(title: 'Password'),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _password,
                                  obscureText: _obscure,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  onChanged: (_) => setState(() {}),
                                  decoration: InputDecoration(
                                    hintText: 'Leave blank to keep current',
                                    prefixIcon: const Icon(
                                      Iconsax.lock,
                                      size: 18,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(
                                        _obscure
                                            ? Iconsax.eye_slash
                                            : Iconsax.eye,
                                        size: 17,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_businessPlans.isNotEmpty) ...[
                                  const SizedBox(height: 22),
                                  _BusinessCard(
                                    active: _hasBusinessPlan,
                                    activeName: _businessPlanName,
                                    plans: _businessPlans,
                                    selected: _businessPlan,
                                    busy: _businessBusy,
                                    onChanged: (p) =>
                                        setState(() => _businessPlan = p),
                                    onAssign: _assignBusiness,
                                    onRemove: _removeBusiness,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        _SaveBar(
                          cost: _cost,
                          addedDays: _addedDays,
                          enabled: _hasChanges,
                          busy: _saving,
                          onSave: _save,
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

/// Hero as a backdrop, not a banner.
///
/// Anchored to the top and faded out downward so the form scrolls over it.
/// Sitting in the column as a 150px image, it pushed the first field below the
/// fold on a short screen — on a form the illustration is context, not
/// content, and should not cost the agent a scroll before they can type.
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.55, 1.0],
            colors: [Colors.black, Colors.black26, Colors.transparent],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: Opacity(
            // Faint enough that text over it stays legible without a scrim.
            opacity: 0.30,
            child: Image.asset(
              'assets/images/user_hero.png',
              height: 260,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────

/// Where the subscription stands, and where this edit would move it.
class _SubscriptionCard extends StatelessWidget {
  final VpnUser user;
  final DateTime? currentExpiry;
  final DateTime? newExpiry;

  const _SubscriptionCard({
    required this.user,
    required this.currentExpiry,
    required this.newExpiry,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final date = DateFormat('dd MMM yyyy');
    final expired =
        currentExpiry != null && currentExpiry!.isBefore(DateTime.now());

    return AppCard(
      tone: SurfaceTone.ink,
      texture: CardTexture.rings,
      showShadow: false,
      radius: AppTheme.radiusLg,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Expires',
                style: t.bodyMedium?.copyWith(
                  color: AppColors.textOnInk.withValues(alpha: 0.7),
                ),
              ),
              const Spacer(),
              if (expired)
                const AppPill(
                  label: 'EXPIRED',
                  color: AppColors.textOnAccent,
                  background: AppColors.danger,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                currentExpiry == null
                    ? 'No expiry'
                    : date.format(currentExpiry!),
                style: t.titleLarge?.copyWith(
                  color: newExpiry == null
                      ? AppColors.textOnInk
                      // Struck through once an extension is pending, so the
                      // agent can see what they are replacing.
                      : AppColors.textOnInk.withValues(alpha: 0.45),
                  decoration: newExpiry == null
                      ? null
                      : TextDecoration.lineThrough,
                  decorationColor: AppColors.textOnInk.withValues(alpha: 0.45),
                ),
              ),
              if (newExpiry != null) ...[
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 16,
                  color: AppColors.textOnInk,
                ),
                const SizedBox(width: 10),
                Text(
                  date.format(newExpiry!),
                  style: t.titleLarge?.copyWith(color: AppColors.textOnInk),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusToggle extends StatelessWidget {
  final String status;
  final ValueChanged<String> onChanged;

  const _StatusToggle({required this.status, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatusOption(
            label: 'Active',
            icon: Iconsax.tick_circle,
            color: AppColors.success,
            wash: AppColors.successWash,
            selected: status == 'active',
            onTap: () => onChanged('active'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatusOption(
            label: 'Paused',
            icon: Iconsax.pause_circle,
            color: AppColors.neutral,
            wash: AppColors.neutralWash,
            selected: status != 'active',
            onTap: () => onChanged('inactive'),
          ),
        ),
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final Color wash;
  final bool selected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.label,
    required this.icon,
    required this.color,
    required this.wash,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // A tint rather than a solid fill. Solid put two large blocks of colour
    // above the plan tiles and outweighed them; status is a state, not the
    // headline of the screen.
    return AppCard(
      onTap: onTap,
      radius: AppTheme.radiusMd,
      showShadow: false,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      tone: selected ? SurfaceTone.wash : SurfaceTone.plain,
      washColor: wash,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 17,
            color: selected ? color : AppColors.textTertiary,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? color : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanPalette {
  final Color color;
  final Color wash;

  const _PlanPalette(this.color, this.wash);

  static _PlanPalette of(String name) {
    final n = name.toLowerCase();
    if (n.contains('business')) {
      return const _PlanPalette(AppColors.orange, AppColors.orangeWash);
    }
    if (n.contains('private')) {
      return const _PlanPalette(AppColors.violet, AppColors.violetWash);
    }
    return const _PlanPalette(AppColors.accentInk, AppColors.accentWash);
  }
}

class _PlanRow extends StatelessWidget {
  final List<Plan> plans;
  final Plan? selected;
  final ValueChanged<Plan> onChanged;

  const _PlanRow({
    required this.plans,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return Text(
        'No plans available',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < plans.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _PlanTile(
                plan: plans[i],
                selected: plans[i].id == selected?.id,
                onTap: () => onChanged(plans[i]),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final Plan plan;
  final bool selected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.plan,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final palette = _PlanPalette.of(plan.planName);

    return Material(
      color: selected ? palette.color : AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(
              color: selected ? palette.color : AppColors.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? AppColors.surface : Colors.transparent,
                  border: selected
                      ? null
                      : Border.all(color: AppColors.borderStrong, width: 1.5),
                ),
                child: selected
                    ? Icon(Icons.check_rounded, size: 14, color: palette.color)
                    : null,
              ),
              const SizedBox(height: 10),
              Text(
                plan.planName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: t.bodyLarge?.copyWith(
                  fontSize: 12.5,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? AppColors.textOnAccent
                      : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              const SizedBox(height: 6),
              Text(
                '${NumberFormat('#,##0').format(plan.price)}/mo',
                maxLines: 1,
                style: t.bodySmall?.copyWith(
                  fontSize: 11,
                  color: selected
                      ? AppColors.textOnAccent.withValues(alpha: 0.85)
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stepper extends StatefulWidget {
  final String label;
  final int value;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_Stepper> createState() => _StepperState();
}

class _StepperState extends State<_Stepper> {
  late final TextEditingController _controller = TextEditingController(
    text: '${widget.value}',
  );
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else {
        _commit(_controller.text, settle: true);
      }
    });
  }

  @override
  void didUpdateWidget(_Stepper old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value && !_focus.hasFocus) {
      _controller.text = '${widget.value}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw, {bool settle = false}) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) {
      if (settle) _controller.text = '${widget.value}';
      return;
    }
    final clamped = parsed.clamp(0, widget.max);
    if (settle || clamped.toString() != raw.trim()) {
      _controller.text = '$clamped';
    }
    if (clamped != widget.value) widget.onChanged(clamped);
  }

  void _step(int delta) {
    final next = (widget.value + delta).clamp(0, widget.max);
    if (next == widget.value) return;
    HapticFeedback.selectionClick();
    _controller.text = '$next';
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      radius: AppTheme.radiusMd,
      showShadow: false,
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.label, style: t.bodySmall),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: _commit,
                  onSubmitted: (v) => _commit(v, settle: true),
                  style: t.headlineMedium?.copyWith(fontSize: 22),
                  decoration: const InputDecoration(
                    isDense: true,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.remove_rounded,
                enabled: widget.value > 0,
                onTap: () => _step(-1),
              ),
              const SizedBox(width: 6),
              _StepButton(
                icon: Icons.add_rounded,
                enabled: widget.value < widget.max,
                onTap: () => _step(1),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? AppColors.surfaceAlt : AppColors.background,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(
            icon,
            size: 18,
            color: enabled ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ),
    );
  }
}

/// Business plan: shows what is attached, or lets one be attached.
///
/// Both actions apply immediately and stay on the screen. They are separate
/// endpoints from the main save, so folding them into the Save button would
/// imply a single atomic update that does not exist.
class _BusinessCard extends StatelessWidget {
  final bool active;
  final String? activeName;
  final List<BusinessPlan> plans;
  final BusinessPlan? selected;
  final bool busy;
  final ValueChanged<BusinessPlan> onChanged;
  final VoidCallback onAssign;
  final VoidCallback onRemove;

  const _BusinessCard({
    required this.active,
    required this.activeName,
    required this.plans,
    required this.selected,
    required this.busy,
    required this.onChanged,
    required this.onAssign,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.all(14),
      tone: active ? SurfaceTone.wash : SurfaceTone.plain,
      washColor: AppColors.orangeWash,
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIconBadge(
                icon: Iconsax.briefcase,
                color: AppColors.orange,
                background: active ? AppColors.surface : AppColors.orangeWash,
                size: 16,
                padding: 8,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Business plan',
                      style: t.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      active ? (activeName ?? 'Active') : 'Not assigned',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (active)
            OutlinedButton.icon(
              onPressed: busy ? null : onRemove,
              icon: const Icon(Iconsax.trash, size: 16),
              label: const Text('Remove business plan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orange,
                side: const BorderSide(color: AppColors.orange),
              ),
            )
          else ...[
            for (final plan in plans)
              InkWell(
                onTap: busy ? null : () => onChanged(plan),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        plan.id == selected?.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 19,
                        color: plan.id == selected?.id
                            ? AppColors.orange
                            : AppColors.borderStrong,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          plan.planName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: t.bodyLarge?.copyWith(fontSize: 14),
                        ),
                      ),
                      Text(
                        '${NumberFormat('#,##0').format(plan.price)}/mo',
                        style: t.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: busy || selected == null ? null : onAssign,
              style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
              child: const Text('Assign business plan'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  final int cost;
  final int addedDays;
  final bool enabled;
  final bool busy;
  final VoidCallback onSave;

  const _SaveBar({
    required this.cost,
    required this.addedDays,
    required this.enabled,
    required this.busy,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    addedDays > 0 ? 'Cost' : 'No extension',
                    style: t.bodySmall,
                  ),
                  Text(
                    addedDays > 0 ? NumberFormat('#,##0').format(cost) : '—',
                    style: t.headlineMedium?.copyWith(fontSize: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: enabled && !busy ? onSave : null,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnAccent,
                      ),
                    )
                  : const Text('Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}
