import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';

import 'package:vpn_agent_app/core/navigation/app_transitions.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/core/utils/formatters.dart';
import 'package:vpn_agent_app/shared_widgets/language_picker_widget.dart';
import 'package:vpn_agent_app/shared_widgets/ui/app_surface.dart';

import 'package:vpn_agent_app/features/agent_management/screens/agent_list_screen.dart';
import 'package:vpn_agent_app/features/auth/screens/login_screen.dart';
import 'package:vpn_agent_app/features/auth/services/auth_service.dart';
import 'package:vpn_agent_app/features/history/screens/credit_history_screen.dart';
import 'package:vpn_agent_app/features/notifications/screens/send_notification_screen.dart';
import 'package:vpn_agent_app/features/profile/bloc/profile_bloc.dart';
import 'package:vpn_agent_app/features/profile/models/profile_user_model.dart';
import 'package:vpn_agent_app/features/profile/screens/manage_payment_screen.dart';
import 'package:vpn_agent_app/features/profile/repositories/profile_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ProfileBloc(repository: ProfileRepository())..add(ProfileStarted()),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatefulWidget {
  const _ProfileView();

  @override
  State<_ProfileView> createState() => _ProfileViewState();
}

class _ProfileViewState extends State<_ProfileView> {
  final _authService = AuthService();

  Future<void> _logout() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const AppIconBadge(
          icon: Iconsax.logout,
          color: AppColors.danger,
          background: AppColors.dangerWash,
          size: 22,
          padding: 12,
        ),
        title: const Text('Sign out?'),
        content: Text(
          'You will need your email and password to sign back in.',
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    await _authService.logout();
    if (!mounted) return;
    // rootNavigator: signing out has to replace the whole shell, not the
    // stack inside whichever tab this was opened from.
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _editTelegram(String current) async {
    final controller = TextEditingController(text: current);

    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Telegram username'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shown to your users so they can reach you outside the app.',
              style: Theme.of(ctx).textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              autocorrect: false,
              decoration: const InputDecoration(
                prefixText: '@',
                hintText: 'username',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              // The @ is presentation: stored without it, and pasting a full
              // handle should not save "@@name".
              controller.text.trim().replaceAll(RegExp(r'^@+'), ''),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    // AGENT_APP_F3 — the dialog's route is torn down before this line runs,
    // so the controller that fed its TextField has no listeners left. It was
    // never disposed, which leaked one per edit.
    controller.dispose();

    if (value == null || !mounted) return;
    context.read<ProfileBloc>().add(ProfileTelegramUpdated(value));
  }

  /// Returns whatever the pushed screen popped with. Payment methods pop true
  /// after saving; the count shown here comes from the profile payload and
  /// would otherwise stay stale until the next pull to refresh.
  Future<T?> _open<T>(Widget screen) {
    return Navigator.of(
      context,
      rootNavigator: true,
    ).push<T>(AppTransitions.slide(screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Profile')),
      body: BlocConsumer<ProfileBloc, ProfileState>(
        listenWhen: (prev, next) =>
            prev.successMessage != next.successMessage ||
            prev.errorMessage != next.errorMessage,
        listener: (context, state) {
          final message = state.successMessage ?? state.errorMessage;
          if (message == null) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(message)));
        },
        builder: (context, state) {
          final user = state.user;

          if (user == null) {
            if (state.status == ProfileStatus.failure) {
              return _buildError(context);
            }
            return const AppLoader();
          }

          final updating = state.status == ProfileStatus.updating;

          return RefreshIndicator(
            onRefresh: () async =>
                context.read<ProfileBloc>().add(ProfileRefreshed()),
            color: AppColors.accentInk,
            backgroundColor: AppColors.surface,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              children: [
                // The bloc emits `updating` while a save is in flight and the
                // screen showed nothing for it — a tap on Save looked like it
                // had done nothing until the snackbar arrived.
                if (updating) ...[
                  const LinearProgressIndicator(minHeight: 2),
                  const SizedBox(height: 12),
                ],
                _IdentityCard(
                  user: user,
                  onEditTelegram: () => _editTelegram(user.telegramUsername),
                ),
                const SizedBox(height: 20),
                const AppSectionHeader(title: 'Money'),
                const SizedBox(height: 10),
                _Tile(
                  icon: Iconsax.wallet_2,
                  color: AppColors.accentInk,
                  title: 'Credit history',
                  subtitle: 'Everything spent and received',
                  onTap: () => _open(const CreditHistoryScreen()),
                ),
                const SizedBox(height: 8),
                _Tile(
                  icon: Iconsax.card,
                  // Amber when there are none: an agent without a payment
                  // method cannot be paid, which is a state to fix rather than
                  // a neutral count.
                  color: user.paymentMethods.isEmpty
                      ? AppColors.warning
                      : AppColors.info,
                  title: 'Payment methods',
                  // The count is the point of the row: an agent with none
                  // cannot be paid, and that is worth seeing without opening
                  // the screen.
                  subtitle: user.paymentMethods.isEmpty
                      ? 'None set — users cannot pay you'
                      : '${user.paymentMethods.length} '
                            'method${user.paymentMethods.length == 1 ? '' : 's'}',
                  subtitleColor: user.paymentMethods.isEmpty
                      ? AppColors.danger
                      : null,
                  onTap: () async {
                    final saved = await _open<bool>(
                      ManagePaymentScreen(initialMethods: user.paymentMethods),
                    );
                    if (saved == true && context.mounted) {
                      context.read<ProfileBloc>().add(ProfileRefreshed());
                    }
                  },
                ),
                if (user.canSendNoti || user.canManageAgents) ...[
                  const SizedBox(height: 20),
                  const AppSectionHeader(title: 'Tools'),
                  const SizedBox(height: 10),
                  if (user.canSendNoti)
                    _Tile(
                      icon: Iconsax.send_2,
                      color: AppColors.violet,
                      title: 'Send a notification',
                      subtitle: 'Push a message to your users',
                      onTap: () => _open(const SendNotificationScreen()),
                    ),
                  if (user.canSendNoti && user.canManageAgents)
                    const SizedBox(height: 8),
                  if (user.canManageAgents)
                    _Tile(
                      icon: Iconsax.user_octagon,
                      color: AppColors.orange,
                      title: 'My agents',
                      subtitle: 'Create and manage sub-agents',
                      onTap: () => _open(const AgentListScreen()),
                    ),
                ],
                const SizedBox(height: 20),
                // AGENT_APP_F5 — the only entry point to the language picker.
                // Without it the app shipped three locales with no way to
                // choose between them.
                const AppSectionHeader(title: 'ဆက်တင်'),
                const SizedBox(height: 10),
                _Tile(
                  icon: Icons.language_rounded,
                  color: AppColors.cyan,
                  title: 'ဘာသာစကား',
                  subtitle: 'ဘာသာစကား ရွေးချယ်ပါ',
                  onTap: () => LanguagePickerWidget.show(context),
                ),
                const SizedBox(height: 20),
                const AppSectionHeader(title: 'What you can do'),
                const SizedBox(height: 10),
                _PermissionSummary(user: user),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Iconsax.logout, size: 17),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppEmptyState(
            icon: Iconsax.warning_2,
            title: 'Could not load your profile',
            subtitle: 'Check your connection and try again.',
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () =>
                context.read<ProfileBloc>().add(ProfileRefreshed()),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

// ── Identity ──────────────────────────────────────────────────────────────

class _IdentityCard extends StatelessWidget {
  final ProfileUser user;
  final VoidCallback onEditTelegram;

  const _IdentityCard({required this.user, required this.onEditTelegram});

  @override
  Widget build(BuildContext context) {
    // AGENT_APP_F7 — NumberFormat('#,##0') was constructed here, inside
    // build(), every time this card repainted. Fmt.money is built once.
    final t = Theme.of(context).textTheme;

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
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.inkSurface,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  user.name.isEmpty ? '?' : user.name[0].toUpperCase(),
                  style: t.titleLarge?.copyWith(color: AppColors.accent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleLarge?.copyWith(
                        color: AppColors.textOnInk,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodySmall?.copyWith(
                        color: AppColors.textOnInk.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.textOnInk.withValues(alpha: 0.12)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InkFigure(
                  label: 'Balance',
                  value: Fmt.money.format(user.creditBalance),
                ),
              ),
              Container(
                width: 1,
                height: 30,
                color: AppColors.textOnInk.withValues(alpha: 0.12),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _InkFigure(
                  label: 'Active users',
                  value: '${user.activeUserCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: onEditTelegram,
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  Icon(
                    Iconsax.send_1,
                    size: 14,
                    color: AppColors.textOnInk.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      user.telegramUsername.isEmpty
                          // Not "—": an empty Telegram handle is a thing to
                          // fix, and the row is what fixes it.
                          ? 'Add your Telegram username'
                          : '@${user.telegramUsername}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.bodyMedium?.copyWith(
                        color: user.telegramUsername.isEmpty
                            ? AppColors.accent
                            : AppColors.textOnInk,
                      ),
                    ),
                  ),
                  Icon(
                    Iconsax.edit_2,
                    size: 14,
                    color: AppColors.textOnInk.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InkFigure extends StatelessWidget {
  final String label;
  final String value;

  const _InkFigure({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: t.bodySmall?.copyWith(
            color: AppColors.textOnInk.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: t.titleLarge?.copyWith(color: AppColors.textOnInk),
        ),
      ],
    );
  }
}

// ── Rows ──────────────────────────────────────────────────────────────────

class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  const _Tile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.subtitleColor,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return AppCard(
      onTap: onTap,
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            color: color,
            background: color.withValues(alpha: 0.12),
            size: 16,
            padding: 9,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: t.bodyLarge?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: t.bodySmall?.copyWith(color: subtitleColor),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}

/// The three permissions as they stand, read-only.
///
/// An agent cannot change their own; this is here so they know why a tool is
/// missing rather than assuming the app is broken.
class _PermissionSummary extends StatelessWidget {
  final ProfileUser user;

  const _PermissionSummary({required this.user});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: AppTheme.radiusMd,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        children: [
          _PermissionRow(
            icon: Iconsax.message_text,
            label: 'Support chat',
            granted: user.canAccessChat,
          ),
          _PermissionRow(
            icon: Iconsax.send_2,
            label: 'Send notifications',
            granted: user.canSendNoti,
          ),
          _PermissionRow(
            icon: Iconsax.user_octagon,
            label: 'Manage sub-agents',
            granted: user.canManageAgents,
            last: true,
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool granted;
  final bool last;

  const _PermissionRow({
    required this.icon,
    required this.label,
    required this.granted,
    this.last = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: granted ? AppColors.accentInk : AppColors.textTertiary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: t.bodyMedium?.copyWith(
                    color: granted
                        ? AppColors.textPrimary
                        : AppColors.textTertiary,
                  ),
                ),
              ),
              Icon(
                granted
                    ? Icons.check_circle_rounded
                    : Icons.remove_circle_outline_rounded,
                size: 17,
                color: granted ? AppColors.success : AppColors.borderStrong,
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}
