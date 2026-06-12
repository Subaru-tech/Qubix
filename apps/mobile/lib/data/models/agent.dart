/// Agent model matching the backend's /agents response shape.
class Agent {
  final String id;
  final String name;
  final String? description;
  final String connectorType;
  final Map<String, dynamic> config;
  final String? systemPrompt;
  final bool isEnabled;
  final String status;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Agent({
    required this.id,
    required this.name,
    this.description,
    required this.connectorType,
    required this.config,
    this.systemPrompt,
    required this.isEnabled,
    required this.status,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      connectorType: json['connectorType'] as String,
      config: Map<String, dynamic>.from(json['config'] as Map? ?? {}),
      systemPrompt: json['systemPrompt'] as String?,
      isEnabled: json['isEnabled'] as bool? ?? true,
      status: json['status'] as String? ?? 'offline',
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'connectorType': connectorType,
        'config': config,
        'systemPrompt': systemPrompt,
        'isEnabled': isEnabled,
        'status': status,
      };

  Agent copyWith({
    String? name,
    String? description,
    String? connectorType,
    Map<String, dynamic>? config,
    String? systemPrompt,
    bool? isEnabled,
    String? status,
  }) {
    return Agent(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      connectorType: connectorType ?? this.connectorType,
      config: config ?? this.config,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      isEnabled: isEnabled ?? this.isEnabled,
      status: status ?? this.status,
      lastUsedAt: lastUsedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}
