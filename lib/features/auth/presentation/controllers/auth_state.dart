import 'package:flutter_riverpod/legacy.dart';

class PendingRegistration {
  const PendingRegistration({
    required this.email,
    required this.password,
    required this.rePassword,
  });

  final String email;
  final String password;
  final String rePassword;
}

final pendingRegistrationProvider = StateProvider<PendingRegistration?>(
  (ref) => null,
);

final otpResendSecondsProvider = StateProvider<int>((ref) => 0);
