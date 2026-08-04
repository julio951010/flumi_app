import 'dart:convert';

dynamic _toEncodable(dynamic value) {
  if (value is DateTime) {
    return value.toIso8601String();
  }
  if (value is List<dynamic>) {
    return value.map(_toEncodable).toList();
  }
  if (value is Map<String, dynamic>) {
    return value.map((k, v) => MapEntry(k, _toEncodable(v)));
  }
  return value;
}

String encodeJson(dynamic object) {
  return jsonEncode(object, toEncodable: _toEncodable);
}
