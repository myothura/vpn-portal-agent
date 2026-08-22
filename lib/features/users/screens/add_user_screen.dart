import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/dashboard/models/dashboard_model.dart';
import 'package:vpn_agent_app/features/dashboard/services/dashboard_service.dart';
import 'package:vpn_agent_app/features/users/models/plan_model.dart';
import 'package:vpn_agent_app/features/users/services/user_management_service.dart';

class AddUserScreen extends StatefulWidget {
  const AddUserScreen({super.key});

  @override
  State<AddUserScreen> createState() => _AddUserScreenState();
}

class _AddUserScreenState extends State<AddUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();

  final _userService = UserManagementService();
  final _dashboardService = DashboardService();

  List<Plan> _plans = [];
  Plan? _plan;

  List<BusinessPlan> _businessPlans = [];
  BusinessPlan? _businessPlan;
  bool _enableBusiness = false;

  /// Duration held as numbers, not text controllers. The old screen parsed
  /// two TextFields on every rebuild and rebuilt the entire screen on every
  /// keystroke via three setState listeners.
  int _months = 1;
  int _days = 0;

  bool _busy = false;
  bool _loadingData = true;
  bool _obscure = true;
  int? _creditBalance;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _loadingData = true);
    try {
      final results = await Future.wait([
        _userService.getAvailablePlans(),
        _dashboardService.getDashboardStats(),
        _userService.getBusinessPlans(),
      ]);
      if (!mounted) return;

      setState(() {
        _plans = results[0] as List<Plan>;
        _plan = _plans.isNotEmpty ? _plans.first : null;

        final stats = results[1];
        if (stats is DashboardStats) _creditBalance = stats.creditBalance;

        _businessPlans = results[2] as List<BusinessPlan>;
        _businessPlan = _businessPlans.isNotEmpty ? _businessPlans.first : null;
      });
    } catch (e) {
      debugPrint('AddUser: initial fetch failed: $e');
    } finally {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  // ── Pricing ──

  int get _chargePrice => _enableBusiness && _businessPlan != null
      ? _businessPlan!.price
      : (_plan?.price ?? 0);

  int get _totalDays => _months * 30 + _days;

  int get _totalCost => ((_chargePrice / 30) * _totalDays).ceil();

  /// Whether the agent can actually afford this. The old screen showed the
  /// balance and the cost side by side but never compared them — the create
  /// failed at the server with a message that blamed the username too.
  bool get _canAfford =>
      _creditBalance == null || _totalCost <= _creditBalance!;

  // ── Actions ──

  void _generatePassword() {
    HapticFeedback.lightImpact();
    const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    setState(() {
      _password.text = String.fromCharCodes(
        Iterable.generate(
          10,
          (_) => chars.codeUnitAt(rnd.nextInt(chars.length)),
        ),
      );
      // Revealed on generate: the agent has to read it out to the customer,
      // and a freshly-made password behind dots is useless.
      _obscure = false;
    });
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_plan == null) return;
    if (_totalDays <= 0) {
      _toast('Set at least one day of duration.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _busy = true);

    final username = _username.text.trim();
    final created = await _userService.createUser(
      username: username,
      password: _password.text,
      planId: _plan!.id,
      months: _months,
      days: _days,
    );

    if (!mounted) return;

    if (!created) {
      setState(() => _busy = false);
      _toast(
        'Could not create the user. Check your balance and that the '
        'username is not already taken.',
      );
      return;
    }

    var businessAssigned = true;
    if (_enableBusiness && _businessPlan != null) {
      businessAssigned = await _assignBusiness(username);
    }

    if (!mounted) return;
    setState(() => _busy = false);

    // The messenger is captured before popping and the message shown after,
    // so it belongs to the screen the agent lands on. Raised against this
    // screen instead, it goes away with the route it was attached to.
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          businessAssigned
              ? 'User created.'
              : 'User created, but the business plan could not be assigned.',
        ),
      ),
    );
  }

  /// Finds the account just created and attaches the business plan.
  ///
  /// Returns false rather than reporting success blindly: the previous version
  /// swallowed every failure into a debugPrint while the UI still said
  /// "created with Business Plan".
  Future<bool> _assignBusiness(String username) async {
    try {
      final response = await _userService.getVpnUsers(search: username);
      final matches =
          response?.users.where((u) => u.username == username).toList() ?? [];

      // Exact match only. The old code fell back to `users.first` when the
      // search missed, which could attach a paid business plan to an entirely
      // unrelated account.
      if (matches.isEmpty) return false;

      await _userService.assignBusinessPlan(
        matches.first.id,
        _businessPlan!.id,
      );
      return true;
    } catch (e) {
      debugPrint('AddUser: business assign failed: $e');
      return false;
    }
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
      appBar: AppBar(title: const Text('New user')),
      body: _loadingData
          ? const AppLoader()
          : GestureDetector(
              onTap: () => FocusScope.of(context).unfocus(),
              child: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        physics: const BouncingScrollPhysics(),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _BalanceRow(balance: _creditBalance),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _username,
                                autocorrect: false,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: Icon(Iconsax.user, size: 18),
                                ),
                                validator: (v) {
                                  final value = v?.trim() ?? '';
                                  if (value.isEmpty) return 'Enter a username';
                                  if (value.length < 3) {
                                    return 'At least 3 characters';
                                  }
                                  // Spaces and punctuation break the Xray
                                  // client email key derived from this name.
                                  if (!RegExp(
                                    r'^[A-Za-z0-9_.-]+$',
                                  ).hasMatch(value)) {
                                    return 'Letters, numbers, _ . - only';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure,
                                autocorrect: false,
                                enableSuggestions: false,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(
                                    Iconsax.lock,
                                    size: 18,
                                  ),
                                  suffixIcon: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Generate',
                                        onPressed: _generatePassword,
                                        icon: const Icon(
                                          Iconsax.refresh,
                                          size: 17,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(
                                          () => _obscure = !_obscure,
                                        ),
                                        icon: Icon(
                                          _obscure
                                              ? Iconsax.eye_slash
                                              : Iconsax.eye,
                                          size: 17,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                validator: (v) => (v ?? '').length < 6
                                    ? 'At least 6 characters'
                                    : null,
                              ),
                              const SizedBox(height: 22),
                              const AppSectionHeader(title: 'Choose plan'),
                              const SizedBox(height: 10),
                              _PlanPicker(
                                plans: _plans,
                                selected: _plan,
                                onChanged: (p) => setState(() => _plan = p),
                              ),
                              const SizedBox(height: 22),
                              const AppSectionHeader(title: 'Duration'),
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
                              if (_businessPlans.isNotEmpty) ...[
                                const SizedBox(height: 22),
                                _BusinessSection(
                                  plans: _businessPlans,
                                  selected: _businessPlan,
                                  enabled: _enableBusiness,
                                  onToggle: (v) =>
                                      setState(() => _enableBusiness = v),
                                  onChanged: (p) =>
                                      setState(() => _businessPlan = p),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    _CostBar(
                      totalCost: _totalCost,
                      monthlyRate: _chargePrice,
                      isBusiness: _enableBusiness,
                      canAfford: _canAfford,
                      busy: _busy,
                      onCreate: _create,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// ── Pieces ────────────────────────────────────────────────────────────────

class _BalanceRow extends StatelessWidget {
  final int? balance;

  const _BalanceRow({required this.balance});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      // Ink, like the dashboard's balance card: the same number in the same
      // treatment wherever it appears.
      tone: SurfaceTone.ink,
      texture: CardTexture.rings,
      showShadow: false,
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          const AppIconBadge(
            icon: Iconsax.wallet_2,
            // White plate on the ink card: inkSurface is barely lighter than
            // the card itself, so the badge read as a smudge rather than a
            // deliberate mark.
            color: AppColors.accentInk,
            background: AppColors.surface,
            size: 16,
            padding: 8,
          ),
          const SizedBox(width: 10),
          Text(
            'Your balance',
            style: t.bodyMedium?.copyWith(
              color: AppColors.textOnInk.withValues(alpha: 0.75),
            ),
          ),
          const Spacer(),
          Text(
            balance == null ? '—' : NumberFormat('#,##0').format(balance),
            style: t.titleMedium?.copyWith(color: AppColors.textOnInk),
          ),
        ],
      ),
    );
  }
}

/// Brand colour per plan.
///
/// Keyed on the plan name rather than an id, because ids differ between the
/// agent's own list and the business list, and the names are the stable thing
/// an agent recognises. Falls back to the brand green for anything new.
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

class _PlanPicker extends StatelessWidget {
  final List<Plan> plans;
  final Plan? selected;
  final ValueChanged<Plan> onChanged;

  const _PlanPicker({
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

    // Three across. IntrinsicHeight rather than a Wrap: a Wrap gives each tile
    // its own height, so a two-line plan name left the tiles beside it visibly
    // short and the prices on three different lines.
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
              // A filled white disc when chosen: on a saturated tile a tinted
              // radio outline is nearly invisible.
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

/// Number field with plus/minus, for a duration.
///
/// Typable as well as steppable: setting twelve months by tapping plus twelve
/// times is absurd, and the previous free TextField had the opposite problem —
/// it accepted "999" and was parsed and validated on every frame.
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
    // Select the whole value on focus, so typing replaces it rather than
    // appending to it — "1" then "2" should mean 2, not 12.
    _focus.addListener(() {
      if (_focus.hasFocus) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else {
        // Leaving the field empty or over the cap resolves to something valid
        // rather than staying in a broken state.
        _commit(_controller.text, settle: true);
      }
    });
  }

  @override
  void didUpdateWidget(_Stepper old) {
    super.didUpdateWidget(old);
    // Only push the parent's value back into the field when the field is not
    // being edited; doing it mid-typing would fight the caret.
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

class _BusinessSection extends StatelessWidget {
  final List<BusinessPlan> plans;
  final BusinessPlan? selected;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<BusinessPlan> onChanged;

  const _BusinessSection({
    required this.plans,
    required this.selected,
    required this.enabled,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.all(14),
      tone: enabled ? SurfaceTone.wash : SurfaceTone.plain,
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
                background: enabled ? AppColors.surface : AppColors.orangeWash,
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
                      'Dedicated servers, charged monthly',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              Switch(
                value: enabled,
                onChanged: onToggle,
                activeThumbColor: AppColors.surface,
                activeTrackColor: AppColors.orange,
              ),
            ],
          ),
          // Options appear only once the toggle is on: listing them while it
          // is off invites picking one and assuming it applied.
          if (enabled) ...[
            const SizedBox(height: 12),
            for (final plan in plans) ...[
              InkWell(
                onTap: () => onChanged(plan),
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
            ],
          ],
        ],
      ),
    );
  }
}

/// Cost summary and the create button, pinned to the bottom.
///
/// Docked rather than floated over the form: the old bar hid itself whenever
/// the keyboard opened, so the price disappeared exactly while the agent was
/// entering the values that determined it.
class _CostBar extends StatelessWidget {
  final int totalCost;
  final int monthlyRate;
  final bool isBusiness;
  final bool canAfford;
  final bool busy;
  final VoidCallback onCreate;

  const _CostBar({
    required this.totalCost,
    required this.monthlyRate,
    required this.isBusiness,
    required this.canAfford,
    required this.busy,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');

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
                  Row(
                    children: [
                      Text(
                        isBusiness ? 'Business total' : 'Total',
                        style: t.bodySmall,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${money.format(monthlyRate)}/mo',
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    money.format(totalCost),
                    style: t.headlineMedium?.copyWith(
                      fontSize: 22,
                      color: canAfford
                          ? AppColors.textPrimary
                          : AppColors.danger,
                    ),
                  ),
                  if (!canAfford)
                    Text(
                      'Over your balance',
                      style: t.bodySmall?.copyWith(color: AppColors.danger),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: busy || !canAfford ? null : onCreate,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnAccent,
                      ),
                    )
                  : const Text('Create user'),
            ),
          ],
        ),
      ),
    );
  }
}
