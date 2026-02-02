class RemoteFile {
  final String name;
  final String path;
  final bool isDirectory;
  final String size;
  final String permissions;
  final String modified;

  RemoteFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    required this.permissions,
    required this.modified,
  });

  factory RemoteFile.fromLsOutput(String line, String currentPath) {
    // Example line: drwxr-xr-x 2 root root 4096 Feb 2 12:00 foldername
    final parts = line.split(RegExp(r'\s+'));
    final permissions = parts[0];
    final isDirectory = permissions.startsWith('d');
    final size = parts[4];
    final date = '${parts[5]} ${parts[6]} ${parts[7]}';

    // standard ls -la: perms links user group size month day time name
    // But sometimes group is missing or extra spaces.
    // simpler strategy: standard ls -la always ends with name.
    // User/Group/Date layout is fairly fixed but might vary slightly.
    // Let's assume the last part is name, but name can have spaces.
    // Safest heuristic provided standard `ls -la`:
    // It has at least 8 columns.

    // Attempt to find the index where the date ends.
    // Date usually 3 parts: Month Day Time/Year (e.g., Feb 2 12:00 or Feb 2 2023)
    // Counting from end might be safer if name has no spaces? No, name can have spaces.

    // Let's rely on the fact that permissions is first.
    // Then links, user, group, size, date (3 parts), name.
    // Total 8 parts before name starts.
    int nameStart = 8;
    if (parts.length < 9) {
      // Fallback or maybe simpler format
      nameStart = parts.length - 1;
    }

    // Re-join the name parts
    final name = parts.sublist(nameStart).join(' ');

    return RemoteFile(
      name: name,
      path: currentPath.endsWith('/')
          ? '$currentPath$name'
          : '$currentPath/$name',
      isDirectory: isDirectory,
      size: size,
      permissions: permissions,
      modified: date,
    );
  }
}
