import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../controllers/auth_controller.dart';
import '../controllers/auth_state.dart';
import '../mixins/auth_validation_mixin.dart';
import '../widgets/auth_feedback_snackbar.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({
    super.key,
    required this.email,
  });

  final String email;

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
    with AuthValidationMixin {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List<TextEditingController>.generate(
      6,
      (_) => TextEditingController(),
      growable: false,
    );
    _focusNodes = List<FocusNode>.generate(6, (_) => FocusNode(), growable: false);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final resendInSeconds = ref.watch(otpResendSecondsProvider);
    final isBusy = authState.isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            const _OtpBackdrop(),
            Center(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final maxWidth = constraints.maxWidth > 700 ? 500.0 : 580.0;
                  return ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Card(
                        margin: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                          side: BorderSide(color: scheme.outlineVariant),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(22, 24, 22, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'تایید کد یکبارمصرف',
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'کد ۶ رقمی ارسال‌شده به ${widget.email} را وارد کنید',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                alignment: WrapAlignment.center,
                                children: List<Widget>.generate(
                                  6,
                                  (index) => SizedBox(
                                    width: 48,
                                    child: TextField(
                                      controller: _controllers[index],
                                      focusNode: _focusNodes[index],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      textInputAction:
                                          index == 5 ? TextInputAction.done : TextInputAction.next,
                                      maxLength: 1,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      decoration: const InputDecoration(
                                        counterText: '',
                                      ),
                                      onChanged: (value) => _onChanged(index, value),
                                    ),
                                  ),
                                  growable: false,
                                ),
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: isBusy ? null : _onVerifyPressed,
                                  icon: isBusy
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Icon(Icons.verified_rounded),
                                  label: const Text('تایید کد'),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (resendInSeconds > 0)
                                Text(
                                  'ارسال مجدد کد تا ${_formatDuration(resendInSeconds)} دیگر',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                )
                              else
                                TextButton(
                                  onPressed: isBusy ? null : _onResendPressed,
                                  child: const Text('ارسال مجدد کد'),
                                ),
                              TextButton(
                                onPressed: isBusy ? null : () => context.go('/auth/register'),
                                child: const Text('بازگشت به ثبت‌نام'),
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

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      _applyPasted(value);
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
      return;
    }

    if (index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  void _applyPasted(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');

    for (var i = 0; i < _controllers.length; i++) {
      _controllers[i].text = i < digits.length ? digits[i] : '';
    }

    if (digits.length >= 6) {
      _focusNodes.last.unfocus();
    } else {
      _focusNodes[digits.length].requestFocus();
    }
  }

  String _readOtp() => _controllers.map((controller) => controller.text).join();

  Future<void> _onVerifyPressed() async {
    HapticFeedback.selectionClick();

    final otp = _readOtp();
    final otpValidation = validateOtp(otp);
    if (otpValidation.isLeft()) {
      HapticFeedback.heavyImpact();
      final message = otpValidation.swap().getOrElse((_) => 'کد تایید نامعتبر است.');
      AuthFeedbackSnackbar.showError(context, message);
      return;
    }

    final result = await ref.read(authControllerProvider.notifier).verifyOtp(
          email: widget.email,
          otp: otp,
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
        context.go('/dashboard');
      },
    );
  }

  Future<void> _onResendPressed() async {
    HapticFeedback.selectionClick();
    final result = await ref.read(authControllerProvider.notifier).resendOtp();

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
        AuthFeedbackSnackbar.showInfo(context, 'کد تایید جدید ارسال شد.');
      },
    );
  }

  String _formatDuration(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class _OtpBackdrop extends StatelessWidget {
  const _OtpBackdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF030711),
            Color(0xFF0C1730),
            Color(0xFF17223F),
          ],
        ),
      ),
      child: Align(
        alignment: const Alignment(0.0, -0.95),
        child: Container(
          width: 240,
          height: 240,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [Color(0x5538BDF8), Colors.transparent],
            ),
          ),
        ),
      ),
    );
  }
}
