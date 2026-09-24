import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax/iconsax.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:vpn_agent_app/core/services/credential_store.dart';
import 'package:vpn_agent_app/core/theme/app_colors.dart';
import 'package:vpn_agent_app/core/theme/app_theme.dart';
import 'package:vpn_agent_app/l10n/app_localizations.dart';
import 'package:vpn_agent_app/shared_widgets/theme_helpers.dart';

import 'package:vpn_agent_app/features/auth/bloc/agent_login_bloc.dart';
import 'package:vpn_agent_app/features/scaffold/main_scaffold.dart';
import 'package:vpn_agent_app/core/navigation/app_transitions.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AgentLoginBloc(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatefulWidget {
  const _LoginView();

  @override
  State<_LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<_LoginView> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocus = FocusNode();

  /// Validation lives in the form rather than being discovered by the server.
  /// The previous screen let an empty username and password through to a
  /// round-trip that could only come back "invalid credentials".
  final _formKey = GlobalKey<FormState>();

  bool _rememberMe = false;
  String _version = '';

  /// Shown above the form. A snackbar alone slides away after four seconds and
  /// leaves nothing behind, so an agent who looked away has no idea why the
  /// login did not go through.
  String? _error;

  @override
  void initState() {
    super.initState();
    _restoreCredentials();
    _loadVersion();
  }

  Future<void> _restoreCredentials() async {
    // Moves any password left in plain-text SharedPreferences by an older
    // build into the keystore before reading.
    await CredentialStore.migrateLegacyPassword();

    final saved = await CredentialStore.read();
    if (saved == null || !mounted) return;
    setState(() {
      _rememberMe = true;
      _emailController.text = saved.email;
      _passwordController.text = saved.password;
    });
  }

  /// Read from the bundle, not hard-coded. The old screen displayed "v2.0.0"
  /// as a literal, which drifted from the actual build the moment either
  /// changed.
  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = 'v${info.version}');
    } catch (_) {}
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  /// The bloc surfaces `e.toString()` for anything that throws, so a dead
  /// network arrives here as a Dio dump. Left as-is it reads as though the
  /// credentials were wrong, which sends people to reset a password that was
  /// never the problem.
  static String _readableError(String? raw) {
    if (raw == null || raw.isEmpty) return 'Login failed. Please try again.';
    final lower = raw.toLowerCase();
    if (lower.contains('socketexception') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection') ||
        lower.contains('timeout')) {
      return 'Cannot reach the server. Check your connection and try again.';
    }
    return raw;
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _error = null);
    HapticFeedback.lightImpact();
    context.read<AgentLoginBloc>().add(
          AgentLoginSubmitted(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final t = Theme.of(context).textTheme;

    // HERO_CACHE_LOGIN_V1 — login_hero.png is 1170x837, which is 3.7 MB once
    // the engine has decoded it, and it is the first image this app ever
    // draws: nothing has been evicted yet when it lands in the cache.
    //
    // The strip it is drawn into is the scroll view's content width — the
    // screen minus the 24pt gutter on each side — so that is what it is
    // decoded at rather than the size the file happens to be authored at.
    // Rounded up to a multiple of 64 so a rotation or a split-screen resize
    // lands on the same cache key instead of decoding a second copy.
    final media = MediaQuery.of(context);
    final heroPixelWidth =
        ((media.size.width - 48) * media.devicePixelRatio).ceil();
    final heroCacheWidth = heroPixelWidth < 64
        ? 64
        : ((heroPixelWidth + 63) ~/ 64) * 64;

    return BlocListener<AgentLoginBloc, AgentLoginState>(
      listener: (context, state) async {
        if (state.status == AgentLoginStatus.failure) {
          setState(() => _error = _readableError(state.errorMessage));
        } else if (state.status == AgentLoginStatus.success) {
          if (_rememberMe) {
            await CredentialStore.save(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );
          } else {
            // Unticking must actually erase what a previous session stored,
            // not merely stop writing.
            await CredentialStore.clear();
          }
          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              AppTransitions.fadeThrough(const MainScaffold()),
            );
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FadeInUp(
                          slideOffset: 0.08,
                          // HERO_CACHE_LOGIN_IMG — the RepaintBoundary is for
                          // the entrance animation: FadeInUp is a
                          // FadeTransition over a SlideTransition, and without
                          // its own layer the hero is re-rasterised on every
                          // frame of it.
                          child: RepaintBoundary(
                            child: Image.asset(
                              'assets/images/login_hero.png',
                              cacheWidth: heroCacheWidth,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        FadeInUp(
                          delay: const Duration(milliseconds: 60),
                          slideOffset: 0.08,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left-aligned and split by weight rather than
                              // two centred lines of identical size. The
                              // greeting is context; the subject is the line
                              // that should carry.
                              Text(
                                'Welcome back',
                                style: t.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              RichText(
                                text: TextSpan(
                                  style: t.headlineMedium?.copyWith(
                                    height: 1.25,
                                    letterSpacing: -0.3,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Manage your\n'),
                                    TextSpan(
                                      text: 'VPN network',
                                      style: TextStyle(
                                        color: AppColors.accentInk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (_error != null) ...[
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: 14),
                        ],
                        FadeInUp(
                          delay: const Duration(milliseconds: 90),
                          slideOffset: 0.08,
                          child: BlocBuilder<AgentLoginBloc, AgentLoginState>(
                            buildWhen: (a, b) => a.status != b.status,
                            builder: (context, state) => _Field(
                              controller: _emailController,
                              label: l10n?.username ?? 'Username',
                              icon: Iconsax.user,
                              enabled:
                                  state.status != AgentLoginStatus.loading,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [AutofillHints.username],
                              onSubmitted: (_) =>
                                  _passwordFocus.requestFocus(),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter your username'
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FadeInUp(
                          delay: const Duration(milliseconds: 160),
                          slideOffset: 0.08,
                          child: BlocBuilder<AgentLoginBloc, AgentLoginState>(
                            // Also on status: the field must lock while the
                            // request is in flight, not only repaint when the
                            // eye is toggled.
                            buildWhen: (a, b) =>
                                a.isPasswordVisible != b.isPasswordVisible ||
                                a.status != b.status,
                            builder: (context, state) => _Field(
                              controller: _passwordController,
                              focusNode: _passwordFocus,
                              label: l10n?.password ?? 'Password',
                              icon: Iconsax.lock,
                              enabled:
                                  state.status != AgentLoginStatus.loading,
                              obscure: !state.isPasswordVisible,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.password],
                              onSubmitted: (_) => _submit(),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Enter your password'
                                  : null,
                              trailing: IconButton(
                                icon: Icon(
                                  state.isPasswordVisible
                                      ? Iconsax.eye_slash
                                      : Iconsax.eye,
                                  size: 18,
                                  color: AppColors.textTertiary,
                                ),
                                onPressed: () => context
                                    .read<AgentLoginBloc>()
                                    .add(AgentLoginPasswordVisibilityToggled()),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        FadeInUp(
                          delay: const Duration(milliseconds: 220),
                          slideOffset: 0.08,
                          child: _RememberRow(
                            value: _rememberMe,
                            onChanged: (v) => setState(() => _rememberMe = v),
                          ),
                        ),
                        const SizedBox(height: 22),
                        FadeInUp(
                          delay: const Duration(milliseconds: 280),
                          slideOffset: 0.08,
                          child: BlocBuilder<AgentLoginBloc, AgentLoginState>(
                            builder: (context, state) {
                              final busy =
                                  state.status == AgentLoginStatus.loading;
                              return FilledButton(
                                onPressed: busy ? null : _submit,
                                style: FilledButton.styleFrom(
                                  // Disabled-while-busy normally greys out,
                                  // which reads as "broken" rather than
                                  // "working". Hold the brand colour and let
                                  // the spinner carry the state.
                                  disabledBackgroundColor: AppColors.accentInk,
                                  disabledForegroundColor:
                                      AppColors.textOnAccent,
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 180),
                                  child: busy
                                      ? Row(
                                          key: const ValueKey('busy'),
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color:
                                                    AppColors.textOnAccent,
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Text('Signing in',
                                                style: t.labelLarge?.copyWith(
                                                    color: AppColors
                                                        .textOnAccent)),
                                          ],
                                        )
                                      : Text(
                                          l10n?.login ?? 'Log in',
                                          key: const ValueKey('idle'),
                                        ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  _version,
                  style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Labelled input. Uses the theme's InputDecorationTheme, so field styling is
/// defined once rather than restated on every screen.
class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscure;
  final Widget? trailing;
  final FocusNode? focusNode;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final bool enabled;
  final List<String>? autofillHints;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscure = false,
    this.trailing,
    this.focusNode,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.validator,
    this.enabled = true,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      // Nothing on the form accepts input mid-request: editing a username
      // while it is being submitted only creates a mismatch between what is
      // on screen and what was actually sent.
      enabled: enabled,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autocorrect: false,
      enableSuggestions: !obscure,
      autofillHints: autofillHints,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 18, color: AppColors.textTertiary),
        suffixIcon: trailing,
      ),
    );
  }
}

/// Checkbox row. The old control was a hand-built 40x22 toggle that looked
/// like a switch — implying it took effect immediately, when it only decides
/// what happens after a successful login.
class _RememberRow extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _RememberRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Checkbox(
              value: value,
              onChanged: (v) => onChanged(v ?? false),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
            Text('Remember me',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

/// Persistent failure notice. Sits above the form so the fields the agent is
/// about to correct are directly beneath the reason.
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.dangerWash,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Iconsax.info_circle, size: 17, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
