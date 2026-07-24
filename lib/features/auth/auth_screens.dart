import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/auth_providers.dart';
import '../../core/app_config.dart';
import '../../l10n/app_localizations.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  Future<void> _google(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(accountControllerProvider.notifier).signInWithGoogle();
    } on Object catch (error) {
      if (context.mounted) _showAuthError(context, error: error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final account = ref.watch(accountControllerProvider).value;
    final busy = account?.busy ?? false;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(28),
              children: [
                const Icon(Icons.cloud_done_outlined, size: 58),
                const SizedBox(height: 24),
                Text(
                  l10n.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.welcomeBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: busy || !AppConfig.hasSupabase
                      ? null
                      : () => _google(context, ref),
                  icon: const Icon(Icons.account_circle_outlined),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(l10n.continueWithGoogle),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: busy || !AppConfig.hasSupabase
                      ? null
                      : () => context.push('/auth?mode=signup'),
                  icon: const Icon(Icons.mail_outline_rounded),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Text(l10n.continueWithEmail),
                  ),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: busy
                      ? null
                      : () async {
                          await ref
                              .read(accountControllerProvider.notifier)
                              .chooseLocal();
                          if (context.mounted) context.go('/setup');
                        },
                  child: Text(l10n.useLocallyAction),
                ),
                Text(
                  AppConfig.hasSupabase
                      ? l10n.localModeNote
                      : l10n.authConfigurationMissing,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (busy) ...[
                  const SizedBox(height: 20),
                  const LinearProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmailAuthScreen extends ConsumerStatefulWidget {
  const EmailAuthScreen({super.key, this.initialSignUp = false});

  final bool initialSignUp;

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  late bool _signUp = widget.initialSignUp;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      if (_signUp) {
        final confirmation = await ref
            .read(accountControllerProvider.notifier)
            .signUp(_email.text, _password.text);
        if (!mounted) return;
        if (confirmation) {
          context.go('/auth/check-email');
        } else {
          context.go('/today');
        }
      } else {
        await ref
            .read(accountControllerProvider.notifier)
            .signInWithPassword(_email.text, _password.text);
        if (mounted) context.go('/today');
      }
    } on Object catch (error) {
      if (mounted) _showAuthError(context, error: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = ref.watch(accountControllerProvider).value?.busy ?? false;
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Form(
              key: _formKey,
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    _signUp ? l10n.signUpTitle : l10n.signInTitle,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(labelText: l10n.emailLabel),
                    validator: (value) {
                      final text = value?.trim() ?? '';
                      if (text.isEmpty) return l10n.emailRequired;
                      if (!text.contains('@') || !text.contains('.')) {
                        return l10n.invalidEmail;
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    enabled: !busy,
                    obscureText: _obscure,
                    autofillHints: _signUp
                        ? const [AutofillHints.newPassword]
                        : const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: l10n.passwordLabel,
                      helperText: _signUp ? l10n.passwordMinimum : null,
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: (value) =>
                        (value?.length ?? 0) < 8 ? l10n.passwordMinimum : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: busy ? null : _submit,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: busy
                          ? const SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              _signUp ? l10n.signUpAction : l10n.signInAction,
                            ),
                    ),
                  ),
                  if (!_signUp)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => context.push('/auth/forgot-password'),
                      child: Text(l10n.forgotPasswordAction),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(() => _signUp = !_signUp),
                    child: Text(
                      _signUp ? l10n.haveAccountAction : l10n.needAccountAction,
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
}

class CheckEmailScreen extends StatelessWidget {
  const CheckEmailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return _AuthMessageScreen(
      icon: Icons.mark_email_read_outlined,
      title: l10n.checkEmailTitle,
      body: l10n.checkEmailBody,
      action: l10n.backToSignInAction,
      onPressed: () => context.go('/auth'),
    );
  }
}

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(accountControllerProvider.notifier)
          .sendPasswordReset(_email.text);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.resetLinkSent)));
      }
    } on Object catch (error) {
      if (mounted) _showAuthError(context, error: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l10n.resetPasswordTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 8),
              Text(l10n.resetPasswordBody),
              const SizedBox(height: 24),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.emailLabel),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _send,
                child: Text(l10n.sendResetLinkAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class UpdatePasswordScreen extends ConsumerStatefulWidget {
  const UpdatePasswordScreen({super.key});

  @override
  ConsumerState<UpdatePasswordScreen> createState() =>
      _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends ConsumerState<UpdatePasswordScreen> {
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    if (_password.text.length < 8) {
      _showAuthError(context, message: l10n.passwordMinimum);
      return;
    }
    try {
      await ref
          .read(accountControllerProvider.notifier)
          .updatePassword(_password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.passwordUpdated)));
      context.go('/today');
    } on Object catch (error) {
      if (mounted) _showAuthError(context, error: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                l10n.newPasswordTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _password,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: l10n.passwordLabel,
                  helperText: l10n.passwordMinimum,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _save,
                child: Text(l10n.updatePasswordAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  ConsumerState<AuthCallbackScreen> createState() => _AuthCallbackScreenState();
}

class MergeLocalDataScreen extends ConsumerWidget {
  const MergeLocalDataScreen({super.key});

  Future<void> _resolve(
    BuildContext context,
    WidgetRef ref, {
    required bool merge,
  }) async {
    try {
      await ref
          .read(accountControllerProvider.notifier)
          .resolveGuestMerge(merge: merge);
      if (context.mounted) context.go('/today');
    } on Object catch (error) {
      if (context.mounted) _showAuthError(context, error: error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final busy = ref.watch(accountControllerProvider).value?.busy ?? false;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.merge_rounded, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    l10n.mergeLocalTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 10),
                  Text(l10n.mergeLocalBody, textAlign: TextAlign.center),
                  const SizedBox(height: 28),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () => _resolve(context, ref, merge: true),
                    child: Text(l10n.mergeAction),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => _resolve(context, ref, merge: false),
                    child: Text(l10n.keepSeparateAction),
                  ),
                  if (busy) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  Timer? _fallback;

  @override
  void initState() {
    super.initState();
    _fallback = Timer(const Duration(seconds: 8), () {
      if (mounted) context.go('/auth');
    });
  }

  @override
  void dispose() {
    _fallback?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final account = ref.watch(accountControllerProvider).value;
    if (account?.isSignedIn == true) {
      _fallback?.cancel();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/today');
      });
    }
    ref.listen(accountControllerProvider, (previous, next) {
      if (next.value?.isSignedIn == true) {
        _fallback?.cancel();
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) context.go('/today');
        });
      }
    });
    final l10n = AppLocalizations.of(context)!;
    return _AuthMessageScreen(
      icon: Icons.sync_rounded,
      title: l10n.authCallbackTitle,
      body: '',
      progress: true,
    );
  }
}

class _AuthMessageScreen extends StatelessWidget {
  const _AuthMessageScreen({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
    this.onPressed,
    this.progress = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? action;
  final VoidCallback? onPressed;
  final bool progress;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 56),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                if (body.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(body, textAlign: TextAlign.center),
                ],
                if (progress) ...[
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(),
                ],
                if (action != null) ...[
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onPressed, child: Text(action!)),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void _showAuthError(BuildContext context, {String? message, Object? error}) {
  final l10n = AppLocalizations.of(context)!;
  final localized = switch (error) {
    AuthException(code: 'invalid_credentials') => l10n.authInvalidCredentials,
    AuthException(code: 'email_not_confirmed') => l10n.authEmailUnconfirmed,
    AuthException(code: 'user_already_exists') =>
      l10n.authEmailAlreadyRegistered,
    AuthException(code: 'email_exists') => l10n.authEmailAlreadyRegistered,
    AuthException(code: 'over_email_send_rate_limit') => l10n.authRateLimited,
    AuthException(code: 'over_request_rate_limit') => l10n.authRateLimited,
    AuthException(code: 'weak_password') => l10n.authWeakPassword,
    _ => l10n.authGenericError,
  };
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message ?? localized)));
}
