// initialize_drug_data.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:drug/data/database/drug_database.dart'; // DB 모델 및 인스턴스 경로 확인
import 'package:shared_preferences/shared_preferences.dart' as sp;
import 'package:csv/csv.dart'; // CSV 파싱을 위한 패키지

Future<void> initializeDrugDataIfNeeded() async {
  final prefs = await sp.SharedPreferences.getInstance();
  // 약 데이터 초기화 플래그 (버전 관리 위해 키 변경 가능)
  bool dbInitialized = prefs.getBool('db_initialized_v2') ?? false;
  // 금기/주의사항 데이터 초기화 플래그 (새로운 버전 키 사용)
  bool alertsInitialized = prefs.getBool('alerts_initialized_v3') ?? false;

  // --- 1. 기존 약 데이터 초기화 로직 ---
  if (!dbInitialized) {
    print('Initializing main drug data (v2)...');
    try {
      final String jsonStr = await rootBundle.loadString('assets/data/drug_data2.json');
      final Map<String, dynamic> jsonData = json.decode(jsonStr);
      final List<dynamic> items = jsonData['items'] as List<dynamic>;
      int drugCount = 0;
      for (final item in items) {
        // Drug 모델의 fromMap이 Map<String, dynamic>을 받도록 되어 있으므로 캐스팅
        await DrugDatabase.instance.insertDrug(Drug.fromMap(item as Map<String, dynamic>));
        drugCount++;
      }
      await prefs.setBool('db_initialized_v2', true);
      print('✅ 약 데이터 $drugCount 건 초기화 완료!');
    } catch (e) {
      print('❌ 약 데이터 초기화 중 오류 발생: $e');
    }
  } else {
    print('🔁 약 데이터는 이미 초기화됨 (v2)');
  }

  // --- !!! 2. 새로운 금기/주의사항 데이터 초기화 로직 (DUR유형을 reasonText로) !!! ---
  if (!alertsInitialized) {
    print('Initializing drug alerts data (v3 - type as reason)...');
    try {
      // CSV 파일 로드 (경로 및 파일명 확인 필요)
      final String csvString = await rootBundle.loadString('assets/data/drug_alerts_data.csv');

      // CSV 파싱 설정 (필드 구분자, 줄바꿈 문자 등 확인)
      List<List<dynamic>> csvTable = const CsvToListConverter(
        eol: '\n', // 줄바꿈 문자 (Windows는 \r\n 일수도 있음)
        fieldDelimiter: ',', // 필드 구분자
        // shouldParseNumbers: false, // 숫자로 자동 파싱 안 함 (모두 문자열로)
      ).convert(csvString);

      if (csvTable.isNotEmpty) {
        csvTable.removeAt(0); // 첫 번째 줄(헤더) 제거
        print('CSV header removed. Processing ${csvTable.length} alert rows...');
      }

      int alertCount = 0;
      for (final row in csvTable) {
        // CSV 파일의 열 순서: 단일/복합, DUR성분명, DUR유형, 제형, 금기내용, 비고
        if (row.length < 3) { // DUR성분명과 DUR유형은 최소한 있어야 함
          print("Skipping invalid row in CSV (not enough columns for essential data): $row");
          continue;
        }

        // String classification = row[0].toString().trim(); // 첫 번째 열 "단일/복합" (현재 모델에 직접 사용 안 함)
        String ingredientsRaw = row[1].toString().trim();  // 두 번째 열 "DUR성분명"
        String durType = row[2].toString().trim();       // 세 번째 열 "DUR유형"
        // String formulation = row.length > 3 ? row[3].toString().trim() : ''; // 제형 (필요 시 사용)
        // String prohibitionContent = row.length > 4 ? row[4].toString().trim() : ''; // 금기내용 (사용 안 함)
        // String remarks = row.length > 5 ? row[5].toString().trim() : ''; // 비고 (사용 안 함)

        String ingredient1;
        String? ingredient2; // Nullable로 선언

        // DUR성분명 파싱 ("성분A - 성분B" 또는 단일 성분)
        if (ingredientsRaw.contains(' - ')) {
          var parts = ingredientsRaw.split(' - ');
          if (parts.length >= 2) {
            ingredient1 = parts[0].trim();
            ingredient2 = parts[1].trim(); // 두 번째 성분 할당
          } else {
            // " - "가 있지만 형식이 이상한 경우, 일단 ingredient1에 전체 저장
            ingredient1 = ingredientsRaw;
            ingredient2 = null; // 이 경우 ingredient2는 없음
            print("Warning: Malformed combined ingredient in CSV (treated as single): $ingredientsRaw");
          }
        } else { // 단일 성분
          ingredient1 = ingredientsRaw;
          ingredient2 = null; // 단일 성분이므로 ingredient2는 null
        }

        // 주요 정보가 비어있으면 건너뛰기
        if (ingredient1.isEmpty || durType.isEmpty) {
          print("Skipping row due to empty ingredient1 or DUR Type in CSV: $row");
          continue;
        }

        // DrugAlert 객체 생성
        final alert = DrugAlert(
          type: durType,         // "DUR유형"을 type으로 사용
          ingredient1: ingredient1,
          ingredient2: ingredient2,    // 병용금기 시 두 번째 성분, 아니면 null
          reasonText: durType,     // "DUR유형"을 reasonText로도 사용 (사용자에게 보여줄 텍스트)
        );
        await DrugDatabase.instance.insertDrugAlert(alert);
        alertCount++;
      }
      await prefs.setBool('alerts_initialized_v3', true);
      print('✅ 금기/주의사항 데이터 $alertCount 건 초기화 완료 (type as reason)!');

    } catch (e) {
      print('❌ 금기/주의사항 데이터 초기화 중 오류 발생: $e');
    }
  } else {
    print('🔁 금기/주의사항 데이터는 이미 초기화됨 (v3 - type as reason)');
  }
  // --- 초기화 로직 끝 ---
}