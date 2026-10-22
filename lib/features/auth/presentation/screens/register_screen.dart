import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../mixins/auth_validation_mixin.dart';
import '../widgets/auth_feedback_snackbar.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with AuthValidationMixin {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _rePasswordController = TextEditingController();

  Timer? _debounce;
  bool _obscurePassword = true;
  bool _obscureRePassword = true;

  String? _emailError;
  String? _passwordError;
  String? _rePasswordError;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_scheduleValidation);
    _passwordController.addListener(_scheduleValidation);
    _rePasswordController.addListener(_scheduleValidation);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _rePasswordController.dispose();
    super.dispose();
  }

  void _scheduleValidation() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), _validateForm);
  }

  void _validateForm() {
    final emailResult = validateEmail(_emailController.text);
    final passwordResult = validatePassword(_passwordController.text);
    final confirmResult = validateConfirmPassword(
      password: _passwordController.text,
      confirmPassword: _rePasswordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _emailError = emailResult.fold((err) => err, (_) => null);
      _passwordError = passwordResult.fold((err) => err, (_) => null);
      _rePasswordError = confirmResult.fold((err) => err, (_) => null);
    });
  }

  bool get _isFormValid => _emailError == null && _passwordError == null && _rePasswordError == null;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final isBusy = authState.isLoading;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _RegisterBackdrop(),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth > 860 ? 540.0 : 620.0;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'ایجاد حساب کاربری',
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'برای ثبت‌نام، ایمیل خود را وارد کنید و کد تایید را ثبت کنید.',
                                textAlign: TextAlign.right,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Colors.white70,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
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
                                textInputAction: TextInputAction.next,
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
                              const SizedBox(height: 12),
                              TextField(
                                controller: _rePasswordController,
                                obscureText: _obscureRePassword,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _onRegisterPressed(),
                                decoration: InputDecoration(
                                  labelText: 'تکرار رمز عبور',
                                  prefixIcon: const Icon(Icons.lock_reset_rounded),
                                  errorText: _rePasswordError,
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      setState(() {
                                        _obscureRePassword = !_obscureRePassword;
                                      });
                                    },
                                    icon: Icon(
                                      _obscureRePassword
                                          ? Icons.visibility_rounded
                                          : Icons.visibility_off_rounded,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              FilledButton.icon(
                                onPressed: isBusy ? null : _onRegisterPressed,
                                icon: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Icon(Icons.mark_email_read_rounded),
                                label: const Text('ارسال کد تایید'),
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.center,
                                child: TextButton(
                                  onPressed: isBusy ? null : () => context.go('/auth/login'),
                                  child: const Text('حساب کاربری دارید؟ وارد شوید'),
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

  Future<void> _onRegisterPressed() async {
    HapticFeedback.selectionClick();
    _validateForm();

    if (!_isFormValid) {
      HapticFeedback.heavyImpact();
      AuthFeedbackSnackbar.showError(context, 'لطفا خطاهای مشخص‌شده را اصلاح کنید.');
      return;
    }

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    final rePassword = _rePasswordController.text;

    final result = await ref.read(authControllerProvider.notifier).registerInit(
          email: email,
          password: password,
          rePassword: rePassword,
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
        context.push('/auth/otp?email=${Uri.encodeComponent(email)}');
      },
    );
  }
}

class _RegisterBackdrop extends StatelessWidget {
  const _RegisterBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF020711),
            Color(0xFF0A1428),
            Color(0xFF16213C),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: const Alignment(-0.86, -0.9),
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x6634D399), Colors.transparent],
                ),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0.95, 0.9),
            child: Container(
              width: 220,
              height: 220,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x5538BDF8), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
