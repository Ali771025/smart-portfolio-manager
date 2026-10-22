class ProblemFieldError {
  const ProblemFieldError({
    required this.field,
    required this.message,
  });

  final String field;
  final String message;
}

class ProblemDetailsException implements Exception {
  const ProblemDetailsException({
    required this.title,
    required this.detail,
    this.status,
    this.type,
    this.instance,
    this.fieldErrors = const <ProblemFieldError>[],
  });

  final String title;
  final String detail;
  final int? status;
  final String? type;
  final String? instance;
  final List<ProblemFieldError> fieldErrors;

  bool get hasFieldErrors => fieldErrors.isNotEmpty;

  Map<String, String> toFieldErrorMap() {
    final map = <String, String>{};
    for (final entry in fieldErrors) {
      map[entry.field] = entry.message;
    }
    return map;
  }

  @override
  String toString() => '$title: $detail';
}
