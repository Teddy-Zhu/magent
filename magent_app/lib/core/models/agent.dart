class AgentInfo {
  final String id;
  final String name;
  final String baseUrl;
  final String token;
  final String status;
  final DateTime? lastSeen;

  AgentInfo({
    required this.id,
    required this.name,
    required this.baseUrl,
    required this.token,
    this.status = 'offline',
    this.lastSeen,
  });

  factory AgentInfo.fromJson(Map<String, dynamic> json) {
    return AgentInfo(
      id: json['id'] as String,
      name: json['name'] as String,
      baseUrl: json['base_url'] as String,
      token: json['token'] as String,
      status: json['status'] as String? ?? 'offline',
      lastSeen: json['last_seen'] != null ? DateTime.parse(json['last_seen'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'base_url': baseUrl,
      'token': token,
      'status': status,
      'last_seen': lastSeen?.toIso8601String(),
    };
  }
}
