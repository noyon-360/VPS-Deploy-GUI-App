import 'package:deploy_gui/models/repository_config.dart';
import 'package:json_annotation/json_annotation.dart';

part 'client_config.g.dart';

@JsonSerializable(explicitToJson: true)
class ClientConfig {
  final String id;
  final String name;
  final String serverAlias; // SSH IP address - Primary unique identifier
  final String? password;
  final List<RepositoryConfig> repositories;
  final DateTime createdAt;
  final DateTime? lastConnected;

  ClientConfig({
    required this.id,
    required this.name,
    required this.serverAlias,
    this.password,
    this.repositories = const [],
    DateTime? createdAt,
    this.lastConnected,
  }) : createdAt = createdAt ?? DateTime.now();

  factory ClientConfig.fromJson(Map<String, dynamic> json) =>
      _$ClientConfigFromJson(json);
  Map<String, dynamic> toJson() => _$ClientConfigToJson(this);

  ClientConfig copyWith({
    String? id,
    String? name,
    String? serverAlias,
    String? password,
    List<RepositoryConfig>? repositories,
    DateTime? createdAt,
    DateTime? lastConnected,
  }) {
    return ClientConfig(
      id: id ?? this.id,
      name: name ?? this.name,
      serverAlias: serverAlias ?? this.serverAlias,
      password: password ?? this.password,
      repositories: repositories ?? this.repositories,
      createdAt: createdAt ?? this.createdAt,
      lastConnected: lastConnected ?? this.lastConnected,
    );
  }

  // Helper methods
  RepositoryConfig? findRepository(String repoUrl) {
    try {
      return repositories.firstWhere((repo) => repo.repoUrl == repoUrl);
    } catch (e) {
      return null;
    }
  }

  ClientConfig addRepository(RepositoryConfig repo) {
    return copyWith(repositories: [...repositories, repo]);
  }

  ClientConfig updateRepository(String repoUrl, RepositoryConfig updatedRepo) {
    final updatedRepos = repositories.map((repo) {
      return repo.repoUrl == repoUrl ? updatedRepo : repo;
    }).toList();
    return copyWith(repositories: updatedRepos);
  }

  ClientConfig removeRepository(String repoUrl) {
    return copyWith(
      repositories: repositories
          .where((repo) => repo.repoUrl != repoUrl)
          .toList(),
    );
  }

  ClientConfig updateLastConnected() {
    return copyWith(lastConnected: DateTime.now());
  }
}
