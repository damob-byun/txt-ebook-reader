class WebDavAccount {
  final String host;
  final int port;
  final String username;
  final String password;
  final bool useHttps;

  WebDavAccount({
    required this.host,
    this.port = 443,
    required this.username,
    required this.password,
    this.useHttps = true,
  });

  WebDavAccount copyWith({
    String? host,
    int? port,
    String? username,
    String? password,
    bool? useHttps,
  }) {
    return WebDavAccount(
      host: host ?? this.host,
      port: port ?? this.port,
      username: username ?? this.username,
      password: password ?? this.password,
      useHttps: useHttps ?? this.useHttps,
    );
  }

  Map<String, dynamic> toJson() => {
    'host': host,
    'port': port,
    'username': username,
    // Password should be handled sensitively, but for simple persistence:
    'password': password,
    'useHttps': useHttps,
  };

  factory WebDavAccount.fromJson(Map<String, dynamic> json) => WebDavAccount(
    host: json['host'] ?? '',
    port: json['port'] ?? 443,
    username: json['username'] ?? '',
    password: json['password'] ?? '',
    useHttps: json['useHttps'] ?? true,
  );
  
  bool get isValid => host.isNotEmpty && username.isNotEmpty;
}
