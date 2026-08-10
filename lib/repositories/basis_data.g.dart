// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'basis_data.dart';

// ignore_for_file: type=lint
class $TabelSesiTable extends TabelSesi
    with TableInfo<$TabelSesiTable, TabelSesiData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TabelSesiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fotoPathMeta = const VerificationMeta(
    'fotoPath',
  );
  @override
  late final GeneratedColumn<String> fotoPath = GeneratedColumn<String>(
    'foto_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _waktuFotoMeta = const VerificationMeta(
    'waktuFoto',
  );
  @override
  late final GeneratedColumn<int> waktuFoto = GeneratedColumn<int>(
    'waktu_foto',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _t0Meta = const VerificationMeta('t0');
  @override
  late final GeneratedColumn<int> t0 = GeneratedColumn<int>(
    't0',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StatusSesi, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<StatusSesi>($TabelSesiTable.$converterstatus);
  @override
  List<GeneratedColumn> get $columns => [id, fotoPath, waktuFoto, t0, status];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tabel_sesi';
  @override
  VerificationContext validateIntegrity(
    Insertable<TabelSesiData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('foto_path')) {
      context.handle(
        _fotoPathMeta,
        fotoPath.isAcceptableOrUnknown(data['foto_path']!, _fotoPathMeta),
      );
    } else if (isInserting) {
      context.missing(_fotoPathMeta);
    }
    if (data.containsKey('waktu_foto')) {
      context.handle(
        _waktuFotoMeta,
        waktuFoto.isAcceptableOrUnknown(data['waktu_foto']!, _waktuFotoMeta),
      );
    } else if (isInserting) {
      context.missing(_waktuFotoMeta);
    }
    if (data.containsKey('t0')) {
      context.handle(_t0Meta, t0.isAcceptableOrUnknown(data['t0']!, _t0Meta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TabelSesiData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TabelSesiData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      fotoPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}foto_path'],
      )!,
      waktuFoto: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}waktu_foto'],
      )!,
      t0: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}t0'],
      ),
      status: $TabelSesiTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
    );
  }

  @override
  $TabelSesiTable createAlias(String alias) {
    return $TabelSesiTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StatusSesi, String, String> $converterstatus =
      const EnumNameConverter<StatusSesi>(StatusSesi.values);
}

class TabelSesiData extends DataClass implements Insertable<TabelSesiData> {
  final String id;
  final String fotoPath;
  final int waktuFoto;
  final int? t0;
  final StatusSesi status;
  const TabelSesiData({
    required this.id,
    required this.fotoPath,
    required this.waktuFoto,
    this.t0,
    required this.status,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['foto_path'] = Variable<String>(fotoPath);
    map['waktu_foto'] = Variable<int>(waktuFoto);
    if (!nullToAbsent || t0 != null) {
      map['t0'] = Variable<int>(t0);
    }
    {
      map['status'] = Variable<String>(
        $TabelSesiTable.$converterstatus.toSql(status),
      );
    }
    return map;
  }

  TabelSesiCompanion toCompanion(bool nullToAbsent) {
    return TabelSesiCompanion(
      id: Value(id),
      fotoPath: Value(fotoPath),
      waktuFoto: Value(waktuFoto),
      t0: t0 == null && nullToAbsent ? const Value.absent() : Value(t0),
      status: Value(status),
    );
  }

  factory TabelSesiData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TabelSesiData(
      id: serializer.fromJson<String>(json['id']),
      fotoPath: serializer.fromJson<String>(json['fotoPath']),
      waktuFoto: serializer.fromJson<int>(json['waktuFoto']),
      t0: serializer.fromJson<int?>(json['t0']),
      status: $TabelSesiTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'fotoPath': serializer.toJson<String>(fotoPath),
      'waktuFoto': serializer.toJson<int>(waktuFoto),
      't0': serializer.toJson<int?>(t0),
      'status': serializer.toJson<String>(
        $TabelSesiTable.$converterstatus.toJson(status),
      ),
    };
  }

  TabelSesiData copyWith({
    String? id,
    String? fotoPath,
    int? waktuFoto,
    Value<int?> t0 = const Value.absent(),
    StatusSesi? status,
  }) => TabelSesiData(
    id: id ?? this.id,
    fotoPath: fotoPath ?? this.fotoPath,
    waktuFoto: waktuFoto ?? this.waktuFoto,
    t0: t0.present ? t0.value : this.t0,
    status: status ?? this.status,
  );
  TabelSesiData copyWithCompanion(TabelSesiCompanion data) {
    return TabelSesiData(
      id: data.id.present ? data.id.value : this.id,
      fotoPath: data.fotoPath.present ? data.fotoPath.value : this.fotoPath,
      waktuFoto: data.waktuFoto.present ? data.waktuFoto.value : this.waktuFoto,
      t0: data.t0.present ? data.t0.value : this.t0,
      status: data.status.present ? data.status.value : this.status,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TabelSesiData(')
          ..write('id: $id, ')
          ..write('fotoPath: $fotoPath, ')
          ..write('waktuFoto: $waktuFoto, ')
          ..write('t0: $t0, ')
          ..write('status: $status')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fotoPath, waktuFoto, t0, status);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TabelSesiData &&
          other.id == this.id &&
          other.fotoPath == this.fotoPath &&
          other.waktuFoto == this.waktuFoto &&
          other.t0 == this.t0 &&
          other.status == this.status);
}

class TabelSesiCompanion extends UpdateCompanion<TabelSesiData> {
  final Value<String> id;
  final Value<String> fotoPath;
  final Value<int> waktuFoto;
  final Value<int?> t0;
  final Value<StatusSesi> status;
  final Value<int> rowid;
  const TabelSesiCompanion({
    this.id = const Value.absent(),
    this.fotoPath = const Value.absent(),
    this.waktuFoto = const Value.absent(),
    this.t0 = const Value.absent(),
    this.status = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TabelSesiCompanion.insert({
    required String id,
    required String fotoPath,
    required int waktuFoto,
    this.t0 = const Value.absent(),
    required StatusSesi status,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       fotoPath = Value(fotoPath),
       waktuFoto = Value(waktuFoto),
       status = Value(status);
  static Insertable<TabelSesiData> custom({
    Expression<String>? id,
    Expression<String>? fotoPath,
    Expression<int>? waktuFoto,
    Expression<int>? t0,
    Expression<String>? status,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fotoPath != null) 'foto_path': fotoPath,
      if (waktuFoto != null) 'waktu_foto': waktuFoto,
      if (t0 != null) 't0': t0,
      if (status != null) 'status': status,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TabelSesiCompanion copyWith({
    Value<String>? id,
    Value<String>? fotoPath,
    Value<int>? waktuFoto,
    Value<int?>? t0,
    Value<StatusSesi>? status,
    Value<int>? rowid,
  }) {
    return TabelSesiCompanion(
      id: id ?? this.id,
      fotoPath: fotoPath ?? this.fotoPath,
      waktuFoto: waktuFoto ?? this.waktuFoto,
      t0: t0 ?? this.t0,
      status: status ?? this.status,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (fotoPath.present) {
      map['foto_path'] = Variable<String>(fotoPath.value);
    }
    if (waktuFoto.present) {
      map['waktu_foto'] = Variable<int>(waktuFoto.value);
    }
    if (t0.present) {
      map['t0'] = Variable<int>(t0.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TabelSesiTable.$converterstatus.toSql(status.value),
      );
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TabelSesiCompanion(')
          ..write('id: $id, ')
          ..write('fotoPath: $fotoPath, ')
          ..write('waktuFoto: $waktuFoto, ')
          ..write('t0: $t0, ')
          ..write('status: $status, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TabelSampelTable extends TabelSampel
    with TableInfo<$TabelSampelTable, TabelSampelData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TabelSampelTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sesiIdMeta = const VerificationMeta('sesiId');
  @override
  late final GeneratedColumn<String> sesiId = GeneratedColumn<String>(
    'sesi_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tabel_sesi (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _indexMeta = const VerificationMeta('index');
  @override
  late final GeneratedColumn<int> index = GeneratedColumn<int>(
    'index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detikRelatifT0Meta = const VerificationMeta(
    'detikRelatifT0',
  );
  @override
  late final GeneratedColumn<int> detikRelatifT0 = GeneratedColumn<int>(
    'detik_relatif_t0',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<StatusSampel, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<StatusSampel>($TabelSampelTable.$converterstatus);
  static const VerificationMeta _dariBufferMeta = const VerificationMeta(
    'dariBuffer',
  );
  @override
  late final GeneratedColumn<bool> dariBuffer = GeneratedColumn<bool>(
    'dari_buffer',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dari_buffer" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _gulaDarahMeta = const VerificationMeta(
    'gulaDarah',
  );
  @override
  late final GeneratedColumn<int> gulaDarah = GeneratedColumn<int>(
    'gula_darah',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _detakJantungMeta = const VerificationMeta(
    'detakJantung',
  );
  @override
  late final GeneratedColumn<int> detakJantung = GeneratedColumn<int>(
    'detak_jantung',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sistolikMeta = const VerificationMeta(
    'sistolik',
  );
  @override
  late final GeneratedColumn<int> sistolik = GeneratedColumn<int>(
    'sistolik',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _diastolikMeta = const VerificationMeta(
    'diastolik',
  );
  @override
  late final GeneratedColumn<int> diastolik = GeneratedColumn<int>(
    'diastolik',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _spo2Meta = const VerificationMeta('spo2');
  @override
  late final GeneratedColumn<int> spo2 = GeneratedColumn<int>(
    'spo2',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sesiId,
    index,
    detikRelatifT0,
    status,
    dariBuffer,
    gulaDarah,
    detakJantung,
    sistolik,
    diastolik,
    spo2,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tabel_sampel';
  @override
  VerificationContext validateIntegrity(
    Insertable<TabelSampelData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sesi_id')) {
      context.handle(
        _sesiIdMeta,
        sesiId.isAcceptableOrUnknown(data['sesi_id']!, _sesiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sesiIdMeta);
    }
    if (data.containsKey('index')) {
      context.handle(
        _indexMeta,
        index.isAcceptableOrUnknown(data['index']!, _indexMeta),
      );
    } else if (isInserting) {
      context.missing(_indexMeta);
    }
    if (data.containsKey('detik_relatif_t0')) {
      context.handle(
        _detikRelatifT0Meta,
        detikRelatifT0.isAcceptableOrUnknown(
          data['detik_relatif_t0']!,
          _detikRelatifT0Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_detikRelatifT0Meta);
    }
    if (data.containsKey('dari_buffer')) {
      context.handle(
        _dariBufferMeta,
        dariBuffer.isAcceptableOrUnknown(data['dari_buffer']!, _dariBufferMeta),
      );
    }
    if (data.containsKey('gula_darah')) {
      context.handle(
        _gulaDarahMeta,
        gulaDarah.isAcceptableOrUnknown(data['gula_darah']!, _gulaDarahMeta),
      );
    }
    if (data.containsKey('detak_jantung')) {
      context.handle(
        _detakJantungMeta,
        detakJantung.isAcceptableOrUnknown(
          data['detak_jantung']!,
          _detakJantungMeta,
        ),
      );
    }
    if (data.containsKey('sistolik')) {
      context.handle(
        _sistolikMeta,
        sistolik.isAcceptableOrUnknown(data['sistolik']!, _sistolikMeta),
      );
    }
    if (data.containsKey('diastolik')) {
      context.handle(
        _diastolikMeta,
        diastolik.isAcceptableOrUnknown(data['diastolik']!, _diastolikMeta),
      );
    }
    if (data.containsKey('spo2')) {
      context.handle(
        _spo2Meta,
        spo2.isAcceptableOrUnknown(data['spo2']!, _spo2Meta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sesiId, index};
  @override
  TabelSampelData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TabelSampelData(
      sesiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sesi_id'],
      )!,
      index: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}index'],
      )!,
      detikRelatifT0: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detik_relatif_t0'],
      )!,
      status: $TabelSampelTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      dariBuffer: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dari_buffer'],
      )!,
      gulaDarah: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}gula_darah'],
      ),
      detakJantung: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}detak_jantung'],
      ),
      sistolik: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sistolik'],
      ),
      diastolik: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}diastolik'],
      ),
      spo2: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}spo2'],
      ),
    );
  }

  @override
  $TabelSampelTable createAlias(String alias) {
    return $TabelSampelTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<StatusSampel, String, String> $converterstatus =
      const EnumNameConverter<StatusSampel>(StatusSampel.values);
}

class TabelSampelData extends DataClass implements Insertable<TabelSampelData> {
  final String sesiId;
  final int index;
  final int detikRelatifT0;
  final StatusSampel status;
  final bool dariBuffer;
  final int? gulaDarah;
  final int? detakJantung;
  final int? sistolik;
  final int? diastolik;
  final int? spo2;
  const TabelSampelData({
    required this.sesiId,
    required this.index,
    required this.detikRelatifT0,
    required this.status,
    required this.dariBuffer,
    this.gulaDarah,
    this.detakJantung,
    this.sistolik,
    this.diastolik,
    this.spo2,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sesi_id'] = Variable<String>(sesiId);
    map['index'] = Variable<int>(index);
    map['detik_relatif_t0'] = Variable<int>(detikRelatifT0);
    {
      map['status'] = Variable<String>(
        $TabelSampelTable.$converterstatus.toSql(status),
      );
    }
    map['dari_buffer'] = Variable<bool>(dariBuffer);
    if (!nullToAbsent || gulaDarah != null) {
      map['gula_darah'] = Variable<int>(gulaDarah);
    }
    if (!nullToAbsent || detakJantung != null) {
      map['detak_jantung'] = Variable<int>(detakJantung);
    }
    if (!nullToAbsent || sistolik != null) {
      map['sistolik'] = Variable<int>(sistolik);
    }
    if (!nullToAbsent || diastolik != null) {
      map['diastolik'] = Variable<int>(diastolik);
    }
    if (!nullToAbsent || spo2 != null) {
      map['spo2'] = Variable<int>(spo2);
    }
    return map;
  }

  TabelSampelCompanion toCompanion(bool nullToAbsent) {
    return TabelSampelCompanion(
      sesiId: Value(sesiId),
      index: Value(index),
      detikRelatifT0: Value(detikRelatifT0),
      status: Value(status),
      dariBuffer: Value(dariBuffer),
      gulaDarah: gulaDarah == null && nullToAbsent
          ? const Value.absent()
          : Value(gulaDarah),
      detakJantung: detakJantung == null && nullToAbsent
          ? const Value.absent()
          : Value(detakJantung),
      sistolik: sistolik == null && nullToAbsent
          ? const Value.absent()
          : Value(sistolik),
      diastolik: diastolik == null && nullToAbsent
          ? const Value.absent()
          : Value(diastolik),
      spo2: spo2 == null && nullToAbsent ? const Value.absent() : Value(spo2),
    );
  }

  factory TabelSampelData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TabelSampelData(
      sesiId: serializer.fromJson<String>(json['sesiId']),
      index: serializer.fromJson<int>(json['index']),
      detikRelatifT0: serializer.fromJson<int>(json['detikRelatifT0']),
      status: $TabelSampelTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      dariBuffer: serializer.fromJson<bool>(json['dariBuffer']),
      gulaDarah: serializer.fromJson<int?>(json['gulaDarah']),
      detakJantung: serializer.fromJson<int?>(json['detakJantung']),
      sistolik: serializer.fromJson<int?>(json['sistolik']),
      diastolik: serializer.fromJson<int?>(json['diastolik']),
      spo2: serializer.fromJson<int?>(json['spo2']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sesiId': serializer.toJson<String>(sesiId),
      'index': serializer.toJson<int>(index),
      'detikRelatifT0': serializer.toJson<int>(detikRelatifT0),
      'status': serializer.toJson<String>(
        $TabelSampelTable.$converterstatus.toJson(status),
      ),
      'dariBuffer': serializer.toJson<bool>(dariBuffer),
      'gulaDarah': serializer.toJson<int?>(gulaDarah),
      'detakJantung': serializer.toJson<int?>(detakJantung),
      'sistolik': serializer.toJson<int?>(sistolik),
      'diastolik': serializer.toJson<int?>(diastolik),
      'spo2': serializer.toJson<int?>(spo2),
    };
  }

  TabelSampelData copyWith({
    String? sesiId,
    int? index,
    int? detikRelatifT0,
    StatusSampel? status,
    bool? dariBuffer,
    Value<int?> gulaDarah = const Value.absent(),
    Value<int?> detakJantung = const Value.absent(),
    Value<int?> sistolik = const Value.absent(),
    Value<int?> diastolik = const Value.absent(),
    Value<int?> spo2 = const Value.absent(),
  }) => TabelSampelData(
    sesiId: sesiId ?? this.sesiId,
    index: index ?? this.index,
    detikRelatifT0: detikRelatifT0 ?? this.detikRelatifT0,
    status: status ?? this.status,
    dariBuffer: dariBuffer ?? this.dariBuffer,
    gulaDarah: gulaDarah.present ? gulaDarah.value : this.gulaDarah,
    detakJantung: detakJantung.present ? detakJantung.value : this.detakJantung,
    sistolik: sistolik.present ? sistolik.value : this.sistolik,
    diastolik: diastolik.present ? diastolik.value : this.diastolik,
    spo2: spo2.present ? spo2.value : this.spo2,
  );
  TabelSampelData copyWithCompanion(TabelSampelCompanion data) {
    return TabelSampelData(
      sesiId: data.sesiId.present ? data.sesiId.value : this.sesiId,
      index: data.index.present ? data.index.value : this.index,
      detikRelatifT0: data.detikRelatifT0.present
          ? data.detikRelatifT0.value
          : this.detikRelatifT0,
      status: data.status.present ? data.status.value : this.status,
      dariBuffer: data.dariBuffer.present
          ? data.dariBuffer.value
          : this.dariBuffer,
      gulaDarah: data.gulaDarah.present ? data.gulaDarah.value : this.gulaDarah,
      detakJantung: data.detakJantung.present
          ? data.detakJantung.value
          : this.detakJantung,
      sistolik: data.sistolik.present ? data.sistolik.value : this.sistolik,
      diastolik: data.diastolik.present ? data.diastolik.value : this.diastolik,
      spo2: data.spo2.present ? data.spo2.value : this.spo2,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TabelSampelData(')
          ..write('sesiId: $sesiId, ')
          ..write('index: $index, ')
          ..write('detikRelatifT0: $detikRelatifT0, ')
          ..write('status: $status, ')
          ..write('dariBuffer: $dariBuffer, ')
          ..write('gulaDarah: $gulaDarah, ')
          ..write('detakJantung: $detakJantung, ')
          ..write('sistolik: $sistolik, ')
          ..write('diastolik: $diastolik, ')
          ..write('spo2: $spo2')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sesiId,
    index,
    detikRelatifT0,
    status,
    dariBuffer,
    gulaDarah,
    detakJantung,
    sistolik,
    diastolik,
    spo2,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TabelSampelData &&
          other.sesiId == this.sesiId &&
          other.index == this.index &&
          other.detikRelatifT0 == this.detikRelatifT0 &&
          other.status == this.status &&
          other.dariBuffer == this.dariBuffer &&
          other.gulaDarah == this.gulaDarah &&
          other.detakJantung == this.detakJantung &&
          other.sistolik == this.sistolik &&
          other.diastolik == this.diastolik &&
          other.spo2 == this.spo2);
}

class TabelSampelCompanion extends UpdateCompanion<TabelSampelData> {
  final Value<String> sesiId;
  final Value<int> index;
  final Value<int> detikRelatifT0;
  final Value<StatusSampel> status;
  final Value<bool> dariBuffer;
  final Value<int?> gulaDarah;
  final Value<int?> detakJantung;
  final Value<int?> sistolik;
  final Value<int?> diastolik;
  final Value<int?> spo2;
  final Value<int> rowid;
  const TabelSampelCompanion({
    this.sesiId = const Value.absent(),
    this.index = const Value.absent(),
    this.detikRelatifT0 = const Value.absent(),
    this.status = const Value.absent(),
    this.dariBuffer = const Value.absent(),
    this.gulaDarah = const Value.absent(),
    this.detakJantung = const Value.absent(),
    this.sistolik = const Value.absent(),
    this.diastolik = const Value.absent(),
    this.spo2 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TabelSampelCompanion.insert({
    required String sesiId,
    required int index,
    required int detikRelatifT0,
    required StatusSampel status,
    this.dariBuffer = const Value.absent(),
    this.gulaDarah = const Value.absent(),
    this.detakJantung = const Value.absent(),
    this.sistolik = const Value.absent(),
    this.diastolik = const Value.absent(),
    this.spo2 = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sesiId = Value(sesiId),
       index = Value(index),
       detikRelatifT0 = Value(detikRelatifT0),
       status = Value(status);
  static Insertable<TabelSampelData> custom({
    Expression<String>? sesiId,
    Expression<int>? index,
    Expression<int>? detikRelatifT0,
    Expression<String>? status,
    Expression<bool>? dariBuffer,
    Expression<int>? gulaDarah,
    Expression<int>? detakJantung,
    Expression<int>? sistolik,
    Expression<int>? diastolik,
    Expression<int>? spo2,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sesiId != null) 'sesi_id': sesiId,
      if (index != null) 'index': index,
      if (detikRelatifT0 != null) 'detik_relatif_t0': detikRelatifT0,
      if (status != null) 'status': status,
      if (dariBuffer != null) 'dari_buffer': dariBuffer,
      if (gulaDarah != null) 'gula_darah': gulaDarah,
      if (detakJantung != null) 'detak_jantung': detakJantung,
      if (sistolik != null) 'sistolik': sistolik,
      if (diastolik != null) 'diastolik': diastolik,
      if (spo2 != null) 'spo2': spo2,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TabelSampelCompanion copyWith({
    Value<String>? sesiId,
    Value<int>? index,
    Value<int>? detikRelatifT0,
    Value<StatusSampel>? status,
    Value<bool>? dariBuffer,
    Value<int?>? gulaDarah,
    Value<int?>? detakJantung,
    Value<int?>? sistolik,
    Value<int?>? diastolik,
    Value<int?>? spo2,
    Value<int>? rowid,
  }) {
    return TabelSampelCompanion(
      sesiId: sesiId ?? this.sesiId,
      index: index ?? this.index,
      detikRelatifT0: detikRelatifT0 ?? this.detikRelatifT0,
      status: status ?? this.status,
      dariBuffer: dariBuffer ?? this.dariBuffer,
      gulaDarah: gulaDarah ?? this.gulaDarah,
      detakJantung: detakJantung ?? this.detakJantung,
      sistolik: sistolik ?? this.sistolik,
      diastolik: diastolik ?? this.diastolik,
      spo2: spo2 ?? this.spo2,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sesiId.present) {
      map['sesi_id'] = Variable<String>(sesiId.value);
    }
    if (index.present) {
      map['index'] = Variable<int>(index.value);
    }
    if (detikRelatifT0.present) {
      map['detik_relatif_t0'] = Variable<int>(detikRelatifT0.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TabelSampelTable.$converterstatus.toSql(status.value),
      );
    }
    if (dariBuffer.present) {
      map['dari_buffer'] = Variable<bool>(dariBuffer.value);
    }
    if (gulaDarah.present) {
      map['gula_darah'] = Variable<int>(gulaDarah.value);
    }
    if (detakJantung.present) {
      map['detak_jantung'] = Variable<int>(detakJantung.value);
    }
    if (sistolik.present) {
      map['sistolik'] = Variable<int>(sistolik.value);
    }
    if (diastolik.present) {
      map['diastolik'] = Variable<int>(diastolik.value);
    }
    if (spo2.present) {
      map['spo2'] = Variable<int>(spo2.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TabelSampelCompanion(')
          ..write('sesiId: $sesiId, ')
          ..write('index: $index, ')
          ..write('detikRelatifT0: $detikRelatifT0, ')
          ..write('status: $status, ')
          ..write('dariBuffer: $dariBuffer, ')
          ..write('gulaDarah: $gulaDarah, ')
          ..write('detakJantung: $detakJantung, ')
          ..write('sistolik: $sistolik, ')
          ..write('diastolik: $diastolik, ')
          ..write('spo2: $spo2, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TabelHasilDeteksiTable extends TabelHasilDeteksi
    with TableInfo<$TabelHasilDeteksiTable, TabelHasilDeteksiData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TabelHasilDeteksiTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sesiIdMeta = const VerificationMeta('sesiId');
  @override
  late final GeneratedColumn<String> sesiId = GeneratedColumn<String>(
    'sesi_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tabel_sesi (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _indeksGlikemikPerkiraanMeta =
      const VerificationMeta('indeksGlikemikPerkiraan');
  @override
  late final GeneratedColumn<String> indeksGlikemikPerkiraan =
      GeneratedColumn<String>(
        'indeks_glikemik_perkiraan',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _keyakinanMeta = const VerificationMeta(
    'keyakinan',
  );
  @override
  late final GeneratedColumn<double> keyakinan = GeneratedColumn<double>(
    'keyakinan',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dikoreksiUserMeta = const VerificationMeta(
    'dikoreksiUser',
  );
  @override
  late final GeneratedColumn<bool> dikoreksiUser = GeneratedColumn<bool>(
    'dikoreksi_user',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("dikoreksi_user" IN (0, 1))',
    ),
  );
  static const VerificationMeta _totalKaloriMeta = const VerificationMeta(
    'totalKalori',
  );
  @override
  late final GeneratedColumn<double> totalKalori = GeneratedColumn<double>(
    'total_kalori',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalKarbohidratMeta = const VerificationMeta(
    'totalKarbohidrat',
  );
  @override
  late final GeneratedColumn<double> totalKarbohidrat = GeneratedColumn<double>(
    'total_karbohidrat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalProteinMeta = const VerificationMeta(
    'totalProtein',
  );
  @override
  late final GeneratedColumn<double> totalProtein = GeneratedColumn<double>(
    'total_protein',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalLemakMeta = const VerificationMeta(
    'totalLemak',
  );
  @override
  late final GeneratedColumn<double> totalLemak = GeneratedColumn<double>(
    'total_lemak',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalGulaTotalMeta = const VerificationMeta(
    'totalGulaTotal',
  );
  @override
  late final GeneratedColumn<double> totalGulaTotal = GeneratedColumn<double>(
    'total_gula_total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalSeratMeta = const VerificationMeta(
    'totalSerat',
  );
  @override
  late final GeneratedColumn<double> totalSerat = GeneratedColumn<double>(
    'total_serat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sesiId,
    indeksGlikemikPerkiraan,
    keyakinan,
    dikoreksiUser,
    totalKalori,
    totalKarbohidrat,
    totalProtein,
    totalLemak,
    totalGulaTotal,
    totalSerat,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tabel_hasil_deteksi';
  @override
  VerificationContext validateIntegrity(
    Insertable<TabelHasilDeteksiData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sesi_id')) {
      context.handle(
        _sesiIdMeta,
        sesiId.isAcceptableOrUnknown(data['sesi_id']!, _sesiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sesiIdMeta);
    }
    if (data.containsKey('indeks_glikemik_perkiraan')) {
      context.handle(
        _indeksGlikemikPerkiraanMeta,
        indeksGlikemikPerkiraan.isAcceptableOrUnknown(
          data['indeks_glikemik_perkiraan']!,
          _indeksGlikemikPerkiraanMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_indeksGlikemikPerkiraanMeta);
    }
    if (data.containsKey('keyakinan')) {
      context.handle(
        _keyakinanMeta,
        keyakinan.isAcceptableOrUnknown(data['keyakinan']!, _keyakinanMeta),
      );
    } else if (isInserting) {
      context.missing(_keyakinanMeta);
    }
    if (data.containsKey('dikoreksi_user')) {
      context.handle(
        _dikoreksiUserMeta,
        dikoreksiUser.isAcceptableOrUnknown(
          data['dikoreksi_user']!,
          _dikoreksiUserMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_dikoreksiUserMeta);
    }
    if (data.containsKey('total_kalori')) {
      context.handle(
        _totalKaloriMeta,
        totalKalori.isAcceptableOrUnknown(
          data['total_kalori']!,
          _totalKaloriMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalKaloriMeta);
    }
    if (data.containsKey('total_karbohidrat')) {
      context.handle(
        _totalKarbohidratMeta,
        totalKarbohidrat.isAcceptableOrUnknown(
          data['total_karbohidrat']!,
          _totalKarbohidratMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalKarbohidratMeta);
    }
    if (data.containsKey('total_protein')) {
      context.handle(
        _totalProteinMeta,
        totalProtein.isAcceptableOrUnknown(
          data['total_protein']!,
          _totalProteinMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalProteinMeta);
    }
    if (data.containsKey('total_lemak')) {
      context.handle(
        _totalLemakMeta,
        totalLemak.isAcceptableOrUnknown(data['total_lemak']!, _totalLemakMeta),
      );
    } else if (isInserting) {
      context.missing(_totalLemakMeta);
    }
    if (data.containsKey('total_gula_total')) {
      context.handle(
        _totalGulaTotalMeta,
        totalGulaTotal.isAcceptableOrUnknown(
          data['total_gula_total']!,
          _totalGulaTotalMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_totalGulaTotalMeta);
    }
    if (data.containsKey('total_serat')) {
      context.handle(
        _totalSeratMeta,
        totalSerat.isAcceptableOrUnknown(data['total_serat']!, _totalSeratMeta),
      );
    } else if (isInserting) {
      context.missing(_totalSeratMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sesiId};
  @override
  TabelHasilDeteksiData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TabelHasilDeteksiData(
      sesiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sesi_id'],
      )!,
      indeksGlikemikPerkiraan: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}indeks_glikemik_perkiraan'],
      )!,
      keyakinan: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}keyakinan'],
      )!,
      dikoreksiUser: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}dikoreksi_user'],
      )!,
      totalKalori: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_kalori'],
      )!,
      totalKarbohidrat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_karbohidrat'],
      )!,
      totalProtein: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_protein'],
      )!,
      totalLemak: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_lemak'],
      )!,
      totalGulaTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_gula_total'],
      )!,
      totalSerat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}total_serat'],
      )!,
    );
  }

  @override
  $TabelHasilDeteksiTable createAlias(String alias) {
    return $TabelHasilDeteksiTable(attachedDatabase, alias);
  }
}

class TabelHasilDeteksiData extends DataClass
    implements Insertable<TabelHasilDeteksiData> {
  final String sesiId;
  final String indeksGlikemikPerkiraan;
  final double keyakinan;
  final bool dikoreksiUser;
  final double totalKalori;
  final double totalKarbohidrat;
  final double totalProtein;
  final double totalLemak;
  final double totalGulaTotal;
  final double totalSerat;
  const TabelHasilDeteksiData({
    required this.sesiId,
    required this.indeksGlikemikPerkiraan,
    required this.keyakinan,
    required this.dikoreksiUser,
    required this.totalKalori,
    required this.totalKarbohidrat,
    required this.totalProtein,
    required this.totalLemak,
    required this.totalGulaTotal,
    required this.totalSerat,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sesi_id'] = Variable<String>(sesiId);
    map['indeks_glikemik_perkiraan'] = Variable<String>(
      indeksGlikemikPerkiraan,
    );
    map['keyakinan'] = Variable<double>(keyakinan);
    map['dikoreksi_user'] = Variable<bool>(dikoreksiUser);
    map['total_kalori'] = Variable<double>(totalKalori);
    map['total_karbohidrat'] = Variable<double>(totalKarbohidrat);
    map['total_protein'] = Variable<double>(totalProtein);
    map['total_lemak'] = Variable<double>(totalLemak);
    map['total_gula_total'] = Variable<double>(totalGulaTotal);
    map['total_serat'] = Variable<double>(totalSerat);
    return map;
  }

  TabelHasilDeteksiCompanion toCompanion(bool nullToAbsent) {
    return TabelHasilDeteksiCompanion(
      sesiId: Value(sesiId),
      indeksGlikemikPerkiraan: Value(indeksGlikemikPerkiraan),
      keyakinan: Value(keyakinan),
      dikoreksiUser: Value(dikoreksiUser),
      totalKalori: Value(totalKalori),
      totalKarbohidrat: Value(totalKarbohidrat),
      totalProtein: Value(totalProtein),
      totalLemak: Value(totalLemak),
      totalGulaTotal: Value(totalGulaTotal),
      totalSerat: Value(totalSerat),
    );
  }

  factory TabelHasilDeteksiData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TabelHasilDeteksiData(
      sesiId: serializer.fromJson<String>(json['sesiId']),
      indeksGlikemikPerkiraan: serializer.fromJson<String>(
        json['indeksGlikemikPerkiraan'],
      ),
      keyakinan: serializer.fromJson<double>(json['keyakinan']),
      dikoreksiUser: serializer.fromJson<bool>(json['dikoreksiUser']),
      totalKalori: serializer.fromJson<double>(json['totalKalori']),
      totalKarbohidrat: serializer.fromJson<double>(json['totalKarbohidrat']),
      totalProtein: serializer.fromJson<double>(json['totalProtein']),
      totalLemak: serializer.fromJson<double>(json['totalLemak']),
      totalGulaTotal: serializer.fromJson<double>(json['totalGulaTotal']),
      totalSerat: serializer.fromJson<double>(json['totalSerat']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sesiId': serializer.toJson<String>(sesiId),
      'indeksGlikemikPerkiraan': serializer.toJson<String>(
        indeksGlikemikPerkiraan,
      ),
      'keyakinan': serializer.toJson<double>(keyakinan),
      'dikoreksiUser': serializer.toJson<bool>(dikoreksiUser),
      'totalKalori': serializer.toJson<double>(totalKalori),
      'totalKarbohidrat': serializer.toJson<double>(totalKarbohidrat),
      'totalProtein': serializer.toJson<double>(totalProtein),
      'totalLemak': serializer.toJson<double>(totalLemak),
      'totalGulaTotal': serializer.toJson<double>(totalGulaTotal),
      'totalSerat': serializer.toJson<double>(totalSerat),
    };
  }

  TabelHasilDeteksiData copyWith({
    String? sesiId,
    String? indeksGlikemikPerkiraan,
    double? keyakinan,
    bool? dikoreksiUser,
    double? totalKalori,
    double? totalKarbohidrat,
    double? totalProtein,
    double? totalLemak,
    double? totalGulaTotal,
    double? totalSerat,
  }) => TabelHasilDeteksiData(
    sesiId: sesiId ?? this.sesiId,
    indeksGlikemikPerkiraan:
        indeksGlikemikPerkiraan ?? this.indeksGlikemikPerkiraan,
    keyakinan: keyakinan ?? this.keyakinan,
    dikoreksiUser: dikoreksiUser ?? this.dikoreksiUser,
    totalKalori: totalKalori ?? this.totalKalori,
    totalKarbohidrat: totalKarbohidrat ?? this.totalKarbohidrat,
    totalProtein: totalProtein ?? this.totalProtein,
    totalLemak: totalLemak ?? this.totalLemak,
    totalGulaTotal: totalGulaTotal ?? this.totalGulaTotal,
    totalSerat: totalSerat ?? this.totalSerat,
  );
  TabelHasilDeteksiData copyWithCompanion(TabelHasilDeteksiCompanion data) {
    return TabelHasilDeteksiData(
      sesiId: data.sesiId.present ? data.sesiId.value : this.sesiId,
      indeksGlikemikPerkiraan: data.indeksGlikemikPerkiraan.present
          ? data.indeksGlikemikPerkiraan.value
          : this.indeksGlikemikPerkiraan,
      keyakinan: data.keyakinan.present ? data.keyakinan.value : this.keyakinan,
      dikoreksiUser: data.dikoreksiUser.present
          ? data.dikoreksiUser.value
          : this.dikoreksiUser,
      totalKalori: data.totalKalori.present
          ? data.totalKalori.value
          : this.totalKalori,
      totalKarbohidrat: data.totalKarbohidrat.present
          ? data.totalKarbohidrat.value
          : this.totalKarbohidrat,
      totalProtein: data.totalProtein.present
          ? data.totalProtein.value
          : this.totalProtein,
      totalLemak: data.totalLemak.present
          ? data.totalLemak.value
          : this.totalLemak,
      totalGulaTotal: data.totalGulaTotal.present
          ? data.totalGulaTotal.value
          : this.totalGulaTotal,
      totalSerat: data.totalSerat.present
          ? data.totalSerat.value
          : this.totalSerat,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TabelHasilDeteksiData(')
          ..write('sesiId: $sesiId, ')
          ..write('indeksGlikemikPerkiraan: $indeksGlikemikPerkiraan, ')
          ..write('keyakinan: $keyakinan, ')
          ..write('dikoreksiUser: $dikoreksiUser, ')
          ..write('totalKalori: $totalKalori, ')
          ..write('totalKarbohidrat: $totalKarbohidrat, ')
          ..write('totalProtein: $totalProtein, ')
          ..write('totalLemak: $totalLemak, ')
          ..write('totalGulaTotal: $totalGulaTotal, ')
          ..write('totalSerat: $totalSerat')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sesiId,
    indeksGlikemikPerkiraan,
    keyakinan,
    dikoreksiUser,
    totalKalori,
    totalKarbohidrat,
    totalProtein,
    totalLemak,
    totalGulaTotal,
    totalSerat,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TabelHasilDeteksiData &&
          other.sesiId == this.sesiId &&
          other.indeksGlikemikPerkiraan == this.indeksGlikemikPerkiraan &&
          other.keyakinan == this.keyakinan &&
          other.dikoreksiUser == this.dikoreksiUser &&
          other.totalKalori == this.totalKalori &&
          other.totalKarbohidrat == this.totalKarbohidrat &&
          other.totalProtein == this.totalProtein &&
          other.totalLemak == this.totalLemak &&
          other.totalGulaTotal == this.totalGulaTotal &&
          other.totalSerat == this.totalSerat);
}

class TabelHasilDeteksiCompanion
    extends UpdateCompanion<TabelHasilDeteksiData> {
  final Value<String> sesiId;
  final Value<String> indeksGlikemikPerkiraan;
  final Value<double> keyakinan;
  final Value<bool> dikoreksiUser;
  final Value<double> totalKalori;
  final Value<double> totalKarbohidrat;
  final Value<double> totalProtein;
  final Value<double> totalLemak;
  final Value<double> totalGulaTotal;
  final Value<double> totalSerat;
  final Value<int> rowid;
  const TabelHasilDeteksiCompanion({
    this.sesiId = const Value.absent(),
    this.indeksGlikemikPerkiraan = const Value.absent(),
    this.keyakinan = const Value.absent(),
    this.dikoreksiUser = const Value.absent(),
    this.totalKalori = const Value.absent(),
    this.totalKarbohidrat = const Value.absent(),
    this.totalProtein = const Value.absent(),
    this.totalLemak = const Value.absent(),
    this.totalGulaTotal = const Value.absent(),
    this.totalSerat = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TabelHasilDeteksiCompanion.insert({
    required String sesiId,
    required String indeksGlikemikPerkiraan,
    required double keyakinan,
    required bool dikoreksiUser,
    required double totalKalori,
    required double totalKarbohidrat,
    required double totalProtein,
    required double totalLemak,
    required double totalGulaTotal,
    required double totalSerat,
    this.rowid = const Value.absent(),
  }) : sesiId = Value(sesiId),
       indeksGlikemikPerkiraan = Value(indeksGlikemikPerkiraan),
       keyakinan = Value(keyakinan),
       dikoreksiUser = Value(dikoreksiUser),
       totalKalori = Value(totalKalori),
       totalKarbohidrat = Value(totalKarbohidrat),
       totalProtein = Value(totalProtein),
       totalLemak = Value(totalLemak),
       totalGulaTotal = Value(totalGulaTotal),
       totalSerat = Value(totalSerat);
  static Insertable<TabelHasilDeteksiData> custom({
    Expression<String>? sesiId,
    Expression<String>? indeksGlikemikPerkiraan,
    Expression<double>? keyakinan,
    Expression<bool>? dikoreksiUser,
    Expression<double>? totalKalori,
    Expression<double>? totalKarbohidrat,
    Expression<double>? totalProtein,
    Expression<double>? totalLemak,
    Expression<double>? totalGulaTotal,
    Expression<double>? totalSerat,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sesiId != null) 'sesi_id': sesiId,
      if (indeksGlikemikPerkiraan != null)
        'indeks_glikemik_perkiraan': indeksGlikemikPerkiraan,
      if (keyakinan != null) 'keyakinan': keyakinan,
      if (dikoreksiUser != null) 'dikoreksi_user': dikoreksiUser,
      if (totalKalori != null) 'total_kalori': totalKalori,
      if (totalKarbohidrat != null) 'total_karbohidrat': totalKarbohidrat,
      if (totalProtein != null) 'total_protein': totalProtein,
      if (totalLemak != null) 'total_lemak': totalLemak,
      if (totalGulaTotal != null) 'total_gula_total': totalGulaTotal,
      if (totalSerat != null) 'total_serat': totalSerat,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TabelHasilDeteksiCompanion copyWith({
    Value<String>? sesiId,
    Value<String>? indeksGlikemikPerkiraan,
    Value<double>? keyakinan,
    Value<bool>? dikoreksiUser,
    Value<double>? totalKalori,
    Value<double>? totalKarbohidrat,
    Value<double>? totalProtein,
    Value<double>? totalLemak,
    Value<double>? totalGulaTotal,
    Value<double>? totalSerat,
    Value<int>? rowid,
  }) {
    return TabelHasilDeteksiCompanion(
      sesiId: sesiId ?? this.sesiId,
      indeksGlikemikPerkiraan:
          indeksGlikemikPerkiraan ?? this.indeksGlikemikPerkiraan,
      keyakinan: keyakinan ?? this.keyakinan,
      dikoreksiUser: dikoreksiUser ?? this.dikoreksiUser,
      totalKalori: totalKalori ?? this.totalKalori,
      totalKarbohidrat: totalKarbohidrat ?? this.totalKarbohidrat,
      totalProtein: totalProtein ?? this.totalProtein,
      totalLemak: totalLemak ?? this.totalLemak,
      totalGulaTotal: totalGulaTotal ?? this.totalGulaTotal,
      totalSerat: totalSerat ?? this.totalSerat,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sesiId.present) {
      map['sesi_id'] = Variable<String>(sesiId.value);
    }
    if (indeksGlikemikPerkiraan.present) {
      map['indeks_glikemik_perkiraan'] = Variable<String>(
        indeksGlikemikPerkiraan.value,
      );
    }
    if (keyakinan.present) {
      map['keyakinan'] = Variable<double>(keyakinan.value);
    }
    if (dikoreksiUser.present) {
      map['dikoreksi_user'] = Variable<bool>(dikoreksiUser.value);
    }
    if (totalKalori.present) {
      map['total_kalori'] = Variable<double>(totalKalori.value);
    }
    if (totalKarbohidrat.present) {
      map['total_karbohidrat'] = Variable<double>(totalKarbohidrat.value);
    }
    if (totalProtein.present) {
      map['total_protein'] = Variable<double>(totalProtein.value);
    }
    if (totalLemak.present) {
      map['total_lemak'] = Variable<double>(totalLemak.value);
    }
    if (totalGulaTotal.present) {
      map['total_gula_total'] = Variable<double>(totalGulaTotal.value);
    }
    if (totalSerat.present) {
      map['total_serat'] = Variable<double>(totalSerat.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TabelHasilDeteksiCompanion(')
          ..write('sesiId: $sesiId, ')
          ..write('indeksGlikemikPerkiraan: $indeksGlikemikPerkiraan, ')
          ..write('keyakinan: $keyakinan, ')
          ..write('dikoreksiUser: $dikoreksiUser, ')
          ..write('totalKalori: $totalKalori, ')
          ..write('totalKarbohidrat: $totalKarbohidrat, ')
          ..write('totalProtein: $totalProtein, ')
          ..write('totalLemak: $totalLemak, ')
          ..write('totalGulaTotal: $totalGulaTotal, ')
          ..write('totalSerat: $totalSerat, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TabelItemMakananTable extends TabelItemMakanan
    with TableInfo<$TabelItemMakananTable, TabelItemMakananData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TabelItemMakananTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sesiIdMeta = const VerificationMeta('sesiId');
  @override
  late final GeneratedColumn<String> sesiId = GeneratedColumn<String>(
    'sesi_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tabel_sesi (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _urutanMeta = const VerificationMeta('urutan');
  @override
  late final GeneratedColumn<int> urutan = GeneratedColumn<int>(
    'urutan',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _namaMeta = const VerificationMeta('nama');
  @override
  late final GeneratedColumn<String> nama = GeneratedColumn<String>(
    'nama',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _porsiMeta = const VerificationMeta('porsi');
  @override
  late final GeneratedColumn<String> porsi = GeneratedColumn<String>(
    'porsi',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _estimasiGramMeta = const VerificationMeta(
    'estimasiGram',
  );
  @override
  late final GeneratedColumn<double> estimasiGram = GeneratedColumn<double>(
    'estimasi_gram',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kaloriMeta = const VerificationMeta('kalori');
  @override
  late final GeneratedColumn<double> kalori = GeneratedColumn<double>(
    'kalori',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _karbohidratMeta = const VerificationMeta(
    'karbohidrat',
  );
  @override
  late final GeneratedColumn<double> karbohidrat = GeneratedColumn<double>(
    'karbohidrat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinMeta = const VerificationMeta(
    'protein',
  );
  @override
  late final GeneratedColumn<double> protein = GeneratedColumn<double>(
    'protein',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lemakMeta = const VerificationMeta('lemak');
  @override
  late final GeneratedColumn<double> lemak = GeneratedColumn<double>(
    'lemak',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _gulaTotalMeta = const VerificationMeta(
    'gulaTotal',
  );
  @override
  late final GeneratedColumn<double> gulaTotal = GeneratedColumn<double>(
    'gula_total',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _seratMeta = const VerificationMeta('serat');
  @override
  late final GeneratedColumn<double> serat = GeneratedColumn<double>(
    'serat',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    sesiId,
    urutan,
    nama,
    porsi,
    estimasiGram,
    kalori,
    karbohidrat,
    protein,
    lemak,
    gulaTotal,
    serat,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tabel_item_makanan';
  @override
  VerificationContext validateIntegrity(
    Insertable<TabelItemMakananData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sesi_id')) {
      context.handle(
        _sesiIdMeta,
        sesiId.isAcceptableOrUnknown(data['sesi_id']!, _sesiIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sesiIdMeta);
    }
    if (data.containsKey('urutan')) {
      context.handle(
        _urutanMeta,
        urutan.isAcceptableOrUnknown(data['urutan']!, _urutanMeta),
      );
    } else if (isInserting) {
      context.missing(_urutanMeta);
    }
    if (data.containsKey('nama')) {
      context.handle(
        _namaMeta,
        nama.isAcceptableOrUnknown(data['nama']!, _namaMeta),
      );
    } else if (isInserting) {
      context.missing(_namaMeta);
    }
    if (data.containsKey('porsi')) {
      context.handle(
        _porsiMeta,
        porsi.isAcceptableOrUnknown(data['porsi']!, _porsiMeta),
      );
    } else if (isInserting) {
      context.missing(_porsiMeta);
    }
    if (data.containsKey('estimasi_gram')) {
      context.handle(
        _estimasiGramMeta,
        estimasiGram.isAcceptableOrUnknown(
          data['estimasi_gram']!,
          _estimasiGramMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_estimasiGramMeta);
    }
    if (data.containsKey('kalori')) {
      context.handle(
        _kaloriMeta,
        kalori.isAcceptableOrUnknown(data['kalori']!, _kaloriMeta),
      );
    } else if (isInserting) {
      context.missing(_kaloriMeta);
    }
    if (data.containsKey('karbohidrat')) {
      context.handle(
        _karbohidratMeta,
        karbohidrat.isAcceptableOrUnknown(
          data['karbohidrat']!,
          _karbohidratMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_karbohidratMeta);
    }
    if (data.containsKey('protein')) {
      context.handle(
        _proteinMeta,
        protein.isAcceptableOrUnknown(data['protein']!, _proteinMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinMeta);
    }
    if (data.containsKey('lemak')) {
      context.handle(
        _lemakMeta,
        lemak.isAcceptableOrUnknown(data['lemak']!, _lemakMeta),
      );
    } else if (isInserting) {
      context.missing(_lemakMeta);
    }
    if (data.containsKey('gula_total')) {
      context.handle(
        _gulaTotalMeta,
        gulaTotal.isAcceptableOrUnknown(data['gula_total']!, _gulaTotalMeta),
      );
    } else if (isInserting) {
      context.missing(_gulaTotalMeta);
    }
    if (data.containsKey('serat')) {
      context.handle(
        _seratMeta,
        serat.isAcceptableOrUnknown(data['serat']!, _seratMeta),
      );
    } else if (isInserting) {
      context.missing(_seratMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sesiId, urutan};
  @override
  TabelItemMakananData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TabelItemMakananData(
      sesiId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sesi_id'],
      )!,
      urutan: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}urutan'],
      )!,
      nama: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nama'],
      )!,
      porsi: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}porsi'],
      )!,
      estimasiGram: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}estimasi_gram'],
      )!,
      kalori: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}kalori'],
      )!,
      karbohidrat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}karbohidrat'],
      )!,
      protein: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein'],
      )!,
      lemak: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}lemak'],
      )!,
      gulaTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}gula_total'],
      )!,
      serat: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serat'],
      )!,
    );
  }

  @override
  $TabelItemMakananTable createAlias(String alias) {
    return $TabelItemMakananTable(attachedDatabase, alias);
  }
}

class TabelItemMakananData extends DataClass
    implements Insertable<TabelItemMakananData> {
  final String sesiId;
  final int urutan;
  final String nama;
  final String porsi;
  final double estimasiGram;
  final double kalori;
  final double karbohidrat;
  final double protein;
  final double lemak;
  final double gulaTotal;
  final double serat;
  const TabelItemMakananData({
    required this.sesiId,
    required this.urutan,
    required this.nama,
    required this.porsi,
    required this.estimasiGram,
    required this.kalori,
    required this.karbohidrat,
    required this.protein,
    required this.lemak,
    required this.gulaTotal,
    required this.serat,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sesi_id'] = Variable<String>(sesiId);
    map['urutan'] = Variable<int>(urutan);
    map['nama'] = Variable<String>(nama);
    map['porsi'] = Variable<String>(porsi);
    map['estimasi_gram'] = Variable<double>(estimasiGram);
    map['kalori'] = Variable<double>(kalori);
    map['karbohidrat'] = Variable<double>(karbohidrat);
    map['protein'] = Variable<double>(protein);
    map['lemak'] = Variable<double>(lemak);
    map['gula_total'] = Variable<double>(gulaTotal);
    map['serat'] = Variable<double>(serat);
    return map;
  }

  TabelItemMakananCompanion toCompanion(bool nullToAbsent) {
    return TabelItemMakananCompanion(
      sesiId: Value(sesiId),
      urutan: Value(urutan),
      nama: Value(nama),
      porsi: Value(porsi),
      estimasiGram: Value(estimasiGram),
      kalori: Value(kalori),
      karbohidrat: Value(karbohidrat),
      protein: Value(protein),
      lemak: Value(lemak),
      gulaTotal: Value(gulaTotal),
      serat: Value(serat),
    );
  }

  factory TabelItemMakananData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TabelItemMakananData(
      sesiId: serializer.fromJson<String>(json['sesiId']),
      urutan: serializer.fromJson<int>(json['urutan']),
      nama: serializer.fromJson<String>(json['nama']),
      porsi: serializer.fromJson<String>(json['porsi']),
      estimasiGram: serializer.fromJson<double>(json['estimasiGram']),
      kalori: serializer.fromJson<double>(json['kalori']),
      karbohidrat: serializer.fromJson<double>(json['karbohidrat']),
      protein: serializer.fromJson<double>(json['protein']),
      lemak: serializer.fromJson<double>(json['lemak']),
      gulaTotal: serializer.fromJson<double>(json['gulaTotal']),
      serat: serializer.fromJson<double>(json['serat']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sesiId': serializer.toJson<String>(sesiId),
      'urutan': serializer.toJson<int>(urutan),
      'nama': serializer.toJson<String>(nama),
      'porsi': serializer.toJson<String>(porsi),
      'estimasiGram': serializer.toJson<double>(estimasiGram),
      'kalori': serializer.toJson<double>(kalori),
      'karbohidrat': serializer.toJson<double>(karbohidrat),
      'protein': serializer.toJson<double>(protein),
      'lemak': serializer.toJson<double>(lemak),
      'gulaTotal': serializer.toJson<double>(gulaTotal),
      'serat': serializer.toJson<double>(serat),
    };
  }

  TabelItemMakananData copyWith({
    String? sesiId,
    int? urutan,
    String? nama,
    String? porsi,
    double? estimasiGram,
    double? kalori,
    double? karbohidrat,
    double? protein,
    double? lemak,
    double? gulaTotal,
    double? serat,
  }) => TabelItemMakananData(
    sesiId: sesiId ?? this.sesiId,
    urutan: urutan ?? this.urutan,
    nama: nama ?? this.nama,
    porsi: porsi ?? this.porsi,
    estimasiGram: estimasiGram ?? this.estimasiGram,
    kalori: kalori ?? this.kalori,
    karbohidrat: karbohidrat ?? this.karbohidrat,
    protein: protein ?? this.protein,
    lemak: lemak ?? this.lemak,
    gulaTotal: gulaTotal ?? this.gulaTotal,
    serat: serat ?? this.serat,
  );
  TabelItemMakananData copyWithCompanion(TabelItemMakananCompanion data) {
    return TabelItemMakananData(
      sesiId: data.sesiId.present ? data.sesiId.value : this.sesiId,
      urutan: data.urutan.present ? data.urutan.value : this.urutan,
      nama: data.nama.present ? data.nama.value : this.nama,
      porsi: data.porsi.present ? data.porsi.value : this.porsi,
      estimasiGram: data.estimasiGram.present
          ? data.estimasiGram.value
          : this.estimasiGram,
      kalori: data.kalori.present ? data.kalori.value : this.kalori,
      karbohidrat: data.karbohidrat.present
          ? data.karbohidrat.value
          : this.karbohidrat,
      protein: data.protein.present ? data.protein.value : this.protein,
      lemak: data.lemak.present ? data.lemak.value : this.lemak,
      gulaTotal: data.gulaTotal.present ? data.gulaTotal.value : this.gulaTotal,
      serat: data.serat.present ? data.serat.value : this.serat,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TabelItemMakananData(')
          ..write('sesiId: $sesiId, ')
          ..write('urutan: $urutan, ')
          ..write('nama: $nama, ')
          ..write('porsi: $porsi, ')
          ..write('estimasiGram: $estimasiGram, ')
          ..write('kalori: $kalori, ')
          ..write('karbohidrat: $karbohidrat, ')
          ..write('protein: $protein, ')
          ..write('lemak: $lemak, ')
          ..write('gulaTotal: $gulaTotal, ')
          ..write('serat: $serat')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sesiId,
    urutan,
    nama,
    porsi,
    estimasiGram,
    kalori,
    karbohidrat,
    protein,
    lemak,
    gulaTotal,
    serat,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TabelItemMakananData &&
          other.sesiId == this.sesiId &&
          other.urutan == this.urutan &&
          other.nama == this.nama &&
          other.porsi == this.porsi &&
          other.estimasiGram == this.estimasiGram &&
          other.kalori == this.kalori &&
          other.karbohidrat == this.karbohidrat &&
          other.protein == this.protein &&
          other.lemak == this.lemak &&
          other.gulaTotal == this.gulaTotal &&
          other.serat == this.serat);
}

class TabelItemMakananCompanion extends UpdateCompanion<TabelItemMakananData> {
  final Value<String> sesiId;
  final Value<int> urutan;
  final Value<String> nama;
  final Value<String> porsi;
  final Value<double> estimasiGram;
  final Value<double> kalori;
  final Value<double> karbohidrat;
  final Value<double> protein;
  final Value<double> lemak;
  final Value<double> gulaTotal;
  final Value<double> serat;
  final Value<int> rowid;
  const TabelItemMakananCompanion({
    this.sesiId = const Value.absent(),
    this.urutan = const Value.absent(),
    this.nama = const Value.absent(),
    this.porsi = const Value.absent(),
    this.estimasiGram = const Value.absent(),
    this.kalori = const Value.absent(),
    this.karbohidrat = const Value.absent(),
    this.protein = const Value.absent(),
    this.lemak = const Value.absent(),
    this.gulaTotal = const Value.absent(),
    this.serat = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TabelItemMakananCompanion.insert({
    required String sesiId,
    required int urutan,
    required String nama,
    required String porsi,
    required double estimasiGram,
    required double kalori,
    required double karbohidrat,
    required double protein,
    required double lemak,
    required double gulaTotal,
    required double serat,
    this.rowid = const Value.absent(),
  }) : sesiId = Value(sesiId),
       urutan = Value(urutan),
       nama = Value(nama),
       porsi = Value(porsi),
       estimasiGram = Value(estimasiGram),
       kalori = Value(kalori),
       karbohidrat = Value(karbohidrat),
       protein = Value(protein),
       lemak = Value(lemak),
       gulaTotal = Value(gulaTotal),
       serat = Value(serat);
  static Insertable<TabelItemMakananData> custom({
    Expression<String>? sesiId,
    Expression<int>? urutan,
    Expression<String>? nama,
    Expression<String>? porsi,
    Expression<double>? estimasiGram,
    Expression<double>? kalori,
    Expression<double>? karbohidrat,
    Expression<double>? protein,
    Expression<double>? lemak,
    Expression<double>? gulaTotal,
    Expression<double>? serat,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sesiId != null) 'sesi_id': sesiId,
      if (urutan != null) 'urutan': urutan,
      if (nama != null) 'nama': nama,
      if (porsi != null) 'porsi': porsi,
      if (estimasiGram != null) 'estimasi_gram': estimasiGram,
      if (kalori != null) 'kalori': kalori,
      if (karbohidrat != null) 'karbohidrat': karbohidrat,
      if (protein != null) 'protein': protein,
      if (lemak != null) 'lemak': lemak,
      if (gulaTotal != null) 'gula_total': gulaTotal,
      if (serat != null) 'serat': serat,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TabelItemMakananCompanion copyWith({
    Value<String>? sesiId,
    Value<int>? urutan,
    Value<String>? nama,
    Value<String>? porsi,
    Value<double>? estimasiGram,
    Value<double>? kalori,
    Value<double>? karbohidrat,
    Value<double>? protein,
    Value<double>? lemak,
    Value<double>? gulaTotal,
    Value<double>? serat,
    Value<int>? rowid,
  }) {
    return TabelItemMakananCompanion(
      sesiId: sesiId ?? this.sesiId,
      urutan: urutan ?? this.urutan,
      nama: nama ?? this.nama,
      porsi: porsi ?? this.porsi,
      estimasiGram: estimasiGram ?? this.estimasiGram,
      kalori: kalori ?? this.kalori,
      karbohidrat: karbohidrat ?? this.karbohidrat,
      protein: protein ?? this.protein,
      lemak: lemak ?? this.lemak,
      gulaTotal: gulaTotal ?? this.gulaTotal,
      serat: serat ?? this.serat,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sesiId.present) {
      map['sesi_id'] = Variable<String>(sesiId.value);
    }
    if (urutan.present) {
      map['urutan'] = Variable<int>(urutan.value);
    }
    if (nama.present) {
      map['nama'] = Variable<String>(nama.value);
    }
    if (porsi.present) {
      map['porsi'] = Variable<String>(porsi.value);
    }
    if (estimasiGram.present) {
      map['estimasi_gram'] = Variable<double>(estimasiGram.value);
    }
    if (kalori.present) {
      map['kalori'] = Variable<double>(kalori.value);
    }
    if (karbohidrat.present) {
      map['karbohidrat'] = Variable<double>(karbohidrat.value);
    }
    if (protein.present) {
      map['protein'] = Variable<double>(protein.value);
    }
    if (lemak.present) {
      map['lemak'] = Variable<double>(lemak.value);
    }
    if (gulaTotal.present) {
      map['gula_total'] = Variable<double>(gulaTotal.value);
    }
    if (serat.present) {
      map['serat'] = Variable<double>(serat.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TabelItemMakananCompanion(')
          ..write('sesiId: $sesiId, ')
          ..write('urutan: $urutan, ')
          ..write('nama: $nama, ')
          ..write('porsi: $porsi, ')
          ..write('estimasiGram: $estimasiGram, ')
          ..write('kalori: $kalori, ')
          ..write('karbohidrat: $karbohidrat, ')
          ..write('protein: $protein, ')
          ..write('lemak: $lemak, ')
          ..write('gulaTotal: $gulaTotal, ')
          ..write('serat: $serat, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TabelAnchorWaktuTable extends TabelAnchorWaktu
    with TableInfo<$TabelAnchorWaktuTable, TabelAnchorWaktuData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TabelAnchorWaktuTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bootIdMeta = const VerificationMeta('bootId');
  @override
  late final GeneratedColumn<int> bootId = GeneratedColumn<int>(
    'boot_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uptimeSMeta = const VerificationMeta(
    'uptimeS',
  );
  @override
  late final GeneratedColumn<int> uptimeS = GeneratedColumn<int>(
    'uptime_s',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epochMeta = const VerificationMeta('epoch');
  @override
  late final GeneratedColumn<int> epoch = GeneratedColumn<int>(
    'epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bootId, uptimeS, epoch];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tabel_anchor_waktu';
  @override
  VerificationContext validateIntegrity(
    Insertable<TabelAnchorWaktuData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('boot_id')) {
      context.handle(
        _bootIdMeta,
        bootId.isAcceptableOrUnknown(data['boot_id']!, _bootIdMeta),
      );
    } else if (isInserting) {
      context.missing(_bootIdMeta);
    }
    if (data.containsKey('uptime_s')) {
      context.handle(
        _uptimeSMeta,
        uptimeS.isAcceptableOrUnknown(data['uptime_s']!, _uptimeSMeta),
      );
    } else if (isInserting) {
      context.missing(_uptimeSMeta);
    }
    if (data.containsKey('epoch')) {
      context.handle(
        _epochMeta,
        epoch.isAcceptableOrUnknown(data['epoch']!, _epochMeta),
      );
    } else if (isInserting) {
      context.missing(_epochMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bootId, uptimeS};
  @override
  TabelAnchorWaktuData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TabelAnchorWaktuData(
      bootId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}boot_id'],
      )!,
      uptimeS: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}uptime_s'],
      )!,
      epoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}epoch'],
      )!,
    );
  }

  @override
  $TabelAnchorWaktuTable createAlias(String alias) {
    return $TabelAnchorWaktuTable(attachedDatabase, alias);
  }
}

class TabelAnchorWaktuData extends DataClass
    implements Insertable<TabelAnchorWaktuData> {
  final int bootId;
  final int uptimeS;
  final int epoch;
  const TabelAnchorWaktuData({
    required this.bootId,
    required this.uptimeS,
    required this.epoch,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['boot_id'] = Variable<int>(bootId);
    map['uptime_s'] = Variable<int>(uptimeS);
    map['epoch'] = Variable<int>(epoch);
    return map;
  }

  TabelAnchorWaktuCompanion toCompanion(bool nullToAbsent) {
    return TabelAnchorWaktuCompanion(
      bootId: Value(bootId),
      uptimeS: Value(uptimeS),
      epoch: Value(epoch),
    );
  }

  factory TabelAnchorWaktuData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TabelAnchorWaktuData(
      bootId: serializer.fromJson<int>(json['bootId']),
      uptimeS: serializer.fromJson<int>(json['uptimeS']),
      epoch: serializer.fromJson<int>(json['epoch']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bootId': serializer.toJson<int>(bootId),
      'uptimeS': serializer.toJson<int>(uptimeS),
      'epoch': serializer.toJson<int>(epoch),
    };
  }

  TabelAnchorWaktuData copyWith({int? bootId, int? uptimeS, int? epoch}) =>
      TabelAnchorWaktuData(
        bootId: bootId ?? this.bootId,
        uptimeS: uptimeS ?? this.uptimeS,
        epoch: epoch ?? this.epoch,
      );
  TabelAnchorWaktuData copyWithCompanion(TabelAnchorWaktuCompanion data) {
    return TabelAnchorWaktuData(
      bootId: data.bootId.present ? data.bootId.value : this.bootId,
      uptimeS: data.uptimeS.present ? data.uptimeS.value : this.uptimeS,
      epoch: data.epoch.present ? data.epoch.value : this.epoch,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TabelAnchorWaktuData(')
          ..write('bootId: $bootId, ')
          ..write('uptimeS: $uptimeS, ')
          ..write('epoch: $epoch')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bootId, uptimeS, epoch);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TabelAnchorWaktuData &&
          other.bootId == this.bootId &&
          other.uptimeS == this.uptimeS &&
          other.epoch == this.epoch);
}

class TabelAnchorWaktuCompanion extends UpdateCompanion<TabelAnchorWaktuData> {
  final Value<int> bootId;
  final Value<int> uptimeS;
  final Value<int> epoch;
  final Value<int> rowid;
  const TabelAnchorWaktuCompanion({
    this.bootId = const Value.absent(),
    this.uptimeS = const Value.absent(),
    this.epoch = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TabelAnchorWaktuCompanion.insert({
    required int bootId,
    required int uptimeS,
    required int epoch,
    this.rowid = const Value.absent(),
  }) : bootId = Value(bootId),
       uptimeS = Value(uptimeS),
       epoch = Value(epoch);
  static Insertable<TabelAnchorWaktuData> custom({
    Expression<int>? bootId,
    Expression<int>? uptimeS,
    Expression<int>? epoch,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bootId != null) 'boot_id': bootId,
      if (uptimeS != null) 'uptime_s': uptimeS,
      if (epoch != null) 'epoch': epoch,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TabelAnchorWaktuCompanion copyWith({
    Value<int>? bootId,
    Value<int>? uptimeS,
    Value<int>? epoch,
    Value<int>? rowid,
  }) {
    return TabelAnchorWaktuCompanion(
      bootId: bootId ?? this.bootId,
      uptimeS: uptimeS ?? this.uptimeS,
      epoch: epoch ?? this.epoch,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bootId.present) {
      map['boot_id'] = Variable<int>(bootId.value);
    }
    if (uptimeS.present) {
      map['uptime_s'] = Variable<int>(uptimeS.value);
    }
    if (epoch.present) {
      map['epoch'] = Variable<int>(epoch.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TabelAnchorWaktuCompanion(')
          ..write('bootId: $bootId, ')
          ..write('uptimeS: $uptimeS, ')
          ..write('epoch: $epoch, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$BasisData extends GeneratedDatabase {
  _$BasisData(QueryExecutor e) : super(e);
  $BasisDataManager get managers => $BasisDataManager(this);
  late final $TabelSesiTable tabelSesi = $TabelSesiTable(this);
  late final $TabelSampelTable tabelSampel = $TabelSampelTable(this);
  late final $TabelHasilDeteksiTable tabelHasilDeteksi =
      $TabelHasilDeteksiTable(this);
  late final $TabelItemMakananTable tabelItemMakanan = $TabelItemMakananTable(
    this,
  );
  late final $TabelAnchorWaktuTable tabelAnchorWaktu = $TabelAnchorWaktuTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    tabelSesi,
    tabelSampel,
    tabelHasilDeteksi,
    tabelItemMakanan,
    tabelAnchorWaktu,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tabel_sesi',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tabel_sampel', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tabel_sesi',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tabel_hasil_deteksi', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tabel_sesi',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('tabel_item_makanan', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$TabelSesiTableCreateCompanionBuilder =
    TabelSesiCompanion Function({
      required String id,
      required String fotoPath,
      required int waktuFoto,
      Value<int?> t0,
      required StatusSesi status,
      Value<int> rowid,
    });
typedef $$TabelSesiTableUpdateCompanionBuilder =
    TabelSesiCompanion Function({
      Value<String> id,
      Value<String> fotoPath,
      Value<int> waktuFoto,
      Value<int?> t0,
      Value<StatusSesi> status,
      Value<int> rowid,
    });

final class $$TabelSesiTableReferences
    extends BaseReferences<_$BasisData, $TabelSesiTable, TabelSesiData> {
  $$TabelSesiTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TabelSampelTable, List<TabelSampelData>>
  _tabelSampelRefsTable(_$BasisData db) => MultiTypedResultKey.fromTable(
    db.tabelSampel,
    aliasName: 'tabel_sesi__id__tabel_sampel__sesi_id',
  );

  $$TabelSampelTableProcessedTableManager get tabelSampelRefs {
    final manager = $$TabelSampelTableTableManager(
      $_db,
      $_db.tabelSampel,
    ).filter((f) => f.sesiId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tabelSampelRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $TabelHasilDeteksiTable,
    List<TabelHasilDeteksiData>
  >
  _tabelHasilDeteksiRefsTable(_$BasisData db) => MultiTypedResultKey.fromTable(
    db.tabelHasilDeteksi,
    aliasName: 'tabel_sesi__id__tabel_hasil_deteksi__sesi_id',
  );

  $$TabelHasilDeteksiTableProcessedTableManager get tabelHasilDeteksiRefs {
    final manager = $$TabelHasilDeteksiTableTableManager(
      $_db,
      $_db.tabelHasilDeteksi,
    ).filter((f) => f.sesiId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _tabelHasilDeteksiRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TabelItemMakananTable, List<TabelItemMakananData>>
  _tabelItemMakananRefsTable(_$BasisData db) => MultiTypedResultKey.fromTable(
    db.tabelItemMakanan,
    aliasName: 'tabel_sesi__id__tabel_item_makanan__sesi_id',
  );

  $$TabelItemMakananTableProcessedTableManager get tabelItemMakananRefs {
    final manager = $$TabelItemMakananTableTableManager(
      $_db,
      $_db.tabelItemMakanan,
    ).filter((f) => f.sesiId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _tabelItemMakananRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TabelSesiTableFilterComposer
    extends Composer<_$BasisData, $TabelSesiTable> {
  $$TabelSesiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get fotoPath => $composableBuilder(
    column: $table.fotoPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get waktuFoto => $composableBuilder(
    column: $table.waktuFoto,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get t0 => $composableBuilder(
    column: $table.t0,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StatusSesi, StatusSesi, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  Expression<bool> tabelSampelRefs(
    Expression<bool> Function($$TabelSampelTableFilterComposer f) f,
  ) {
    final $$TabelSampelTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tabelSampel,
      getReferencedColumn: (t) => t.sesiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSampelTableFilterComposer(
            $db: $db,
            $table: $db.tabelSampel,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tabelHasilDeteksiRefs(
    Expression<bool> Function($$TabelHasilDeteksiTableFilterComposer f) f,
  ) {
    final $$TabelHasilDeteksiTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tabelHasilDeteksi,
      getReferencedColumn: (t) => t.sesiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelHasilDeteksiTableFilterComposer(
            $db: $db,
            $table: $db.tabelHasilDeteksi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tabelItemMakananRefs(
    Expression<bool> Function($$TabelItemMakananTableFilterComposer f) f,
  ) {
    final $$TabelItemMakananTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tabelItemMakanan,
      getReferencedColumn: (t) => t.sesiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelItemMakananTableFilterComposer(
            $db: $db,
            $table: $db.tabelItemMakanan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TabelSesiTableOrderingComposer
    extends Composer<_$BasisData, $TabelSesiTable> {
  $$TabelSesiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fotoPath => $composableBuilder(
    column: $table.fotoPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get waktuFoto => $composableBuilder(
    column: $table.waktuFoto,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get t0 => $composableBuilder(
    column: $table.t0,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TabelSesiTableAnnotationComposer
    extends Composer<_$BasisData, $TabelSesiTable> {
  $$TabelSesiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fotoPath =>
      $composableBuilder(column: $table.fotoPath, builder: (column) => column);

  GeneratedColumn<int> get waktuFoto =>
      $composableBuilder(column: $table.waktuFoto, builder: (column) => column);

  GeneratedColumn<int> get t0 =>
      $composableBuilder(column: $table.t0, builder: (column) => column);

  GeneratedColumnWithTypeConverter<StatusSesi, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  Expression<T> tabelSampelRefs<T extends Object>(
    Expression<T> Function($$TabelSampelTableAnnotationComposer a) f,
  ) {
    final $$TabelSampelTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tabelSampel,
      getReferencedColumn: (t) => t.sesiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSampelTableAnnotationComposer(
            $db: $db,
            $table: $db.tabelSampel,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> tabelHasilDeteksiRefs<T extends Object>(
    Expression<T> Function($$TabelHasilDeteksiTableAnnotationComposer a) f,
  ) {
    final $$TabelHasilDeteksiTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.tabelHasilDeteksi,
          getReferencedColumn: (t) => t.sesiId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$TabelHasilDeteksiTableAnnotationComposer(
                $db: $db,
                $table: $db.tabelHasilDeteksi,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> tabelItemMakananRefs<T extends Object>(
    Expression<T> Function($$TabelItemMakananTableAnnotationComposer a) f,
  ) {
    final $$TabelItemMakananTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tabelItemMakanan,
      getReferencedColumn: (t) => t.sesiId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelItemMakananTableAnnotationComposer(
            $db: $db,
            $table: $db.tabelItemMakanan,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TabelSesiTableTableManager
    extends
        RootTableManager<
          _$BasisData,
          $TabelSesiTable,
          TabelSesiData,
          $$TabelSesiTableFilterComposer,
          $$TabelSesiTableOrderingComposer,
          $$TabelSesiTableAnnotationComposer,
          $$TabelSesiTableCreateCompanionBuilder,
          $$TabelSesiTableUpdateCompanionBuilder,
          (TabelSesiData, $$TabelSesiTableReferences),
          TabelSesiData,
          PrefetchHooks Function({
            bool tabelSampelRefs,
            bool tabelHasilDeteksiRefs,
            bool tabelItemMakananRefs,
          })
        > {
  $$TabelSesiTableTableManager(_$BasisData db, $TabelSesiTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TabelSesiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TabelSesiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TabelSesiTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> fotoPath = const Value.absent(),
                Value<int> waktuFoto = const Value.absent(),
                Value<int?> t0 = const Value.absent(),
                Value<StatusSesi> status = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TabelSesiCompanion(
                id: id,
                fotoPath: fotoPath,
                waktuFoto: waktuFoto,
                t0: t0,
                status: status,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String fotoPath,
                required int waktuFoto,
                Value<int?> t0 = const Value.absent(),
                required StatusSesi status,
                Value<int> rowid = const Value.absent(),
              }) => TabelSesiCompanion.insert(
                id: id,
                fotoPath: fotoPath,
                waktuFoto: waktuFoto,
                t0: t0,
                status: status,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TabelSesiTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                tabelSampelRefs = false,
                tabelHasilDeteksiRefs = false,
                tabelItemMakananRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (tabelSampelRefs) db.tabelSampel,
                    if (tabelHasilDeteksiRefs) db.tabelHasilDeteksi,
                    if (tabelItemMakananRefs) db.tabelItemMakanan,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (tabelSampelRefs)
                        await $_getPrefetchedData<
                          TabelSesiData,
                          $TabelSesiTable,
                          TabelSampelData
                        >(
                          currentTable: table,
                          referencedTable: $$TabelSesiTableReferences
                              ._tabelSampelRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TabelSesiTableReferences(
                                db,
                                table,
                                p0,
                              ).tabelSampelRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sesiId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tabelHasilDeteksiRefs)
                        await $_getPrefetchedData<
                          TabelSesiData,
                          $TabelSesiTable,
                          TabelHasilDeteksiData
                        >(
                          currentTable: table,
                          referencedTable: $$TabelSesiTableReferences
                              ._tabelHasilDeteksiRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TabelSesiTableReferences(
                                db,
                                table,
                                p0,
                              ).tabelHasilDeteksiRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sesiId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tabelItemMakananRefs)
                        await $_getPrefetchedData<
                          TabelSesiData,
                          $TabelSesiTable,
                          TabelItemMakananData
                        >(
                          currentTable: table,
                          referencedTable: $$TabelSesiTableReferences
                              ._tabelItemMakananRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TabelSesiTableReferences(
                                db,
                                table,
                                p0,
                              ).tabelItemMakananRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.sesiId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TabelSesiTableProcessedTableManager =
    ProcessedTableManager<
      _$BasisData,
      $TabelSesiTable,
      TabelSesiData,
      $$TabelSesiTableFilterComposer,
      $$TabelSesiTableOrderingComposer,
      $$TabelSesiTableAnnotationComposer,
      $$TabelSesiTableCreateCompanionBuilder,
      $$TabelSesiTableUpdateCompanionBuilder,
      (TabelSesiData, $$TabelSesiTableReferences),
      TabelSesiData,
      PrefetchHooks Function({
        bool tabelSampelRefs,
        bool tabelHasilDeteksiRefs,
        bool tabelItemMakananRefs,
      })
    >;
typedef $$TabelSampelTableCreateCompanionBuilder =
    TabelSampelCompanion Function({
      required String sesiId,
      required int index,
      required int detikRelatifT0,
      required StatusSampel status,
      Value<bool> dariBuffer,
      Value<int?> gulaDarah,
      Value<int?> detakJantung,
      Value<int?> sistolik,
      Value<int?> diastolik,
      Value<int?> spo2,
      Value<int> rowid,
    });
typedef $$TabelSampelTableUpdateCompanionBuilder =
    TabelSampelCompanion Function({
      Value<String> sesiId,
      Value<int> index,
      Value<int> detikRelatifT0,
      Value<StatusSampel> status,
      Value<bool> dariBuffer,
      Value<int?> gulaDarah,
      Value<int?> detakJantung,
      Value<int?> sistolik,
      Value<int?> diastolik,
      Value<int?> spo2,
      Value<int> rowid,
    });

final class $$TabelSampelTableReferences
    extends BaseReferences<_$BasisData, $TabelSampelTable, TabelSampelData> {
  $$TabelSampelTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TabelSesiTable _sesiIdTable(_$BasisData db) =>
      db.tabelSesi.createAlias('tabel_sampel__sesi_id__tabel_sesi__id');

  $$TabelSesiTableProcessedTableManager get sesiId {
    final $_column = $_itemColumn<String>('sesi_id')!;

    final manager = $$TabelSesiTableTableManager(
      $_db,
      $_db.tabelSesi,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sesiIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TabelSampelTableFilterComposer
    extends Composer<_$BasisData, $TabelSampelTable> {
  $$TabelSampelTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detikRelatifT0 => $composableBuilder(
    column: $table.detikRelatifT0,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<StatusSampel, StatusSampel, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get dariBuffer => $composableBuilder(
    column: $table.dariBuffer,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get gulaDarah => $composableBuilder(
    column: $table.gulaDarah,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get detakJantung => $composableBuilder(
    column: $table.detakJantung,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sistolik => $composableBuilder(
    column: $table.sistolik,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get diastolik => $composableBuilder(
    column: $table.diastolik,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get spo2 => $composableBuilder(
    column: $table.spo2,
    builder: (column) => ColumnFilters(column),
  );

  $$TabelSesiTableFilterComposer get sesiId {
    final $$TabelSesiTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sesiId,
      referencedTable: $db.tabelSesi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSesiTableFilterComposer(
            $db: $db,
            $table: $db.tabelSesi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabelSampelTableOrderingComposer
    extends Composer<_$BasisData, $TabelSampelTable> {
  $$TabelSampelTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get index => $composableBuilder(
    column: $table.index,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detikRelatifT0 => $composableBuilder(
    column: $table.detikRelatifT0,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dariBuffer => $composableBuilder(
    column: $table.dariBuffer,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get gulaDarah => $composableBuilder(
    column: $table.gulaDarah,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get detakJantung => $composableBuilder(
    column: $table.detakJantung,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sistolik => $composableBuilder(
    column: $table.sistolik,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get diastolik => $composableBuilder(
    column: $table.diastolik,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get spo2 => $composableBuilder(
    column: $table.spo2,
    builder: (column) => ColumnOrderings(column),
  );

  $$TabelSesiTableOrderingComposer get sesiId {
    final $$TabelSesiTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sesiId,
      referencedTable: $db.tabelSesi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSesiTableOrderingComposer(
            $db: $db,
            $table: $db.tabelSesi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabelSampelTableAnnotationComposer
    extends Composer<_$BasisData, $TabelSampelTable> {
  $$TabelSampelTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get index =>
      $composableBuilder(column: $table.index, builder: (column) => column);

  GeneratedColumn<int> get detikRelatifT0 => $composableBuilder(
    column: $table.detikRelatifT0,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<StatusSampel, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<bool> get dariBuffer => $composableBuilder(
    column: $table.dariBuffer,
    builder: (column) => column,
  );

  GeneratedColumn<int> get gulaDarah =>
      $composableBuilder(column: $table.gulaDarah, builder: (column) => column);

  GeneratedColumn<int> get detakJantung => $composableBuilder(
    column: $table.detakJantung,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sistolik =>
      $composableBuilder(column: $table.sistolik, builder: (column) => column);

  GeneratedColumn<int> get diastolik =>
      $composableBuilder(column: $table.diastolik, builder: (column) => column);

  GeneratedColumn<int> get spo2 =>
      $composableBuilder(column: $table.spo2, builder: (column) => column);

  $$TabelSesiTableAnnotationComposer get sesiId {
    final $$TabelSesiTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sesiId,
      referencedTable: $db.tabelSesi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSesiTableAnnotationComposer(
            $db: $db,
            $table: $db.tabelSesi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabelSampelTableTableManager
    extends
        RootTableManager<
          _$BasisData,
          $TabelSampelTable,
          TabelSampelData,
          $$TabelSampelTableFilterComposer,
          $$TabelSampelTableOrderingComposer,
          $$TabelSampelTableAnnotationComposer,
          $$TabelSampelTableCreateCompanionBuilder,
          $$TabelSampelTableUpdateCompanionBuilder,
          (TabelSampelData, $$TabelSampelTableReferences),
          TabelSampelData,
          PrefetchHooks Function({bool sesiId})
        > {
  $$TabelSampelTableTableManager(_$BasisData db, $TabelSampelTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TabelSampelTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TabelSampelTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TabelSampelTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sesiId = const Value.absent(),
                Value<int> index = const Value.absent(),
                Value<int> detikRelatifT0 = const Value.absent(),
                Value<StatusSampel> status = const Value.absent(),
                Value<bool> dariBuffer = const Value.absent(),
                Value<int?> gulaDarah = const Value.absent(),
                Value<int?> detakJantung = const Value.absent(),
                Value<int?> sistolik = const Value.absent(),
                Value<int?> diastolik = const Value.absent(),
                Value<int?> spo2 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TabelSampelCompanion(
                sesiId: sesiId,
                index: index,
                detikRelatifT0: detikRelatifT0,
                status: status,
                dariBuffer: dariBuffer,
                gulaDarah: gulaDarah,
                detakJantung: detakJantung,
                sistolik: sistolik,
                diastolik: diastolik,
                spo2: spo2,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sesiId,
                required int index,
                required int detikRelatifT0,
                required StatusSampel status,
                Value<bool> dariBuffer = const Value.absent(),
                Value<int?> gulaDarah = const Value.absent(),
                Value<int?> detakJantung = const Value.absent(),
                Value<int?> sistolik = const Value.absent(),
                Value<int?> diastolik = const Value.absent(),
                Value<int?> spo2 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TabelSampelCompanion.insert(
                sesiId: sesiId,
                index: index,
                detikRelatifT0: detikRelatifT0,
                status: status,
                dariBuffer: dariBuffer,
                gulaDarah: gulaDarah,
                detakJantung: detakJantung,
                sistolik: sistolik,
                diastolik: diastolik,
                spo2: spo2,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TabelSampelTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sesiId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sesiId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sesiId,
                                referencedTable: $$TabelSampelTableReferences
                                    ._sesiIdTable(db),
                                referencedColumn: $$TabelSampelTableReferences
                                    ._sesiIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TabelSampelTableProcessedTableManager =
    ProcessedTableManager<
      _$BasisData,
      $TabelSampelTable,
      TabelSampelData,
      $$TabelSampelTableFilterComposer,
      $$TabelSampelTableOrderingComposer,
      $$TabelSampelTableAnnotationComposer,
      $$TabelSampelTableCreateCompanionBuilder,
      $$TabelSampelTableUpdateCompanionBuilder,
      (TabelSampelData, $$TabelSampelTableReferences),
      TabelSampelData,
      PrefetchHooks Function({bool sesiId})
    >;
typedef $$TabelHasilDeteksiTableCreateCompanionBuilder =
    TabelHasilDeteksiCompanion Function({
      required String sesiId,
      required String indeksGlikemikPerkiraan,
      required double keyakinan,
      required bool dikoreksiUser,
      required double totalKalori,
      required double totalKarbohidrat,
      required double totalProtein,
      required double totalLemak,
      required double totalGulaTotal,
      required double totalSerat,
      Value<int> rowid,
    });
typedef $$TabelHasilDeteksiTableUpdateCompanionBuilder =
    TabelHasilDeteksiCompanion Function({
      Value<String> sesiId,
      Value<String> indeksGlikemikPerkiraan,
      Value<double> keyakinan,
      Value<bool> dikoreksiUser,
      Value<double> totalKalori,
      Value<double> totalKarbohidrat,
      Value<double> totalProtein,
      Value<double> totalLemak,
      Value<double> totalGulaTotal,
      Value<double> totalSerat,
      Value<int> rowid,
    });

final class $$TabelHasilDeteksiTableReferences
    extends
        BaseReferences<
          _$BasisData,
          $TabelHasilDeteksiTable,
          TabelHasilDeteksiData
        > {
  $$TabelHasilDeteksiTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TabelSesiTable _sesiIdTable(_$BasisData db) =>
      db.tabelSesi.createAlias('tabel_hasil_deteksi__sesi_id__tabel_sesi__id');

  $$TabelSesiTableProcessedTableManager get sesiId {
    final $_column = $_itemColumn<String>('sesi_id')!;

    final manager = $$TabelSesiTableTableManager(
      $_db,
      $_db.tabelSesi,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sesiIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TabelHasilDeteksiTableFilterComposer
    extends Composer<_$BasisData, $TabelHasilDeteksiTable> {
  $$TabelHasilDeteksiTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get indeksGlikemikPerkiraan => $composableBuilder(
    column: $table.indeksGlikemikPerkiraan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get keyakinan => $composableBuilder(
    column: $table.keyakinan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get dikoreksiUser => $composableBuilder(
    column: $table.dikoreksiUser,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalKalori => $composableBuilder(
    column: $table.totalKalori,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalKarbohidrat => $composableBuilder(
    column: $table.totalKarbohidrat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalProtein => $composableBuilder(
    column: $table.totalProtein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalLemak => $composableBuilder(
    column: $table.totalLemak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalGulaTotal => $composableBuilder(
    column: $table.totalGulaTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get totalSerat => $composableBuilder(
    column: $table.totalSerat,
    builder: (column) => ColumnFilters(column),
  );

  $$TabelSesiTableFilterComposer get sesiId {
    final $$TabelSesiTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sesiId,
      referencedTable: $db.tabelSesi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSesiTableFilterComposer(
            $db: $db,
            $table: $db.tabelSesi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabelHasilDeteksiTableOrderingComposer
    extends Composer<_$BasisData, $TabelHasilDeteksiTable> {
  $$TabelHasilDeteksiTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get indeksGlikemikPerkiraan => $composableBuilder(
    column: $table.indeksGlikemikPerkiraan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get keyakinan => $composableBuilder(
    column: $table.keyakinan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get dikoreksiUser => $composableBuilder(
    column: $table.dikoreksiUser,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalKalori => $composableBuilder(
    column: $table.totalKalori,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalKarbohidrat => $composableBuilder(
    column: $table.totalKarbohidrat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalProtein => $composableBuilder(
    column: $table.totalProtein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalLemak => $composableBuilder(
    column: $table.totalLemak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalGulaTotal => $composableBuilder(
    column: $table.totalGulaTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get totalSerat => $composableBuilder(
    column: $table.totalSerat,
    builder: (column) => ColumnOrderings(column),
  );

  $$TabelSesiTableOrderingComposer get sesiId {
    final $$TabelSesiTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sesiId,
      referencedTable: $db.tabelSesi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSesiTableOrderingComposer(
            $db: $db,
            $table: $db.tabelSesi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabelHasilDeteksiTableAnnotationComposer
    extends Composer<_$BasisData, $TabelHasilDeteksiTable> {
  $$TabelHasilDeteksiTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get indeksGlikemikPerkiraan => $composableBuilder(
    column: $table.indeksGlikemikPerkiraan,
    builder: (column) => column,
  );

  GeneratedColumn<double> get keyakinan =>
      $composableBuilder(column: $table.keyakinan, builder: (column) => column);

  GeneratedColumn<bool> get dikoreksiUser => $composableBuilder(
    column: $table.dikoreksiUser,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalKalori => $composableBuilder(
    column: $table.totalKalori,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalKarbohidrat => $composableBuilder(
    column: $table.totalKarbohidrat,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalProtein => $composableBuilder(
    column: $table.totalProtein,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalLemak => $composableBuilder(
    column: $table.totalLemak,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalGulaTotal => $composableBuilder(
    column: $table.totalGulaTotal,
    builder: (column) => column,
  );

  GeneratedColumn<double> get totalSerat => $composableBuilder(
    column: $table.totalSerat,
    builder: (column) => column,
  );

  $$TabelSesiTableAnnotationComposer get sesiId {
    final $$TabelSesiTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sesiId,
      referencedTable: $db.tabelSesi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSesiTableAnnotationComposer(
            $db: $db,
            $table: $db.tabelSesi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabelHasilDeteksiTableTableManager
    extends
        RootTableManager<
          _$BasisData,
          $TabelHasilDeteksiTable,
          TabelHasilDeteksiData,
          $$TabelHasilDeteksiTableFilterComposer,
          $$TabelHasilDeteksiTableOrderingComposer,
          $$TabelHasilDeteksiTableAnnotationComposer,
          $$TabelHasilDeteksiTableCreateCompanionBuilder,
          $$TabelHasilDeteksiTableUpdateCompanionBuilder,
          (TabelHasilDeteksiData, $$TabelHasilDeteksiTableReferences),
          TabelHasilDeteksiData,
          PrefetchHooks Function({bool sesiId})
        > {
  $$TabelHasilDeteksiTableTableManager(
    _$BasisData db,
    $TabelHasilDeteksiTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TabelHasilDeteksiTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TabelHasilDeteksiTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TabelHasilDeteksiTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sesiId = const Value.absent(),
                Value<String> indeksGlikemikPerkiraan = const Value.absent(),
                Value<double> keyakinan = const Value.absent(),
                Value<bool> dikoreksiUser = const Value.absent(),
                Value<double> totalKalori = const Value.absent(),
                Value<double> totalKarbohidrat = const Value.absent(),
                Value<double> totalProtein = const Value.absent(),
                Value<double> totalLemak = const Value.absent(),
                Value<double> totalGulaTotal = const Value.absent(),
                Value<double> totalSerat = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TabelHasilDeteksiCompanion(
                sesiId: sesiId,
                indeksGlikemikPerkiraan: indeksGlikemikPerkiraan,
                keyakinan: keyakinan,
                dikoreksiUser: dikoreksiUser,
                totalKalori: totalKalori,
                totalKarbohidrat: totalKarbohidrat,
                totalProtein: totalProtein,
                totalLemak: totalLemak,
                totalGulaTotal: totalGulaTotal,
                totalSerat: totalSerat,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sesiId,
                required String indeksGlikemikPerkiraan,
                required double keyakinan,
                required bool dikoreksiUser,
                required double totalKalori,
                required double totalKarbohidrat,
                required double totalProtein,
                required double totalLemak,
                required double totalGulaTotal,
                required double totalSerat,
                Value<int> rowid = const Value.absent(),
              }) => TabelHasilDeteksiCompanion.insert(
                sesiId: sesiId,
                indeksGlikemikPerkiraan: indeksGlikemikPerkiraan,
                keyakinan: keyakinan,
                dikoreksiUser: dikoreksiUser,
                totalKalori: totalKalori,
                totalKarbohidrat: totalKarbohidrat,
                totalProtein: totalProtein,
                totalLemak: totalLemak,
                totalGulaTotal: totalGulaTotal,
                totalSerat: totalSerat,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TabelHasilDeteksiTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sesiId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sesiId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sesiId,
                                referencedTable:
                                    $$TabelHasilDeteksiTableReferences
                                        ._sesiIdTable(db),
                                referencedColumn:
                                    $$TabelHasilDeteksiTableReferences
                                        ._sesiIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TabelHasilDeteksiTableProcessedTableManager =
    ProcessedTableManager<
      _$BasisData,
      $TabelHasilDeteksiTable,
      TabelHasilDeteksiData,
      $$TabelHasilDeteksiTableFilterComposer,
      $$TabelHasilDeteksiTableOrderingComposer,
      $$TabelHasilDeteksiTableAnnotationComposer,
      $$TabelHasilDeteksiTableCreateCompanionBuilder,
      $$TabelHasilDeteksiTableUpdateCompanionBuilder,
      (TabelHasilDeteksiData, $$TabelHasilDeteksiTableReferences),
      TabelHasilDeteksiData,
      PrefetchHooks Function({bool sesiId})
    >;
typedef $$TabelItemMakananTableCreateCompanionBuilder =
    TabelItemMakananCompanion Function({
      required String sesiId,
      required int urutan,
      required String nama,
      required String porsi,
      required double estimasiGram,
      required double kalori,
      required double karbohidrat,
      required double protein,
      required double lemak,
      required double gulaTotal,
      required double serat,
      Value<int> rowid,
    });
typedef $$TabelItemMakananTableUpdateCompanionBuilder =
    TabelItemMakananCompanion Function({
      Value<String> sesiId,
      Value<int> urutan,
      Value<String> nama,
      Value<String> porsi,
      Value<double> estimasiGram,
      Value<double> kalori,
      Value<double> karbohidrat,
      Value<double> protein,
      Value<double> lemak,
      Value<double> gulaTotal,
      Value<double> serat,
      Value<int> rowid,
    });

final class $$TabelItemMakananTableReferences
    extends
        BaseReferences<
          _$BasisData,
          $TabelItemMakananTable,
          TabelItemMakananData
        > {
  $$TabelItemMakananTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $TabelSesiTable _sesiIdTable(_$BasisData db) =>
      db.tabelSesi.createAlias('tabel_item_makanan__sesi_id__tabel_sesi__id');

  $$TabelSesiTableProcessedTableManager get sesiId {
    final $_column = $_itemColumn<String>('sesi_id')!;

    final manager = $$TabelSesiTableTableManager(
      $_db,
      $_db.tabelSesi,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sesiIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TabelItemMakananTableFilterComposer
    extends Composer<_$BasisData, $TabelItemMakananTable> {
  $$TabelItemMakananTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get urutan => $composableBuilder(
    column: $table.urutan,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get porsi => $composableBuilder(
    column: $table.porsi,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get estimasiGram => $composableBuilder(
    column: $table.estimasiGram,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get kalori => $composableBuilder(
    column: $table.kalori,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get karbohidrat => $composableBuilder(
    column: $table.karbohidrat,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lemak => $composableBuilder(
    column: $table.lemak,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get gulaTotal => $composableBuilder(
    column: $table.gulaTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get serat => $composableBuilder(
    column: $table.serat,
    builder: (column) => ColumnFilters(column),
  );

  $$TabelSesiTableFilterComposer get sesiId {
    final $$TabelSesiTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sesiId,
      referencedTable: $db.tabelSesi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSesiTableFilterComposer(
            $db: $db,
            $table: $db.tabelSesi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabelItemMakananTableOrderingComposer
    extends Composer<_$BasisData, $TabelItemMakananTable> {
  $$TabelItemMakananTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get urutan => $composableBuilder(
    column: $table.urutan,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nama => $composableBuilder(
    column: $table.nama,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get porsi => $composableBuilder(
    column: $table.porsi,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get estimasiGram => $composableBuilder(
    column: $table.estimasiGram,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get kalori => $composableBuilder(
    column: $table.kalori,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get karbohidrat => $composableBuilder(
    column: $table.karbohidrat,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lemak => $composableBuilder(
    column: $table.lemak,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get gulaTotal => $composableBuilder(
    column: $table.gulaTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get serat => $composableBuilder(
    column: $table.serat,
    builder: (column) => ColumnOrderings(column),
  );

  $$TabelSesiTableOrderingComposer get sesiId {
    final $$TabelSesiTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sesiId,
      referencedTable: $db.tabelSesi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSesiTableOrderingComposer(
            $db: $db,
            $table: $db.tabelSesi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabelItemMakananTableAnnotationComposer
    extends Composer<_$BasisData, $TabelItemMakananTable> {
  $$TabelItemMakananTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get urutan =>
      $composableBuilder(column: $table.urutan, builder: (column) => column);

  GeneratedColumn<String> get nama =>
      $composableBuilder(column: $table.nama, builder: (column) => column);

  GeneratedColumn<String> get porsi =>
      $composableBuilder(column: $table.porsi, builder: (column) => column);

  GeneratedColumn<double> get estimasiGram => $composableBuilder(
    column: $table.estimasiGram,
    builder: (column) => column,
  );

  GeneratedColumn<double> get kalori =>
      $composableBuilder(column: $table.kalori, builder: (column) => column);

  GeneratedColumn<double> get karbohidrat => $composableBuilder(
    column: $table.karbohidrat,
    builder: (column) => column,
  );

  GeneratedColumn<double> get protein =>
      $composableBuilder(column: $table.protein, builder: (column) => column);

  GeneratedColumn<double> get lemak =>
      $composableBuilder(column: $table.lemak, builder: (column) => column);

  GeneratedColumn<double> get gulaTotal =>
      $composableBuilder(column: $table.gulaTotal, builder: (column) => column);

  GeneratedColumn<double> get serat =>
      $composableBuilder(column: $table.serat, builder: (column) => column);

  $$TabelSesiTableAnnotationComposer get sesiId {
    final $$TabelSesiTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sesiId,
      referencedTable: $db.tabelSesi,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TabelSesiTableAnnotationComposer(
            $db: $db,
            $table: $db.tabelSesi,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TabelItemMakananTableTableManager
    extends
        RootTableManager<
          _$BasisData,
          $TabelItemMakananTable,
          TabelItemMakananData,
          $$TabelItemMakananTableFilterComposer,
          $$TabelItemMakananTableOrderingComposer,
          $$TabelItemMakananTableAnnotationComposer,
          $$TabelItemMakananTableCreateCompanionBuilder,
          $$TabelItemMakananTableUpdateCompanionBuilder,
          (TabelItemMakananData, $$TabelItemMakananTableReferences),
          TabelItemMakananData,
          PrefetchHooks Function({bool sesiId})
        > {
  $$TabelItemMakananTableTableManager(
    _$BasisData db,
    $TabelItemMakananTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TabelItemMakananTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TabelItemMakananTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TabelItemMakananTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> sesiId = const Value.absent(),
                Value<int> urutan = const Value.absent(),
                Value<String> nama = const Value.absent(),
                Value<String> porsi = const Value.absent(),
                Value<double> estimasiGram = const Value.absent(),
                Value<double> kalori = const Value.absent(),
                Value<double> karbohidrat = const Value.absent(),
                Value<double> protein = const Value.absent(),
                Value<double> lemak = const Value.absent(),
                Value<double> gulaTotal = const Value.absent(),
                Value<double> serat = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TabelItemMakananCompanion(
                sesiId: sesiId,
                urutan: urutan,
                nama: nama,
                porsi: porsi,
                estimasiGram: estimasiGram,
                kalori: kalori,
                karbohidrat: karbohidrat,
                protein: protein,
                lemak: lemak,
                gulaTotal: gulaTotal,
                serat: serat,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sesiId,
                required int urutan,
                required String nama,
                required String porsi,
                required double estimasiGram,
                required double kalori,
                required double karbohidrat,
                required double protein,
                required double lemak,
                required double gulaTotal,
                required double serat,
                Value<int> rowid = const Value.absent(),
              }) => TabelItemMakananCompanion.insert(
                sesiId: sesiId,
                urutan: urutan,
                nama: nama,
                porsi: porsi,
                estimasiGram: estimasiGram,
                kalori: kalori,
                karbohidrat: karbohidrat,
                protein: protein,
                lemak: lemak,
                gulaTotal: gulaTotal,
                serat: serat,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TabelItemMakananTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({sesiId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (sesiId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.sesiId,
                                referencedTable:
                                    $$TabelItemMakananTableReferences
                                        ._sesiIdTable(db),
                                referencedColumn:
                                    $$TabelItemMakananTableReferences
                                        ._sesiIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TabelItemMakananTableProcessedTableManager =
    ProcessedTableManager<
      _$BasisData,
      $TabelItemMakananTable,
      TabelItemMakananData,
      $$TabelItemMakananTableFilterComposer,
      $$TabelItemMakananTableOrderingComposer,
      $$TabelItemMakananTableAnnotationComposer,
      $$TabelItemMakananTableCreateCompanionBuilder,
      $$TabelItemMakananTableUpdateCompanionBuilder,
      (TabelItemMakananData, $$TabelItemMakananTableReferences),
      TabelItemMakananData,
      PrefetchHooks Function({bool sesiId})
    >;
typedef $$TabelAnchorWaktuTableCreateCompanionBuilder =
    TabelAnchorWaktuCompanion Function({
      required int bootId,
      required int uptimeS,
      required int epoch,
      Value<int> rowid,
    });
typedef $$TabelAnchorWaktuTableUpdateCompanionBuilder =
    TabelAnchorWaktuCompanion Function({
      Value<int> bootId,
      Value<int> uptimeS,
      Value<int> epoch,
      Value<int> rowid,
    });

class $$TabelAnchorWaktuTableFilterComposer
    extends Composer<_$BasisData, $TabelAnchorWaktuTable> {
  $$TabelAnchorWaktuTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get bootId => $composableBuilder(
    column: $table.bootId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get uptimeS => $composableBuilder(
    column: $table.uptimeS,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get epoch => $composableBuilder(
    column: $table.epoch,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TabelAnchorWaktuTableOrderingComposer
    extends Composer<_$BasisData, $TabelAnchorWaktuTable> {
  $$TabelAnchorWaktuTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get bootId => $composableBuilder(
    column: $table.bootId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get uptimeS => $composableBuilder(
    column: $table.uptimeS,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get epoch => $composableBuilder(
    column: $table.epoch,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TabelAnchorWaktuTableAnnotationComposer
    extends Composer<_$BasisData, $TabelAnchorWaktuTable> {
  $$TabelAnchorWaktuTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get bootId =>
      $composableBuilder(column: $table.bootId, builder: (column) => column);

  GeneratedColumn<int> get uptimeS =>
      $composableBuilder(column: $table.uptimeS, builder: (column) => column);

  GeneratedColumn<int> get epoch =>
      $composableBuilder(column: $table.epoch, builder: (column) => column);
}

class $$TabelAnchorWaktuTableTableManager
    extends
        RootTableManager<
          _$BasisData,
          $TabelAnchorWaktuTable,
          TabelAnchorWaktuData,
          $$TabelAnchorWaktuTableFilterComposer,
          $$TabelAnchorWaktuTableOrderingComposer,
          $$TabelAnchorWaktuTableAnnotationComposer,
          $$TabelAnchorWaktuTableCreateCompanionBuilder,
          $$TabelAnchorWaktuTableUpdateCompanionBuilder,
          (
            TabelAnchorWaktuData,
            BaseReferences<
              _$BasisData,
              $TabelAnchorWaktuTable,
              TabelAnchorWaktuData
            >,
          ),
          TabelAnchorWaktuData,
          PrefetchHooks Function()
        > {
  $$TabelAnchorWaktuTableTableManager(
    _$BasisData db,
    $TabelAnchorWaktuTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TabelAnchorWaktuTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TabelAnchorWaktuTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TabelAnchorWaktuTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> bootId = const Value.absent(),
                Value<int> uptimeS = const Value.absent(),
                Value<int> epoch = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TabelAnchorWaktuCompanion(
                bootId: bootId,
                uptimeS: uptimeS,
                epoch: epoch,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int bootId,
                required int uptimeS,
                required int epoch,
                Value<int> rowid = const Value.absent(),
              }) => TabelAnchorWaktuCompanion.insert(
                bootId: bootId,
                uptimeS: uptimeS,
                epoch: epoch,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TabelAnchorWaktuTableProcessedTableManager =
    ProcessedTableManager<
      _$BasisData,
      $TabelAnchorWaktuTable,
      TabelAnchorWaktuData,
      $$TabelAnchorWaktuTableFilterComposer,
      $$TabelAnchorWaktuTableOrderingComposer,
      $$TabelAnchorWaktuTableAnnotationComposer,
      $$TabelAnchorWaktuTableCreateCompanionBuilder,
      $$TabelAnchorWaktuTableUpdateCompanionBuilder,
      (
        TabelAnchorWaktuData,
        BaseReferences<
          _$BasisData,
          $TabelAnchorWaktuTable,
          TabelAnchorWaktuData
        >,
      ),
      TabelAnchorWaktuData,
      PrefetchHooks Function()
    >;

class $BasisDataManager {
  final _$BasisData _db;
  $BasisDataManager(this._db);
  $$TabelSesiTableTableManager get tabelSesi =>
      $$TabelSesiTableTableManager(_db, _db.tabelSesi);
  $$TabelSampelTableTableManager get tabelSampel =>
      $$TabelSampelTableTableManager(_db, _db.tabelSampel);
  $$TabelHasilDeteksiTableTableManager get tabelHasilDeteksi =>
      $$TabelHasilDeteksiTableTableManager(_db, _db.tabelHasilDeteksi);
  $$TabelItemMakananTableTableManager get tabelItemMakanan =>
      $$TabelItemMakananTableTableManager(_db, _db.tabelItemMakanan);
  $$TabelAnchorWaktuTableTableManager get tabelAnchorWaktu =>
      $$TabelAnchorWaktuTableTableManager(_db, _db.tabelAnchorWaktu);
}
