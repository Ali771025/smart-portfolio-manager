import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/auth_session.dart';
import '../controllers/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    this.redirectTo,
  });

  final String? redirectTo;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>(debugLabel: 'auth_screen_form');

  Timer? _debounce;
  bool _emailDirty = false;
  bool _passwordDirty = false;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_onFieldChanged);
    _passwordController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      if (!mounted) {
        return;
      }
      setState(() {
        _emailDirty = true;
        _passwordDirty = true;
      });
      _formKey.currentState?.validate();
    }); 
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    ref.listen<AsyncValue<AuthSession?>>(
      authControllerProvider,
      (previous, next) {
        final prevLoading = previous?.isLoading ?? false;
        if (prevLoading && next.hasError) {
          HapticFeedback.heavyImpact();
          final message = next.error?.toString() ?? 'ورود انجام نشد.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        final nextSession = next.value;
        if (nextSession != null && !nextSession.isExpired) {
          HapticFeedback.lightImpact();
          final target = widget.redirectTo?.isNotEmpty == true
              ? widget.redirectTo!
              : '/dashboard';
          context.go(target);
        }
      },
    );

    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _AuthBackground(),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer.withValues(alpha: 0.94),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                'ورود به سامانه مدیریت هوشمند پرتفو',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'برای ادامه، اطلاعات حساب خود را وارد کنید.',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.username],
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'ایمیل',
                                  hintText: 'ایمیل خود را وارد کنید',
                                  prefixIcon: Icon(Icons.alternate_email_rounded),
                                ),
                                validator: (value) {
                                  if (!_emailDirty) {
                                    return null;
                                  }
                                  final email = value?.trim() ?? '';
                                  if (email.isEmpty) {
                                    return 'ایمیل الزامی است.';
                                  }
                                  final emailRegex = RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  );
                                  if (!emailRegex.hasMatch(email)) {
                                    return 'فرمت ایمیل معتبر نیست.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _passwordController,
                                obscureText: true,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onFieldSubmitted: (_) => _onSubmit(),
                                decoration: const InputDecoration(
                                  labelText: 'رمز عبور',
                                  prefixIcon: Icon(Icons.lock_outline_rounded),
                                ),
                                validator: (value) {
                                  if (!_passwordDirty) {
                                    return null;
                                  }
                                  final password = value ?? '';
                                  if (password.isEmpty) {
                                    return 'رمز عبور الزامی است.';
                                  }
                                  if (password.length < 8) {
                                    return 'حداقل ۸ کاراکتر وارد کنید.';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: isBusy ? null : _onSubmit,
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: const Text('ورود'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onSubmit() async {
    _emailDirty = true;
    _passwordDirty = true;
    if (!(_formKey.currentState?.validate() ?? false)) {
      HapticFeedback.vibrate();
      setState(() {});
      return;
    }

    await ref.read(authControllerProvider.notifier).login(
          email: _emailController.text.trim().toLowerCase(),
          password: _passwordController.text,
        );
  }
}

class _AuthBackground extends StatelessWidget {
  const _AuthBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: <Color>[
            Color(0xFF04121F),
            Color(0xFF061120),
            Color(0xFF0D1324),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const Alignment(0.85, -0.95),
            child: Container(
              width: 230,
              height: 230,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[Color(0xAA38BDF8), Colors.transparent],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.95, 0.95),
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: <Color>[Color(0x6634D399), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
