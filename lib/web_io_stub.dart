class File {
  final String path;
  File(this.path);
  bool existsSync() => false;
  Future<bool> exists() async => false;
  List<int> readAsBytesSync() => [];
  Future<List<int>> readAsBytes() async => [];
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