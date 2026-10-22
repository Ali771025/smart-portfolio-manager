import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../mixins/auth_validation_mixin.dart';
import '../widgets/auth_feedback_snackbar.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.redirectTo,
  });

  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> with AuthValidationMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  Timer? _debounce;
  bool _obscurePassword = true;

  String? _emailError;
  String? _passwordError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_scheduleValidation);
    _passwordController.addListener(_scheduleValidation);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _scheduleValidation() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), _validateForm);
  }

  void _validateForm() {
    final emailResult = validateEmail(_emailController.text);
    final passwordResult = validatePassword(_passwordController.text);

    if (!mounted) {
      return;
    }

    setState(() {
      _emailError = emailResult.fold((err) => err, (_) => null);
      _passwordError = passwordResult.fold((err) => err, (_) => null);
    });
  }

  bool get _isFormValid => _emailError == null && _passwordError == null;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _AuthBackdrop(),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth > 700 ? 460.0 : 520.0;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Card(
                        margin: EdgeInsets.zero,
                        color: scheme.surface.withValues(alpha: 0.92),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'خوش آمدید',
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'برای ادامه به داشبورد سرمایه‌گذاری وارد شوید.',
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autofillHints: const [AutofillHints.username],
                                decoration: InputDecoration(
                                  labelText: 'ایمیل',
                                  hintText: 'ایمیل خود را وارد کنید',
                                  prefixIcon: const Icon(Icons.alternate_email_rounded),
                                  errorText: _emailError,
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                autofillHints: const [AutofillHints.password],
                                onSubmitted: (_) => _onLoginPressed(),
                                decoration: InputDecoration(
                                  labelText: 'رمز عبور',
                                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                                  errorText: _passwordError,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: isBusy ? null : _onLoginPressed,
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.login_rounded),
                                label: const Text('ورود'),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.center,
                                child: TextButton(
                                  onPressed: isBusy ? null : () => context.push('/auth/register'),
                                  child: const Text('حساب کاربری ندارید؟ ثبت‌نام کنید'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onLoginPressed() async {
    HapticFeedback.selectionClick();
    _validateForm();

    if (!_isFormValid) {
      HapticFeedback.heavyImpact();
      AuthFeedbackSnackbar.showError(context, 'لطفا خطاهای مشخص‌شده را اصلاح کنید.');
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    final result = await ref.read(authControllerProvider.notifier).login(
          email: email,
          password: password,
        );

    if (!mounted) {
      return;
    }

    result.match(
      (failure) {
        HapticFeedback.heavyImpact();
        AuthFeedbackSnackbar.showError(context, failure.message);
      },
      (_) {
        HapticFeedback.lightImpact();
        final target = widget.redirectTo?.isNotEmpty == true ? widget.redirectTo! : '/dashboard';
        context.go(target);
      },
    );
  }
}

class _AuthBackdrop extends StatelessWidget {
  const _AuthBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF030712),
            Color(0xFF091224),
            Color(0xFF111827),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const Alignment(0.86, -0.94),
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x6638BDF8), Colors.transparent],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(-0.95, 0.9),
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x5534D399), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
