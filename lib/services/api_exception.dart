class ApiException implements Exception {
  final String message;
  final int statusCode;
  final String? requestId;

  ApiException(this.message, {this.statusCode = 500, this.requestId});

  @override
  String toString() => message;
}
