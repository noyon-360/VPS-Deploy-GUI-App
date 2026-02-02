class DiscoveredApplication {
  final String pathOnServer;
  final String? repoUrl;
  final String? branch;
  final String? appName;
  final String? port;
  final String? domain;
  final bool hasSSL;
  final String? sslEmail;
  final String? installCommand;
  final String? startCommand;
  final String? nginxConfigPath;
  final String? gitUsername;
  final String? gitToken;

  DiscoveredApplication({
    required this.pathOnServer,
    this.repoUrl,
    this.branch,
    this.appName,
    this.port,
    this.domain,
    this.hasSSL = false,
    this.sslEmail,
    this.installCommand,
    this.startCommand,
    this.nginxConfigPath,
    this.gitUsername,
    this.gitToken,
  });

  // Helper properties
  bool get isGitRepo => repoUrl != null && repoUrl!.isNotEmpty;
  bool get hasPm2Process => appName != null && appName!.isNotEmpty;
  bool get hasNginxConfig => domain != null && domain!.isNotEmpty;
  bool get isFullyConfigured => isGitRepo && hasPm2Process && hasNginxConfig;

  // Get a display name for the application
  String get displayName {
    if (appName != null && appName!.isNotEmpty) return appName!;
    return pathOnServer.split('/').last;
  }

  // Get a status summary
  String get statusSummary {
    final parts = <String>[];
    if (isGitRepo) parts.add('Git');
    if (hasPm2Process) parts.add('PM2');
    if (hasNginxConfig) parts.add('Nginx');
    if (hasSSL) parts.add('SSL');
    return parts.isEmpty ? 'Basic' : parts.join(' • ');
  }

  // Get completeness percentage
  int get completenessPercentage {
    int score = 0;
    if (isGitRepo) score += 25;
    if (hasPm2Process) score += 25;
    if (hasNginxConfig) score += 25;
    if (hasSSL) score += 25;
    return score;
  }

  @override
  String toString() {
    return 'DiscoveredApplication(path: $pathOnServer, app: $appName, domain: $domain)';
  }
}
