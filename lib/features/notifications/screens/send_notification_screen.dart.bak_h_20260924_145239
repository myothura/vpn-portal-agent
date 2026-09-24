import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/notifications/services/notification_list_service.dart';
import 'package:vpn_agent_app/features/users/models/vpn_user_model.dart';
import 'package:vpn_agent_app/features/users/services/user_management_service.dart';

class SendNotificationScreen extends StatefulWidget {
  const SendNotificationScreen({super.key});

  @override
  State<SendNotificationScreen> createState() => _SendNotificationScreenState();
}

class _SendNotificationScreenState extends State<SendNotificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _searchController = TextEditingController();

  final _service = NotificationListService();
  final _userService = UserManagementService();

  bool _broadcast = false;
  bool _sending = false;

  VpnUser? _recipient;
  List<VpnUser> _results = [];
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    // Rebuilds the preview and the send button's enabled state as the message
    // is typed.
    _titleController.addListener(_onChanged);
    _bodyController.addListener(_onChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.removeListener(_onChanged);
    _bodyController.removeListener(_onChanged);
    _titleController.dispose();
    _bodyController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  // ── Recipient ───────────────────────────────────────────────────────────

  void _onSearchChanged(String query) {
    _debounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      final response = await _userService.getVpnUsers(
        page: 1,
        search: query.trim(),
      );
      if (!mounted) return;
      setState(() {
        _results = response?.users ?? [];
        _searching = false;
      });
    });
  }

  void _selectUser(VpnUser user) {
    HapticFeedback.selectionClick();
    FocusScope.of(context).unfocus();
    setState(() {
      _recipient = user;
      _results = [];
      _searchController.clear();
    });
  }

  void _clearRecipient() {
    setState(() {
      _recipient = null;
      _results = [];
      _searchController.clear();
    });
  }

  // ── Send ────────────────────────────────────────────────────────────────

  bool get _canSend =>
      _titleController.text.trim().isNotEmpty &&
      _bodyController.text.trim().isNotEmpty &&
      (_broadcast || _recipient != null);

  Future<void> _send() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_broadcast && _recipient == null) return;

    // A broadcast cannot be recalled and lands on every one of the agent's
    // users at once, so it is confirmed. A single send is not.
    if (_broadcast) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: const AppIconBadge(
            icon: Iconsax.send_2,
            color: AppColors.warning,
            background: AppColors.warningWash,
            size: 22,
            padding: 12,
          ),
          title: const Text('Send to everyone?'),
          content: Text(
            'This goes to all of your users as a push notification. It cannot '
            'be recalled.',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Send to all'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }

    // ANALYZER_CLEAN_V1 — the confirm dialog was awaited above.
    if (!mounted) return;
    FocusScope.of(context).unfocus();
    HapticFeedback.mediumImpact();
    setState(() => _sending = true);

    final success = await _service.sendNotificationToUser(
      userId: _broadcast ? 'all' : _recipient!.id.toString(),
      title: _titleController.text.trim(),
      body: _bodyController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _sending = false);

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not send the notification.')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop(true);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _broadcast
              ? 'Sent to all your users.'
              : 'Sent to ${_recipient!.username}.',
        ),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Send notification')),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
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
                      const AppSectionHeader(title: 'Who receives this'),
                      const SizedBox(height: 10),
                      _AudienceToggle(
                        broadcast: _broadcast,
                        // The recipient is kept when switching to broadcast
                        // and back — discarding it meant an agent comparing
                        // the two options had to search for the same user
                        // again.
                        onChanged: (v) => setState(() => _broadcast = v),
                      ),
                      if (!_broadcast) ...[
                        const SizedBox(height: 12),
                        _RecipientField(
                          controller: _searchController,
                          recipient: _recipient,
                          results: _results,
                          searching: _searching,
                          onChanged: _onSearchChanged,
                          onSelect: _selectUser,
                          onClear: _clearRecipient,
                        ),
                      ],
                      const SizedBox(height: 22),
                      const AppSectionHeader(title: 'Message'),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _titleController,
                        textInputAction: TextInputAction.next,
                        maxLength: 65,
                        // 65 is roughly where Android and iOS truncate a
                        // notification title; past it the tail is written but
                        // never read.
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => currentLength < 50
                            ? null
                            : Text(
                                '$currentLength / $maxLength',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 10),
                              ),
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Enter a title' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _bodyController,
                        maxLines: 4,
                        maxLength: 240,
                        buildCounter:
                            (
                              _, {
                              required currentLength,
                              required isFocused,
                              maxLength,
                            }) => currentLength < 180
                            ? null
                            : Text(
                                '$currentLength / $maxLength',
                                style: Theme.of(
                                  context,
                                ).textTheme.bodySmall?.copyWith(fontSize: 10),
                              ),
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          alignLabelWithHint: true,
                        ),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Enter a message' : null,
                      ),
                      const SizedBox(height: 22),
                      const AppSectionHeader(title: 'Preview'),
                      const SizedBox(height: 10),
                      _Preview(
                        title: _titleController.text.trim(),
                        body: _bodyController.text.trim(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _SendBar(
              broadcast: _broadcast,
              recipient: _recipient?.username,
              enabled: _canSend,
              busy: _sending,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Audience ──────────────────────────────────────────────────────────────

class _AudienceToggle extends StatelessWidget {
  final bool broadcast;
  final ValueChanged<bool> onChanged;

  const _AudienceToggle({required this.broadcast, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AudienceOption(
            icon: Iconsax.user,
            label: 'One user',
            selected: !broadcast,
            color: AppColors.accentInk,
            onTap: () => onChanged(false),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _AudienceOption(
            icon: Iconsax.profile_2user,
            label: 'All my users',
            selected: broadcast,
            // Amber, not brand green: this option reaches everyone at once and
            // should not look like the safe default.
            color: AppColors.warning,
            onTap: () => onChanged(true),
          ),
        ),
      ],
    );
  }
}

class _AudienceOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _AudienceOption({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.surface,
      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            border: Border.all(color: selected ? color : AppColors.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: selected
                    ? AppColors.textOnAccent
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: selected
                        ? AppColors.textOnAccent
                        : AppColors.textSecondary,
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

class _RecipientField extends StatelessWidget {
  final TextEditingController controller;
  final VpnUser? recipient;
  final List<VpnUser> results;
  final bool searching;
  final ValueChanged<String> onChanged;
  final ValueChanged<VpnUser> onSelect;
  final VoidCallback onClear;

  const _RecipientField({
    required this.controller,
    required this.recipient,
    required this.results,
    required this.searching,
    required this.onChanged,
    required this.onSelect,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // Once chosen, the field is replaced by the choice. Leaving a search box
    // with the name typed into it left it ambiguous whether the send was
    // aimed at that user or at whatever was in the box.
    if (recipient != null) {
      return AppCard(
        radius: AppTheme.radiusMd,
        showShadow: false,
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        tone: SurfaceTone.wash,
        washColor: AppColors.accentWash,
        child: Row(
          children: [
            const AppIconBadge(
              icon: Iconsax.user,
              color: AppColors.accentInk,
              background: AppColors.surface,
              size: 15,
              padding: 8,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                recipient!.username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.bodyLarge?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              onPressed: onClear,
              icon: const Icon(Iconsax.close_circle, size: 18),
              color: AppColors.textTertiary,
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Search by username',
            prefixIcon: const Icon(Iconsax.search_normal_1, size: 18),
            suffixIcon: searching
                ? const Padding(
                    padding: EdgeInsets.all(14),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : null,
          ),
        ),
        if (results.isNotEmpty) ...[
          const SizedBox(height: 8),
          AppCard(
            radius: AppTheme.radiusMd,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // Capped: a search matching hundreds should not turn the form
                // into a user list.
                for (final user in results.take(6))
                  InkWell(
                    onTap: () => onSelect(user),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              user.username,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: t.bodyLarge?.copyWith(fontSize: 14),
                            ),
                          ),
                          if (user.planName != null)
                            Text(user.planName!, style: t.bodySmall),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// ── Preview ───────────────────────────────────────────────────────────────

/// What the notification will look like on the user's phone.
///
/// The agent is writing for a lock screen, not a form: the truncation and the
/// weight are the point, and neither was visible while typing into two plain
/// fields.
class _Preview extends StatelessWidget {
  final String title;
  final String body;

  const _Preview({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final empty = title.isEmpty && body.isEmpty;

    return AppCard(
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.all(12),
      tone: SurfaceTone.wash,
      washColor: AppColors.surfaceAlt,
      showShadow: false,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.ink,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            // A 128px copy: assets/icon/icon.png is the 976KB launcher source
            // and is not declared as an asset anyway, so this preview was
            // always falling back to the placeholder glyph.
            child: Image.asset(
              'assets/images/app_mark.png',
              width: 26,
              height: 26,
              errorBuilder: (_, __, ___) => const Icon(
                Iconsax.notification,
                size: 16,
                color: AppColors.accent,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empty ? 'Title' : (title.isEmpty ? 'Title' : title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyLarge?.copyWith(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: title.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  body.isEmpty ? 'Your message appears here.' : body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(
                    color: body.isEmpty
                        ? AppColors.textTertiary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('now', style: t.bodySmall?.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

// ── Send bar ──────────────────────────────────────────────────────────────

class _SendBar extends StatelessWidget {
  final bool broadcast;
  final String? recipient;
  final bool enabled;
  final bool busy;
  final VoidCallback onSend;

  const _SendBar({
    required this.broadcast,
    required this.recipient,
    required this.enabled,
    required this.busy,
    required this.onSend,
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
                  Text('Sending to', style: t.bodySmall),
                  Text(
                    broadcast
                        ? 'All your users'
                        : (recipient ?? 'No one selected'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: t.bodyLarge?.copyWith(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: broadcast
                          ? AppColors.warning
                          : (recipient == null
                                ? AppColors.textTertiary
                                : AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: enabled && !busy ? onSend : null,
              icon: busy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnAccent,
                      ),
                    )
                  : const Icon(Iconsax.send_1, size: 17),
              label: Text(busy ? 'Sending' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}
