/// JSON helpers shared by the model classes. Enum-like values stay as the backend's strings
/// (e.g. 'PENDING_PAYMENT'); use [label] to show them.
typedef Json = Map<String, dynamic>;

DateTime? parseDate(Object? value) => value == null ? null : DateTime.parse(value as String).toLocal();

double? parseMoney(Object? value) => value == null ? null : (value as num).toDouble();

List<T> parseList<T>(Object? value, T Function(Json) fromJson) =>
    ((value as List?) ?? const []).map((e) => fromJson(e as Json)).toList();

/// 'PENDING_PAYMENT' -> 'Pending payment'
String label(String? value) {
  if (value == null || value.isEmpty) return '';
  final words = value.toLowerCase().replaceAll('_', ' ');
  return words[0].toUpperCase() + words.substring(1);
}

class PageResult<T> {
  PageResult({required this.content, required this.page, required this.totalElements, required this.totalPages});

  final List<T> content;
  final int page;
  final int totalElements;
  final int totalPages;

  factory PageResult.fromJson(Json json, T Function(Json) fromJson) => PageResult(
        content: parseList(json['content'], fromJson),
        page: json['page'] as int,
        totalElements: json['totalElements'] as int,
        totalPages: json['totalPages'] as int,
      );
}
