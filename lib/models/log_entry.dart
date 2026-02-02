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
        return const Color(0xFF61AFEF); // Blue
      case LogType.stdout:
        return const Color(0xFFABB2BF); // Light Grey
      case LogType.stderr:
        return const Color(0xFFE06C75); // Red
      case LogType.info:
        return const Color(0xFF98C379); // Green
    }
  }
}
