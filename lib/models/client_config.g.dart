// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ClientConfig _$ClientConfigFromJson(Map<String, dynamic> json) => ClientConfig(
  id: json['id'] as String,
  name: json['name'] as String,
  serverAlias: json['serverAlias'] as String,
  password: json['password'] as String?,
  repositories:
      (json['repositories'] as List<dynamic>?)
          ?.map((e) => RepositoryConfig.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  createdAt: json['createdAt'] == null
      ? null
      : DateTime.parse(json['createdAt'] as String),
  lastConnected: json['lastConnected'] == null
      ? null
      : DateTime.parse(json['lastConnected'] as String),
);

Map<String, dynamic> _$ClientConfigToJson(ClientConfig instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'serverAlias': instance.serverAlias,
      'password': instance.password,
      'repositories': instance.repositories.map((e) => e.toJson()).toList(),
      'createdAt': instance.createdAt.toIso8601String(),
      'lastConnected': instance.lastConnected?.toIso8601String(),
    };
