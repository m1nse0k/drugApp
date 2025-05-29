import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Drug {
  final String itemSeq; // 필수
  final String? entpName; // Nullable
  final String? itemName; // Nullable
  final String? efcyQesitm; // Nullable
  final String? useMethodQesitm; // Nullable
  final String? atpnWarnQesitm; // Nullable
  final String? atpnQesitm; // Nullable
  final String? intrcQesitm; // Nullable
  final String? seQesitm; // Nullable
  final String? depositMethodQesitm; // Nullable
  final String? openDe; // Nullable
  final String? updateDe; // Nullable
  final String? itemImage; // Nullable
  final int? bizno; // Nullable
  final String? ingredients; // Nullable (이것이 dl_material에 해당)

  Drug({
    required this.itemSeq, // itemSeq는 PK이므로 계속 required
    this.entpName,
    this.itemName,
    this.efcyQesitm,
    this.useMethodQesitm,
    this.atpnWarnQesitm,
    this.atpnQesitm,
    this.intrcQesitm,
    this.seQesitm,
    this.depositMethodQesitm,
    this.openDe,
    this.updateDe,
    this.itemImage,
    this.bizno,
    this.ingredients,
  });

  Map<String, dynamic> toMap() {
    return {
      'itemSeq': itemSeq,
      'entpName': entpName,
      'itemName': itemName,
      'efcyQesitm': efcyQesitm,
      'useMethodQesitm': useMethodQesitm,
      'atpnWarnQesitm': atpnWarnQesitm,
      'atpnQesitm': atpnQesitm,
      'intrcQesitm': intrcQesitm,
      'seQesitm': seQesitm,
      'depositMethodQesitm': depositMethodQesitm,
      'openDe': openDe,
      'updateDe': updateDe,
      'itemImage': itemImage,
      'bizno': bizno,
      'ingredients': ingredients, // DB 컬럼명도 ingredients로 통일
    };
  }

  factory Drug.fromMap(Map<String, dynamic> map) {
    return Drug(
      itemSeq: map['itemSeq']?.toString() ?? '', // itemSeq는 빈 문자열로라도 있어야 함
      entpName: map['entpName'] as String?,
      itemName: map['itemName'] as String?,
      efcyQesitm: map['efcyQesitm'] as String?,
      useMethodQesitm: map['useMethodQesitm'] as String?,
      atpnWarnQesitm: map['atpnWarnQesitm'] as String?,
      atpnQesitm: map['atpnQesitm'] as String?,
      intrcQesitm: map['intrcQesitm'] as String?,
      seQesitm: map['seQesitm'] as String?,
      depositMethodQesitm: map['depositMethodQesitm'] as String?,
      openDe: map['openDe'] as String?,
      updateDe: map['updateDe'] as String?,
      itemImage: map['itemImage'] as String?,
      bizno:
          map['bizno'] is int
              ? map['bizno']
                  as int? // Nullable int로 변경
              : (map['bizno'] != null
                  ? int.tryParse(map['bizno'].toString())
                  : null), // 파싱 실패 또는 null이면 null
      // 'dl_material'이 JSON에 있으면 사용하고, 없으면 'ingredients' 사용, 둘 다 없으면 null
      ingredients:
          map['ingredients'] as String? ?? map['dl_material'] as String?,
    );
  }
}

class DrugSchedule {
  final int? id;
  final DateTime startDate;
  final DateTime endDate;
  final int frequency;
  final List<String> times;
  final int itemSeq;

  DrugSchedule({
    this.id,
    required this.startDate,
    required this.endDate,
    required this.frequency,
    required this.times,
    required this.itemSeq,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'frequency': frequency,
      'times': times.join(','),
      'itemSeq': itemSeq,
    };
  }

  factory DrugSchedule.fromMap(Map<String, dynamic> map) {
    // 안전하게 itemSeq 값을 파싱
    final rawItemSeq = map['itemSeq'];
    final parsedItemSeq =
        rawItemSeq is int
            ? rawItemSeq
            : int.tryParse(rawItemSeq?.toString() ?? '0') ?? 0;

    return DrugSchedule(
      id: map['id'] as int?,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      frequency: map['frequency'] as int,
      times: (map['times'] as String).split(','),
      itemSeq: parsedItemSeq,
    );
  }
}

class DrugAlert {
  final int? id;
  final String type;
  final String ingredient1;
  final String? ingredient2;
  final String reasonText; // 이 필드는 type과 동일한 값을 저장하거나, type을 직접 사용

  DrugAlert({
    this.id,
    required this.type,
    required this.ingredient1,
    this.ingredient2,
    required this.reasonText,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'ingredient1': ingredient1,
      'ingredient2': ingredient2,
      'reason_text': reasonText,
    };
  }

  factory DrugAlert.fromMap(Map<String, dynamic> map) {
    return DrugAlert(
      id: map['id'] as int?,
      type: map['type'] as String,
      ingredient1: map['ingredient1'] as String,
      ingredient2: map['ingredient2'] as String?,
      reasonText: map['reason_text'] as String,
    );
  }
}

class DrugDatabase {
  static final DrugDatabase instance = DrugDatabase._init();
  static Database? _database;

  DrugDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    // DB 버전은 drug_alerts 테이블 추가 시 이미 2로 증가했다고 가정
    // 만약 drugs 테이블 컬럼도 NULL을 허용하도록 변경한다면 버전 추가 증가 필요
    _database = await _initDB('drugs_v2.db'); // 또는 현재 사용하는 DB 파일명 및 버전
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 2, // drug_alerts 테이블 추가 시 이미 버전 2라고 가정
      // 만약 drugs 테이블 컬럼 변경 시 버전 3으로 올리고 onUpgrade 추가 필요
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future _createDB(Database db, int version) async {
    // --- !!! drugs 테이블 컬럼을 NULL 허용하도록 수정 (PK 제외) !!! ---
    await db.execute('''
      CREATE TABLE drugs (
        itemSeq TEXT PRIMARY KEY,
        entpName TEXT,
        itemName TEXT,
        efcyQesitm TEXT,
        useMethodQesitm TEXT,
        atpnWarnQesitm TEXT,
        atpnQesitm TEXT,
        intrcQesitm TEXT,
        seQesitm TEXT,
        depositMethodQesitm TEXT,
        openDe TEXT,
        updateDe TEXT,
        itemImage TEXT,
        bizno INTEGER, 
        ingredients TEXT 
      )
    ''');
    // 기본적으로 SQLite에서 TEXT, INTEGER 타입은 NULL을 허용합니다.
    // NOT NULL 제약조건이 명시되지 않으면 NULLABLE 입니다.
    // 따라서 위 스키마는 이미 Nullable 필드를 지원합니다.
    // -------------------------------------------------------------

    await db.execute('''
      CREATE TABLE drug_schedules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        startDate TEXT,
        endDate TEXT,
        frequency INTEGER,
        times TEXT,
        itemSeq INTEGER,
        FOREIGN KEY (itemSeq) REFERENCES drugs(itemSeq)
      )
    ''');

    // drug_alerts 테이블 생성 (이전 답변 내용, reason_text 컬럼 포함)
    await db.execute('''
      CREATE TABLE drug_alerts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        ingredient1 TEXT NOT NULL,
        ingredient2 TEXT,
        reason_text TEXT NOT NULL 
      )
    ''');
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2 && newVersion >= 2) {
      // 버전 1 -> 2 (drug_alerts 테이블 추가)
      await db.execute('''
        CREATE TABLE drug_alerts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          type TEXT NOT NULL,
          ingredient1 TEXT NOT NULL,
          ingredient2 TEXT,
          reason_text TEXT NOT NULL
        )
      ''');
      print("DrugAlerts table created on upgrade to v2.");
    }
    // 만약 drugs 테이블의 컬럼을 NOT NULL -> NULL로 변경하는 등의 스키마 변경이 있다면,
    // 버전을 3으로 올리고, oldVersion < 3 조건으로 ALTER TABLE 구문을 실행해야 합니다.
    // 하지만 SQLite는 기존 컬럼의 제약조건 변경이 복잡하므로,
    // 데이터를 백업하고 테이블을 삭제 후 재생성하는 것이 더 간단할 수 있습니다.
    // 여기서는 drugs 테이블은 onCreate에서부터 Nullable로 생성되었다고 가정합니다.
  }

  Future<List<Drug>> getAllDrugs() async {
    final db = await instance.database;
    final result = await db.query('drugs');
    return result.map((m) => Drug.fromMap(m)).toList();
  }

  Future<int> insertDrug(Drug drug) async {
    final db = await instance.database;
    return await db.insert(
      'drugs',
      drug.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<List<DrugSchedule>> getAllSchedules() async {
    final db = await instance.database;
    final result = await db.query('drug_schedules');
    return result.map((m) => DrugSchedule.fromMap(m)).toList();
  }

  Future<int> insertSchedule(DrugSchedule schedule) async {
    final db = await instance.database;
    return await db.insert('drug_schedules', schedule.toMap());
  }

  Future<int> deleteSchedule(int id) async {
    final db = await instance.database;
    return await db.delete('drug_schedules', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> updateSchedule(DrugSchedule schedule) async {
    final db = await instance.database;
    return await db.update(
      'drug_schedules',
      schedule.toMap(),
      where: 'id = ?',
      whereArgs: [schedule.id],
    );
  }

  Future<DrugSchedule?> getScheduleById(int id) async {
    final db = await instance.database;
    final maps = await db.query(
      'drug_schedules',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1, // ID는 고유하므로 1개만 가져옴
    );

    if (maps.isNotEmpty) {
      return DrugSchedule.fromMap(maps.first);
    } else {
      return null; // 해당 ID의 스케줄 없음
    }
  }

  /// itemSeq로 특정 약 정보 조회
  Future<Drug?> getDrugByItemSeq(String itemSeq) async {
    final db = await instance.database;
    final maps = await db.query(
      'drugs',
      where: 'itemSeq = ?',
      whereArgs: [itemSeq],
      limit: 1, // itemSeq는 고유해야 함
    );

    if (maps.isNotEmpty) {
      return Drug.fromMap(maps.first);
    } else {
      return null; // 해당 itemSeq의 약 없음
    }
  }

  // DrugAlert 데이터 삽입
  Future<int> insertDrugAlert(DrugAlert alert) async {
    final db = await instance.database;
    return await db.insert(
      'drug_alerts',
      alert.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    ); // 중복 시 교체 (선택 사항)
  }

  // 병용금기 검사 (특정 타입만 조회)
  Future<List<DrugAlert>> checkProhibitedCombination(
    String material1,
    String material2,
  ) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drug_alerts',
      where:
          'type = ? AND ((ingredient1 = ? AND ingredient2 = ?) OR (ingredient1 = ? AND ingredient2 = ?))',
      whereArgs: [
        "병용금기",
        material1.trim(),
        material2.trim(),
        material2.trim(),
        material1.trim(),
      ],
    );
    // maps가 비어있더라도 빈 List<DrugAlert>를 반환하므로 null을 반환하지 않습니다.
    return maps.map((map) => DrugAlert.fromMap(map)).toList();
  }

  // 특정 조건(임부, 수유부 등)에 대한 단일 성분 금기/주의 검사
  Future<List<DrugAlert>> checkSpecificAlert(
    String material,
    String alertType,
  ) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drug_alerts',
      where: 'type = ? AND ingredient1 = ?',
      whereArgs: [alertType, material.trim()],
    );
    return maps.map((map) => DrugAlert.fromMap(map)).toList();
  }

  Future<List<DrugAlert>> getSpecificAlertsForIngredient(
    String material,
  ) async {
    final db = await instance.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'drug_alerts',
      where: 'ingredient1 = ? AND type != ?', // type이 '병용금기'가 아닌 모든 알림 조회
      whereArgs: [material.trim(), "병용금기"],
    );
    if (maps.isNotEmpty) {
      return maps.map((map) => DrugAlert.fromMap(map)).toList();
    }
    return []; // 결과가 없으면 빈 리스트 반환
  }

  Future<void> close() async {
    final db = await instance.database;
    await db.close();
  }
}
