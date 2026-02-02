import 'package:json_annotation/json_annotation.dart';

part 'deployment_action.g.dart';

enum DeploymentActionType {
  cloneAndInstall,
  deployApplication,
  configureDomainSSL,
}

enum DeploymentStatus { success, failed, inProgress }

@JsonSerializable()
class DeploymentAction {
  final DeploymentActionType actionType;
  final DateTime timestamp;
  final DeploymentStatus status;
  final Map<String, dynamic>? details;
  final String? logSummary;

  DeploymentAction({
    required this.actionType,
    required this.timestamp,
    required this.status,
    this.details,
    this.logSummary,
  });

  factory DeploymentAction.fromJson(Map<String, dynamic> json) =>
      _$DeploymentActionFromJson(json);
  Map<String, dynamic> toJson() => _$DeploymentActionToJson(this);

  DeploymentAction copyWith({
    DeploymentActionType? actionType,
    DateTime? timestamp,
    DeploymentStatus? status,
    Map<String, dynamic>? details,
    String? logSummary,
  }) {
    return DeploymentAction(
      actionType: actionType ?? this.actionType,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      details: details ?? this.details,
      logSummary: logSummary ?? this.logSummary,
    );
  }

  String get actionName {
    switch (actionType) {
      case DeploymentActionType.cloneAndInstall:
        return 'Clone & Install';
      case DeploymentActionType.deployApplication:
        return 'Deploy Application';
      case DeploymentActionType.configureDomainSSL:
        return 'Configure Domain & SSL';
    }
  }

  String get statusText {
    switch (status) {
      case DeploymentStatus.success:
        return 'Success';
      case DeploymentStatus.failed:
        return 'Failed';
      case DeploymentStatus.inProgress:
        return 'In Progress';
    }
  }
}
