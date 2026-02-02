class ServerToolStatus {
  final String name;
  final bool isInstalled;
  final String? version;

  ServerToolStatus({
    required this.name,
    required this.isInstalled,
    this.version,
  });
}
