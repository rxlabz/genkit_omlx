/// Helper utilities for safe dynamic value coercion from Genkit config maps.
library;

double? asDouble(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  return null;
}

int? asInt(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return null;
}

bool? asBool(Object? value) {
  return value is bool ? value : null;
}

List<String>? asStringList(Object? value) {
  if (value is List) {
    final strings = value.whereType<String>().toList(growable: false);
    if (strings.length == value.length) {
      return strings;
    }
  }
  if (value is String) {
    return [value];
  }
  return null;
}

Map<String, dynamic>? asStringDynamicMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}
