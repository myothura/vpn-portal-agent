import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/agent_management/models/agent_model.dart';
import 'package:vpn_agent_app/features/agent_management/services/agent_management_service.dart';
import 'package:vpn_agent_app/features/profile/services/profile_service.dart';

class CreateEditAgentScreen extends StatefulWidget {
  final AgentModel? agent;

  const CreateEditAgentScreen({super.key, this.agent});

  @override
  State<CreateEditAgentScreen> createState() => _CreateEditAgentScreenState();
}

class _CreateEditAgentScreenState extends State<CreateEditAgentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _service = AgentManagementService();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _credit = TextEditingController();
  final _addCredit = TextEditingController();
  final _bonus = TextEditingController(text: '0');

  bool _active = true;
  bool _canSendNoti = false;
  bool _canAccessChat = false;
  bool _canManageAgents = false;

  bool _isAdmin = false;
  bool _saving = false;
  bool _obscure = true;

  List<dynamic> _plans = [];
  List<int> _selectedPlanIds = [];
  bool _loadingPlans = true;

  bool get _isEdit => widget.agent != null;

  @override
  void initState() {
    super.initState();
    _loadPlans();
    _loadAdminStatus();

    final agent = widget.agent;
    if (agent != null) {
      _name.text = agent.name;
      _email.text = agent.email;
      _active = agent.status == 'active';
      _canSendNoti = agent.canSendNotifications;
      _canAccessChat = agent.canAccessChat;
      _canManageAgents = agent.canManageAgents;
      _bonus.text = agent.topupBonusPercent.toStringAsFixed(0);
      _selectedPlanIds = List.from(agent.planIds);
    }

    for (final c in [_name, _email, _password, _credit, _addCredit, _bonus]) {
      c.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _credit, _addCredit, _bonus]) {
      c.removeListener(_onChanged);
      c.dispose();
    }
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadAdminStatus() async {
    try {
      final profile = await ProfileService().getProfile();
      if (profile != null && mounted) {
        setState(() => _isAdmin = profile['id'] == 16);
      }
    } catch (_) {}
  }

  Future<void> _loadPlans() async {
    final plans = await _service.getPlans();
    if (!mounted) return;
    setState(() {
      _plans = plans;
      _loadingPlans = false;
    });
  }

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedPlanIds.isEmpty) {
      _toast('Choose at least one plan for this agent to sell.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _saving = true);

    final data = <String, dynamic>{
      'name': _name.text.trim(),
      'status': _active ? 'active' : 'inactive',
      'plans': _selectedPlanIds,
    };

    if (_isAdmin) {
      data['can_send_notifications'] = _canSendNoti;
      data['can_access_chat'] = _canAccessChat;
      // The third permission. The endpoint has always accepted it on update
      // and now on create; the app simply never sent it, so an agent's
      // authority to create sub-agents could only be granted from the web.
      data['can_manage_agents'] = _canManageAgents;
      data['topup_bonus_percent'] = double.tryParse(_bonus.text.trim()) ?? 0;
    }

    bool success;
    if (_isEdit) {
      if (_password.text.isNotEmpty) data['password'] = _password.text.trim();
      final add = int.tryParse(_addCredit.text.trim()) ?? 0;
      if (add > 0) data['add_credit'] = add;
      success = await _service.updateAgent(widget.agent!.id, data);
    } else {
      data['email'] = _email.text.trim();
      data['password'] = _password.text.trim();
      data['credit_balance'] = int.tryParse(_credit.text.trim()) ?? 0;
      success = await _service.createAgent(data);
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (!success) {
      _toast(
        _isEdit
            ? 'Could not save the changes.'
            : 'Could not create the agent. The email may already be in use.',
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(
      SnackBar(content: Text(_isEdit ? 'Agent updated.' : 'Agent created.')),
    );
  }

  void _toast(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_isEdit ? widget.agent!.name : 'New agent')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Stack(
          children: [
            const _HeroBackdrop(),
            Column(
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
                          // Bonus first: the credit field below shows what a
                          // cash figure becomes after it, so setting it later
                          // meant entering an amount, scrolling down, and
                          // scrolling back to see the result change.
                          if (_isAdmin) ...[
                            const AppSectionHeader(title: 'Top-up bonus'),
                            const SizedBox(height: 4),
                            Text(
                              'Extra credit on top of cash they pay in. Feeds the '
                              'profit and loss report.',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            const SizedBox(height: 10),
                            _BonusField(controller: _bonus),
                            const SizedBox(height: 22),
                          ],
                          const AppSectionHeader(title: 'Account'),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _name,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Name',
                              prefixIcon: Icon(Iconsax.user, size: 18),
                            ),
                            validator: (v) => (v ?? '').trim().isEmpty
                                ? 'Enter a name'
                                : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            // The email is the login and the server treats it as
                            // unique; changing it would move the account rather
                            // than edit it.
                            enabled: !_isEdit,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              helperText: _isEdit ? 'Cannot be changed' : null,
                              prefixIcon: const Icon(Iconsax.sms, size: 18),
                            ),
                            validator: (v) {
                              if (_isEdit) return null;
                              final value = (v ?? '').trim();
                              if (value.isEmpty) return 'Enter an email';
                              if (!RegExp(
                                r'^[^@\s]+@[^@\s]+\.[^@\s]+',
                              ).hasMatch(value)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            obscureText: _obscure,
                            autocorrect: false,
                            enableSuggestions: false,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              hintText: _isEdit
                                  ? 'Leave blank to keep current'
                                  : null,
                              prefixIcon: const Icon(Iconsax.lock, size: 18),
                              suffixIcon: IconButton(
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                                icon: Icon(
                                  _obscure ? Iconsax.eye_slash : Iconsax.eye,
                                  size: 17,
                                ),
                              ),
                            ),
                            validator: (v) {
                              final value = v ?? '';
                              if (_isEdit && value.isEmpty) return null;
                              return value.length < 6
                                  ? 'At least 6 characters'
                                  : null;
                            },
                          ),
                          const SizedBox(height: 12),
                          _StatusToggle(
                            active: _active,
                            onChanged: (v) => setState(() => _active = v),
                          ),
                          const SizedBox(height: 22),
                          _CreditSection(
                            isEdit: _isEdit,
                            currentBalance: widget.agent?.creditBalance,
                            initialController: _credit,
                            addController: _addCredit,
                            bonusPercent:
                                double.tryParse(_bonus.text.trim()) ?? 0,
                          ),
                          const SizedBox(height: 22),
                          const AppSectionHeader(title: 'Plans they can sell'),
                          const SizedBox(height: 4),
                          Text(
                            'The agent can only create users on these plans.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          if (_loadingPlans)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: AppLoader(compact: true),
                            )
                          else
                            _PlanPicker(
                              plans: _plans,
                              selected: _selectedPlanIds,
                              onToggle: (id) => setState(() {
                                _selectedPlanIds.contains(id)
                                    ? _selectedPlanIds.remove(id)
                                    : _selectedPlanIds.add(id);
                              }),
                            ),
                          if (_isAdmin) ...[
                            const SizedBox(height: 22),
                            const AppSectionHeader(title: 'Permissions'),
                            const SizedBox(height: 10),
                            _PermissionTile(
                              icon: Iconsax.message_text,
                              color: AppColors.info,
                              title: 'Support chat',
                              subtitle:
                                  'Read and reply to their users\' messages',
                              value: _canAccessChat,
                              onChanged: (v) =>
                                  setState(() => _canAccessChat = v),
                            ),
                            const SizedBox(height: 8),
                            _PermissionTile(
                              icon: Iconsax.send_2,
                              color: AppColors.violet,
                              title: 'Send notifications',
                              subtitle: 'Push messages to their own users',
                              value: _canSendNoti,
                              onChanged: (v) =>
                                  setState(() => _canSendNoti = v),
                            ),
                            const SizedBox(height: 8),
                            _PermissionTile(
                              icon: Iconsax.user_octagon,
                              color: AppColors.orange,
                              title: 'Manage sub-agents',
                              subtitle: 'Create and edit agents beneath them',
                              value: _canManageAgents,
                              onChanged: (v) =>
                                  setState(() => _canManageAgents = v),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                _SaveBar(
                  isEdit: _isEdit,
                  busy: _saving,
                  planCount: _selectedPlanIds.length,
                  permissionCount: [
                    _canAccessChat,
                    _canSendNoti,
                    _canManageAgents,
                  ].where((granted) => granted).length,
                  onSave: _submit,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Same backdrop as the user forms, anchored to the top and faded out so the
/// fields scroll over it. Reused rather than given its own artwork: an agent
/// form and a user form are the same kind of screen, and a second illustration
/// would be a second thing to keep in step.
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

// ── Status ────────────────────────────────────────────────────────────────

class _StatusToggle extends StatelessWidget {
  final bool active;
  final ValueChanged<bool> onChanged;

  const _StatusToggle({required this.active, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      radius: AppTheme.radiusMd,
      showShadow: false,
      padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
      tone: active ? SurfaceTone.plain : SurfaceTone.wash,
      washColor: AppColors.neutralWash,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  active ? 'Active' : 'Paused',
                  style: t.bodyLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  active
                      ? 'Can sign in and sell'
                      : 'Cannot sign in; their users keep working',
                  style: t.bodySmall,
                ),
              ],
            ),
          ),
          Switch(value: active, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Credit ────────────────────────────────────────────────────────────────

class _CreditSection extends StatelessWidget {
  final bool isEdit;
  final int? currentBalance;
  final TextEditingController initialController;
  final TextEditingController addController;
  final double bonusPercent;

  const _CreditSection({
    required this.isEdit,
    required this.currentBalance,
    required this.initialController,
    required this.addController,
    required this.bonusPercent,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final money = NumberFormat('#,##0');

    final field = isEdit ? addController : initialController;
    final entered = int.tryParse(field.text.trim()) ?? 0;
    final granted = (entered * (1 + bonusPercent / 100)).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(title: isEdit ? 'Add credit' : 'Starting credit'),
        const SizedBox(height: 4),
        Text(
          isEdit
              ? 'Taken from your balance and added to theirs.'
              : 'Taken from your balance when the agent is created.',
          style: t.bodySmall,
        ),
        if (isEdit && currentBalance != null) ...[
          const SizedBox(height: 8),
          Text(
            'They currently hold ${money.format(currentBalance)}.',
            style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 10),
        TextFormField(
          controller: field,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: isEdit ? 'Cash received' : 'Cash received',
            prefixIcon: const Icon(Iconsax.wallet_2, size: 18),
            // The bonus is applied server-side, so the number typed is not
            // the number granted. Showing the result avoids an agent
            // discovering the difference after the fact.
            suffixText: entered > 0 && bonusPercent > 0
                ? '→ ${money.format(granted)}'
                : null,
            suffixStyle: t.bodyMedium?.copyWith(
              color: AppColors.accentInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _BonusField extends StatelessWidget {
  final TextEditingController controller;

  const _BonusField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: const InputDecoration(
        labelText: 'Bonus',
        suffixText: '%',
        prefixIcon: Icon(Iconsax.gift, size: 18),
      ),
      validator: (v) {
        final value = int.tryParse((v ?? '').trim());
        if (value == null) return null;
        // Matches the server's rule rather than guessing at one; anything
        // outside it is refused there anyway.
        return value > 100 ? 'Between 0 and 100' : null;
      },
    );
  }
}

// ── Plans ─────────────────────────────────────────────────────────────────

/// Brand colour per plan, matching the new-user screen so the same plan is
/// the same colour wherever it appears.
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
  final List<dynamic> plans;
  final List<int> selected;
  final ValueChanged<int> onToggle;

  const _PlanPicker({
    required this.plans,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return Text(
        'No plans available',
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    // Three across, as on the new-user form. IntrinsicHeight rather than a
    // Wrap: a Wrap sizes each tile to its own content, so a two-line plan name
    // leaves its neighbours short and the prices on different lines.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < plans.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: _PlanTile(
                name: (plans[i]['plan_name'] ?? 'Plan').toString(),
                price: NumberFormat(
                  '#,##0',
                ).format(plans[i]['price_per_month_credits'] ?? 0),
                selected: selected.contains(plans[i]['id']),
                onTap: () => onToggle(plans[i]['id'] as int),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanTile extends StatelessWidget {
  final String name;
  final String price;
  final bool selected;
  final VoidCallback onTap;

  const _PlanTile({
    required this.name,
    required this.price,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final palette = _PlanPalette.of(name);

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
              // Round, matching the plan tiles on the user forms. The square
              // was meant to signal "choose several", but the two screens
              // sitting side by side with different marks for the same tile
              // reads as inconsistency rather than a distinction.
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
                name,
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
                '$price/mo',
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

// ── Permissions ───────────────────────────────────────────────────────────

class _PermissionTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PermissionTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      onTap: () => onChanged(!value),
      radius: AppTheme.radiusMd,
      showShadow: false,
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 6),
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            color: value ? color : AppColors.textTertiary,
            background: value
                ? color.withValues(alpha: 0.12)
                : AppColors.surfaceAlt,
            size: 15,
            padding: 8,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: t.bodyLarge?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                // Each says what the agent gains, not what the flag is
                // called: "can_manage_agents" means nothing to whoever is
                // granting it.
                Text(subtitle, style: t.bodySmall),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ── Save bar ──────────────────────────────────────────────────────────────

class _SaveBar extends StatelessWidget {
  final bool isEdit;
  final bool busy;
  final int planCount;
  final int permissionCount;
  final VoidCallback onSave;

  const _SaveBar({
    required this.isEdit,
    required this.busy,
    required this.planCount,
    required this.permissionCount,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // width: infinity so the fill reaches both edges — the bar was only as
    // wide as the button inside it, leaving page background either side of a
    // floating white block.
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      // Padding inside SafeArea, so the white runs to the bottom of the
      // screen rather than stopping above the home indicator.
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            // What is about to be saved, so a bar spanning the screen is not
            // just a button with empty space beside it.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    planCount == 0
                        ? 'No plans chosen'
                        : '$planCount plan${planCount == 1 ? '' : 's'}',
                    style: t.bodyLarge?.copyWith(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: planCount == 0
                          ? AppColors.danger
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    permissionCount == 0
                        ? 'No permissions'
                        : '$permissionCount permission'
                              '${permissionCount == 1 ? '' : 's'}',
                    style: t.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: busy ? null : onSave,
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnAccent,
                      ),
                    )
                  : Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}
