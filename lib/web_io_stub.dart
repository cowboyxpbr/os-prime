import 'dart:typed_data';

class File {
  final String path;
  File(this.path);
  bool existsSync() => false;
  Future<bool> exists() async => false;
  Future<void> delete() async {}
  Uint8List readAsBytesSync() => Uint8List(0);
  Future<Uint8List> readAsBytes() async => Uint8List(0);
  Future<File> writeAsBytes(List<int> bytes) async => this;
  Future<String> readAsString() async => '';
  Future<File> writeAsString(String contents) async => this;
}

class Directory {
  final String path;
  Directory(this.path);
}

class HttpClient {
  Future<HttpClientRequest> postUrl(Uri url) async => HttpClientRequest();
  void close() {}
}

class HttpClientRequest {
  final HttpHeaders headers = HttpHeaders();
  void add(List<int> data) {}
  Future<HttpClientResponse> close() async => HttpClientResponse();
}

class HttpHeaders {
  void set(String name, Object value) {}
}

class HttpClientResponse {
  int get statusCode => 200;
  Stream<List<int>> transform<S>(dynamic streamTransformer) => Stream.value([]);
}