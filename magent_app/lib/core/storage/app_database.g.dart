// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProjectEntriesTable extends ProjectEntries
    with TableInfo<$ProjectEntriesTable, ProjectEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _defaultProviderMeta = const VerificationMeta(
    'defaultProvider',
  );
  @override
  late final GeneratedColumn<String> defaultProvider = GeneratedColumn<String>(
    'default_provider',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    id,
    name,
    path,
    defaultProvider,
    revision,
    dataJson,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('default_provider')) {
      context.handle(
        _defaultProviderMeta,
        defaultProvider.isAcceptableOrUnknown(
          data['default_provider']!,
          _defaultProviderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultProviderMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, id};
  @override
  ProjectEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      defaultProvider: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}default_provider'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      ),
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $ProjectEntriesTable createAlias(String alias) {
    return $ProjectEntriesTable(attachedDatabase, alias);
  }
}

class ProjectEntry extends DataClass implements Insertable<ProjectEntry> {
  final String agentId;
  final String id;
  final String name;
  final String path;
  final String defaultProvider;
  final int? revision;
  final String dataJson;
  final DateTime? createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const ProjectEntry({
    required this.agentId,
    required this.id,
    required this.name,
    required this.path,
    required this.defaultProvider,
    this.revision,
    required this.dataJson,
    this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['path'] = Variable<String>(path);
    map['default_provider'] = Variable<String>(defaultProvider);
    if (!nullToAbsent || revision != null) {
      map['revision'] = Variable<int>(revision);
    }
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<DateTime>(createdAt);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  ProjectEntriesCompanion toCompanion(bool nullToAbsent) {
    return ProjectEntriesCompanion(
      agentId: Value(agentId),
      id: Value(id),
      name: Value(name),
      path: Value(path),
      defaultProvider: Value(defaultProvider),
      revision: revision == null && nullToAbsent
          ? const Value.absent()
          : Value(revision),
      dataJson: Value(dataJson),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory ProjectEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      path: serializer.fromJson<String>(json['path']),
      defaultProvider: serializer.fromJson<String>(json['defaultProvider']),
      revision: serializer.fromJson<int?>(json['revision']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      createdAt: serializer.fromJson<DateTime?>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'path': serializer.toJson<String>(path),
      'defaultProvider': serializer.toJson<String>(defaultProvider),
      'revision': serializer.toJson<int?>(revision),
      'dataJson': serializer.toJson<String>(dataJson),
      'createdAt': serializer.toJson<DateTime?>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  ProjectEntry copyWith({
    String? agentId,
    String? id,
    String? name,
    String? path,
    String? defaultProvider,
    Value<int?> revision = const Value.absent(),
    String? dataJson,
    Value<DateTime?> createdAt = const Value.absent(),
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => ProjectEntry(
    agentId: agentId ?? this.agentId,
    id: id ?? this.id,
    name: name ?? this.name,
    path: path ?? this.path,
    defaultProvider: defaultProvider ?? this.defaultProvider,
    revision: revision.present ? revision.value : this.revision,
    dataJson: dataJson ?? this.dataJson,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  ProjectEntry copyWithCompanion(ProjectEntriesCompanion data) {
    return ProjectEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      path: data.path.present ? data.path.value : this.path,
      defaultProvider: data.defaultProvider.present
          ? data.defaultProvider.value
          : this.defaultProvider,
      revision: data.revision.present ? data.revision.value : this.revision,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectEntry(')
          ..write('agentId: $agentId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('defaultProvider: $defaultProvider, ')
          ..write('revision: $revision, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    agentId,
    id,
    name,
    path,
    defaultProvider,
    revision,
    dataJson,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectEntry &&
          other.agentId == this.agentId &&
          other.id == this.id &&
          other.name == this.name &&
          other.path == this.path &&
          other.defaultProvider == this.defaultProvider &&
          other.revision == this.revision &&
          other.dataJson == this.dataJson &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class ProjectEntriesCompanion extends UpdateCompanion<ProjectEntry> {
  final Value<String> agentId;
  final Value<String> id;
  final Value<String> name;
  final Value<String> path;
  final Value<String> defaultProvider;
  final Value<int?> revision;
  final Value<String> dataJson;
  final Value<DateTime?> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const ProjectEntriesCompanion({
    this.agentId = const Value.absent(),
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.path = const Value.absent(),
    this.defaultProvider = const Value.absent(),
    this.revision = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectEntriesCompanion.insert({
    required String agentId,
    required String id,
    required String name,
    required String path,
    required String defaultProvider,
    this.revision = const Value.absent(),
    required String dataJson,
    this.createdAt = const Value.absent(),
    required DateTime updatedAt,
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       id = Value(id),
       name = Value(name),
       path = Value(path),
       defaultProvider = Value(defaultProvider),
       dataJson = Value(dataJson),
       updatedAt = Value(updatedAt);
  static Insertable<ProjectEntry> custom({
    Expression<String>? agentId,
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? path,
    Expression<String>? defaultProvider,
    Expression<int>? revision,
    Expression<String>? dataJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (path != null) 'path': path,
      if (defaultProvider != null) 'default_provider': defaultProvider,
      if (revision != null) 'revision': revision,
      if (dataJson != null) 'data_json': dataJson,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? id,
    Value<String>? name,
    Value<String>? path,
    Value<String>? defaultProvider,
    Value<int?>? revision,
    Value<String>? dataJson,
    Value<DateTime?>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return ProjectEntriesCompanion(
      agentId: agentId ?? this.agentId,
      id: id ?? this.id,
      name: name ?? this.name,
      path: path ?? this.path,
      defaultProvider: defaultProvider ?? this.defaultProvider,
      revision: revision ?? this.revision,
      dataJson: dataJson ?? this.dataJson,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (defaultProvider.present) {
      map['default_provider'] = Variable<String>(defaultProvider.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('defaultProvider: $defaultProvider, ')
          ..write('revision: $revision, ')
          ..write('dataJson: $dataJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ProviderEntriesTable extends ProviderEntries
    with TableInfo<$ProviderEntriesTable, ProviderEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProviderEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<String> version = GeneratedColumn<String>(
    'version',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _runModeMeta = const VerificationMeta(
    'runMode',
  );
  @override
  late final GeneratedColumn<String> runMode = GeneratedColumn<String>(
    'run_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capabilitiesJsonMeta = const VerificationMeta(
    'capabilitiesJson',
  );
  @override
  late final GeneratedColumn<String> capabilitiesJson = GeneratedColumn<String>(
    'capabilities_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configJsonMeta = const VerificationMeta(
    'configJson',
  );
  @override
  late final GeneratedColumn<String> configJson = GeneratedColumn<String>(
    'config_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _configSchemaJsonMeta = const VerificationMeta(
    'configSchemaJson',
  );
  @override
  late final GeneratedColumn<String> configSchemaJson = GeneratedColumn<String>(
    'config_schema_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    name,
    status,
    version,
    runMode,
    capabilitiesJson,
    configJson,
    configSchemaJson,
    dataJson,
    revision,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'provider_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProviderEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    }
    if (data.containsKey('run_mode')) {
      context.handle(
        _runModeMeta,
        runMode.isAcceptableOrUnknown(data['run_mode']!, _runModeMeta),
      );
    }
    if (data.containsKey('capabilities_json')) {
      context.handle(
        _capabilitiesJsonMeta,
        capabilitiesJson.isAcceptableOrUnknown(
          data['capabilities_json']!,
          _capabilitiesJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_capabilitiesJsonMeta);
    }
    if (data.containsKey('config_json')) {
      context.handle(
        _configJsonMeta,
        configJson.isAcceptableOrUnknown(data['config_json']!, _configJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_configJsonMeta);
    }
    if (data.containsKey('config_schema_json')) {
      context.handle(
        _configSchemaJsonMeta,
        configSchemaJson.isAcceptableOrUnknown(
          data['config_schema_json']!,
          _configSchemaJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_configSchemaJsonMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, name};
  @override
  ProviderEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProviderEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version'],
      ),
      runMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}run_mode'],
      ),
      capabilitiesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}capabilities_json'],
      )!,
      configJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_json'],
      )!,
      configSchemaJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}config_schema_json'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ProviderEntriesTable createAlias(String alias) {
    return $ProviderEntriesTable(attachedDatabase, alias);
  }
}

class ProviderEntry extends DataClass implements Insertable<ProviderEntry> {
  final String agentId;
  final String name;
  final String status;
  final String? version;
  final String? runMode;
  final String capabilitiesJson;
  final String configJson;
  final String configSchemaJson;
  final String dataJson;
  final int? revision;
  final DateTime updatedAt;
  const ProviderEntry({
    required this.agentId,
    required this.name,
    required this.status,
    this.version,
    this.runMode,
    required this.capabilitiesJson,
    required this.configJson,
    required this.configSchemaJson,
    required this.dataJson,
    this.revision,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['name'] = Variable<String>(name);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || version != null) {
      map['version'] = Variable<String>(version);
    }
    if (!nullToAbsent || runMode != null) {
      map['run_mode'] = Variable<String>(runMode);
    }
    map['capabilities_json'] = Variable<String>(capabilitiesJson);
    map['config_json'] = Variable<String>(configJson);
    map['config_schema_json'] = Variable<String>(configSchemaJson);
    map['data_json'] = Variable<String>(dataJson);
    if (!nullToAbsent || revision != null) {
      map['revision'] = Variable<int>(revision);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ProviderEntriesCompanion toCompanion(bool nullToAbsent) {
    return ProviderEntriesCompanion(
      agentId: Value(agentId),
      name: Value(name),
      status: Value(status),
      version: version == null && nullToAbsent
          ? const Value.absent()
          : Value(version),
      runMode: runMode == null && nullToAbsent
          ? const Value.absent()
          : Value(runMode),
      capabilitiesJson: Value(capabilitiesJson),
      configJson: Value(configJson),
      configSchemaJson: Value(configSchemaJson),
      dataJson: Value(dataJson),
      revision: revision == null && nullToAbsent
          ? const Value.absent()
          : Value(revision),
      updatedAt: Value(updatedAt),
    );
  }

  factory ProviderEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProviderEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      name: serializer.fromJson<String>(json['name']),
      status: serializer.fromJson<String>(json['status']),
      version: serializer.fromJson<String?>(json['version']),
      runMode: serializer.fromJson<String?>(json['runMode']),
      capabilitiesJson: serializer.fromJson<String>(json['capabilitiesJson']),
      configJson: serializer.fromJson<String>(json['configJson']),
      configSchemaJson: serializer.fromJson<String>(json['configSchemaJson']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      revision: serializer.fromJson<int?>(json['revision']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'name': serializer.toJson<String>(name),
      'status': serializer.toJson<String>(status),
      'version': serializer.toJson<String?>(version),
      'runMode': serializer.toJson<String?>(runMode),
      'capabilitiesJson': serializer.toJson<String>(capabilitiesJson),
      'configJson': serializer.toJson<String>(configJson),
      'configSchemaJson': serializer.toJson<String>(configSchemaJson),
      'dataJson': serializer.toJson<String>(dataJson),
      'revision': serializer.toJson<int?>(revision),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ProviderEntry copyWith({
    String? agentId,
    String? name,
    String? status,
    Value<String?> version = const Value.absent(),
    Value<String?> runMode = const Value.absent(),
    String? capabilitiesJson,
    String? configJson,
    String? configSchemaJson,
    String? dataJson,
    Value<int?> revision = const Value.absent(),
    DateTime? updatedAt,
  }) => ProviderEntry(
    agentId: agentId ?? this.agentId,
    name: name ?? this.name,
    status: status ?? this.status,
    version: version.present ? version.value : this.version,
    runMode: runMode.present ? runMode.value : this.runMode,
    capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
    configJson: configJson ?? this.configJson,
    configSchemaJson: configSchemaJson ?? this.configSchemaJson,
    dataJson: dataJson ?? this.dataJson,
    revision: revision.present ? revision.value : this.revision,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ProviderEntry copyWithCompanion(ProviderEntriesCompanion data) {
    return ProviderEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      name: data.name.present ? data.name.value : this.name,
      status: data.status.present ? data.status.value : this.status,
      version: data.version.present ? data.version.value : this.version,
      runMode: data.runMode.present ? data.runMode.value : this.runMode,
      capabilitiesJson: data.capabilitiesJson.present
          ? data.capabilitiesJson.value
          : this.capabilitiesJson,
      configJson: data.configJson.present
          ? data.configJson.value
          : this.configJson,
      configSchemaJson: data.configSchemaJson.present
          ? data.configSchemaJson.value
          : this.configSchemaJson,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      revision: data.revision.present ? data.revision.value : this.revision,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProviderEntry(')
          ..write('agentId: $agentId, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('runMode: $runMode, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('configJson: $configJson, ')
          ..write('configSchemaJson: $configSchemaJson, ')
          ..write('dataJson: $dataJson, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    agentId,
    name,
    status,
    version,
    runMode,
    capabilitiesJson,
    configJson,
    configSchemaJson,
    dataJson,
    revision,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProviderEntry &&
          other.agentId == this.agentId &&
          other.name == this.name &&
          other.status == this.status &&
          other.version == this.version &&
          other.runMode == this.runMode &&
          other.capabilitiesJson == this.capabilitiesJson &&
          other.configJson == this.configJson &&
          other.configSchemaJson == this.configSchemaJson &&
          other.dataJson == this.dataJson &&
          other.revision == this.revision &&
          other.updatedAt == this.updatedAt);
}

class ProviderEntriesCompanion extends UpdateCompanion<ProviderEntry> {
  final Value<String> agentId;
  final Value<String> name;
  final Value<String> status;
  final Value<String?> version;
  final Value<String?> runMode;
  final Value<String> capabilitiesJson;
  final Value<String> configJson;
  final Value<String> configSchemaJson;
  final Value<String> dataJson;
  final Value<int?> revision;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ProviderEntriesCompanion({
    this.agentId = const Value.absent(),
    this.name = const Value.absent(),
    this.status = const Value.absent(),
    this.version = const Value.absent(),
    this.runMode = const Value.absent(),
    this.capabilitiesJson = const Value.absent(),
    this.configJson = const Value.absent(),
    this.configSchemaJson = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.revision = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProviderEntriesCompanion.insert({
    required String agentId,
    required String name,
    required String status,
    this.version = const Value.absent(),
    this.runMode = const Value.absent(),
    required String capabilitiesJson,
    required String configJson,
    required String configSchemaJson,
    required String dataJson,
    this.revision = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       name = Value(name),
       status = Value(status),
       capabilitiesJson = Value(capabilitiesJson),
       configJson = Value(configJson),
       configSchemaJson = Value(configSchemaJson),
       dataJson = Value(dataJson),
       updatedAt = Value(updatedAt);
  static Insertable<ProviderEntry> custom({
    Expression<String>? agentId,
    Expression<String>? name,
    Expression<String>? status,
    Expression<String>? version,
    Expression<String>? runMode,
    Expression<String>? capabilitiesJson,
    Expression<String>? configJson,
    Expression<String>? configSchemaJson,
    Expression<String>? dataJson,
    Expression<int>? revision,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (name != null) 'name': name,
      if (status != null) 'status': status,
      if (version != null) 'version': version,
      if (runMode != null) 'run_mode': runMode,
      if (capabilitiesJson != null) 'capabilities_json': capabilitiesJson,
      if (configJson != null) 'config_json': configJson,
      if (configSchemaJson != null) 'config_schema_json': configSchemaJson,
      if (dataJson != null) 'data_json': dataJson,
      if (revision != null) 'revision': revision,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProviderEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? name,
    Value<String>? status,
    Value<String?>? version,
    Value<String?>? runMode,
    Value<String>? capabilitiesJson,
    Value<String>? configJson,
    Value<String>? configSchemaJson,
    Value<String>? dataJson,
    Value<int?>? revision,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return ProviderEntriesCompanion(
      agentId: agentId ?? this.agentId,
      name: name ?? this.name,
      status: status ?? this.status,
      version: version ?? this.version,
      runMode: runMode ?? this.runMode,
      capabilitiesJson: capabilitiesJson ?? this.capabilitiesJson,
      configJson: configJson ?? this.configJson,
      configSchemaJson: configSchemaJson ?? this.configSchemaJson,
      dataJson: dataJson ?? this.dataJson,
      revision: revision ?? this.revision,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (version.present) {
      map['version'] = Variable<String>(version.value);
    }
    if (runMode.present) {
      map['run_mode'] = Variable<String>(runMode.value);
    }
    if (capabilitiesJson.present) {
      map['capabilities_json'] = Variable<String>(capabilitiesJson.value);
    }
    if (configJson.present) {
      map['config_json'] = Variable<String>(configJson.value);
    }
    if (configSchemaJson.present) {
      map['config_schema_json'] = Variable<String>(configSchemaJson.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProviderEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('name: $name, ')
          ..write('status: $status, ')
          ..write('version: $version, ')
          ..write('runMode: $runMode, ')
          ..write('capabilitiesJson: $capabilitiesJson, ')
          ..write('configJson: $configJson, ')
          ..write('configSchemaJson: $configSchemaJson, ')
          ..write('dataJson: $dataJson, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionEntriesTable extends SessionEntries
    with TableInfo<$SessionEntriesTable, SessionEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerIdMeta = const VerificationMeta(
    'providerId',
  );
  @override
  late final GeneratedColumn<String> providerId = GeneratedColumn<String>(
    'provider_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _threadIdMeta = const VerificationMeta(
    'threadId',
  );
  @override
  late final GeneratedColumn<String> threadId = GeneratedColumn<String>(
    'thread_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _workdirMeta = const VerificationMeta(
    'workdir',
  );
  @override
  late final GeneratedColumn<String> workdir = GeneratedColumn<String>(
    'workdir',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('stopped'),
  );
  static const VerificationMeta _modelMeta = const VerificationMeta('model');
  @override
  late final GeneratedColumn<String> model = GeneratedColumn<String>(
    'model',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _effortMeta = const VerificationMeta('effort');
  @override
  late final GeneratedColumn<String> effort = GeneratedColumn<String>(
    'effort',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _approvalPolicyMeta = const VerificationMeta(
    'approvalPolicy',
  );
  @override
  late final GeneratedColumn<String> approvalPolicy = GeneratedColumn<String>(
    'approval_policy',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sandboxModeMeta = const VerificationMeta(
    'sandboxMode',
  );
  @override
  late final GeneratedColumn<String> sandboxMode = GeneratedColumn<String>(
    'sandbox_mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _providerCursorMeta = const VerificationMeta(
    'providerCursor',
  );
  @override
  late final GeneratedColumn<String> providerCursor = GeneratedColumn<String>(
    'provider_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _listRevisionMeta = const VerificationMeta(
    'listRevision',
  );
  @override
  late final GeneratedColumn<int> listRevision = GeneratedColumn<int>(
    'list_revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archivedAtMeta = const VerificationMeta(
    'archivedAt',
  );
  @override
  late final GeneratedColumn<DateTime> archivedAt = GeneratedColumn<DateTime>(
    'archived_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    id,
    providerId,
    threadId,
    projectId,
    workdir,
    title,
    status,
    model,
    effort,
    approvalPolicy,
    sandboxMode,
    providerCursor,
    listRevision,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('provider_id')) {
      context.handle(
        _providerIdMeta,
        providerId.isAcceptableOrUnknown(data['provider_id']!, _providerIdMeta),
      );
    } else if (isInserting) {
      context.missing(_providerIdMeta);
    }
    if (data.containsKey('thread_id')) {
      context.handle(
        _threadIdMeta,
        threadId.isAcceptableOrUnknown(data['thread_id']!, _threadIdMeta),
      );
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('workdir')) {
      context.handle(
        _workdirMeta,
        workdir.isAcceptableOrUnknown(data['workdir']!, _workdirMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('model')) {
      context.handle(
        _modelMeta,
        model.isAcceptableOrUnknown(data['model']!, _modelMeta),
      );
    }
    if (data.containsKey('effort')) {
      context.handle(
        _effortMeta,
        effort.isAcceptableOrUnknown(data['effort']!, _effortMeta),
      );
    }
    if (data.containsKey('approval_policy')) {
      context.handle(
        _approvalPolicyMeta,
        approvalPolicy.isAcceptableOrUnknown(
          data['approval_policy']!,
          _approvalPolicyMeta,
        ),
      );
    }
    if (data.containsKey('sandbox_mode')) {
      context.handle(
        _sandboxModeMeta,
        sandboxMode.isAcceptableOrUnknown(
          data['sandbox_mode']!,
          _sandboxModeMeta,
        ),
      );
    }
    if (data.containsKey('provider_cursor')) {
      context.handle(
        _providerCursorMeta,
        providerCursor.isAcceptableOrUnknown(
          data['provider_cursor']!,
          _providerCursorMeta,
        ),
      );
    }
    if (data.containsKey('list_revision')) {
      context.handle(
        _listRevisionMeta,
        listRevision.isAcceptableOrUnknown(
          data['list_revision']!,
          _listRevisionMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('archived_at')) {
      context.handle(
        _archivedAtMeta,
        archivedAt.isAcceptableOrUnknown(data['archived_at']!, _archivedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, id};
  @override
  SessionEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      providerId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_id'],
      )!,
      threadId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}thread_id'],
      ),
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      workdir: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}workdir'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      model: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}model'],
      ),
      effort: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}effort'],
      ),
      approvalPolicy: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approval_policy'],
      ),
      sandboxMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sandbox_mode'],
      ),
      providerCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_cursor'],
      ),
      listRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}list_revision'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      archivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}archived_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $SessionEntriesTable createAlias(String alias) {
    return $SessionEntriesTable(attachedDatabase, alias);
  }
}

class SessionEntry extends DataClass implements Insertable<SessionEntry> {
  final String agentId;
  final String id;
  final String providerId;
  final String? threadId;
  final String projectId;
  final String? workdir;
  final String? title;
  final String status;
  final String? model;
  final String? effort;
  final String? approvalPolicy;
  final String? sandboxMode;
  final String? providerCursor;
  final int? listRevision;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  const SessionEntry({
    required this.agentId,
    required this.id,
    required this.providerId,
    this.threadId,
    required this.projectId,
    this.workdir,
    this.title,
    required this.status,
    this.model,
    this.effort,
    this.approvalPolicy,
    this.sandboxMode,
    this.providerCursor,
    this.listRevision,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['id'] = Variable<String>(id);
    map['provider_id'] = Variable<String>(providerId);
    if (!nullToAbsent || threadId != null) {
      map['thread_id'] = Variable<String>(threadId);
    }
    map['project_id'] = Variable<String>(projectId);
    if (!nullToAbsent || workdir != null) {
      map['workdir'] = Variable<String>(workdir);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || model != null) {
      map['model'] = Variable<String>(model);
    }
    if (!nullToAbsent || effort != null) {
      map['effort'] = Variable<String>(effort);
    }
    if (!nullToAbsent || approvalPolicy != null) {
      map['approval_policy'] = Variable<String>(approvalPolicy);
    }
    if (!nullToAbsent || sandboxMode != null) {
      map['sandbox_mode'] = Variable<String>(sandboxMode);
    }
    if (!nullToAbsent || providerCursor != null) {
      map['provider_cursor'] = Variable<String>(providerCursor);
    }
    if (!nullToAbsent || listRevision != null) {
      map['list_revision'] = Variable<int>(listRevision);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || archivedAt != null) {
      map['archived_at'] = Variable<DateTime>(archivedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  SessionEntriesCompanion toCompanion(bool nullToAbsent) {
    return SessionEntriesCompanion(
      agentId: Value(agentId),
      id: Value(id),
      providerId: Value(providerId),
      threadId: threadId == null && nullToAbsent
          ? const Value.absent()
          : Value(threadId),
      projectId: Value(projectId),
      workdir: workdir == null && nullToAbsent
          ? const Value.absent()
          : Value(workdir),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      status: Value(status),
      model: model == null && nullToAbsent
          ? const Value.absent()
          : Value(model),
      effort: effort == null && nullToAbsent
          ? const Value.absent()
          : Value(effort),
      approvalPolicy: approvalPolicy == null && nullToAbsent
          ? const Value.absent()
          : Value(approvalPolicy),
      sandboxMode: sandboxMode == null && nullToAbsent
          ? const Value.absent()
          : Value(sandboxMode),
      providerCursor: providerCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(providerCursor),
      listRevision: listRevision == null && nullToAbsent
          ? const Value.absent()
          : Value(listRevision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      archivedAt: archivedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory SessionEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      id: serializer.fromJson<String>(json['id']),
      providerId: serializer.fromJson<String>(json['providerId']),
      threadId: serializer.fromJson<String?>(json['threadId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      workdir: serializer.fromJson<String?>(json['workdir']),
      title: serializer.fromJson<String?>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      model: serializer.fromJson<String?>(json['model']),
      effort: serializer.fromJson<String?>(json['effort']),
      approvalPolicy: serializer.fromJson<String?>(json['approvalPolicy']),
      sandboxMode: serializer.fromJson<String?>(json['sandboxMode']),
      providerCursor: serializer.fromJson<String?>(json['providerCursor']),
      listRevision: serializer.fromJson<int?>(json['listRevision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      archivedAt: serializer.fromJson<DateTime?>(json['archivedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'id': serializer.toJson<String>(id),
      'providerId': serializer.toJson<String>(providerId),
      'threadId': serializer.toJson<String?>(threadId),
      'projectId': serializer.toJson<String>(projectId),
      'workdir': serializer.toJson<String?>(workdir),
      'title': serializer.toJson<String?>(title),
      'status': serializer.toJson<String>(status),
      'model': serializer.toJson<String?>(model),
      'effort': serializer.toJson<String?>(effort),
      'approvalPolicy': serializer.toJson<String?>(approvalPolicy),
      'sandboxMode': serializer.toJson<String?>(sandboxMode),
      'providerCursor': serializer.toJson<String?>(providerCursor),
      'listRevision': serializer.toJson<int?>(listRevision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'archivedAt': serializer.toJson<DateTime?>(archivedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  SessionEntry copyWith({
    String? agentId,
    String? id,
    String? providerId,
    Value<String?> threadId = const Value.absent(),
    String? projectId,
    Value<String?> workdir = const Value.absent(),
    Value<String?> title = const Value.absent(),
    String? status,
    Value<String?> model = const Value.absent(),
    Value<String?> effort = const Value.absent(),
    Value<String?> approvalPolicy = const Value.absent(),
    Value<String?> sandboxMode = const Value.absent(),
    Value<String?> providerCursor = const Value.absent(),
    Value<int?> listRevision = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> archivedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => SessionEntry(
    agentId: agentId ?? this.agentId,
    id: id ?? this.id,
    providerId: providerId ?? this.providerId,
    threadId: threadId.present ? threadId.value : this.threadId,
    projectId: projectId ?? this.projectId,
    workdir: workdir.present ? workdir.value : this.workdir,
    title: title.present ? title.value : this.title,
    status: status ?? this.status,
    model: model.present ? model.value : this.model,
    effort: effort.present ? effort.value : this.effort,
    approvalPolicy: approvalPolicy.present
        ? approvalPolicy.value
        : this.approvalPolicy,
    sandboxMode: sandboxMode.present ? sandboxMode.value : this.sandboxMode,
    providerCursor: providerCursor.present
        ? providerCursor.value
        : this.providerCursor,
    listRevision: listRevision.present ? listRevision.value : this.listRevision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt.present ? archivedAt.value : this.archivedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  SessionEntry copyWithCompanion(SessionEntriesCompanion data) {
    return SessionEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      id: data.id.present ? data.id.value : this.id,
      providerId: data.providerId.present
          ? data.providerId.value
          : this.providerId,
      threadId: data.threadId.present ? data.threadId.value : this.threadId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      workdir: data.workdir.present ? data.workdir.value : this.workdir,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      model: data.model.present ? data.model.value : this.model,
      effort: data.effort.present ? data.effort.value : this.effort,
      approvalPolicy: data.approvalPolicy.present
          ? data.approvalPolicy.value
          : this.approvalPolicy,
      sandboxMode: data.sandboxMode.present
          ? data.sandboxMode.value
          : this.sandboxMode,
      providerCursor: data.providerCursor.present
          ? data.providerCursor.value
          : this.providerCursor,
      listRevision: data.listRevision.present
          ? data.listRevision.value
          : this.listRevision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      archivedAt: data.archivedAt.present
          ? data.archivedAt.value
          : this.archivedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionEntry(')
          ..write('agentId: $agentId, ')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('threadId: $threadId, ')
          ..write('projectId: $projectId, ')
          ..write('workdir: $workdir, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('model: $model, ')
          ..write('effort: $effort, ')
          ..write('approvalPolicy: $approvalPolicy, ')
          ..write('sandboxMode: $sandboxMode, ')
          ..write('providerCursor: $providerCursor, ')
          ..write('listRevision: $listRevision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    agentId,
    id,
    providerId,
    threadId,
    projectId,
    workdir,
    title,
    status,
    model,
    effort,
    approvalPolicy,
    sandboxMode,
    providerCursor,
    listRevision,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionEntry &&
          other.agentId == this.agentId &&
          other.id == this.id &&
          other.providerId == this.providerId &&
          other.threadId == this.threadId &&
          other.projectId == this.projectId &&
          other.workdir == this.workdir &&
          other.title == this.title &&
          other.status == this.status &&
          other.model == this.model &&
          other.effort == this.effort &&
          other.approvalPolicy == this.approvalPolicy &&
          other.sandboxMode == this.sandboxMode &&
          other.providerCursor == this.providerCursor &&
          other.listRevision == this.listRevision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.archivedAt == this.archivedAt &&
          other.deletedAt == this.deletedAt);
}

class SessionEntriesCompanion extends UpdateCompanion<SessionEntry> {
  final Value<String> agentId;
  final Value<String> id;
  final Value<String> providerId;
  final Value<String?> threadId;
  final Value<String> projectId;
  final Value<String?> workdir;
  final Value<String?> title;
  final Value<String> status;
  final Value<String?> model;
  final Value<String?> effort;
  final Value<String?> approvalPolicy;
  final Value<String?> sandboxMode;
  final Value<String?> providerCursor;
  final Value<int?> listRevision;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> archivedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> rowid;
  const SessionEntriesCompanion({
    this.agentId = const Value.absent(),
    this.id = const Value.absent(),
    this.providerId = const Value.absent(),
    this.threadId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.workdir = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.model = const Value.absent(),
    this.effort = const Value.absent(),
    this.approvalPolicy = const Value.absent(),
    this.sandboxMode = const Value.absent(),
    this.providerCursor = const Value.absent(),
    this.listRevision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionEntriesCompanion.insert({
    required String agentId,
    required String id,
    required String providerId,
    this.threadId = const Value.absent(),
    required String projectId,
    this.workdir = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.model = const Value.absent(),
    this.effort = const Value.absent(),
    this.approvalPolicy = const Value.absent(),
    this.sandboxMode = const Value.absent(),
    this.providerCursor = const Value.absent(),
    this.listRevision = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.archivedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       id = Value(id),
       providerId = Value(providerId),
       projectId = Value(projectId),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SessionEntry> custom({
    Expression<String>? agentId,
    Expression<String>? id,
    Expression<String>? providerId,
    Expression<String>? threadId,
    Expression<String>? projectId,
    Expression<String>? workdir,
    Expression<String>? title,
    Expression<String>? status,
    Expression<String>? model,
    Expression<String>? effort,
    Expression<String>? approvalPolicy,
    Expression<String>? sandboxMode,
    Expression<String>? providerCursor,
    Expression<int>? listRevision,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? archivedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (id != null) 'id': id,
      if (providerId != null) 'provider_id': providerId,
      if (threadId != null) 'thread_id': threadId,
      if (projectId != null) 'project_id': projectId,
      if (workdir != null) 'workdir': workdir,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (model != null) 'model': model,
      if (effort != null) 'effort': effort,
      if (approvalPolicy != null) 'approval_policy': approvalPolicy,
      if (sandboxMode != null) 'sandbox_mode': sandboxMode,
      if (providerCursor != null) 'provider_cursor': providerCursor,
      if (listRevision != null) 'list_revision': listRevision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (archivedAt != null) 'archived_at': archivedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? id,
    Value<String>? providerId,
    Value<String?>? threadId,
    Value<String>? projectId,
    Value<String?>? workdir,
    Value<String?>? title,
    Value<String>? status,
    Value<String?>? model,
    Value<String?>? effort,
    Value<String?>? approvalPolicy,
    Value<String?>? sandboxMode,
    Value<String?>? providerCursor,
    Value<int?>? listRevision,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? archivedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? rowid,
  }) {
    return SessionEntriesCompanion(
      agentId: agentId ?? this.agentId,
      id: id ?? this.id,
      providerId: providerId ?? this.providerId,
      threadId: threadId ?? this.threadId,
      projectId: projectId ?? this.projectId,
      workdir: workdir ?? this.workdir,
      title: title ?? this.title,
      status: status ?? this.status,
      model: model ?? this.model,
      effort: effort ?? this.effort,
      approvalPolicy: approvalPolicy ?? this.approvalPolicy,
      sandboxMode: sandboxMode ?? this.sandboxMode,
      providerCursor: providerCursor ?? this.providerCursor,
      listRevision: listRevision ?? this.listRevision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      archivedAt: archivedAt ?? this.archivedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (providerId.present) {
      map['provider_id'] = Variable<String>(providerId.value);
    }
    if (threadId.present) {
      map['thread_id'] = Variable<String>(threadId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (workdir.present) {
      map['workdir'] = Variable<String>(workdir.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (model.present) {
      map['model'] = Variable<String>(model.value);
    }
    if (effort.present) {
      map['effort'] = Variable<String>(effort.value);
    }
    if (approvalPolicy.present) {
      map['approval_policy'] = Variable<String>(approvalPolicy.value);
    }
    if (sandboxMode.present) {
      map['sandbox_mode'] = Variable<String>(sandboxMode.value);
    }
    if (providerCursor.present) {
      map['provider_cursor'] = Variable<String>(providerCursor.value);
    }
    if (listRevision.present) {
      map['list_revision'] = Variable<int>(listRevision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (archivedAt.present) {
      map['archived_at'] = Variable<DateTime>(archivedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('id: $id, ')
          ..write('providerId: $providerId, ')
          ..write('threadId: $threadId, ')
          ..write('projectId: $projectId, ')
          ..write('workdir: $workdir, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('model: $model, ')
          ..write('effort: $effort, ')
          ..write('approvalPolicy: $approvalPolicy, ')
          ..write('sandboxMode: $sandboxMode, ')
          ..write('providerCursor: $providerCursor, ')
          ..write('listRevision: $listRevision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('archivedAt: $archivedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionEventEntriesTable extends SessionEventEntries
    with TableInfo<$SessionEventEntriesTable, SessionEventEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionEventEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _providerCursorMeta = const VerificationMeta(
    'providerCursor',
  );
  @override
  late final GeneratedColumn<String> providerCursor = GeneratedColumn<String>(
    'provider_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _turnIdMeta = const VerificationMeta('turnId');
  @override
  late final GeneratedColumn<String> turnId = GeneratedColumn<String>(
    'turn_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dataMeta = const VerificationMeta('data');
  @override
  late final GeneratedColumn<String> data = GeneratedColumn<String>(
    'data',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    agentId,
    sessionId,
    providerCursor,
    type,
    itemId,
    turnId,
    data,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_event_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionEventEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('provider_cursor')) {
      context.handle(
        _providerCursorMeta,
        providerCursor.isAcceptableOrUnknown(
          data['provider_cursor']!,
          _providerCursorMeta,
        ),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('turn_id')) {
      context.handle(
        _turnIdMeta,
        turnId.isAcceptableOrUnknown(data['turn_id']!, _turnIdMeta),
      );
    }
    if (data.containsKey('data')) {
      context.handle(
        _dataMeta,
        this.data.isAcceptableOrUnknown(data['data']!, _dataMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionEventEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionEventEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      providerCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_cursor'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      turnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_id'],
      ),
      data: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SessionEventEntriesTable createAlias(String alias) {
    return $SessionEventEntriesTable(attachedDatabase, alias);
  }
}

class SessionEventEntry extends DataClass
    implements Insertable<SessionEventEntry> {
  final int id;
  final String agentId;
  final String sessionId;
  final String? providerCursor;
  final String type;
  final String? itemId;
  final String? turnId;
  final String data;
  final DateTime createdAt;
  const SessionEventEntry({
    required this.id,
    required this.agentId,
    required this.sessionId,
    this.providerCursor,
    required this.type,
    this.itemId,
    this.turnId,
    required this.data,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['agent_id'] = Variable<String>(agentId);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || providerCursor != null) {
      map['provider_cursor'] = Variable<String>(providerCursor);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    if (!nullToAbsent || turnId != null) {
      map['turn_id'] = Variable<String>(turnId);
    }
    map['data'] = Variable<String>(data);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SessionEventEntriesCompanion toCompanion(bool nullToAbsent) {
    return SessionEventEntriesCompanion(
      id: Value(id),
      agentId: Value(agentId),
      sessionId: Value(sessionId),
      providerCursor: providerCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(providerCursor),
      type: Value(type),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      turnId: turnId == null && nullToAbsent
          ? const Value.absent()
          : Value(turnId),
      data: Value(data),
      createdAt: Value(createdAt),
    );
  }

  factory SessionEventEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionEventEntry(
      id: serializer.fromJson<int>(json['id']),
      agentId: serializer.fromJson<String>(json['agentId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      providerCursor: serializer.fromJson<String?>(json['providerCursor']),
      type: serializer.fromJson<String>(json['type']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      turnId: serializer.fromJson<String?>(json['turnId']),
      data: serializer.fromJson<String>(json['data']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'agentId': serializer.toJson<String>(agentId),
      'sessionId': serializer.toJson<String>(sessionId),
      'providerCursor': serializer.toJson<String?>(providerCursor),
      'type': serializer.toJson<String>(type),
      'itemId': serializer.toJson<String?>(itemId),
      'turnId': serializer.toJson<String?>(turnId),
      'data': serializer.toJson<String>(data),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SessionEventEntry copyWith({
    int? id,
    String? agentId,
    String? sessionId,
    Value<String?> providerCursor = const Value.absent(),
    String? type,
    Value<String?> itemId = const Value.absent(),
    Value<String?> turnId = const Value.absent(),
    String? data,
    DateTime? createdAt,
  }) => SessionEventEntry(
    id: id ?? this.id,
    agentId: agentId ?? this.agentId,
    sessionId: sessionId ?? this.sessionId,
    providerCursor: providerCursor.present
        ? providerCursor.value
        : this.providerCursor,
    type: type ?? this.type,
    itemId: itemId.present ? itemId.value : this.itemId,
    turnId: turnId.present ? turnId.value : this.turnId,
    data: data ?? this.data,
    createdAt: createdAt ?? this.createdAt,
  );
  SessionEventEntry copyWithCompanion(SessionEventEntriesCompanion data) {
    return SessionEventEntry(
      id: data.id.present ? data.id.value : this.id,
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      providerCursor: data.providerCursor.present
          ? data.providerCursor.value
          : this.providerCursor,
      type: data.type.present ? data.type.value : this.type,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      turnId: data.turnId.present ? data.turnId.value : this.turnId,
      data: data.data.present ? data.data.value : this.data,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionEventEntry(')
          ..write('id: $id, ')
          ..write('agentId: $agentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('providerCursor: $providerCursor, ')
          ..write('type: $type, ')
          ..write('itemId: $itemId, ')
          ..write('turnId: $turnId, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    agentId,
    sessionId,
    providerCursor,
    type,
    itemId,
    turnId,
    data,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionEventEntry &&
          other.id == this.id &&
          other.agentId == this.agentId &&
          other.sessionId == this.sessionId &&
          other.providerCursor == this.providerCursor &&
          other.type == this.type &&
          other.itemId == this.itemId &&
          other.turnId == this.turnId &&
          other.data == this.data &&
          other.createdAt == this.createdAt);
}

class SessionEventEntriesCompanion extends UpdateCompanion<SessionEventEntry> {
  final Value<int> id;
  final Value<String> agentId;
  final Value<String> sessionId;
  final Value<String?> providerCursor;
  final Value<String> type;
  final Value<String?> itemId;
  final Value<String?> turnId;
  final Value<String> data;
  final Value<DateTime> createdAt;
  const SessionEventEntriesCompanion({
    this.id = const Value.absent(),
    this.agentId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.providerCursor = const Value.absent(),
    this.type = const Value.absent(),
    this.itemId = const Value.absent(),
    this.turnId = const Value.absent(),
    this.data = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SessionEventEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String agentId,
    required String sessionId,
    this.providerCursor = const Value.absent(),
    required String type,
    this.itemId = const Value.absent(),
    this.turnId = const Value.absent(),
    this.data = const Value.absent(),
    required DateTime createdAt,
  }) : agentId = Value(agentId),
       sessionId = Value(sessionId),
       type = Value(type),
       createdAt = Value(createdAt);
  static Insertable<SessionEventEntry> custom({
    Expression<int>? id,
    Expression<String>? agentId,
    Expression<String>? sessionId,
    Expression<String>? providerCursor,
    Expression<String>? type,
    Expression<String>? itemId,
    Expression<String>? turnId,
    Expression<String>? data,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (agentId != null) 'agent_id': agentId,
      if (sessionId != null) 'session_id': sessionId,
      if (providerCursor != null) 'provider_cursor': providerCursor,
      if (type != null) 'type': type,
      if (itemId != null) 'item_id': itemId,
      if (turnId != null) 'turn_id': turnId,
      if (data != null) 'data': data,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SessionEventEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? agentId,
    Value<String>? sessionId,
    Value<String?>? providerCursor,
    Value<String>? type,
    Value<String?>? itemId,
    Value<String?>? turnId,
    Value<String>? data,
    Value<DateTime>? createdAt,
  }) {
    return SessionEventEntriesCompanion(
      id: id ?? this.id,
      agentId: agentId ?? this.agentId,
      sessionId: sessionId ?? this.sessionId,
      providerCursor: providerCursor ?? this.providerCursor,
      type: type ?? this.type,
      itemId: itemId ?? this.itemId,
      turnId: turnId ?? this.turnId,
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (providerCursor.present) {
      map['provider_cursor'] = Variable<String>(providerCursor.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (turnId.present) {
      map['turn_id'] = Variable<String>(turnId.value);
    }
    if (data.present) {
      map['data'] = Variable<String>(data.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionEventEntriesCompanion(')
          ..write('id: $id, ')
          ..write('agentId: $agentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('providerCursor: $providerCursor, ')
          ..write('type: $type, ')
          ..write('itemId: $itemId, ')
          ..write('turnId: $turnId, ')
          ..write('data: $data, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SessionItemEntriesTable extends SessionItemEntries
    with TableInfo<$SessionItemEntriesTable, SessionItemEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionItemEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _turnIdMeta = const VerificationMeta('turnId');
  @override
  late final GeneratedColumn<String> turnId = GeneratedColumn<String>(
    'turn_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _providerCursorMeta = const VerificationMeta(
    'providerCursor',
  );
  @override
  late final GeneratedColumn<String> providerCursor = GeneratedColumn<String>(
    'provider_cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    sessionId,
    itemId,
    turnId,
    type,
    status,
    role,
    summary,
    content,
    providerCursor,
    revision,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_item_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionItemEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('turn_id')) {
      context.handle(
        _turnIdMeta,
        turnId.isAcceptableOrUnknown(data['turn_id']!, _turnIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    }
    if (data.containsKey('provider_cursor')) {
      context.handle(
        _providerCursorMeta,
        providerCursor.isAcceptableOrUnknown(
          data['provider_cursor']!,
          _providerCursorMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, sessionId, itemId};
  @override
  SessionItemEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionItemEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      turnId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}turn_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      providerCursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}provider_cursor'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SessionItemEntriesTable createAlias(String alias) {
    return $SessionItemEntriesTable(attachedDatabase, alias);
  }
}

class SessionItemEntry extends DataClass
    implements Insertable<SessionItemEntry> {
  final String agentId;
  final String sessionId;
  final String itemId;
  final String? turnId;
  final String type;
  final String? status;
  final String? role;
  final String? summary;
  final String content;
  final String? providerCursor;
  final int? revision;
  final DateTime createdAt;
  final DateTime updatedAt;
  const SessionItemEntry({
    required this.agentId,
    required this.sessionId,
    required this.itemId,
    this.turnId,
    required this.type,
    this.status,
    this.role,
    this.summary,
    required this.content,
    this.providerCursor,
    this.revision,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['session_id'] = Variable<String>(sessionId);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || turnId != null) {
      map['turn_id'] = Variable<String>(turnId);
    }
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || status != null) {
      map['status'] = Variable<String>(status);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || providerCursor != null) {
      map['provider_cursor'] = Variable<String>(providerCursor);
    }
    if (!nullToAbsent || revision != null) {
      map['revision'] = Variable<int>(revision);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SessionItemEntriesCompanion toCompanion(bool nullToAbsent) {
    return SessionItemEntriesCompanion(
      agentId: Value(agentId),
      sessionId: Value(sessionId),
      itemId: Value(itemId),
      turnId: turnId == null && nullToAbsent
          ? const Value.absent()
          : Value(turnId),
      type: Value(type),
      status: status == null && nullToAbsent
          ? const Value.absent()
          : Value(status),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      content: Value(content),
      providerCursor: providerCursor == null && nullToAbsent
          ? const Value.absent()
          : Value(providerCursor),
      revision: revision == null && nullToAbsent
          ? const Value.absent()
          : Value(revision),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory SessionItemEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionItemEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      itemId: serializer.fromJson<String>(json['itemId']),
      turnId: serializer.fromJson<String?>(json['turnId']),
      type: serializer.fromJson<String>(json['type']),
      status: serializer.fromJson<String?>(json['status']),
      role: serializer.fromJson<String?>(json['role']),
      summary: serializer.fromJson<String?>(json['summary']),
      content: serializer.fromJson<String>(json['content']),
      providerCursor: serializer.fromJson<String?>(json['providerCursor']),
      revision: serializer.fromJson<int?>(json['revision']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'sessionId': serializer.toJson<String>(sessionId),
      'itemId': serializer.toJson<String>(itemId),
      'turnId': serializer.toJson<String?>(turnId),
      'type': serializer.toJson<String>(type),
      'status': serializer.toJson<String?>(status),
      'role': serializer.toJson<String?>(role),
      'summary': serializer.toJson<String?>(summary),
      'content': serializer.toJson<String>(content),
      'providerCursor': serializer.toJson<String?>(providerCursor),
      'revision': serializer.toJson<int?>(revision),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SessionItemEntry copyWith({
    String? agentId,
    String? sessionId,
    String? itemId,
    Value<String?> turnId = const Value.absent(),
    String? type,
    Value<String?> status = const Value.absent(),
    Value<String?> role = const Value.absent(),
    Value<String?> summary = const Value.absent(),
    String? content,
    Value<String?> providerCursor = const Value.absent(),
    Value<int?> revision = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => SessionItemEntry(
    agentId: agentId ?? this.agentId,
    sessionId: sessionId ?? this.sessionId,
    itemId: itemId ?? this.itemId,
    turnId: turnId.present ? turnId.value : this.turnId,
    type: type ?? this.type,
    status: status.present ? status.value : this.status,
    role: role.present ? role.value : this.role,
    summary: summary.present ? summary.value : this.summary,
    content: content ?? this.content,
    providerCursor: providerCursor.present
        ? providerCursor.value
        : this.providerCursor,
    revision: revision.present ? revision.value : this.revision,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SessionItemEntry copyWithCompanion(SessionItemEntriesCompanion data) {
    return SessionItemEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      turnId: data.turnId.present ? data.turnId.value : this.turnId,
      type: data.type.present ? data.type.value : this.type,
      status: data.status.present ? data.status.value : this.status,
      role: data.role.present ? data.role.value : this.role,
      summary: data.summary.present ? data.summary.value : this.summary,
      content: data.content.present ? data.content.value : this.content,
      providerCursor: data.providerCursor.present
          ? data.providerCursor.value
          : this.providerCursor,
      revision: data.revision.present ? data.revision.value : this.revision,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionItemEntry(')
          ..write('agentId: $agentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('itemId: $itemId, ')
          ..write('turnId: $turnId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('role: $role, ')
          ..write('summary: $summary, ')
          ..write('content: $content, ')
          ..write('providerCursor: $providerCursor, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    agentId,
    sessionId,
    itemId,
    turnId,
    type,
    status,
    role,
    summary,
    content,
    providerCursor,
    revision,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionItemEntry &&
          other.agentId == this.agentId &&
          other.sessionId == this.sessionId &&
          other.itemId == this.itemId &&
          other.turnId == this.turnId &&
          other.type == this.type &&
          other.status == this.status &&
          other.role == this.role &&
          other.summary == this.summary &&
          other.content == this.content &&
          other.providerCursor == this.providerCursor &&
          other.revision == this.revision &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SessionItemEntriesCompanion extends UpdateCompanion<SessionItemEntry> {
  final Value<String> agentId;
  final Value<String> sessionId;
  final Value<String> itemId;
  final Value<String?> turnId;
  final Value<String> type;
  final Value<String?> status;
  final Value<String?> role;
  final Value<String?> summary;
  final Value<String> content;
  final Value<String?> providerCursor;
  final Value<int?> revision;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SessionItemEntriesCompanion({
    this.agentId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.turnId = const Value.absent(),
    this.type = const Value.absent(),
    this.status = const Value.absent(),
    this.role = const Value.absent(),
    this.summary = const Value.absent(),
    this.content = const Value.absent(),
    this.providerCursor = const Value.absent(),
    this.revision = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionItemEntriesCompanion.insert({
    required String agentId,
    required String sessionId,
    required String itemId,
    this.turnId = const Value.absent(),
    required String type,
    this.status = const Value.absent(),
    this.role = const Value.absent(),
    this.summary = const Value.absent(),
    this.content = const Value.absent(),
    this.providerCursor = const Value.absent(),
    this.revision = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       sessionId = Value(sessionId),
       itemId = Value(itemId),
       type = Value(type),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<SessionItemEntry> custom({
    Expression<String>? agentId,
    Expression<String>? sessionId,
    Expression<String>? itemId,
    Expression<String>? turnId,
    Expression<String>? type,
    Expression<String>? status,
    Expression<String>? role,
    Expression<String>? summary,
    Expression<String>? content,
    Expression<String>? providerCursor,
    Expression<int>? revision,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (sessionId != null) 'session_id': sessionId,
      if (itemId != null) 'item_id': itemId,
      if (turnId != null) 'turn_id': turnId,
      if (type != null) 'type': type,
      if (status != null) 'status': status,
      if (role != null) 'role': role,
      if (summary != null) 'summary': summary,
      if (content != null) 'content': content,
      if (providerCursor != null) 'provider_cursor': providerCursor,
      if (revision != null) 'revision': revision,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionItemEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? sessionId,
    Value<String>? itemId,
    Value<String?>? turnId,
    Value<String>? type,
    Value<String?>? status,
    Value<String?>? role,
    Value<String?>? summary,
    Value<String>? content,
    Value<String?>? providerCursor,
    Value<int?>? revision,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SessionItemEntriesCompanion(
      agentId: agentId ?? this.agentId,
      sessionId: sessionId ?? this.sessionId,
      itemId: itemId ?? this.itemId,
      turnId: turnId ?? this.turnId,
      type: type ?? this.type,
      status: status ?? this.status,
      role: role ?? this.role,
      summary: summary ?? this.summary,
      content: content ?? this.content,
      providerCursor: providerCursor ?? this.providerCursor,
      revision: revision ?? this.revision,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (turnId.present) {
      map['turn_id'] = Variable<String>(turnId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (providerCursor.present) {
      map['provider_cursor'] = Variable<String>(providerCursor.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionItemEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('sessionId: $sessionId, ')
          ..write('itemId: $itemId, ')
          ..write('turnId: $turnId, ')
          ..write('type: $type, ')
          ..write('status: $status, ')
          ..write('role: $role, ')
          ..write('summary: $summary, ')
          ..write('content: $content, ')
          ..write('providerCursor: $providerCursor, ')
          ..write('revision: $revision, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingApprovalEntriesTable extends PendingApprovalEntries
    with TableInfo<$PendingApprovalEntriesTable, PendingApprovalEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingApprovalEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _approvalIdMeta = const VerificationMeta(
    'approvalId',
  );
  @override
  late final GeneratedColumn<String> approvalId = GeneratedColumn<String>(
    'approval_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _requestJsonMeta = const VerificationMeta(
    'requestJson',
  );
  @override
  late final GeneratedColumn<String> requestJson = GeneratedColumn<String>(
    'request_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<DateTime> resolvedAt = GeneratedColumn<DateTime>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    approvalId,
    sessionId,
    itemId,
    type,
    requestJson,
    status,
    createdAt,
    resolvedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_approval_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingApprovalEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('approval_id')) {
      context.handle(
        _approvalIdMeta,
        approvalId.isAcceptableOrUnknown(data['approval_id']!, _approvalIdMeta),
      );
    } else if (isInserting) {
      context.missing(_approvalIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('request_json')) {
      context.handle(
        _requestJsonMeta,
        requestJson.isAcceptableOrUnknown(
          data['request_json']!,
          _requestJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_requestJsonMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, approvalId};
  @override
  PendingApprovalEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingApprovalEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      approvalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}approval_id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}session_id'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      ),
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      requestJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}request_json'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}resolved_at'],
      ),
    );
  }

  @override
  $PendingApprovalEntriesTable createAlias(String alias) {
    return $PendingApprovalEntriesTable(attachedDatabase, alias);
  }
}

class PendingApprovalEntry extends DataClass
    implements Insertable<PendingApprovalEntry> {
  final String agentId;
  final String approvalId;
  final String sessionId;
  final String? itemId;
  final String type;
  final String requestJson;
  final String status;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  const PendingApprovalEntry({
    required this.agentId,
    required this.approvalId,
    required this.sessionId,
    this.itemId,
    required this.type,
    required this.requestJson,
    required this.status,
    required this.createdAt,
    this.resolvedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['approval_id'] = Variable<String>(approvalId);
    map['session_id'] = Variable<String>(sessionId);
    if (!nullToAbsent || itemId != null) {
      map['item_id'] = Variable<String>(itemId);
    }
    map['type'] = Variable<String>(type);
    map['request_json'] = Variable<String>(requestJson);
    map['status'] = Variable<String>(status);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt);
    }
    return map;
  }

  PendingApprovalEntriesCompanion toCompanion(bool nullToAbsent) {
    return PendingApprovalEntriesCompanion(
      agentId: Value(agentId),
      approvalId: Value(approvalId),
      sessionId: Value(sessionId),
      itemId: itemId == null && nullToAbsent
          ? const Value.absent()
          : Value(itemId),
      type: Value(type),
      requestJson: Value(requestJson),
      status: Value(status),
      createdAt: Value(createdAt),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
    );
  }

  factory PendingApprovalEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingApprovalEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      approvalId: serializer.fromJson<String>(json['approvalId']),
      sessionId: serializer.fromJson<String>(json['sessionId']),
      itemId: serializer.fromJson<String?>(json['itemId']),
      type: serializer.fromJson<String>(json['type']),
      requestJson: serializer.fromJson<String>(json['requestJson']),
      status: serializer.fromJson<String>(json['status']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      resolvedAt: serializer.fromJson<DateTime?>(json['resolvedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'approvalId': serializer.toJson<String>(approvalId),
      'sessionId': serializer.toJson<String>(sessionId),
      'itemId': serializer.toJson<String?>(itemId),
      'type': serializer.toJson<String>(type),
      'requestJson': serializer.toJson<String>(requestJson),
      'status': serializer.toJson<String>(status),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'resolvedAt': serializer.toJson<DateTime?>(resolvedAt),
    };
  }

  PendingApprovalEntry copyWith({
    String? agentId,
    String? approvalId,
    String? sessionId,
    Value<String?> itemId = const Value.absent(),
    String? type,
    String? requestJson,
    String? status,
    DateTime? createdAt,
    Value<DateTime?> resolvedAt = const Value.absent(),
  }) => PendingApprovalEntry(
    agentId: agentId ?? this.agentId,
    approvalId: approvalId ?? this.approvalId,
    sessionId: sessionId ?? this.sessionId,
    itemId: itemId.present ? itemId.value : this.itemId,
    type: type ?? this.type,
    requestJson: requestJson ?? this.requestJson,
    status: status ?? this.status,
    createdAt: createdAt ?? this.createdAt,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
  );
  PendingApprovalEntry copyWithCompanion(PendingApprovalEntriesCompanion data) {
    return PendingApprovalEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      approvalId: data.approvalId.present
          ? data.approvalId.value
          : this.approvalId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      type: data.type.present ? data.type.value : this.type,
      requestJson: data.requestJson.present
          ? data.requestJson.value
          : this.requestJson,
      status: data.status.present ? data.status.value : this.status,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingApprovalEntry(')
          ..write('agentId: $agentId, ')
          ..write('approvalId: $approvalId, ')
          ..write('sessionId: $sessionId, ')
          ..write('itemId: $itemId, ')
          ..write('type: $type, ')
          ..write('requestJson: $requestJson, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    agentId,
    approvalId,
    sessionId,
    itemId,
    type,
    requestJson,
    status,
    createdAt,
    resolvedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingApprovalEntry &&
          other.agentId == this.agentId &&
          other.approvalId == this.approvalId &&
          other.sessionId == this.sessionId &&
          other.itemId == this.itemId &&
          other.type == this.type &&
          other.requestJson == this.requestJson &&
          other.status == this.status &&
          other.createdAt == this.createdAt &&
          other.resolvedAt == this.resolvedAt);
}

class PendingApprovalEntriesCompanion
    extends UpdateCompanion<PendingApprovalEntry> {
  final Value<String> agentId;
  final Value<String> approvalId;
  final Value<String> sessionId;
  final Value<String?> itemId;
  final Value<String> type;
  final Value<String> requestJson;
  final Value<String> status;
  final Value<DateTime> createdAt;
  final Value<DateTime?> resolvedAt;
  final Value<int> rowid;
  const PendingApprovalEntriesCompanion({
    this.agentId = const Value.absent(),
    this.approvalId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.itemId = const Value.absent(),
    this.type = const Value.absent(),
    this.requestJson = const Value.absent(),
    this.status = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PendingApprovalEntriesCompanion.insert({
    required String agentId,
    required String approvalId,
    required String sessionId,
    this.itemId = const Value.absent(),
    required String type,
    required String requestJson,
    this.status = const Value.absent(),
    required DateTime createdAt,
    this.resolvedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       approvalId = Value(approvalId),
       sessionId = Value(sessionId),
       type = Value(type),
       requestJson = Value(requestJson),
       createdAt = Value(createdAt);
  static Insertable<PendingApprovalEntry> custom({
    Expression<String>? agentId,
    Expression<String>? approvalId,
    Expression<String>? sessionId,
    Expression<String>? itemId,
    Expression<String>? type,
    Expression<String>? requestJson,
    Expression<String>? status,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? resolvedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (approvalId != null) 'approval_id': approvalId,
      if (sessionId != null) 'session_id': sessionId,
      if (itemId != null) 'item_id': itemId,
      if (type != null) 'type': type,
      if (requestJson != null) 'request_json': requestJson,
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PendingApprovalEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? approvalId,
    Value<String>? sessionId,
    Value<String?>? itemId,
    Value<String>? type,
    Value<String>? requestJson,
    Value<String>? status,
    Value<DateTime>? createdAt,
    Value<DateTime?>? resolvedAt,
    Value<int>? rowid,
  }) {
    return PendingApprovalEntriesCompanion(
      agentId: agentId ?? this.agentId,
      approvalId: approvalId ?? this.approvalId,
      sessionId: sessionId ?? this.sessionId,
      itemId: itemId ?? this.itemId,
      type: type ?? this.type,
      requestJson: requestJson ?? this.requestJson,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (approvalId.present) {
      map['approval_id'] = Variable<String>(approvalId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (requestJson.present) {
      map['request_json'] = Variable<String>(requestJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<DateTime>(resolvedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingApprovalEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('approvalId: $approvalId, ')
          ..write('sessionId: $sessionId, ')
          ..write('itemId: $itemId, ')
          ..write('type: $type, ')
          ..write('requestJson: $requestJson, ')
          ..write('status: $status, ')
          ..write('createdAt: $createdAt, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncStateEntriesTable extends SyncStateEntries
    with TableInfo<$SyncStateEntriesTable, SyncStateEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncStateEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scopeMeta = const VerificationMeta('scope');
  @override
  late final GeneratedColumn<String> scope = GeneratedColumn<String>(
    'scope',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _cursorMeta = const VerificationMeta('cursor');
  @override
  late final GeneratedColumn<String> cursor = GeneratedColumn<String>(
    'cursor',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    scope,
    key,
    cursor,
    hash,
    revision,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_state_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncStateEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('scope')) {
      context.handle(
        _scopeMeta,
        scope.isAcceptableOrUnknown(data['scope']!, _scopeMeta),
      );
    } else if (isInserting) {
      context.missing(_scopeMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('cursor')) {
      context.handle(
        _cursorMeta,
        cursor.isAcceptableOrUnknown(data['cursor']!, _cursorMeta),
      );
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, scope, key};
  @override
  SyncStateEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncStateEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      scope: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scope'],
      )!,
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      cursor: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}cursor'],
      ),
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncStateEntriesTable createAlias(String alias) {
    return $SyncStateEntriesTable(attachedDatabase, alias);
  }
}

class SyncStateEntry extends DataClass implements Insertable<SyncStateEntry> {
  final String agentId;
  final String scope;
  final String key;
  final String? cursor;
  final String? hash;
  final int? revision;
  final DateTime updatedAt;
  const SyncStateEntry({
    required this.agentId,
    required this.scope,
    required this.key,
    this.cursor,
    this.hash,
    this.revision,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['scope'] = Variable<String>(scope);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || cursor != null) {
      map['cursor'] = Variable<String>(cursor);
    }
    if (!nullToAbsent || hash != null) {
      map['hash'] = Variable<String>(hash);
    }
    if (!nullToAbsent || revision != null) {
      map['revision'] = Variable<int>(revision);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SyncStateEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncStateEntriesCompanion(
      agentId: Value(agentId),
      scope: Value(scope),
      key: Value(key),
      cursor: cursor == null && nullToAbsent
          ? const Value.absent()
          : Value(cursor),
      hash: hash == null && nullToAbsent ? const Value.absent() : Value(hash),
      revision: revision == null && nullToAbsent
          ? const Value.absent()
          : Value(revision),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncStateEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncStateEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      scope: serializer.fromJson<String>(json['scope']),
      key: serializer.fromJson<String>(json['key']),
      cursor: serializer.fromJson<String?>(json['cursor']),
      hash: serializer.fromJson<String?>(json['hash']),
      revision: serializer.fromJson<int?>(json['revision']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'scope': serializer.toJson<String>(scope),
      'key': serializer.toJson<String>(key),
      'cursor': serializer.toJson<String?>(cursor),
      'hash': serializer.toJson<String?>(hash),
      'revision': serializer.toJson<int?>(revision),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  SyncStateEntry copyWith({
    String? agentId,
    String? scope,
    String? key,
    Value<String?> cursor = const Value.absent(),
    Value<String?> hash = const Value.absent(),
    Value<int?> revision = const Value.absent(),
    DateTime? updatedAt,
  }) => SyncStateEntry(
    agentId: agentId ?? this.agentId,
    scope: scope ?? this.scope,
    key: key ?? this.key,
    cursor: cursor.present ? cursor.value : this.cursor,
    hash: hash.present ? hash.value : this.hash,
    revision: revision.present ? revision.value : this.revision,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncStateEntry copyWithCompanion(SyncStateEntriesCompanion data) {
    return SyncStateEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      scope: data.scope.present ? data.scope.value : this.scope,
      key: data.key.present ? data.key.value : this.key,
      cursor: data.cursor.present ? data.cursor.value : this.cursor,
      hash: data.hash.present ? data.hash.value : this.hash,
      revision: data.revision.present ? data.revision.value : this.revision,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateEntry(')
          ..write('agentId: $agentId, ')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('cursor: $cursor, ')
          ..write('hash: $hash, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(agentId, scope, key, cursor, hash, revision, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncStateEntry &&
          other.agentId == this.agentId &&
          other.scope == this.scope &&
          other.key == this.key &&
          other.cursor == this.cursor &&
          other.hash == this.hash &&
          other.revision == this.revision &&
          other.updatedAt == this.updatedAt);
}

class SyncStateEntriesCompanion extends UpdateCompanion<SyncStateEntry> {
  final Value<String> agentId;
  final Value<String> scope;
  final Value<String> key;
  final Value<String?> cursor;
  final Value<String?> hash;
  final Value<int?> revision;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const SyncStateEntriesCompanion({
    this.agentId = const Value.absent(),
    this.scope = const Value.absent(),
    this.key = const Value.absent(),
    this.cursor = const Value.absent(),
    this.hash = const Value.absent(),
    this.revision = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncStateEntriesCompanion.insert({
    required String agentId,
    required String scope,
    required String key,
    this.cursor = const Value.absent(),
    this.hash = const Value.absent(),
    this.revision = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       scope = Value(scope),
       key = Value(key),
       updatedAt = Value(updatedAt);
  static Insertable<SyncStateEntry> custom({
    Expression<String>? agentId,
    Expression<String>? scope,
    Expression<String>? key,
    Expression<String>? cursor,
    Expression<String>? hash,
    Expression<int>? revision,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (scope != null) 'scope': scope,
      if (key != null) 'key': key,
      if (cursor != null) 'cursor': cursor,
      if (hash != null) 'hash': hash,
      if (revision != null) 'revision': revision,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncStateEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? scope,
    Value<String>? key,
    Value<String?>? cursor,
    Value<String?>? hash,
    Value<int?>? revision,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncStateEntriesCompanion(
      agentId: agentId ?? this.agentId,
      scope: scope ?? this.scope,
      key: key ?? this.key,
      cursor: cursor ?? this.cursor,
      hash: hash ?? this.hash,
      revision: revision ?? this.revision,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(scope.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (cursor.present) {
      map['cursor'] = Variable<String>(cursor.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncStateEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('scope: $scope, ')
          ..write('key: $key, ')
          ..write('cursor: $cursor, ')
          ..write('hash: $hash, ')
          ..write('revision: $revision, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GitSummaryEntriesTable extends GitSummaryEntries
    with TableInfo<$GitSummaryEntriesTable, GitSummaryEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GitSummaryEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dataJsonMeta = const VerificationMeta(
    'dataJson',
  );
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
    'data_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    projectId,
    version,
    dataJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'git_summary_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<GitSummaryEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(
        _dataJsonMeta,
        dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_dataJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, projectId};
  @override
  GitSummaryEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GitSummaryEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      dataJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}data_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GitSummaryEntriesTable createAlias(String alias) {
    return $GitSummaryEntriesTable(attachedDatabase, alias);
  }
}

class GitSummaryEntry extends DataClass implements Insertable<GitSummaryEntry> {
  final String agentId;
  final String projectId;
  final int version;
  final String dataJson;
  final DateTime updatedAt;
  const GitSummaryEntry({
    required this.agentId,
    required this.projectId,
    required this.version,
    required this.dataJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['project_id'] = Variable<String>(projectId);
    map['version'] = Variable<int>(version);
    map['data_json'] = Variable<String>(dataJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GitSummaryEntriesCompanion toCompanion(bool nullToAbsent) {
    return GitSummaryEntriesCompanion(
      agentId: Value(agentId),
      projectId: Value(projectId),
      version: Value(version),
      dataJson: Value(dataJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory GitSummaryEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GitSummaryEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      version: serializer.fromJson<int>(json['version']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'projectId': serializer.toJson<String>(projectId),
      'version': serializer.toJson<int>(version),
      'dataJson': serializer.toJson<String>(dataJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GitSummaryEntry copyWith({
    String? agentId,
    String? projectId,
    int? version,
    String? dataJson,
    DateTime? updatedAt,
  }) => GitSummaryEntry(
    agentId: agentId ?? this.agentId,
    projectId: projectId ?? this.projectId,
    version: version ?? this.version,
    dataJson: dataJson ?? this.dataJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GitSummaryEntry copyWithCompanion(GitSummaryEntriesCompanion data) {
    return GitSummaryEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      version: data.version.present ? data.version.value : this.version,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GitSummaryEntry(')
          ..write('agentId: $agentId, ')
          ..write('projectId: $projectId, ')
          ..write('version: $version, ')
          ..write('dataJson: $dataJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(agentId, projectId, version, dataJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GitSummaryEntry &&
          other.agentId == this.agentId &&
          other.projectId == this.projectId &&
          other.version == this.version &&
          other.dataJson == this.dataJson &&
          other.updatedAt == this.updatedAt);
}

class GitSummaryEntriesCompanion extends UpdateCompanion<GitSummaryEntry> {
  final Value<String> agentId;
  final Value<String> projectId;
  final Value<int> version;
  final Value<String> dataJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GitSummaryEntriesCompanion({
    this.agentId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.version = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GitSummaryEntriesCompanion.insert({
    required String agentId,
    required String projectId,
    required int version,
    required String dataJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       projectId = Value(projectId),
       version = Value(version),
       dataJson = Value(dataJson),
       updatedAt = Value(updatedAt);
  static Insertable<GitSummaryEntry> custom({
    Expression<String>? agentId,
    Expression<String>? projectId,
    Expression<int>? version,
    Expression<String>? dataJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (projectId != null) 'project_id': projectId,
      if (version != null) 'version': version,
      if (dataJson != null) 'data_json': dataJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GitSummaryEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? projectId,
    Value<int>? version,
    Value<String>? dataJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GitSummaryEntriesCompanion(
      agentId: agentId ?? this.agentId,
      projectId: projectId ?? this.projectId,
      version: version ?? this.version,
      dataJson: dataJson ?? this.dataJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GitSummaryEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('projectId: $projectId, ')
          ..write('version: $version, ')
          ..write('dataJson: $dataJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GitChangesEntriesTable extends GitChangesEntries
    with TableInfo<$GitChangesEntriesTable, GitChangesEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GitChangesEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _versionMeta = const VerificationMeta(
    'version',
  );
  @override
  late final GeneratedColumn<int> version = GeneratedColumn<int>(
    'version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filesJsonMeta = const VerificationMeta(
    'filesJson',
  );
  @override
  late final GeneratedColumn<String> filesJson = GeneratedColumn<String>(
    'files_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    projectId,
    version,
    filesJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'git_changes_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<GitChangesEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('version')) {
      context.handle(
        _versionMeta,
        version.isAcceptableOrUnknown(data['version']!, _versionMeta),
      );
    } else if (isInserting) {
      context.missing(_versionMeta);
    }
    if (data.containsKey('files_json')) {
      context.handle(
        _filesJsonMeta,
        filesJson.isAcceptableOrUnknown(data['files_json']!, _filesJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_filesJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, projectId};
  @override
  GitChangesEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GitChangesEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      version: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}version'],
      )!,
      filesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}files_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GitChangesEntriesTable createAlias(String alias) {
    return $GitChangesEntriesTable(attachedDatabase, alias);
  }
}

class GitChangesEntry extends DataClass implements Insertable<GitChangesEntry> {
  final String agentId;
  final String projectId;
  final int version;
  final String filesJson;
  final DateTime updatedAt;
  const GitChangesEntry({
    required this.agentId,
    required this.projectId,
    required this.version,
    required this.filesJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['project_id'] = Variable<String>(projectId);
    map['version'] = Variable<int>(version);
    map['files_json'] = Variable<String>(filesJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  GitChangesEntriesCompanion toCompanion(bool nullToAbsent) {
    return GitChangesEntriesCompanion(
      agentId: Value(agentId),
      projectId: Value(projectId),
      version: Value(version),
      filesJson: Value(filesJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory GitChangesEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GitChangesEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      version: serializer.fromJson<int>(json['version']),
      filesJson: serializer.fromJson<String>(json['filesJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'projectId': serializer.toJson<String>(projectId),
      'version': serializer.toJson<int>(version),
      'filesJson': serializer.toJson<String>(filesJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  GitChangesEntry copyWith({
    String? agentId,
    String? projectId,
    int? version,
    String? filesJson,
    DateTime? updatedAt,
  }) => GitChangesEntry(
    agentId: agentId ?? this.agentId,
    projectId: projectId ?? this.projectId,
    version: version ?? this.version,
    filesJson: filesJson ?? this.filesJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GitChangesEntry copyWithCompanion(GitChangesEntriesCompanion data) {
    return GitChangesEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      version: data.version.present ? data.version.value : this.version,
      filesJson: data.filesJson.present ? data.filesJson.value : this.filesJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GitChangesEntry(')
          ..write('agentId: $agentId, ')
          ..write('projectId: $projectId, ')
          ..write('version: $version, ')
          ..write('filesJson: $filesJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(agentId, projectId, version, filesJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GitChangesEntry &&
          other.agentId == this.agentId &&
          other.projectId == this.projectId &&
          other.version == this.version &&
          other.filesJson == this.filesJson &&
          other.updatedAt == this.updatedAt);
}

class GitChangesEntriesCompanion extends UpdateCompanion<GitChangesEntry> {
  final Value<String> agentId;
  final Value<String> projectId;
  final Value<int> version;
  final Value<String> filesJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const GitChangesEntriesCompanion({
    this.agentId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.version = const Value.absent(),
    this.filesJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GitChangesEntriesCompanion.insert({
    required String agentId,
    required String projectId,
    required int version,
    required String filesJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       projectId = Value(projectId),
       version = Value(version),
       filesJson = Value(filesJson),
       updatedAt = Value(updatedAt);
  static Insertable<GitChangesEntry> custom({
    Expression<String>? agentId,
    Expression<String>? projectId,
    Expression<int>? version,
    Expression<String>? filesJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (projectId != null) 'project_id': projectId,
      if (version != null) 'version': version,
      if (filesJson != null) 'files_json': filesJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GitChangesEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? projectId,
    Value<int>? version,
    Value<String>? filesJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return GitChangesEntriesCompanion(
      agentId: agentId ?? this.agentId,
      projectId: projectId ?? this.projectId,
      version: version ?? this.version,
      filesJson: filesJson ?? this.filesJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (version.present) {
      map['version'] = Variable<int>(version.value);
    }
    if (filesJson.present) {
      map['files_json'] = Variable<String>(filesJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GitChangesEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('projectId: $projectId, ')
          ..write('version: $version, ')
          ..write('filesJson: $filesJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DirCacheEntriesTable extends DirCacheEntries
    with TableInfo<$DirCacheEntriesTable, DirCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DirCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemsJsonMeta = const VerificationMeta(
    'itemsJson',
  );
  @override
  late final GeneratedColumn<String> itemsJson = GeneratedColumn<String>(
    'items_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    projectId,
    path,
    hash,
    itemsJson,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dir_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<DirCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('items_json')) {
      context.handle(
        _itemsJsonMeta,
        itemsJson.isAcceptableOrUnknown(data['items_json']!, _itemsJsonMeta),
      );
    } else if (isInserting) {
      context.missing(_itemsJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, projectId, path};
  @override
  DirCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DirCacheEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      itemsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}items_json'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DirCacheEntriesTable createAlias(String alias) {
    return $DirCacheEntriesTable(attachedDatabase, alias);
  }
}

class DirCacheEntry extends DataClass implements Insertable<DirCacheEntry> {
  final String agentId;
  final String projectId;
  final String path;
  final String hash;
  final String itemsJson;
  final DateTime updatedAt;
  const DirCacheEntry({
    required this.agentId,
    required this.projectId,
    required this.path,
    required this.hash,
    required this.itemsJson,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['project_id'] = Variable<String>(projectId);
    map['path'] = Variable<String>(path);
    map['hash'] = Variable<String>(hash);
    map['items_json'] = Variable<String>(itemsJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DirCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return DirCacheEntriesCompanion(
      agentId: Value(agentId),
      projectId: Value(projectId),
      path: Value(path),
      hash: Value(hash),
      itemsJson: Value(itemsJson),
      updatedAt: Value(updatedAt),
    );
  }

  factory DirCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DirCacheEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      path: serializer.fromJson<String>(json['path']),
      hash: serializer.fromJson<String>(json['hash']),
      itemsJson: serializer.fromJson<String>(json['itemsJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'projectId': serializer.toJson<String>(projectId),
      'path': serializer.toJson<String>(path),
      'hash': serializer.toJson<String>(hash),
      'itemsJson': serializer.toJson<String>(itemsJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DirCacheEntry copyWith({
    String? agentId,
    String? projectId,
    String? path,
    String? hash,
    String? itemsJson,
    DateTime? updatedAt,
  }) => DirCacheEntry(
    agentId: agentId ?? this.agentId,
    projectId: projectId ?? this.projectId,
    path: path ?? this.path,
    hash: hash ?? this.hash,
    itemsJson: itemsJson ?? this.itemsJson,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DirCacheEntry copyWithCompanion(DirCacheEntriesCompanion data) {
    return DirCacheEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      path: data.path.present ? data.path.value : this.path,
      hash: data.hash.present ? data.hash.value : this.hash,
      itemsJson: data.itemsJson.present ? data.itemsJson.value : this.itemsJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DirCacheEntry(')
          ..write('agentId: $agentId, ')
          ..write('projectId: $projectId, ')
          ..write('path: $path, ')
          ..write('hash: $hash, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(agentId, projectId, path, hash, itemsJson, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DirCacheEntry &&
          other.agentId == this.agentId &&
          other.projectId == this.projectId &&
          other.path == this.path &&
          other.hash == this.hash &&
          other.itemsJson == this.itemsJson &&
          other.updatedAt == this.updatedAt);
}

class DirCacheEntriesCompanion extends UpdateCompanion<DirCacheEntry> {
  final Value<String> agentId;
  final Value<String> projectId;
  final Value<String> path;
  final Value<String> hash;
  final Value<String> itemsJson;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const DirCacheEntriesCompanion({
    this.agentId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.path = const Value.absent(),
    this.hash = const Value.absent(),
    this.itemsJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DirCacheEntriesCompanion.insert({
    required String agentId,
    required String projectId,
    required String path,
    required String hash,
    required String itemsJson,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       projectId = Value(projectId),
       path = Value(path),
       hash = Value(hash),
       itemsJson = Value(itemsJson),
       updatedAt = Value(updatedAt);
  static Insertable<DirCacheEntry> custom({
    Expression<String>? agentId,
    Expression<String>? projectId,
    Expression<String>? path,
    Expression<String>? hash,
    Expression<String>? itemsJson,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (projectId != null) 'project_id': projectId,
      if (path != null) 'path': path,
      if (hash != null) 'hash': hash,
      if (itemsJson != null) 'items_json': itemsJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DirCacheEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? projectId,
    Value<String>? path,
    Value<String>? hash,
    Value<String>? itemsJson,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return DirCacheEntriesCompanion(
      agentId: agentId ?? this.agentId,
      projectId: projectId ?? this.projectId,
      path: path ?? this.path,
      hash: hash ?? this.hash,
      itemsJson: itemsJson ?? this.itemsJson,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (itemsJson.present) {
      map['items_json'] = Variable<String>(itemsJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DirCacheEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('projectId: $projectId, ')
          ..write('path: $path, ')
          ..write('hash: $hash, ')
          ..write('itemsJson: $itemsJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FileCacheEntriesTable extends FileCacheEntries
    with TableInfo<$FileCacheEntriesTable, FileCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FileCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _agentIdMeta = const VerificationMeta(
    'agentId',
  );
  @override
  late final GeneratedColumn<String> agentId = GeneratedColumn<String>(
    'agent_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectIdMeta = const VerificationMeta(
    'projectId',
  );
  @override
  late final GeneratedColumn<String> projectId = GeneratedColumn<String>(
    'project_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rangeKeyMeta = const VerificationMeta(
    'rangeKey',
  );
  @override
  late final GeneratedColumn<String> rangeKey = GeneratedColumn<String>(
    'range_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hashMeta = const VerificationMeta('hash');
  @override
  late final GeneratedColumn<String> hash = GeneratedColumn<String>(
    'hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _encodingMeta = const VerificationMeta(
    'encoding',
  );
  @override
  late final GeneratedColumn<String> encoding = GeneratedColumn<String>(
    'encoding',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _totalLinesMeta = const VerificationMeta(
    'totalLines',
  );
  @override
  late final GeneratedColumn<int> totalLines = GeneratedColumn<int>(
    'total_lines',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _offsetMeta = const VerificationMeta('offset');
  @override
  late final GeneratedColumn<int> offset = GeneratedColumn<int>(
    'offset',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _limitMeta = const VerificationMeta('limit');
  @override
  late final GeneratedColumn<int> limit = GeneratedColumn<int>(
    'limit',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    agentId,
    projectId,
    path,
    rangeKey,
    hash,
    encoding,
    content,
    size,
    totalLines,
    offset,
    limit,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'file_cache_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<FileCacheEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('agent_id')) {
      context.handle(
        _agentIdMeta,
        agentId.isAcceptableOrUnknown(data['agent_id']!, _agentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_agentIdMeta);
    }
    if (data.containsKey('project_id')) {
      context.handle(
        _projectIdMeta,
        projectId.isAcceptableOrUnknown(data['project_id']!, _projectIdMeta),
      );
    } else if (isInserting) {
      context.missing(_projectIdMeta);
    }
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('range_key')) {
      context.handle(
        _rangeKeyMeta,
        rangeKey.isAcceptableOrUnknown(data['range_key']!, _rangeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_rangeKeyMeta);
    }
    if (data.containsKey('hash')) {
      context.handle(
        _hashMeta,
        hash.isAcceptableOrUnknown(data['hash']!, _hashMeta),
      );
    } else if (isInserting) {
      context.missing(_hashMeta);
    }
    if (data.containsKey('encoding')) {
      context.handle(
        _encodingMeta,
        encoding.isAcceptableOrUnknown(data['encoding']!, _encodingMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    }
    if (data.containsKey('total_lines')) {
      context.handle(
        _totalLinesMeta,
        totalLines.isAcceptableOrUnknown(data['total_lines']!, _totalLinesMeta),
      );
    }
    if (data.containsKey('offset')) {
      context.handle(
        _offsetMeta,
        offset.isAcceptableOrUnknown(data['offset']!, _offsetMeta),
      );
    }
    if (data.containsKey('limit')) {
      context.handle(
        _limitMeta,
        limit.isAcceptableOrUnknown(data['limit']!, _limitMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {agentId, projectId, path, rangeKey};
  @override
  FileCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FileCacheEntry(
      agentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}agent_id'],
      )!,
      projectId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}project_id'],
      )!,
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      rangeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}range_key'],
      )!,
      hash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hash'],
      )!,
      encoding: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encoding'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      ),
      totalLines: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_lines'],
      ),
      offset: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}offset'],
      ),
      limit: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}limit'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $FileCacheEntriesTable createAlias(String alias) {
    return $FileCacheEntriesTable(attachedDatabase, alias);
  }
}

class FileCacheEntry extends DataClass implements Insertable<FileCacheEntry> {
  final String agentId;
  final String projectId;
  final String path;
  final String rangeKey;
  final String hash;
  final String? encoding;
  final String content;
  final int? size;
  final int? totalLines;
  final int? offset;
  final int? limit;
  final DateTime updatedAt;
  const FileCacheEntry({
    required this.agentId,
    required this.projectId,
    required this.path,
    required this.rangeKey,
    required this.hash,
    this.encoding,
    required this.content,
    this.size,
    this.totalLines,
    this.offset,
    this.limit,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['agent_id'] = Variable<String>(agentId);
    map['project_id'] = Variable<String>(projectId);
    map['path'] = Variable<String>(path);
    map['range_key'] = Variable<String>(rangeKey);
    map['hash'] = Variable<String>(hash);
    if (!nullToAbsent || encoding != null) {
      map['encoding'] = Variable<String>(encoding);
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || size != null) {
      map['size'] = Variable<int>(size);
    }
    if (!nullToAbsent || totalLines != null) {
      map['total_lines'] = Variable<int>(totalLines);
    }
    if (!nullToAbsent || offset != null) {
      map['offset'] = Variable<int>(offset);
    }
    if (!nullToAbsent || limit != null) {
      map['limit'] = Variable<int>(limit);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  FileCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return FileCacheEntriesCompanion(
      agentId: Value(agentId),
      projectId: Value(projectId),
      path: Value(path),
      rangeKey: Value(rangeKey),
      hash: Value(hash),
      encoding: encoding == null && nullToAbsent
          ? const Value.absent()
          : Value(encoding),
      content: Value(content),
      size: size == null && nullToAbsent ? const Value.absent() : Value(size),
      totalLines: totalLines == null && nullToAbsent
          ? const Value.absent()
          : Value(totalLines),
      offset: offset == null && nullToAbsent
          ? const Value.absent()
          : Value(offset),
      limit: limit == null && nullToAbsent
          ? const Value.absent()
          : Value(limit),
      updatedAt: Value(updatedAt),
    );
  }

  factory FileCacheEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FileCacheEntry(
      agentId: serializer.fromJson<String>(json['agentId']),
      projectId: serializer.fromJson<String>(json['projectId']),
      path: serializer.fromJson<String>(json['path']),
      rangeKey: serializer.fromJson<String>(json['rangeKey']),
      hash: serializer.fromJson<String>(json['hash']),
      encoding: serializer.fromJson<String?>(json['encoding']),
      content: serializer.fromJson<String>(json['content']),
      size: serializer.fromJson<int?>(json['size']),
      totalLines: serializer.fromJson<int?>(json['totalLines']),
      offset: serializer.fromJson<int?>(json['offset']),
      limit: serializer.fromJson<int?>(json['limit']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'agentId': serializer.toJson<String>(agentId),
      'projectId': serializer.toJson<String>(projectId),
      'path': serializer.toJson<String>(path),
      'rangeKey': serializer.toJson<String>(rangeKey),
      'hash': serializer.toJson<String>(hash),
      'encoding': serializer.toJson<String?>(encoding),
      'content': serializer.toJson<String>(content),
      'size': serializer.toJson<int?>(size),
      'totalLines': serializer.toJson<int?>(totalLines),
      'offset': serializer.toJson<int?>(offset),
      'limit': serializer.toJson<int?>(limit),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  FileCacheEntry copyWith({
    String? agentId,
    String? projectId,
    String? path,
    String? rangeKey,
    String? hash,
    Value<String?> encoding = const Value.absent(),
    String? content,
    Value<int?> size = const Value.absent(),
    Value<int?> totalLines = const Value.absent(),
    Value<int?> offset = const Value.absent(),
    Value<int?> limit = const Value.absent(),
    DateTime? updatedAt,
  }) => FileCacheEntry(
    agentId: agentId ?? this.agentId,
    projectId: projectId ?? this.projectId,
    path: path ?? this.path,
    rangeKey: rangeKey ?? this.rangeKey,
    hash: hash ?? this.hash,
    encoding: encoding.present ? encoding.value : this.encoding,
    content: content ?? this.content,
    size: size.present ? size.value : this.size,
    totalLines: totalLines.present ? totalLines.value : this.totalLines,
    offset: offset.present ? offset.value : this.offset,
    limit: limit.present ? limit.value : this.limit,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  FileCacheEntry copyWithCompanion(FileCacheEntriesCompanion data) {
    return FileCacheEntry(
      agentId: data.agentId.present ? data.agentId.value : this.agentId,
      projectId: data.projectId.present ? data.projectId.value : this.projectId,
      path: data.path.present ? data.path.value : this.path,
      rangeKey: data.rangeKey.present ? data.rangeKey.value : this.rangeKey,
      hash: data.hash.present ? data.hash.value : this.hash,
      encoding: data.encoding.present ? data.encoding.value : this.encoding,
      content: data.content.present ? data.content.value : this.content,
      size: data.size.present ? data.size.value : this.size,
      totalLines: data.totalLines.present
          ? data.totalLines.value
          : this.totalLines,
      offset: data.offset.present ? data.offset.value : this.offset,
      limit: data.limit.present ? data.limit.value : this.limit,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FileCacheEntry(')
          ..write('agentId: $agentId, ')
          ..write('projectId: $projectId, ')
          ..write('path: $path, ')
          ..write('rangeKey: $rangeKey, ')
          ..write('hash: $hash, ')
          ..write('encoding: $encoding, ')
          ..write('content: $content, ')
          ..write('size: $size, ')
          ..write('totalLines: $totalLines, ')
          ..write('offset: $offset, ')
          ..write('limit: $limit, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    agentId,
    projectId,
    path,
    rangeKey,
    hash,
    encoding,
    content,
    size,
    totalLines,
    offset,
    limit,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FileCacheEntry &&
          other.agentId == this.agentId &&
          other.projectId == this.projectId &&
          other.path == this.path &&
          other.rangeKey == this.rangeKey &&
          other.hash == this.hash &&
          other.encoding == this.encoding &&
          other.content == this.content &&
          other.size == this.size &&
          other.totalLines == this.totalLines &&
          other.offset == this.offset &&
          other.limit == this.limit &&
          other.updatedAt == this.updatedAt);
}

class FileCacheEntriesCompanion extends UpdateCompanion<FileCacheEntry> {
  final Value<String> agentId;
  final Value<String> projectId;
  final Value<String> path;
  final Value<String> rangeKey;
  final Value<String> hash;
  final Value<String?> encoding;
  final Value<String> content;
  final Value<int?> size;
  final Value<int?> totalLines;
  final Value<int?> offset;
  final Value<int?> limit;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const FileCacheEntriesCompanion({
    this.agentId = const Value.absent(),
    this.projectId = const Value.absent(),
    this.path = const Value.absent(),
    this.rangeKey = const Value.absent(),
    this.hash = const Value.absent(),
    this.encoding = const Value.absent(),
    this.content = const Value.absent(),
    this.size = const Value.absent(),
    this.totalLines = const Value.absent(),
    this.offset = const Value.absent(),
    this.limit = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FileCacheEntriesCompanion.insert({
    required String agentId,
    required String projectId,
    required String path,
    required String rangeKey,
    required String hash,
    this.encoding = const Value.absent(),
    required String content,
    this.size = const Value.absent(),
    this.totalLines = const Value.absent(),
    this.offset = const Value.absent(),
    this.limit = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : agentId = Value(agentId),
       projectId = Value(projectId),
       path = Value(path),
       rangeKey = Value(rangeKey),
       hash = Value(hash),
       content = Value(content),
       updatedAt = Value(updatedAt);
  static Insertable<FileCacheEntry> custom({
    Expression<String>? agentId,
    Expression<String>? projectId,
    Expression<String>? path,
    Expression<String>? rangeKey,
    Expression<String>? hash,
    Expression<String>? encoding,
    Expression<String>? content,
    Expression<int>? size,
    Expression<int>? totalLines,
    Expression<int>? offset,
    Expression<int>? limit,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (agentId != null) 'agent_id': agentId,
      if (projectId != null) 'project_id': projectId,
      if (path != null) 'path': path,
      if (rangeKey != null) 'range_key': rangeKey,
      if (hash != null) 'hash': hash,
      if (encoding != null) 'encoding': encoding,
      if (content != null) 'content': content,
      if (size != null) 'size': size,
      if (totalLines != null) 'total_lines': totalLines,
      if (offset != null) 'offset': offset,
      if (limit != null) 'limit': limit,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FileCacheEntriesCompanion copyWith({
    Value<String>? agentId,
    Value<String>? projectId,
    Value<String>? path,
    Value<String>? rangeKey,
    Value<String>? hash,
    Value<String?>? encoding,
    Value<String>? content,
    Value<int?>? size,
    Value<int?>? totalLines,
    Value<int?>? offset,
    Value<int?>? limit,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return FileCacheEntriesCompanion(
      agentId: agentId ?? this.agentId,
      projectId: projectId ?? this.projectId,
      path: path ?? this.path,
      rangeKey: rangeKey ?? this.rangeKey,
      hash: hash ?? this.hash,
      encoding: encoding ?? this.encoding,
      content: content ?? this.content,
      size: size ?? this.size,
      totalLines: totalLines ?? this.totalLines,
      offset: offset ?? this.offset,
      limit: limit ?? this.limit,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (agentId.present) {
      map['agent_id'] = Variable<String>(agentId.value);
    }
    if (projectId.present) {
      map['project_id'] = Variable<String>(projectId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (rangeKey.present) {
      map['range_key'] = Variable<String>(rangeKey.value);
    }
    if (hash.present) {
      map['hash'] = Variable<String>(hash.value);
    }
    if (encoding.present) {
      map['encoding'] = Variable<String>(encoding.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (totalLines.present) {
      map['total_lines'] = Variable<int>(totalLines.value);
    }
    if (offset.present) {
      map['offset'] = Variable<int>(offset.value);
    }
    if (limit.present) {
      map['limit'] = Variable<int>(limit.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FileCacheEntriesCompanion(')
          ..write('agentId: $agentId, ')
          ..write('projectId: $projectId, ')
          ..write('path: $path, ')
          ..write('rangeKey: $rangeKey, ')
          ..write('hash: $hash, ')
          ..write('encoding: $encoding, ')
          ..write('content: $content, ')
          ..write('size: $size, ')
          ..write('totalLines: $totalLines, ')
          ..write('offset: $offset, ')
          ..write('limit: $limit, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectEntriesTable projectEntries = $ProjectEntriesTable(this);
  late final $ProviderEntriesTable providerEntries = $ProviderEntriesTable(
    this,
  );
  late final $SessionEntriesTable sessionEntries = $SessionEntriesTable(this);
  late final $SessionEventEntriesTable sessionEventEntries =
      $SessionEventEntriesTable(this);
  late final $SessionItemEntriesTable sessionItemEntries =
      $SessionItemEntriesTable(this);
  late final $PendingApprovalEntriesTable pendingApprovalEntries =
      $PendingApprovalEntriesTable(this);
  late final $SyncStateEntriesTable syncStateEntries = $SyncStateEntriesTable(
    this,
  );
  late final $GitSummaryEntriesTable gitSummaryEntries =
      $GitSummaryEntriesTable(this);
  late final $GitChangesEntriesTable gitChangesEntries =
      $GitChangesEntriesTable(this);
  late final $DirCacheEntriesTable dirCacheEntries = $DirCacheEntriesTable(
    this,
  );
  late final $FileCacheEntriesTable fileCacheEntries = $FileCacheEntriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projectEntries,
    providerEntries,
    sessionEntries,
    sessionEventEntries,
    sessionItemEntries,
    pendingApprovalEntries,
    syncStateEntries,
    gitSummaryEntries,
    gitChangesEntries,
    dirCacheEntries,
    fileCacheEntries,
  ];
}

typedef $$ProjectEntriesTableCreateCompanionBuilder =
    ProjectEntriesCompanion Function({
      required String agentId,
      required String id,
      required String name,
      required String path,
      required String defaultProvider,
      Value<int?> revision,
      required String dataJson,
      Value<DateTime?> createdAt,
      required DateTime updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$ProjectEntriesTableUpdateCompanionBuilder =
    ProjectEntriesCompanion Function({
      Value<String> agentId,
      Value<String> id,
      Value<String> name,
      Value<String> path,
      Value<String> defaultProvider,
      Value<int?> revision,
      Value<String> dataJson,
      Value<DateTime?> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$ProjectEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectEntriesTable> {
  $$ProjectEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get defaultProvider => $composableBuilder(
    column: $table.defaultProvider,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectEntriesTable> {
  $$ProjectEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get defaultProvider => $composableBuilder(
    column: $table.defaultProvider,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectEntriesTable> {
  $$ProjectEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get defaultProvider => $composableBuilder(
    column: $table.defaultProvider,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$ProjectEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectEntriesTable,
          ProjectEntry,
          $$ProjectEntriesTableFilterComposer,
          $$ProjectEntriesTableOrderingComposer,
          $$ProjectEntriesTableAnnotationComposer,
          $$ProjectEntriesTableCreateCompanionBuilder,
          $$ProjectEntriesTableUpdateCompanionBuilder,
          (
            ProjectEntry,
            BaseReferences<_$AppDatabase, $ProjectEntriesTable, ProjectEntry>,
          ),
          ProjectEntry,
          PrefetchHooks Function()
        > {
  $$ProjectEntriesTableTableManager(
    _$AppDatabase db,
    $ProjectEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> defaultProvider = const Value.absent(),
                Value<int?> revision = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<DateTime?> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectEntriesCompanion(
                agentId: agentId,
                id: id,
                name: name,
                path: path,
                defaultProvider: defaultProvider,
                revision: revision,
                dataJson: dataJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String id,
                required String name,
                required String path,
                required String defaultProvider,
                Value<int?> revision = const Value.absent(),
                required String dataJson,
                Value<DateTime?> createdAt = const Value.absent(),
                required DateTime updatedAt,
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectEntriesCompanion.insert(
                agentId: agentId,
                id: id,
                name: name,
                path: path,
                defaultProvider: defaultProvider,
                revision: revision,
                dataJson: dataJson,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectEntriesTable,
      ProjectEntry,
      $$ProjectEntriesTableFilterComposer,
      $$ProjectEntriesTableOrderingComposer,
      $$ProjectEntriesTableAnnotationComposer,
      $$ProjectEntriesTableCreateCompanionBuilder,
      $$ProjectEntriesTableUpdateCompanionBuilder,
      (
        ProjectEntry,
        BaseReferences<_$AppDatabase, $ProjectEntriesTable, ProjectEntry>,
      ),
      ProjectEntry,
      PrefetchHooks Function()
    >;
typedef $$ProviderEntriesTableCreateCompanionBuilder =
    ProviderEntriesCompanion Function({
      required String agentId,
      required String name,
      required String status,
      Value<String?> version,
      Value<String?> runMode,
      required String capabilitiesJson,
      required String configJson,
      required String configSchemaJson,
      required String dataJson,
      Value<int?> revision,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$ProviderEntriesTableUpdateCompanionBuilder =
    ProviderEntriesCompanion Function({
      Value<String> agentId,
      Value<String> name,
      Value<String> status,
      Value<String?> version,
      Value<String?> runMode,
      Value<String> capabilitiesJson,
      Value<String> configJson,
      Value<String> configSchemaJson,
      Value<String> dataJson,
      Value<int?> revision,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$ProviderEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ProviderEntriesTable> {
  $$ProviderEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get runMode => $composableBuilder(
    column: $table.runMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get configSchemaJson => $composableBuilder(
    column: $table.configSchemaJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProviderEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProviderEntriesTable> {
  $$ProviderEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get runMode => $composableBuilder(
    column: $table.runMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get configSchemaJson => $composableBuilder(
    column: $table.configSchemaJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProviderEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProviderEntriesTable> {
  $$ProviderEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get runMode =>
      $composableBuilder(column: $table.runMode, builder: (column) => column);

  GeneratedColumn<String> get capabilitiesJson => $composableBuilder(
    column: $table.capabilitiesJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configJson => $composableBuilder(
    column: $table.configJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get configSchemaJson => $composableBuilder(
    column: $table.configSchemaJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$ProviderEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProviderEntriesTable,
          ProviderEntry,
          $$ProviderEntriesTableFilterComposer,
          $$ProviderEntriesTableOrderingComposer,
          $$ProviderEntriesTableAnnotationComposer,
          $$ProviderEntriesTableCreateCompanionBuilder,
          $$ProviderEntriesTableUpdateCompanionBuilder,
          (
            ProviderEntry,
            BaseReferences<_$AppDatabase, $ProviderEntriesTable, ProviderEntry>,
          ),
          ProviderEntry,
          PrefetchHooks Function()
        > {
  $$ProviderEntriesTableTableManager(
    _$AppDatabase db,
    $ProviderEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProviderEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProviderEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProviderEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> version = const Value.absent(),
                Value<String?> runMode = const Value.absent(),
                Value<String> capabilitiesJson = const Value.absent(),
                Value<String> configJson = const Value.absent(),
                Value<String> configSchemaJson = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<int?> revision = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProviderEntriesCompanion(
                agentId: agentId,
                name: name,
                status: status,
                version: version,
                runMode: runMode,
                capabilitiesJson: capabilitiesJson,
                configJson: configJson,
                configSchemaJson: configSchemaJson,
                dataJson: dataJson,
                revision: revision,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String name,
                required String status,
                Value<String?> version = const Value.absent(),
                Value<String?> runMode = const Value.absent(),
                required String capabilitiesJson,
                required String configJson,
                required String configSchemaJson,
                required String dataJson,
                Value<int?> revision = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => ProviderEntriesCompanion.insert(
                agentId: agentId,
                name: name,
                status: status,
                version: version,
                runMode: runMode,
                capabilitiesJson: capabilitiesJson,
                configJson: configJson,
                configSchemaJson: configSchemaJson,
                dataJson: dataJson,
                revision: revision,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProviderEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProviderEntriesTable,
      ProviderEntry,
      $$ProviderEntriesTableFilterComposer,
      $$ProviderEntriesTableOrderingComposer,
      $$ProviderEntriesTableAnnotationComposer,
      $$ProviderEntriesTableCreateCompanionBuilder,
      $$ProviderEntriesTableUpdateCompanionBuilder,
      (
        ProviderEntry,
        BaseReferences<_$AppDatabase, $ProviderEntriesTable, ProviderEntry>,
      ),
      ProviderEntry,
      PrefetchHooks Function()
    >;
typedef $$SessionEntriesTableCreateCompanionBuilder =
    SessionEntriesCompanion Function({
      required String agentId,
      required String id,
      required String providerId,
      Value<String?> threadId,
      required String projectId,
      Value<String?> workdir,
      Value<String?> title,
      Value<String> status,
      Value<String?> model,
      Value<String?> effort,
      Value<String?> approvalPolicy,
      Value<String?> sandboxMode,
      Value<String?> providerCursor,
      Value<int?> listRevision,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });
typedef $$SessionEntriesTableUpdateCompanionBuilder =
    SessionEntriesCompanion Function({
      Value<String> agentId,
      Value<String> id,
      Value<String> providerId,
      Value<String?> threadId,
      Value<String> projectId,
      Value<String?> workdir,
      Value<String?> title,
      Value<String> status,
      Value<String?> model,
      Value<String?> effort,
      Value<String?> approvalPolicy,
      Value<String?> sandboxMode,
      Value<String?> providerCursor,
      Value<int?> listRevision,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> archivedAt,
      Value<DateTime?> deletedAt,
      Value<int> rowid,
    });

class $$SessionEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SessionEntriesTable> {
  $$SessionEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get workdir => $composableBuilder(
    column: $table.workdir,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get effort => $composableBuilder(
    column: $table.effort,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvalPolicy => $composableBuilder(
    column: $table.approvalPolicy,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sandboxMode => $composableBuilder(
    column: $table.sandboxMode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerCursor => $composableBuilder(
    column: $table.providerCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get listRevision => $composableBuilder(
    column: $table.listRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionEntriesTable> {
  $$SessionEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get threadId => $composableBuilder(
    column: $table.threadId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get workdir => $composableBuilder(
    column: $table.workdir,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get model => $composableBuilder(
    column: $table.model,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get effort => $composableBuilder(
    column: $table.effort,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvalPolicy => $composableBuilder(
    column: $table.approvalPolicy,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sandboxMode => $composableBuilder(
    column: $table.sandboxMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerCursor => $composableBuilder(
    column: $table.providerCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get listRevision => $composableBuilder(
    column: $table.listRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionEntriesTable> {
  $$SessionEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get providerId => $composableBuilder(
    column: $table.providerId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get threadId =>
      $composableBuilder(column: $table.threadId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get workdir =>
      $composableBuilder(column: $table.workdir, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get model =>
      $composableBuilder(column: $table.model, builder: (column) => column);

  GeneratedColumn<String> get effort =>
      $composableBuilder(column: $table.effort, builder: (column) => column);

  GeneratedColumn<String> get approvalPolicy => $composableBuilder(
    column: $table.approvalPolicy,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sandboxMode => $composableBuilder(
    column: $table.sandboxMode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get providerCursor => $composableBuilder(
    column: $table.providerCursor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get listRevision => $composableBuilder(
    column: $table.listRevision,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get archivedAt => $composableBuilder(
    column: $table.archivedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$SessionEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionEntriesTable,
          SessionEntry,
          $$SessionEntriesTableFilterComposer,
          $$SessionEntriesTableOrderingComposer,
          $$SessionEntriesTableAnnotationComposer,
          $$SessionEntriesTableCreateCompanionBuilder,
          $$SessionEntriesTableUpdateCompanionBuilder,
          (
            SessionEntry,
            BaseReferences<_$AppDatabase, $SessionEntriesTable, SessionEntry>,
          ),
          SessionEntry,
          PrefetchHooks Function()
        > {
  $$SessionEntriesTableTableManager(
    _$AppDatabase db,
    $SessionEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> id = const Value.absent(),
                Value<String> providerId = const Value.absent(),
                Value<String?> threadId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String?> workdir = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> effort = const Value.absent(),
                Value<String?> approvalPolicy = const Value.absent(),
                Value<String?> sandboxMode = const Value.absent(),
                Value<String?> providerCursor = const Value.absent(),
                Value<int?> listRevision = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionEntriesCompanion(
                agentId: agentId,
                id: id,
                providerId: providerId,
                threadId: threadId,
                projectId: projectId,
                workdir: workdir,
                title: title,
                status: status,
                model: model,
                effort: effort,
                approvalPolicy: approvalPolicy,
                sandboxMode: sandboxMode,
                providerCursor: providerCursor,
                listRevision: listRevision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String id,
                required String providerId,
                Value<String?> threadId = const Value.absent(),
                required String projectId,
                Value<String?> workdir = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> model = const Value.absent(),
                Value<String?> effort = const Value.absent(),
                Value<String?> approvalPolicy = const Value.absent(),
                Value<String?> sandboxMode = const Value.absent(),
                Value<String?> providerCursor = const Value.absent(),
                Value<int?> listRevision = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<DateTime?> archivedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionEntriesCompanion.insert(
                agentId: agentId,
                id: id,
                providerId: providerId,
                threadId: threadId,
                projectId: projectId,
                workdir: workdir,
                title: title,
                status: status,
                model: model,
                effort: effort,
                approvalPolicy: approvalPolicy,
                sandboxMode: sandboxMode,
                providerCursor: providerCursor,
                listRevision: listRevision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                archivedAt: archivedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionEntriesTable,
      SessionEntry,
      $$SessionEntriesTableFilterComposer,
      $$SessionEntriesTableOrderingComposer,
      $$SessionEntriesTableAnnotationComposer,
      $$SessionEntriesTableCreateCompanionBuilder,
      $$SessionEntriesTableUpdateCompanionBuilder,
      (
        SessionEntry,
        BaseReferences<_$AppDatabase, $SessionEntriesTable, SessionEntry>,
      ),
      SessionEntry,
      PrefetchHooks Function()
    >;
typedef $$SessionEventEntriesTableCreateCompanionBuilder =
    SessionEventEntriesCompanion Function({
      Value<int> id,
      required String agentId,
      required String sessionId,
      Value<String?> providerCursor,
      required String type,
      Value<String?> itemId,
      Value<String?> turnId,
      Value<String> data,
      required DateTime createdAt,
    });
typedef $$SessionEventEntriesTableUpdateCompanionBuilder =
    SessionEventEntriesCompanion Function({
      Value<int> id,
      Value<String> agentId,
      Value<String> sessionId,
      Value<String?> providerCursor,
      Value<String> type,
      Value<String?> itemId,
      Value<String?> turnId,
      Value<String> data,
      Value<DateTime> createdAt,
    });

class $$SessionEventEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SessionEventEntriesTable> {
  $$SessionEventEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerCursor => $composableBuilder(
    column: $table.providerCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turnId => $composableBuilder(
    column: $table.turnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionEventEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionEventEntriesTable> {
  $$SessionEventEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerCursor => $composableBuilder(
    column: $table.providerCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turnId => $composableBuilder(
    column: $table.turnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get data => $composableBuilder(
    column: $table.data,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionEventEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionEventEntriesTable> {
  $$SessionEventEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get providerCursor => $composableBuilder(
    column: $table.providerCursor,
    builder: (column) => column,
  );

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get turnId =>
      $composableBuilder(column: $table.turnId, builder: (column) => column);

  GeneratedColumn<String> get data =>
      $composableBuilder(column: $table.data, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SessionEventEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionEventEntriesTable,
          SessionEventEntry,
          $$SessionEventEntriesTableFilterComposer,
          $$SessionEventEntriesTableOrderingComposer,
          $$SessionEventEntriesTableAnnotationComposer,
          $$SessionEventEntriesTableCreateCompanionBuilder,
          $$SessionEventEntriesTableUpdateCompanionBuilder,
          (
            SessionEventEntry,
            BaseReferences<
              _$AppDatabase,
              $SessionEventEntriesTable,
              SessionEventEntry
            >,
          ),
          SessionEventEntry,
          PrefetchHooks Function()
        > {
  $$SessionEventEntriesTableTableManager(
    _$AppDatabase db,
    $SessionEventEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionEventEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionEventEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SessionEventEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> agentId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String?> providerCursor = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String?> turnId = const Value.absent(),
                Value<String> data = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SessionEventEntriesCompanion(
                id: id,
                agentId: agentId,
                sessionId: sessionId,
                providerCursor: providerCursor,
                type: type,
                itemId: itemId,
                turnId: turnId,
                data: data,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String agentId,
                required String sessionId,
                Value<String?> providerCursor = const Value.absent(),
                required String type,
                Value<String?> itemId = const Value.absent(),
                Value<String?> turnId = const Value.absent(),
                Value<String> data = const Value.absent(),
                required DateTime createdAt,
              }) => SessionEventEntriesCompanion.insert(
                id: id,
                agentId: agentId,
                sessionId: sessionId,
                providerCursor: providerCursor,
                type: type,
                itemId: itemId,
                turnId: turnId,
                data: data,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionEventEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionEventEntriesTable,
      SessionEventEntry,
      $$SessionEventEntriesTableFilterComposer,
      $$SessionEventEntriesTableOrderingComposer,
      $$SessionEventEntriesTableAnnotationComposer,
      $$SessionEventEntriesTableCreateCompanionBuilder,
      $$SessionEventEntriesTableUpdateCompanionBuilder,
      (
        SessionEventEntry,
        BaseReferences<
          _$AppDatabase,
          $SessionEventEntriesTable,
          SessionEventEntry
        >,
      ),
      SessionEventEntry,
      PrefetchHooks Function()
    >;
typedef $$SessionItemEntriesTableCreateCompanionBuilder =
    SessionItemEntriesCompanion Function({
      required String agentId,
      required String sessionId,
      required String itemId,
      Value<String?> turnId,
      required String type,
      Value<String?> status,
      Value<String?> role,
      Value<String?> summary,
      Value<String> content,
      Value<String?> providerCursor,
      Value<int?> revision,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SessionItemEntriesTableUpdateCompanionBuilder =
    SessionItemEntriesCompanion Function({
      Value<String> agentId,
      Value<String> sessionId,
      Value<String> itemId,
      Value<String?> turnId,
      Value<String> type,
      Value<String?> status,
      Value<String?> role,
      Value<String?> summary,
      Value<String> content,
      Value<String?> providerCursor,
      Value<int?> revision,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SessionItemEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SessionItemEntriesTable> {
  $$SessionItemEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get turnId => $composableBuilder(
    column: $table.turnId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get providerCursor => $composableBuilder(
    column: $table.providerCursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SessionItemEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionItemEntriesTable> {
  $$SessionItemEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get turnId => $composableBuilder(
    column: $table.turnId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get providerCursor => $composableBuilder(
    column: $table.providerCursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionItemEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionItemEntriesTable> {
  $$SessionItemEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get turnId =>
      $composableBuilder(column: $table.turnId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get providerCursor => $composableBuilder(
    column: $table.providerCursor,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SessionItemEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionItemEntriesTable,
          SessionItemEntry,
          $$SessionItemEntriesTableFilterComposer,
          $$SessionItemEntriesTableOrderingComposer,
          $$SessionItemEntriesTableAnnotationComposer,
          $$SessionItemEntriesTableCreateCompanionBuilder,
          $$SessionItemEntriesTableUpdateCompanionBuilder,
          (
            SessionItemEntry,
            BaseReferences<
              _$AppDatabase,
              $SessionItemEntriesTable,
              SessionItemEntry
            >,
          ),
          SessionItemEntry,
          PrefetchHooks Function()
        > {
  $$SessionItemEntriesTableTableManager(
    _$AppDatabase db,
    $SessionItemEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionItemEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionItemEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionItemEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<String?> turnId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> status = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> providerCursor = const Value.absent(),
                Value<int?> revision = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SessionItemEntriesCompanion(
                agentId: agentId,
                sessionId: sessionId,
                itemId: itemId,
                turnId: turnId,
                type: type,
                status: status,
                role: role,
                summary: summary,
                content: content,
                providerCursor: providerCursor,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String sessionId,
                required String itemId,
                Value<String?> turnId = const Value.absent(),
                required String type,
                Value<String?> status = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> providerCursor = const Value.absent(),
                Value<int?> revision = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SessionItemEntriesCompanion.insert(
                agentId: agentId,
                sessionId: sessionId,
                itemId: itemId,
                turnId: turnId,
                type: type,
                status: status,
                role: role,
                summary: summary,
                content: content,
                providerCursor: providerCursor,
                revision: revision,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SessionItemEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionItemEntriesTable,
      SessionItemEntry,
      $$SessionItemEntriesTableFilterComposer,
      $$SessionItemEntriesTableOrderingComposer,
      $$SessionItemEntriesTableAnnotationComposer,
      $$SessionItemEntriesTableCreateCompanionBuilder,
      $$SessionItemEntriesTableUpdateCompanionBuilder,
      (
        SessionItemEntry,
        BaseReferences<
          _$AppDatabase,
          $SessionItemEntriesTable,
          SessionItemEntry
        >,
      ),
      SessionItemEntry,
      PrefetchHooks Function()
    >;
typedef $$PendingApprovalEntriesTableCreateCompanionBuilder =
    PendingApprovalEntriesCompanion Function({
      required String agentId,
      required String approvalId,
      required String sessionId,
      Value<String?> itemId,
      required String type,
      required String requestJson,
      Value<String> status,
      required DateTime createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });
typedef $$PendingApprovalEntriesTableUpdateCompanionBuilder =
    PendingApprovalEntriesCompanion Function({
      Value<String> agentId,
      Value<String> approvalId,
      Value<String> sessionId,
      Value<String?> itemId,
      Value<String> type,
      Value<String> requestJson,
      Value<String> status,
      Value<DateTime> createdAt,
      Value<DateTime?> resolvedAt,
      Value<int> rowid,
    });

class $$PendingApprovalEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $PendingApprovalEntriesTable> {
  $$PendingApprovalEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get approvalId => $composableBuilder(
    column: $table.approvalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingApprovalEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingApprovalEntriesTable> {
  $$PendingApprovalEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get approvalId => $composableBuilder(
    column: $table.approvalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sessionId => $composableBuilder(
    column: $table.sessionId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingApprovalEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingApprovalEntriesTable> {
  $$PendingApprovalEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get approvalId => $composableBuilder(
    column: $table.approvalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get requestJson => $composableBuilder(
    column: $table.requestJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );
}

class $$PendingApprovalEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingApprovalEntriesTable,
          PendingApprovalEntry,
          $$PendingApprovalEntriesTableFilterComposer,
          $$PendingApprovalEntriesTableOrderingComposer,
          $$PendingApprovalEntriesTableAnnotationComposer,
          $$PendingApprovalEntriesTableCreateCompanionBuilder,
          $$PendingApprovalEntriesTableUpdateCompanionBuilder,
          (
            PendingApprovalEntry,
            BaseReferences<
              _$AppDatabase,
              $PendingApprovalEntriesTable,
              PendingApprovalEntry
            >,
          ),
          PendingApprovalEntry,
          PrefetchHooks Function()
        > {
  $$PendingApprovalEntriesTableTableManager(
    _$AppDatabase db,
    $PendingApprovalEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingApprovalEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$PendingApprovalEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$PendingApprovalEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> approvalId = const Value.absent(),
                Value<String> sessionId = const Value.absent(),
                Value<String?> itemId = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String> requestJson = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingApprovalEntriesCompanion(
                agentId: agentId,
                approvalId: approvalId,
                sessionId: sessionId,
                itemId: itemId,
                type: type,
                requestJson: requestJson,
                status: status,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String approvalId,
                required String sessionId,
                Value<String?> itemId = const Value.absent(),
                required String type,
                required String requestJson,
                Value<String> status = const Value.absent(),
                required DateTime createdAt,
                Value<DateTime?> resolvedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PendingApprovalEntriesCompanion.insert(
                agentId: agentId,
                approvalId: approvalId,
                sessionId: sessionId,
                itemId: itemId,
                type: type,
                requestJson: requestJson,
                status: status,
                createdAt: createdAt,
                resolvedAt: resolvedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingApprovalEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingApprovalEntriesTable,
      PendingApprovalEntry,
      $$PendingApprovalEntriesTableFilterComposer,
      $$PendingApprovalEntriesTableOrderingComposer,
      $$PendingApprovalEntriesTableAnnotationComposer,
      $$PendingApprovalEntriesTableCreateCompanionBuilder,
      $$PendingApprovalEntriesTableUpdateCompanionBuilder,
      (
        PendingApprovalEntry,
        BaseReferences<
          _$AppDatabase,
          $PendingApprovalEntriesTable,
          PendingApprovalEntry
        >,
      ),
      PendingApprovalEntry,
      PrefetchHooks Function()
    >;
typedef $$SyncStateEntriesTableCreateCompanionBuilder =
    SyncStateEntriesCompanion Function({
      required String agentId,
      required String scope,
      required String key,
      Value<String?> cursor,
      Value<String?> hash,
      Value<int?> revision,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$SyncStateEntriesTableUpdateCompanionBuilder =
    SyncStateEntriesCompanion Function({
      Value<String> agentId,
      Value<String> scope,
      Value<String> key,
      Value<String?> cursor,
      Value<String?> hash,
      Value<int?> revision,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$SyncStateEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncStateEntriesTable> {
  $$SyncStateEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncStateEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncStateEntriesTable> {
  $$SyncStateEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get cursor => $composableBuilder(
    column: $table.cursor,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncStateEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncStateEntriesTable> {
  $$SyncStateEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get cursor =>
      $composableBuilder(column: $table.cursor, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncStateEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncStateEntriesTable,
          SyncStateEntry,
          $$SyncStateEntriesTableFilterComposer,
          $$SyncStateEntriesTableOrderingComposer,
          $$SyncStateEntriesTableAnnotationComposer,
          $$SyncStateEntriesTableCreateCompanionBuilder,
          $$SyncStateEntriesTableUpdateCompanionBuilder,
          (
            SyncStateEntry,
            BaseReferences<
              _$AppDatabase,
              $SyncStateEntriesTable,
              SyncStateEntry
            >,
          ),
          SyncStateEntry,
          PrefetchHooks Function()
        > {
  $$SyncStateEntriesTableTableManager(
    _$AppDatabase db,
    $SyncStateEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncStateEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncStateEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncStateEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> scope = const Value.absent(),
                Value<String> key = const Value.absent(),
                Value<String?> cursor = const Value.absent(),
                Value<String?> hash = const Value.absent(),
                Value<int?> revision = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncStateEntriesCompanion(
                agentId: agentId,
                scope: scope,
                key: key,
                cursor: cursor,
                hash: hash,
                revision: revision,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String scope,
                required String key,
                Value<String?> cursor = const Value.absent(),
                Value<String?> hash = const Value.absent(),
                Value<int?> revision = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncStateEntriesCompanion.insert(
                agentId: agentId,
                scope: scope,
                key: key,
                cursor: cursor,
                hash: hash,
                revision: revision,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SyncStateEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncStateEntriesTable,
      SyncStateEntry,
      $$SyncStateEntriesTableFilterComposer,
      $$SyncStateEntriesTableOrderingComposer,
      $$SyncStateEntriesTableAnnotationComposer,
      $$SyncStateEntriesTableCreateCompanionBuilder,
      $$SyncStateEntriesTableUpdateCompanionBuilder,
      (
        SyncStateEntry,
        BaseReferences<_$AppDatabase, $SyncStateEntriesTable, SyncStateEntry>,
      ),
      SyncStateEntry,
      PrefetchHooks Function()
    >;
typedef $$GitSummaryEntriesTableCreateCompanionBuilder =
    GitSummaryEntriesCompanion Function({
      required String agentId,
      required String projectId,
      required int version,
      required String dataJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GitSummaryEntriesTableUpdateCompanionBuilder =
    GitSummaryEntriesCompanion Function({
      Value<String> agentId,
      Value<String> projectId,
      Value<int> version,
      Value<String> dataJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$GitSummaryEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $GitSummaryEntriesTable> {
  $$GitSummaryEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GitSummaryEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GitSummaryEntriesTable> {
  $$GitSummaryEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dataJson => $composableBuilder(
    column: $table.dataJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GitSummaryEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GitSummaryEntriesTable> {
  $$GitSummaryEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GitSummaryEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GitSummaryEntriesTable,
          GitSummaryEntry,
          $$GitSummaryEntriesTableFilterComposer,
          $$GitSummaryEntriesTableOrderingComposer,
          $$GitSummaryEntriesTableAnnotationComposer,
          $$GitSummaryEntriesTableCreateCompanionBuilder,
          $$GitSummaryEntriesTableUpdateCompanionBuilder,
          (
            GitSummaryEntry,
            BaseReferences<
              _$AppDatabase,
              $GitSummaryEntriesTable,
              GitSummaryEntry
            >,
          ),
          GitSummaryEntry,
          PrefetchHooks Function()
        > {
  $$GitSummaryEntriesTableTableManager(
    _$AppDatabase db,
    $GitSummaryEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GitSummaryEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GitSummaryEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GitSummaryEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> dataJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GitSummaryEntriesCompanion(
                agentId: agentId,
                projectId: projectId,
                version: version,
                dataJson: dataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String projectId,
                required int version,
                required String dataJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GitSummaryEntriesCompanion.insert(
                agentId: agentId,
                projectId: projectId,
                version: version,
                dataJson: dataJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GitSummaryEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GitSummaryEntriesTable,
      GitSummaryEntry,
      $$GitSummaryEntriesTableFilterComposer,
      $$GitSummaryEntriesTableOrderingComposer,
      $$GitSummaryEntriesTableAnnotationComposer,
      $$GitSummaryEntriesTableCreateCompanionBuilder,
      $$GitSummaryEntriesTableUpdateCompanionBuilder,
      (
        GitSummaryEntry,
        BaseReferences<_$AppDatabase, $GitSummaryEntriesTable, GitSummaryEntry>,
      ),
      GitSummaryEntry,
      PrefetchHooks Function()
    >;
typedef $$GitChangesEntriesTableCreateCompanionBuilder =
    GitChangesEntriesCompanion Function({
      required String agentId,
      required String projectId,
      required int version,
      required String filesJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$GitChangesEntriesTableUpdateCompanionBuilder =
    GitChangesEntriesCompanion Function({
      Value<String> agentId,
      Value<String> projectId,
      Value<int> version,
      Value<String> filesJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$GitChangesEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $GitChangesEntriesTable> {
  $$GitChangesEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filesJson => $composableBuilder(
    column: $table.filesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GitChangesEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $GitChangesEntriesTable> {
  $$GitChangesEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get version => $composableBuilder(
    column: $table.version,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filesJson => $composableBuilder(
    column: $table.filesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GitChangesEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $GitChangesEntriesTable> {
  $$GitChangesEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<int> get version =>
      $composableBuilder(column: $table.version, builder: (column) => column);

  GeneratedColumn<String> get filesJson =>
      $composableBuilder(column: $table.filesJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GitChangesEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GitChangesEntriesTable,
          GitChangesEntry,
          $$GitChangesEntriesTableFilterComposer,
          $$GitChangesEntriesTableOrderingComposer,
          $$GitChangesEntriesTableAnnotationComposer,
          $$GitChangesEntriesTableCreateCompanionBuilder,
          $$GitChangesEntriesTableUpdateCompanionBuilder,
          (
            GitChangesEntry,
            BaseReferences<
              _$AppDatabase,
              $GitChangesEntriesTable,
              GitChangesEntry
            >,
          ),
          GitChangesEntry,
          PrefetchHooks Function()
        > {
  $$GitChangesEntriesTableTableManager(
    _$AppDatabase db,
    $GitChangesEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GitChangesEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GitChangesEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GitChangesEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<int> version = const Value.absent(),
                Value<String> filesJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GitChangesEntriesCompanion(
                agentId: agentId,
                projectId: projectId,
                version: version,
                filesJson: filesJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String projectId,
                required int version,
                required String filesJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GitChangesEntriesCompanion.insert(
                agentId: agentId,
                projectId: projectId,
                version: version,
                filesJson: filesJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GitChangesEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GitChangesEntriesTable,
      GitChangesEntry,
      $$GitChangesEntriesTableFilterComposer,
      $$GitChangesEntriesTableOrderingComposer,
      $$GitChangesEntriesTableAnnotationComposer,
      $$GitChangesEntriesTableCreateCompanionBuilder,
      $$GitChangesEntriesTableUpdateCompanionBuilder,
      (
        GitChangesEntry,
        BaseReferences<_$AppDatabase, $GitChangesEntriesTable, GitChangesEntry>,
      ),
      GitChangesEntry,
      PrefetchHooks Function()
    >;
typedef $$DirCacheEntriesTableCreateCompanionBuilder =
    DirCacheEntriesCompanion Function({
      required String agentId,
      required String projectId,
      required String path,
      required String hash,
      required String itemsJson,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$DirCacheEntriesTableUpdateCompanionBuilder =
    DirCacheEntriesCompanion Function({
      Value<String> agentId,
      Value<String> projectId,
      Value<String> path,
      Value<String> hash,
      Value<String> itemsJson,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$DirCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $DirCacheEntriesTable> {
  $$DirCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DirCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DirCacheEntriesTable> {
  $$DirCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemsJson => $composableBuilder(
    column: $table.itemsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DirCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DirCacheEntriesTable> {
  $$DirCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<String> get itemsJson =>
      $composableBuilder(column: $table.itemsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DirCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DirCacheEntriesTable,
          DirCacheEntry,
          $$DirCacheEntriesTableFilterComposer,
          $$DirCacheEntriesTableOrderingComposer,
          $$DirCacheEntriesTableAnnotationComposer,
          $$DirCacheEntriesTableCreateCompanionBuilder,
          $$DirCacheEntriesTableUpdateCompanionBuilder,
          (
            DirCacheEntry,
            BaseReferences<_$AppDatabase, $DirCacheEntriesTable, DirCacheEntry>,
          ),
          DirCacheEntry,
          PrefetchHooks Function()
        > {
  $$DirCacheEntriesTableTableManager(
    _$AppDatabase db,
    $DirCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DirCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DirCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DirCacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<String> itemsJson = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DirCacheEntriesCompanion(
                agentId: agentId,
                projectId: projectId,
                path: path,
                hash: hash,
                itemsJson: itemsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String projectId,
                required String path,
                required String hash,
                required String itemsJson,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => DirCacheEntriesCompanion.insert(
                agentId: agentId,
                projectId: projectId,
                path: path,
                hash: hash,
                itemsJson: itemsJson,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DirCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DirCacheEntriesTable,
      DirCacheEntry,
      $$DirCacheEntriesTableFilterComposer,
      $$DirCacheEntriesTableOrderingComposer,
      $$DirCacheEntriesTableAnnotationComposer,
      $$DirCacheEntriesTableCreateCompanionBuilder,
      $$DirCacheEntriesTableUpdateCompanionBuilder,
      (
        DirCacheEntry,
        BaseReferences<_$AppDatabase, $DirCacheEntriesTable, DirCacheEntry>,
      ),
      DirCacheEntry,
      PrefetchHooks Function()
    >;
typedef $$FileCacheEntriesTableCreateCompanionBuilder =
    FileCacheEntriesCompanion Function({
      required String agentId,
      required String projectId,
      required String path,
      required String rangeKey,
      required String hash,
      Value<String?> encoding,
      required String content,
      Value<int?> size,
      Value<int?> totalLines,
      Value<int?> offset,
      Value<int?> limit,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$FileCacheEntriesTableUpdateCompanionBuilder =
    FileCacheEntriesCompanion Function({
      Value<String> agentId,
      Value<String> projectId,
      Value<String> path,
      Value<String> rangeKey,
      Value<String> hash,
      Value<String?> encoding,
      Value<String> content,
      Value<int?> size,
      Value<int?> totalLines,
      Value<int?> offset,
      Value<int?> limit,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$FileCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $FileCacheEntriesTable> {
  $$FileCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get rangeKey => $composableBuilder(
    column: $table.rangeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encoding => $composableBuilder(
    column: $table.encoding,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalLines => $composableBuilder(
    column: $table.totalLines,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get limit => $composableBuilder(
    column: $table.limit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$FileCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $FileCacheEntriesTable> {
  $$FileCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get agentId => $composableBuilder(
    column: $table.agentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get projectId => $composableBuilder(
    column: $table.projectId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get rangeKey => $composableBuilder(
    column: $table.rangeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hash => $composableBuilder(
    column: $table.hash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encoding => $composableBuilder(
    column: $table.encoding,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalLines => $composableBuilder(
    column: $table.totalLines,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get offset => $composableBuilder(
    column: $table.offset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get limit => $composableBuilder(
    column: $table.limit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FileCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FileCacheEntriesTable> {
  $$FileCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get agentId =>
      $composableBuilder(column: $table.agentId, builder: (column) => column);

  GeneratedColumn<String> get projectId =>
      $composableBuilder(column: $table.projectId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get rangeKey =>
      $composableBuilder(column: $table.rangeKey, builder: (column) => column);

  GeneratedColumn<String> get hash =>
      $composableBuilder(column: $table.hash, builder: (column) => column);

  GeneratedColumn<String> get encoding =>
      $composableBuilder(column: $table.encoding, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get totalLines => $composableBuilder(
    column: $table.totalLines,
    builder: (column) => column,
  );

  GeneratedColumn<int> get offset =>
      $composableBuilder(column: $table.offset, builder: (column) => column);

  GeneratedColumn<int> get limit =>
      $composableBuilder(column: $table.limit, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$FileCacheEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FileCacheEntriesTable,
          FileCacheEntry,
          $$FileCacheEntriesTableFilterComposer,
          $$FileCacheEntriesTableOrderingComposer,
          $$FileCacheEntriesTableAnnotationComposer,
          $$FileCacheEntriesTableCreateCompanionBuilder,
          $$FileCacheEntriesTableUpdateCompanionBuilder,
          (
            FileCacheEntry,
            BaseReferences<
              _$AppDatabase,
              $FileCacheEntriesTable,
              FileCacheEntry
            >,
          ),
          FileCacheEntry,
          PrefetchHooks Function()
        > {
  $$FileCacheEntriesTableTableManager(
    _$AppDatabase db,
    $FileCacheEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FileCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FileCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FileCacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> agentId = const Value.absent(),
                Value<String> projectId = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<String> rangeKey = const Value.absent(),
                Value<String> hash = const Value.absent(),
                Value<String?> encoding = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<int?> size = const Value.absent(),
                Value<int?> totalLines = const Value.absent(),
                Value<int?> offset = const Value.absent(),
                Value<int?> limit = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FileCacheEntriesCompanion(
                agentId: agentId,
                projectId: projectId,
                path: path,
                rangeKey: rangeKey,
                hash: hash,
                encoding: encoding,
                content: content,
                size: size,
                totalLines: totalLines,
                offset: offset,
                limit: limit,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String agentId,
                required String projectId,
                required String path,
                required String rangeKey,
                required String hash,
                Value<String?> encoding = const Value.absent(),
                required String content,
                Value<int?> size = const Value.absent(),
                Value<int?> totalLines = const Value.absent(),
                Value<int?> offset = const Value.absent(),
                Value<int?> limit = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => FileCacheEntriesCompanion.insert(
                agentId: agentId,
                projectId: projectId,
                path: path,
                rangeKey: rangeKey,
                hash: hash,
                encoding: encoding,
                content: content,
                size: size,
                totalLines: totalLines,
                offset: offset,
                limit: limit,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$FileCacheEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FileCacheEntriesTable,
      FileCacheEntry,
      $$FileCacheEntriesTableFilterComposer,
      $$FileCacheEntriesTableOrderingComposer,
      $$FileCacheEntriesTableAnnotationComposer,
      $$FileCacheEntriesTableCreateCompanionBuilder,
      $$FileCacheEntriesTableUpdateCompanionBuilder,
      (
        FileCacheEntry,
        BaseReferences<_$AppDatabase, $FileCacheEntriesTable, FileCacheEntry>,
      ),
      FileCacheEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectEntriesTableTableManager get projectEntries =>
      $$ProjectEntriesTableTableManager(_db, _db.projectEntries);
  $$ProviderEntriesTableTableManager get providerEntries =>
      $$ProviderEntriesTableTableManager(_db, _db.providerEntries);
  $$SessionEntriesTableTableManager get sessionEntries =>
      $$SessionEntriesTableTableManager(_db, _db.sessionEntries);
  $$SessionEventEntriesTableTableManager get sessionEventEntries =>
      $$SessionEventEntriesTableTableManager(_db, _db.sessionEventEntries);
  $$SessionItemEntriesTableTableManager get sessionItemEntries =>
      $$SessionItemEntriesTableTableManager(_db, _db.sessionItemEntries);
  $$PendingApprovalEntriesTableTableManager get pendingApprovalEntries =>
      $$PendingApprovalEntriesTableTableManager(
        _db,
        _db.pendingApprovalEntries,
      );
  $$SyncStateEntriesTableTableManager get syncStateEntries =>
      $$SyncStateEntriesTableTableManager(_db, _db.syncStateEntries);
  $$GitSummaryEntriesTableTableManager get gitSummaryEntries =>
      $$GitSummaryEntriesTableTableManager(_db, _db.gitSummaryEntries);
  $$GitChangesEntriesTableTableManager get gitChangesEntries =>
      $$GitChangesEntriesTableTableManager(_db, _db.gitChangesEntries);
  $$DirCacheEntriesTableTableManager get dirCacheEntries =>
      $$DirCacheEntriesTableTableManager(_db, _db.dirCacheEntries);
  $$FileCacheEntriesTableTableManager get fileCacheEntries =>
      $$FileCacheEntriesTableTableManager(_db, _db.fileCacheEntries);
}
