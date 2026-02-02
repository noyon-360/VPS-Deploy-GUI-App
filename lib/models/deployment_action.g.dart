// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'deployment_action.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DeploymentAction _$DeploymentActionFromJson(Map<String, dynamic> json) =>
    DeploymentAction(
      actionType: $enumDecode(
        _$DeploymentActionTypeEnumMap,
        json['actionType'],
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: $enumDecode(_$DeploymentStatusEnumMap, json['status']),
      details: json['details'] as Map<String, dynamic>?,
      logSummary: json['logSummary'] as String?,
    );

Map<String, dynamic> _$DeploymentActionToJson(DeploymentAction instance) =>
    <String, dynamic>{
      'actionType': _$DeploymentActionTypeEnumMap[instance.actionType]!,
      'timestamp': instance.timestamp.toIso8601String(),
      'status': _$DeploymentStatusEnumMap[instance.status]!,
      'details': instance.details,
      'logSummary': instance.logSummary,
    };

const _$DeploymentActionTypeEnumMap = {
  DeploymentActionType.cloneAndInstall: 'cloneAndInstall',
  DeploymentActionType.deployApplication: 'deployApplication',
  DeploymentActionType.configureDomainSSL: 'configureDomainSSL',
};

const _$DeploymentStatusEnumMap = {
  DeploymentStatus.success: 'success',
  DeploymentStatus.failed: 'failed',
  DeploymentStatus.inProgress: 'inProgress',
};
