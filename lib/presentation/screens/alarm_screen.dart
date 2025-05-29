// // lib/presentation/screens/alarm_screen.dart
// import 'package:alarm/alarm.dart';
// import 'package:alarm/model/alarm_settings.dart'; // AlarmSettings 사용 위해 추가
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:drug/data/database/drug_database.dart'; // DB 모델 경로 확인

// class AlarmScreen extends StatefulWidget {
//   final AlarmSettings alarmSettings; // 실행된 알람 정보

//   const AlarmScreen({super.key, required this.alarmSettings});

//   @override
//   State<AlarmScreen> createState() => _AlarmScreenState();
// }

// class _AlarmScreenState extends State<AlarmScreen> {
//   String _drugName = "약"; // DB 조회 전 기본값

//   @override
//   void initState() {
//     super.initState();
//     _loadDrugName(); // 화면 시작 시 약 이름 로드
//   }

//   // 알람 ID로 약 이름 조회 (alarm_manager.dart의 로직과 유사)
//   Future<void> _loadDrugName() async {
//     // alarmSettings.id 에서 scheduleId 추출 (ID 규칙 동일 가정)
//     int derivedScheduleId = widget.alarmSettings.id ~/ 100;
//     print("AlarmScreen: Loading drug name for schedule ID: $derivedScheduleId");
//     try {
//       final db = DrugDatabase.instance; // DB 인스턴스
//       final schedule = await db.getScheduleById(derivedScheduleId);
//       if (schedule != null) {
//         final drug = await db.getDrugByItemSeq(schedule.itemSeq.toString());
//         if (drug != null && mounted) {
//           setState(() {
//             _drugName = drug.itemName;
//             print("AlarmScreen: Drug name loaded: $_drugName");
//           });
//         } else {
//            print("⚠️ AlarmScreen: Could not find drug with itemSeq: ${schedule.itemSeq}");
//         }
//       } else {
//          print("⚠️ AlarmScreen: Could not find schedule with ID: $derivedScheduleId");
//       }
//     } catch (e) {
//       print("❌ AlarmScreen: Error loading drug name: $e");
//     }
//   }

//   // 알람 해제 함수
//   Future<void> _dismissAlarm() async {
//     print("AlarmScreen: Dismiss button pressed for alarm ${widget.alarmSettings.id}");
//     try {
//       await Alarm.stop(widget.alarmSettings.id); // 알람 중지
//       print("... Alarm ${widget.alarmSettings.id} stopped successfully.");
//       if (mounted) Navigator.pop(context); // 현재 알람 화면 닫기
//     } catch (e) {
//       print("❌ AlarmScreen: Error stopping alarm ${widget.alarmSettings.id}: $e");
//       // 오류 발생해도 화면은 닫도록 처리 가능
//       if (mounted) Navigator.pop(context);
//     }
//   }

//   // 다시 울림 함수 (예: 5분 후) - 필요시 주석 해제 및 로직 확인
//   // Future<void> _snoozeAlarm() async {
//   //   final now = DateTime.now();
//   //   final snoozeTime = now.add(const Duration(minutes: 5));
//   //   print("AlarmScreen: Snooze button pressed for alarm ${widget.alarmSettings.id}. Snoozing until $snoozeTime");
//   //   try {
//   //     // 현재 알람 중지 시도 (선택적, set이 덮어쓸 수도 있음)
//   //     await Alarm.stop(widget.alarmSettings.id);
//   //     // 기존 설정에서 시간만 변경하여 다시 설정
//   //     final snoozeSettings = widget.alarmSettings.copyWith(dateTime: snoozeTime);
//   //     await Alarm.set(alarmSettings: snoozeSettings);
//   //     print("... Alarm ${widget.alarmSettings.id} snoozed successfully.");
//   //     if (mounted) Navigator.pop(context);
//   //   } catch (e) {
//   //      print("❌ AlarmScreen: Error snoozing alarm ${widget.alarmSettings.id}: $e");
//   //      if (mounted) Navigator.pop(context);
//   //   }
//   // }

//   @override
//   Widget build(BuildContext context) {
//     final timeFormatter = DateFormat('a h:mm', 'ko_KR'); // 오전/오후 시:분 형식

//     return PopScope( // <<<=== 뒤로가기 버튼으로 닫지 못하게 (선택적)
//       canPop: false, // 시스템 뒤로가기 버튼 비활성화
//       child: Scaffold(
//         backgroundColor: Colors.black.withOpacity(0.85), // 배경 더 어둡게
//         body: SafeArea(
//           child: Center(
//             child: Padding(
//               padding: const EdgeInsets.all(30.0),
//               child: Column(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   // 알람 아이콘 및 시간
//                   Icon(Icons.alarm_on, size: 90, color: Colors.white),
//                   const SizedBox(height: 25),
//                   Text(
//                     timeFormatter.format(widget.alarmSettings.dateTime),
//                     style: const TextStyle(fontSize: 55, color: Colors.white, fontWeight: FontWeight.w300), // 폰트 두께 조절
//                   ),
//                   const SizedBox(height: 20),
//                   // 약 이름 표시
//                   Text(
//                     '[$_drugName]', // 약 이름 강조
//                     style: const TextStyle(fontSize: 28, color: Colors.tealAccent, fontWeight: FontWeight.bold), // 색상 및 두께 변경
//                     textAlign: TextAlign.center,
//                   ),
//                   const Text(
//                     '복용 시간입니다!',
//                     style: TextStyle(fontSize: 24, color: Colors.white),
//                     textAlign: TextAlign.center,
//                   ),
//                   const SizedBox(height: 60), // 버튼과의 간격 증가
//                   // 해제 버튼
//                   SizedBox(
//                     width: MediaQuery.of(context).size.width * 0.6, // 버튼 너비 조절
//                     child: ElevatedButton.icon(
//                       icon: const Icon(Icons.check_circle_outline, color: Colors.white),
//                       label: const Text('복용 완료 (해제)', style: TextStyle(fontSize: 18, color: Colors.white)),
//                       onPressed: _dismissAlarm,
//                       style: ElevatedButton.styleFrom(
//                         backgroundColor: Colors.green[600], // 버튼 색상 변경
//                         padding: const EdgeInsets.symmetric(vertical: 18), // 버튼 높이 조절
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//                         elevation: 5,
//                       ),
//                     ),
//                   ),
//                   const SizedBox(height: 20),
//                   // 다시 울림 버튼 (필요시 주석 해제)
//                   // SizedBox(
//                   //   width: MediaQuery.of(context).size.width * 0.5,
//                   //   child: OutlinedButton.icon(
//                   //     icon: Icon(Icons.snooze, color: Colors.white70),
//                   //     label: Text('5분 뒤 다시 알림', style: TextStyle(fontSize: 16, color: Colors.white70)),
//                   //     onPressed: _snoozeAlarm,
//                   //     style: OutlinedButton.styleFrom(
//                   //       side: BorderSide(color: Colors.white54),
//                   //       padding: EdgeInsets.symmetric(vertical: 12),
//                   //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
//                   //     ),
//                   //   ),
//                   // ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
// }