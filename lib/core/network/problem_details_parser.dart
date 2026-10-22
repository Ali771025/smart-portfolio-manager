import 'dart:convert';

class ProblemFieldIssue {
  const ProblemFieldIssue({
    required this.field,
    required this.message,
  });

  final String field;
  final String message;
}

class ProblemDetailsPayload {
  const ProblemDetailsPayload({
    required this.title,
    required this.detail,
    this.status,
    this.type,
    this.instance,
    this.errors = const <ProblemFieldIssue>[],
  });

  final String title;
  final String detail;
  final int? status;
  final String? type;
  final String? instance;
  final List<ProblemFieldIssue> errors;
}

class ProblemDetailsException implements Exception {
  const ProblemDetailsException(this.problem);

  final ProblemDetailsPayload problem;

  @override
  String toString() => '${problem.title}: ${problem.detail}';
}

ProblemDetailsPayload parseProblemDetails(Object? payload) {
  final decoded = _decodeMap(payload);
  final title = decoded?['title']?.toString() ?? 'Request failed';
  final detail = decoded?['detail']?.toString() ?? 'Unexpected server error.';
  final status = _asInt(decoded?['status']);
  final type = decoded?['type']?.toString();
  final instance = decoded?['instance']?.toString();
  final errors = _extractErrors(decoded);

  return ProblemDetailsPayload(
    title: title,
    detail: detail,
    status: status,
    type: type,
    instance: instance,
    errors: errors,
  );
}

Map<String, dynamic>? _decodeMap(Object? data) {
  if (data is Map<String, dynamic>) {
    return data;
  }
  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }
  if (data is String && data.trim().isNotEmpty) {
    try {
      final decoded = jsonDecode(data);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
  }
  return null;
}

int? _asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

List<ProblemFieldIssue> _extractErrors(Map<String, dynamic>? decoded) {
  final raw = decoded?['errors'];
  if (raw is! List) {
    return const <ProblemFieldIssue>[];
  }

  return raw
      .whereType<Map>()
      .map((entry) {
        final map = Map<String, dynamic>.from(entry);
        final field = map['field']?.toString() ?? '';
        final message = map['message']?.toString() ?? map['msg']?.toString() ?? '';
        if (field.isEmpty || message.isEmpty) {
          return null;
        }
        return ProblemFieldIssue(field: field, message: message);
      })
      .whereType<ProblemFieldIssue>()
      .toList(growable: false);
}
