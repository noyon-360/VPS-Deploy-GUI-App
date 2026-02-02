import 'package:flutter/material.dart';

enum LogType { command, stdout, stderr, info }

class LogEntry {
  final DateTime timestamp;
  final String message;
  final LogType type;

  LogEntry({required this.message, required this.type, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();

  String get formattedTimestamp =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';

  Color get color {
    switch (type) {
      case LogType.command:
        return const Color(0xFF61AFEF); // Soft Cyan/Blue for commands
      case LogType.stdout:
        return Colors.white.withValues(alpha: 0.9); // Bright white for output
      case LogType.stderr:
        return const Color(0xFFE06C75); // Soft red for errors
      case LogType.info:
        return Colors.white.withValues(
          alpha: 0.5,
        ); // Dimmed white for system info
    }
  }
}
