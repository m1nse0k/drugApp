import 'dart:async';
import 'dart:typed_data'; // Int64List 사용 위해 필요
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:drug/data/database/drug_database.dart'; // <<<=== DB 클래스 임포트

/// ⚠️ entry-point 로직임을 명시해야 isolate에서도 살아남습니다.
@pragma('vm:entry-point')
Future<void> alarmCallback(int alarmId) async {
  // 콜백 함수 시작 로그
  print('🔔 [${DateTime.now()}] Alarm callback received! ID: $alarmId');
  print(
    '✅✅✅ [${DateTime.now()}] ALARM CALLBACK FINISHED SUCCESSFULLY. ID: $alarmId ✅✅✅',
  );

  final player = AudioPlayer();

  try {
    // Flutter 환경 초기화 (필수)
    WidgetsFlutterBinding.ensureInitialized();
    print('Flutter binding initialized.');

    // --- 약 이름 조회 로직 시작 ---
    String drugName = '등록된 약'; // 기본값
    int? derivedScheduleId;
    try {
      // 1. alarmId로부터 scheduleId 계산 (ID 생성 규칙에 의존)
      derivedScheduleId = alarmId ~/ 100; // 정수 나눗셈
      print('Derived schedule ID: $derivedScheduleId');

      // 2. DB 인스턴스 가져오기 (콜백 내에서 DB 접근)
      // 주의: 앱의 메인 Isolate와 다른 Isolate이므로, DB 인스턴스를 새로 얻어야 할 수 있음
      // DrugDatabase.instance가 싱글톤이고 Isolate 간 공유 문제가 없다면 그대로 사용 가능
      final db = DrugDatabase.instance;
      print('Database instance obtained.');

      // 3. scheduleId로 스케줄 정보 조회 (itemSeq 얻기 위해)
      // DB 메서드가 필요함 (예: getScheduleById) - DrugDatabase 클래스에 추가 필요 가정
      final schedule = await db.getScheduleById(
        derivedScheduleId,
      ); // ID로 스케줄 조회
      print('Schedule fetched from DB: ${schedule?.toMap()}'); // 로그 추가

      if (schedule != null) {
        // 4. itemSeq로 약 정보 조회 (itemName 얻기 위해)
        // DB 메서드가 필요함 (예: getDrugByItemSeq) - DrugDatabase 클래스에 추가 필요 가정
        final drug = await db.getDrugByItemSeq(
          schedule.itemSeq.toString(),
        ); // itemSeq로 약 조회
        print('Drug fetched from DB: ${drug?.toMap()}'); // 로그 추가

        if (drug != null) {
          drugName = drug.itemName ?? '알 수 없는 약 (DB 정보 누락)'; // 약 이름 사용
        } else {
          print('⚠️ Could not find drug with itemSeq: ${schedule.itemSeq}');
          drugName = '알 수 없는 약 (ID: ${schedule.itemSeq})';
        }
      } else {
        print('⚠️ Could not find schedule with ID: $derivedScheduleId');
        drugName = '알 수 없는 스케줄';
      }
    } catch (e) {
      print('❌ Error fetching drug name from DB: $e');
      // DB 조회 실패 시 기본값 사용
    }
    print('Using drug name for notification: $drugName');
    // --- 약 이름 조회 로직 끝 ---

    // 1) flutter_local_notifications 플러그인 별도 초기화
    final localNotif = FlutterLocalNotificationsPlugin();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await localNotif.initialize(
      const InitializationSettings(android: androidInit, iOS: null),
    );
    print('Local notifications initialized.');

    // 3) 벨소리 재생 (just_audio)
    try {
      print('Setting audio asset: assets/sounds/alarm_sound.mp3');
      await player.setAsset('assets/sounds/alarm_sound.mp3');
      print('Audio asset set. Attempting to play sound...');
      // 볼륨 설정 시도 (선택 사항, 효과 없을 수 있음)
      // await player.setVolume(1.0);
      await player.play();
      print('Audio playing initiated. Check MEDIA volume.');
      // 완료 후 해제
      player.processingStateStream.listen((state) {
        if (state == ProcessingState.completed) {
          print('Audio playback completed. Disposing player.');
          player.dispose();
        }
      });
    } catch (e) {
      print('❌ Error playing sound with just_audio: $e');
      await player.dispose();
    }

    // 4) 풀스크린 알림 띄우기 (약 이름 사용, 진동은 여기서 처리)
    final androidDetails = AndroidNotificationDetails(
      'medication_alarm_channel', // 채널 ID (main.dart에서 생성/관리 추천)
      '복약 알림',
      channelDescription: '정해진 시간에 약 복용 알림을 받습니다.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: false, // just_audio로 재생하므로 false
      enableVibration: true, // <<<=== 알림 시스템 진동 활성화
      vibrationPattern: Int64List.fromList([
        0,
        1000,
        500,
        1000,
      ]), // <<<=== 진동 패턴
      fullScreenIntent: true,
      autoCancel: false,
      ongoing: true,
      category: AndroidNotificationCategory.alarm,
      // visibility: NotificationVisibility.public, // 필요 시 조절
    );
    final details = NotificationDetails(android: androidDetails, iOS: null);

    print('Showing notification for ID: $alarmId with Drug Name: $drugName');
    await localNotif.show(
      alarmId,
      '💊 복약 시간입니다!',
      '지금 [$drugName] 약을 복용하세요.', // <<<=== 약 이름 표시
      details,
      payload: alarmId.toString(), // payload는 그대로 alarmId 유지 가능
    );
    print('Notification shown for ID: $alarmId');

    print(
      '✅ [${DateTime.now()}] Alarm callback finished successfully for ID: $alarmId',
    );
  } catch (e) {
    print('❌❌❌ FATAL Error in alarm callback for ID $alarmId: $e');
    // 에러 시 플레이어 정리
    if (player.playing) await player.stop();
    await player.dispose();
  }
}
