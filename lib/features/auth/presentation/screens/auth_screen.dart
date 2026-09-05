import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../home/presentation/widgets/scene_widgets.dart';
import '../../data/local_account_store.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.account,
    required this.onCreateAccount,
    required this.onLogin,
    required this.onBiometricLogin,
  });

  final LocalAccount? account;
  final Future<void> Function({
    required String username,
    required String password,
    required AccountMascot mascot,
    required bool enableBiometric,
  }) onCreateAccount;
  final Future<bool> Function({
    required String username,
    required String password,
  }) onLogin;
  final Future<bool> Function() onBiometricLogin;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  AccountMascot _selectedMascot = AccountMascot.panda;
  late bool _isCreatingAccount;
  bool _enableBiometric = true;
  bool _isSubmitting = false;
  bool _hidePassword = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _isCreatingAccount = widget.account == null;
    final account = widget.account;
    if (account != null) {
      _usernameController.text = account.username;
      _selectedMascot = account.mascot;
      _enableBiometric = account.isBiometricEnabled;
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      if (_isCreatingAccount) {
        await widget.onCreateAccount(
          username: _usernameController.text,
          password: _passwordController.text,
          mascot: _selectedMascot,
          enableBiometric: _enableBiometric,
        );
      } else {
        final success = await widget.onLogin(
          username: _usernameController.text,
          password: _passwordController.text,
        );
        if (!success && mounted) {
          setState(() => _message = 'Hindi tugma ang username o password.');
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Hindi na-save sa Supabase: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _useBiometric() async {
    setState(() {
      _isSubmitting = true;
      _message = null;
    });

    try {
      final success = await widget.onBiometricLogin();
      if (!success && mounted) {
        setState(
          () => _message =
              'Hindi na-confirm ang fingerprint. Pwede ka pa rin mag-login gamit username at password.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width <= 520;
    const panelText = Color(0xFFFFF4EA);

    return Scaffold(
      body: Stack(
        children: [
          const _AuthBackdrop(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  compact ? 12 : 24,
                  compact ? 10 : 24,
                  compact ? 12 : 24,
                  (compact ? 10 : 24) + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _AuthHeader(compact: compact),
                      SizedBox(height: compact ? 14 : 18),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF111318),
                              Color(0xFF1B1F26),
                              Color(0xFF252A33),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(
                              0xFFFF8795,
                            ).withValues(alpha: 0.34),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF08090C,
                              ).withValues(alpha: 0.66),
                              blurRadius: 0,
                              offset: const Offset(0, 9),
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFFFF7888,
                              ).withValues(alpha: 0.18),
                              blurRadius: 42,
                              offset: const Offset(0, 18),
                            ),
                            BoxShadow(
                              color: const Color(
                                0xFF000000,
                              ).withValues(alpha: 0.42),
                              blurRadius: 58,
                              offset: const Offset(0, 26),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(compact ? 16 : 22),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _AuthMascotHero(
                                  mascot: _selectedMascot,
                                  isCreatingAccount: _isCreatingAccount,
                                  compact: compact,
                                )
                                    .animate()
                                    .fadeIn(delay: 100.ms)
                                    .slideX(begin: -0.1, end: 0),
                                SizedBox(height: compact ? 12 : 18),
                                _AuthModeSwitch(
                                  isCreatingAccount: _isCreatingAccount,
                                  onChanged: (value) {
                                    setState(() {
                                      _isCreatingAccount = value;
                                      _message = null;
                                    });
                                  },
                                )
                                    .animate()
                                    .fadeIn(delay: 200.ms)
                                    .slideY(begin: 0.1, end: 0),
                                const SizedBox(height: 18),
                                AnimatedSwitcher(
                                  duration: const Duration(
                                    milliseconds: 260,
                                  ),
                                  switchInCurve: Curves.easeOutCubic,
                                  switchOutCurve: Curves.easeInCubic,
                                  transitionBuilder: (child, animation) {
                                    return FadeTransition(
                                      opacity: animation,
                                      child: SlideTransition(
                                        position: Tween<Offset>(
                                          begin: const Offset(0.04, 0),
                                          end: Offset.zero,
                                        ).animate(animation),
                                        child: child,
                                      ),
                                    );
                                  },
                                  child: _SectionTitle(
                                    key: ValueKey(_isCreatingAccount),
                                    icon: _isCreatingAccount
                                        ? Icons.auto_awesome_rounded
                                        : Icons.lock_open_rounded,
                                    title: _isCreatingAccount
                                        ? 'Create your key'
                                        : 'Welcome back',
                                    subtitle: _isCreatingAccount
                                        ? 'Gawa ng secure account bago pumasok sa garden.'
                                        : 'Unlock your saved Panpanskii space.',
                                  ),
                                ),
                                SizedBox(height: compact ? 14 : 20),
                                TextFormField(
                                  controller: _usernameController,
                                  autofillHints: const [AutofillHints.username],
                                  style: const TextStyle(
                                    color: panelText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  textInputAction: TextInputAction.next,
                                  cursorColor: const Color(0xFFFFD45A),
                                  decoration: InputDecoration(
                                    labelText: 'Username',
                                    prefixIcon: const Icon(
                                      Icons.person_rounded,
                                    ),
                                    filled: true,
                                    fillColor: const Color(
                                      0xFF111318,
                                    ).withValues(alpha: 0.86),
                                    labelStyle: const TextStyle(
                                      color: Color(0xFFCFC3E8),
                                      fontWeight: FontWeight.w800,
                                    ),
                                    prefixIconColor: const Color(
                                      0xFFFFD45A,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        14,
                                      ),
                                      borderSide: BorderSide(
                                        color: const Color(
                                          0xFF6E628F,
                                        ).withValues(alpha: 0.8),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        14,
                                      ),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFFFD45A),
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().length < 3) {
                                      return 'At least 3 characters ang username.';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),
                                TextFormField(
                                  controller: _passwordController,
                                  autofillHints: const [AutofillHints.password],
                                  style: const TextStyle(
                                    color: panelText,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  obscureText: _hidePassword,
                                  cursorColor: const Color(0xFFFFD45A),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                      Icons.lock_rounded,
                                    ),
                                    filled: true,
                                    fillColor: const Color(
                                      0xFF111318,
                                    ).withValues(alpha: 0.86),
                                    labelStyle: const TextStyle(
                                      color: Color(0xFFCFC3E8),
                                      fontWeight: FontWeight.w800,
                                    ),
                                    prefixIconColor: const Color(
                                      0xFFFFD45A,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        14,
                                      ),
                                      borderSide: BorderSide(
                                        color: const Color(
                                          0xFF6E628F,
                                        ).withValues(alpha: 0.8),
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                        14,
                                      ),
                                      borderSide: const BorderSide(
                                        color: Color(0xFFFFD45A),
                                        width: 2,
                                      ),
                                    ),
                                    suffixIcon: IconButton(
                                      tooltip: _hidePassword
                                          ? 'Show password'
                                          : 'Hide password',
                                      onPressed: () => setState(
                                        () => _hidePassword = !_hidePassword,
                                      ),
                                      icon: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 180,
                                        ),
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(
                                            scale: animation,
                                            child: child,
                                          );
                                        },
                                        child: Icon(
                                          _hidePassword
                                              ? Icons.visibility_rounded
                                              : Icons.visibility_off_rounded,
                                          key: ValueKey(_hidePassword),
                                          color: const Color(0xFFCFC3E8),
                                        ),
                                      ),
                                    ),
                                  ),
                                  onChanged: (_) {
                                    if (_isCreatingAccount) {
                                      setState(() {});
                                    }
                                  },
                                  onFieldSubmitted: (_) => _submit(),
                                  validator: (value) {
                                    if (value == null || value.length < 6) {
                                      return 'At least 6 characters ang password.';
                                    }
                                    return null;
                                  },
                                ),
                                if (_isCreatingAccount)
                                  _PasswordStrengthIndicator(
                                    password: _passwordController.text,
                                  ),
                                if (!_isCreatingAccount) ...[
                                  const SizedBox(height: 10),
                                  _BiometricInfoTile(
                                    isEnabled:
                                        widget.account?.isBiometricEnabled ??
                                            false,
                                  ),
                                ],
                                if (_isCreatingAccount) ...[
                                  const SizedBox(height: 18),
                                  Text(
                                    'Choose profile',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontSize: 17,
                                      color: panelText,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MascotChoice(
                                          mascot: AccountMascot.panda,
                                          isSelected: _selectedMascot ==
                                              AccountMascot.panda,
                                          onTap: () => setState(
                                            () => _selectedMascot =
                                                AccountMascot.panda,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _MascotChoice(
                                          mascot: AccountMascot.koala,
                                          isSelected: _selectedMascot ==
                                              AccountMascot.koala,
                                          onTap: () => setState(
                                            () => _selectedMascot =
                                                AccountMascot.koala,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _BiometricConsentTile(
                                    value: _enableBiometric,
                                    onChanged: (value) => setState(
                                      () => _enableBiometric = value,
                                    ),
                                  ),
                                ],
                                if (_message != null) ...[
                                  const SizedBox(height: 14),
                                  _InlineMessage(message: _message!),
                                ],
                                const SizedBox(height: 20),
                                FilledButton.icon(
                                  onPressed: _isSubmitting ? null : _submit,
                                  icon: _isSubmitting
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Icon(
                                          _isCreatingAccount
                                              ? Icons.favorite_rounded
                                              : Icons.login_rounded,
                                        ),
                                  label: Text(
                                    _isCreatingAccount
                                        ? 'Create account'
                                        : 'Log in',
                                  ),
                                ),
                                if (!_isCreatingAccount &&
                                    widget.account != null &&
                                    widget.account!.isBiometricEnabled) ...[
                                  const SizedBox(height: 10),
                                  OutlinedButton.icon(
                                    onPressed:
                                        _isSubmitting ? null : _useBiometric,
                                    icon: const Icon(
                                      Icons.fingerprint_rounded,
                                    ),
                                    label: const Text('Use fingerprint'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(duration: 380.ms, curve: Curves.easeOutCubic)
                          .slideY(
                            begin: 0.035,
                            end: 0,
                            duration: 380.ms,
                            curve: Curves.easeOutCubic,
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return const _AnimatedAuthBackdrop();
  }
}

class _AnimatedAuthBackdrop extends StatefulWidget {
  const _AnimatedAuthBackdrop();

  @override
  State<_AnimatedAuthBackdrop> createState() => _AnimatedAuthBackdropState();
}

class _AnimatedAuthBackdropState extends State<_AnimatedAuthBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 14),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF111318),
            Color(0xFF1B1F26),
            Color(0xFF252A33),
            Color(0xFF111318),
          ],
        ),
      ),
      child: AnimatedBuilder(
        animation: _controller,
        child: const SizedBox.expand(),
        builder: (context, child) {
          final value = Curves.easeInOut.transform(_controller.value);
          return Stack(
            children: [
              child!,
              Positioned(
                left: -110 + (value * 32),
                top: 80 - (value * 18),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.08 + (value * 0.04),
                    child: const _AuthGlow(
                      size: 300,
                      color: Color(0xFFFFD45A),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -130 - (value * 24),
                bottom: 40 + (value * 20),
                child: IgnorePointer(
                  child: Opacity(
                    opacity: 0.08 + ((1 - value) * 0.04),
                    child: const _AuthGlow(
                      size: 340,
                      color: Color(0xFFFF7A9A),
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
}

class _AuthGlow extends StatelessWidget {
  const _AuthGlow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: SizedBox.square(dimension: size),
    );
  }
}

class _AuthMascotHero extends StatelessWidget {
  const _AuthMascotHero({
    required this.mascot,
    required this.isCreatingAccount,
    required this.compact,
  });

  final AccountMascot mascot;
  final bool isCreatingAccount;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isPanda = mascot == AccountMascot.panda;
    final accent = isPanda ? const Color(0xFFFFD45A) : const Color(0xFF9BE0BC);

    return Row(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.16),
                blurRadius: 22,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            transitionBuilder: (child, animation) {
              return ScaleTransition(scale: animation, child: child);
            },
            child: _MascotAvatar(
              key: ValueKey(mascot),
              mascot: mascot,
              size: compact ? 60 : 78,
              isCreatingAccount: isCreatingAccount,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  isCreatingAccount ? 'Make it yours' : 'Your space is waiting',
                  key: ValueKey(isCreatingAccount),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: const Color(0xFFFFF4EA),
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isPanda ? 'Panda mode selected' : 'Koala mode selected',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFFCFC3E8),
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 300.ms).slideX(begin: -0.025, end: 0);
  }
}

class _AuthHeader extends StatelessWidget {
  const _AuthHeader({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFD45A).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: const Color(0xFFFFD45A).withValues(alpha: 0.42),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Text(
              'PANPANSKII SECURE SPACE',
              style: TextStyle(
                color: Color(0xFFFFE6A6),
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Panpanskii lockscreen',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontSize: compact ? 29 : 38,
            height: 1.04,
            color: const Color(0xFFFFF4EA),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create or unlock your cozy private space.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFCFC3E8),
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _AuthModeSwitch extends StatelessWidget {
  const _AuthModeSwitch({
    required this.isCreatingAccount,
    required this.onChanged,
  });

  final bool isCreatingAccount;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111318).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6E628F).withValues(alpha: 0.72),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            Expanded(
              child: _ModeButton(
                label: 'Create',
                icon: Icons.person_add_alt_1_rounded,
                isSelected: isCreatingAccount,
                onTap: () => onChanged(true),
              ),
            ),
            Expanded(
              child: _ModeButton(
                label: 'Log in',
                icon: Icons.login_rounded,
                isSelected: !isCreatingAccount,
                onTap: () => onChanged(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFFF7A9A) : Colors.transparent,
        borderRadius: BorderRadius.circular(11),
        boxShadow: isSelected
            ? [
                BoxShadow(
                  color: const Color(0xFFFF7A9A).withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected ? Colors.white : const Color(0xFFCFC3E8),
                ),
                const SizedBox(width: 7),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : const Color(0xFFEFE6FF),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFD45A).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFFFFD45A).withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: const Color(0xFFFFD45A)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFFFFF4EA),
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFFCFC3E8),
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BiometricConsentTile extends StatelessWidget {
  const _BiometricConsentTile({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF111318).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFF6E628F).withValues(alpha: 0.72),
        ),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.only(left: 14, right: 10),
        value: value,
        onChanged: onChanged,
        secondary: const Icon(
          Icons.fingerprint_rounded,
          color: Color(0xFFFFD45A),
        ),
        title: const Text(
          'Fingerprint unlock',
          style: TextStyle(
            color: Color(0xFFFFF4EA),
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: const Text(
          'Your phone will ask permission after account creation.',
          style: TextStyle(color: Color(0xFFCFC3E8)),
        ),
      ),
    );
  }
}

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) {
      return const SizedBox.shrink();
    }

    var score = 0;
    if (password.length >= 8) score += 1;
    if (RegExp(r'[A-Z]').hasMatch(password)) score += 1;
    if (RegExp(r'[0-9]').hasMatch(password)) score += 1;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score += 1;

    final label = score <= 1
        ? 'Weak password'
        : score <= 2
            ? 'Getting stronger'
            : score == 3
                ? 'Good password'
                : 'Strong password';
    final color = score <= 1
        ? const Color(0xFFFF8D86)
        : score <= 2
            ? const Color(0xFFFFD45A)
            : const Color(0xFF9BE0BC);

    return Padding(
      padding: const EdgeInsets.only(top: 8, left: 4, right: 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: List.generate(4, (index) {
                return Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    height: 4,
                    margin: EdgeInsets.only(right: index == 3 ? 0 : 4),
                    decoration: BoxDecoration(
                      color: index < score
                          ? color
                          : const Color(0xFF6E628F).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Text(
              label,
              key: ValueKey(label),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BiometricInfoTile extends StatelessWidget {
  const _BiometricInfoTile({required this.isEnabled});

  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      label: isEnabled
          ? 'Fingerprint unlock is ready on this phone.'
          : 'After password login, fingerprint unlock can be enabled on this phone.',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF9BE0BC).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF9BE0BC).withValues(alpha: 0.32),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(
                Icons.fingerprint_rounded,
                color: Color(0xFF9BE0BC),
                size: 21,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEnabled
                      ? 'Fingerprint is ready on this phone.'
                      : 'After login, we can enable fingerprint for your next visit.',
                  style: const TextStyle(
                    color: Color(0xFFC7F0D8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
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

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.error.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.info_rounded,
              color: theme.colorScheme.onErrorContainer,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MascotChoice extends StatelessWidget {
  const _MascotChoice({
    required this.mascot,
    required this.isSelected,
    required this.onTap,
  });

  final AccountMascot mascot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFFFD45A).withValues(alpha: 0.18)
              : const Color(0xFF111318).withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFFFD45A)
                : const Color(0xFF6E628F).withValues(alpha: 0.72),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFFFFD45A).withValues(alpha: 0.16),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            AnimatedScale(
              scale: isSelected ? 1.08 : 0.96,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: _MascotAvatar(
                mascot: mascot,
                isCreatingAccount: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              mascot.label,
              style: theme.textTheme.labelLarge?.copyWith(
                color: const Color(0xFFFFF4EA),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MascotAvatar extends StatelessWidget {
  const _MascotAvatar({
    super.key,
    required this.mascot,
    this.size = 78,
    this.isCreatingAccount = true,
  });

  final AccountMascot mascot;
  final double size;
  final bool isCreatingAccount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: mascot == AccountMascot.panda
            ? Pippa(
                size: size * 0.92,
                row: isCreatingAccount ? 0 : 4,
                frameCount: isCreatingAccount ? 6 : 5,
                duration: Duration(
                  milliseconds: isCreatingAccount ? 900 : 1120,
                ),
              )
            : Kebo(
                size: size * 0.92,
                row: isCreatingAccount ? 0 : 4,
                frameCount: isCreatingAccount ? 7 : 5,
                duration: Duration(
                  milliseconds: isCreatingAccount ? 960 : 1180,
                ),
              ),
      ),
    );
  }
}
