import 'package:fpdart/fpdart.dart';

mixin AuthValidationMixin {
  static final RegExp _emailRegex = RegExp(
    r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$",
  );

  static final RegExp _passwordRegex = RegExp(r'^(?=.*[A-Za-z])(?=.*\d).{8,128}$');
  static final RegExp _otpRegex = RegExp(r'^\d{6}$');

  Either<String, String> validateEmail(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized.isEmpty) {
      return const Left('ایمیل الزامی است.');
    }
    if (normalized.length > 320 || !_emailRegex.hasMatch(normalized)) {
      return const Left('لطفا یک ایمیل معتبر وارد کنید.');
    }
    return Right(normalized);
  }

  Either<String, String> validatePassword(String value) {
    if (value.isEmpty) {
      return const Left('رمز عبور الزامی است.');
    }
    if (!_passwordRegex.hasMatch(value)) {
      return const Left('حداقل ۸ کاراکتر شامل یک حرف و یک عدد وارد کنید.');
    }
    return Right(value);
  }

  Either<String, String> validateConfirmPassword({
    required String password,
    required String confirmPassword,
  }) {
    if (confirmPassword.isEmpty) {
      return const Left('تکرار رمز عبور الزامی است.');
    }
    if (password != confirmPassword) {
      return const Left('رمز عبور و تکرار آن یکسان نیستند.');
    }
    return Right(confirmPassword);
  }

  Either<String, String> validateOtp(String value) {
    final normalized = value.trim();
    if (!_otpRegex.hasMatch(normalized)) {
      return const Left('کد تایید باید دقیقا ۶ رقم باشد.');
    }
    return Right(normalized);
  }
}
