import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:drug/core/alarm_manager.dart'; // alarmCallback 경로 확인
import 'package:drug/data/database/drug_database.dart'; // DB 클래스 경로 확인
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ScheduleInputScreen extends StatefulWidget {
  final int itemSeq;
  final String drugName;
  final DrugSchedule? existingSchedule; // DB 모델 클래스

  const ScheduleInputScreen({
    super.key,
    required this.itemSeq,
    required this.drugName,
    this.existingSchedule,
  });

  @override
  State<ScheduleInputScreen> createState() => _ScheduleInputScreenState();
}

class _ScheduleInputScreenState extends State<ScheduleInputScreen> {
  // final DrugService drugService = DrugService(DrugRepositoryImpl()); // 직접 DB 인스턴스 사용

  DateTimeRange? dateRange;
  int frequency = 1;
  List<TimeOfDay> selectedTimes = [const TimeOfDay(hour: 8, minute: 0)];
  bool _isSaving = false; // 저장 중복 방지 플래그

  @override
  void initState() {
    super.initState();
    if (widget.existingSchedule != null) {
      final sched = widget.existingSchedule!;
      // 종료일 시간 포함하도록 조정 (DB 저장 시점 기준)
      final endDateAdjusted = DateTime(
        sched.endDate.year,
        sched.endDate.month,
        sched.endDate.day,
        23,
        59,
        59,
      );
      dateRange = DateTimeRange(start: sched.startDate, end: endDateAdjusted);
      frequency = sched.frequency;
      selectedTimes = sched.times.map(_parseTime).toList();
    }
  }

  /// 정확 알람/알람 시계 권한 설정 화면 열기 (Helper)
  Future<void> _openAppSettings() async {
    // 시스템 설정의 앱 상세 정보 화면으로 이동 시도
    await openAppSettings();
  }

  /// 필요한 권한 확인 및 요청 (가장 중요!)
  Future<bool> _checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return true; // Android 외 플랫폼은 true 반환

    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    List<Permission> permissionsToRequest = [];
    bool permissionsGranted = true;

    // 1. 정확한 알람 권한 (Android 12+)
    if (deviceInfo.version.sdkInt >= 31) {
      var scheduleStatus = await Permission.scheduleExactAlarm.status;
      print('[Permission] ScheduleExactAlarm status: $scheduleStatus');
      if (!scheduleStatus.isGranted) {
        // 이 권한은 사용자가 직접 설정해야 함
        await _showPermissionDialog(
          title: '정확한 알람 권한 필요',
          content: '정확한 시간에 알림을 받으려면, 앱 설정에서 "알람 및 리마인더" 권한을 허용해주세요.',
        );
        // 설정 후 결과를 알 수 없으므로, 일단 false 반환하고 사용자에게 재시도 유도
        return false;
      }
    }

    // 3. 알림 권한 (Android 13+)
    if (deviceInfo.version.sdkInt >= 33) {
      var notificationStatus = await Permission.notification.status;
      print('[Permission] Notification permission status: $notificationStatus');
      if (!notificationStatus.isGranted) {
        permissionsToRequest.add(Permission.notification);
      }
    }

    // 요청 필요한 권한들 한 번에 요청
    if (permissionsToRequest.isNotEmpty) {
      print('Requesting permissions: $permissionsToRequest');
      Map<Permission, PermissionStatus> statuses =
          await permissionsToRequest.request();
      print('Permission results: $statuses');

      // 요청 결과 확인
      statuses.forEach((permission, status) {
        if (!status.isGranted) {
          print('Permission denied: $permission');
          permissionsGranted = false;
        }
      });
    }

    if (!permissionsGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('알림 작동에 필요한 권한이 거부되었습니다.')));
    }

    return permissionsGranted;
  }

  // 권한 설정 안내 다이얼로그 (Helper)
  Future<void> _showPermissionDialog({
    required String title,
    required String content,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (ctx) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _openAppSettings(); // 앱 설정 화면 열기
                },
                child: const Text('설정 열기'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx), // 사용자가 취소
                child: const Text('나중에'),
              ),
            ],
          ),
    );
  }

  Future<void> pickDateRange() async {
    final now = DateTime.now();
    final firstValidDate = now.subtract(const Duration(days: 1)); // 어제부터

    final range = await showDateRangePicker(
      context: context,
      firstDate: firstValidDate,
      lastDate: DateTime(now.year + 1, now.month, now.day),
      initialDateRange: dateRange,
      helpText: '복용 시작일과 종료일을 선택하세요',
      saveText: '확인',
      // locale: const Locale('ko', 'KR'), // MaterialApp에서 설정됨
    );
    if (range != null) {
      // 종료일을 23:59:59로 설정하여 해당 일자 포함
      final adjustedEnd = DateTime(
        range.end.year,
        range.end.month,
        range.end.day,
        23,
        59,
        59,
      );
      setState(
        () => dateRange = DateTimeRange(start: range.start, end: adjustedEnd),
      );
    }
  }

  Future<void> pickTime(int index) async {
    final time = await showTimePicker(
      context: context,
      initialTime: selectedTimes[index],
      helpText: '복용 시간 ${index + 1} 선택',
      // builder: (context, child) { // 필요 시 테마 적용
      //   return Theme(data: Theme.of(context).copyWith(...), child: child!);
      // },
    );
    if (time != null) {
      setState(() => selectedTimes[index] = time);
    }
  }

  /// 스케줄 저장 및 알람 예약 (병용금기/주의사항 검사 추가, DUR 유형 직접 표시)
  Future<void> saveSchedule() async {
    // 중복 저장 방지
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // 1. 입력 값 유효성 검사
    if (dateRange == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('복용 기간을 선택해주세요.')));
      setState(() => _isSaving = false);
      return;
    }

    // 2. 필수 권한 확인 및 요청
    print("Checking permissions before saving schedule...");
    bool permissionsGranted = await _checkAndRequestPermissions();
    if (!permissionsGranted) {
      print("Permissions not granted or user cancelled. Aborting save.");
      setState(() => _isSaving = false);
      return;
    }
    print("All necessary permissions seem to be granted.");

    // 3. 데이터 준비 (DB 저장 및 알람 설정을 위한 모델)
    final timesAsString =
        selectedTimes
            .map(
              (t) =>
                  '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
            )
            .toList();

    final scheduleToSave = DrugSchedule(
      id: widget.existingSchedule?.id,
      itemSeq: widget.itemSeq,
      startDate: dateRange!.start,
      endDate: dateRange!.end,
      frequency: frequency,
      times: timesAsString,
    );

    // --- !!! 4. 금기/주의사항 검사 로직 시작 !!! ---
    bool blockSaving = false;
    List<String> warningMessages = [];

    try {
      final db = DrugDatabase.instance;
      final newDrug = await db.getDrugByItemSeq(
        scheduleToSave.itemSeq.toString(),
      );

      if (newDrug == null ||
          newDrug.ingredients == null ||
          newDrug.ingredients!.isEmpty) {
        print(
          "Warning: Cannot find new drug's material info for checking alerts (ingredients field).",
        );
      } else {
        String newDrugRawMaterial =
            newDrug.ingredients!; // Drug 모델의 ingredients 필드 사용
        List<String> newDrugMaterials =
            newDrugRawMaterial
                .split('|') // 파이프(|) 문자로 분리
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
        print("New drug materials for check: $newDrugMaterials");

        for (String singleNewMaterial in newDrugMaterials) {
          if (singleNewMaterial.isEmpty) continue; // 빈 성분명은 건너뛰기

          // 1. 병용금기 검사
          final existingSchedules = await db.getAllSchedules();
          for (final existingSchedule in existingSchedules) {
            // 자기 자신과의 비교는 제외 (수정 시나리오)
            if (widget.existingSchedule != null &&
                widget.existingSchedule!.id == existingSchedule.id)
              continue;
            // 새로 저장하는 경우 (id가 null)이거나, 다른 스케줄일 때만 비교
            if (scheduleToSave.id != null &&
                scheduleToSave.id == existingSchedule.id)
              continue;

            final existingDrug = await db.getDrugByItemSeq(
              existingSchedule.itemSeq.toString(),
            );
            if (existingDrug != null &&
                existingDrug.ingredients != null &&
                existingDrug.ingredients!.isNotEmpty) {
              String existingDrugRawMaterial = existingDrug.ingredients!;
              List<String> existingDrugMaterials =
                  existingDrugRawMaterial
                      .split('|')
                      .map((e) => e.trim())
                      .where((e) => e.isNotEmpty)
                      .toList();

              for (String singleExistingMaterial in existingDrugMaterials) {
                if (singleExistingMaterial.isEmpty) continue;

                // DrugDatabase의 checkProhibitedCombination은 DrugAlert 리스트를 반환
                List<DrugAlert> prohibitedAlerts = await db
                    .checkProhibitedCombination(
                      singleNewMaterial,
                      singleExistingMaterial,
                    );
                if (prohibitedAlerts.isNotEmpty) {
                  blockSaving = true; // 병용금기는 추가를 막음
                  for (final alert in prohibitedAlerts) {
                    // 여러 병용금기 사유가 있을 수 있음
                    String message =
                        "${newDrug.itemName}($singleNewMaterial)과(와) ${existingDrug.itemName}($singleExistingMaterial)은(는) 함께 복용 시 '${alert.type}' 항목에 해당합니다.";
                    if (!warningMessages.contains(message))
                      warningMessages.add(message);
                  }
                }
              }
            }
          }

          // 2. 특정 성분에 대한 모든 기타 주의사항 검사 (DUR 유형 직접 사용)
          List<DrugAlert> specificAlerts = await db
              .getSpecificAlertsForIngredient(singleNewMaterial);

          for (final alert in specificAlerts) {
            // DB에서 가져온 모든 주의사항에 대해 메시지 생성
            // alert.type을 직접 사용하여 어떤 유형의 주의사항인지 표시
            String message =
                "${newDrug.itemName ?? '이 약'}($singleNewMaterial) 관련 주의사항: '${alert.type}'";
            if (!warningMessages.contains(message))
              warningMessages.add(message);

            // 특정 주의사항 유형에 따라 blockSaving 여부 결정 (예: "임부금기"는 막기)
            // if (alert.type == "임부금기" /* || alert.type == "특정연령대금기" 등 */) {
            //   blockSaving = true;
            // }
          }
        }
      }
    } catch (e) {
      print("Error during contraindication/alert check: $e");
      String errorMessage = "약물 정보 검사 중 오류가 발생했습니다. 다시 시도해주세요.";
      if (!warningMessages.contains(errorMessage))
        warningMessages.add(errorMessage);
      // blockSaving = true; // 심각한 오류 시 저장 중단 결정 가능
    }

    // 검사 결과에 따라 처리
    if (warningMessages.isNotEmpty) {
      final bool? continueSave = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => AlertDialog(
              title: Row(
                // <<<=== 아이콘과 텍스트를 Row로 배치하여 제목 꾸미기
                children: [
                  Icon(
                    blockSaving
                        ? Icons.error_outline
                        : Icons.warning_amber_rounded,
                    color: blockSaving ? Colors.red : Colors.orangeAccent,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    blockSaving ? "복용 불가 약물" : "주의사항 알림",
                    style: TextStyle(),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: ListBody(
                  // 여러 텍스트 위젯을 Column처럼 배치하되, 약간의 기본 패딩 제공
                  children:
                      warningMessages.map((msg) {
                        // 각 메시지를 "• "로 시작하도록 하고, RichText를 사용하여 들여쓰기 효과
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 5.0, top: 1.0),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start, // 텍스트 정렬 기준
                            children: [
                              // const Text(
                              //   "•",
                              //   style: TextStyle(
                              //     fontSize: 16,
                              //     fontWeight: FontWeight.bold,
                              //   ),
                              // ), // 불릿 포인트
                              Expanded(
                                // 남은 공간을 텍스트가 차지하도록
                                child: Text(
                                  msg,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    height: 1.4,
                                  ), // 줄 간격 조절
                                  // softWrap: true, // Text 위젯은 기본적으로 softWrap이 true
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  child: const Text("확인"),
                  onPressed: () => Navigator.of(ctx).pop(false), // 저장 안 함
                ),
                if (!blockSaving) // 추가를 막지 않는 경우에만 "계속 추가" 버튼 표시
                  TextButton(
                    child: const Text(
                      "계속 추가",
                      style: TextStyle(color: Colors.blue),
                    ),
                    onPressed: () => Navigator.of(ctx).pop(true), // 저장 진행
                  ),
              ],
            ),
      );

      if (continueSave != true || blockSaving) {
        setState(() => _isSaving = false);
        return; // 저장 중단
      }
    }

    // 경고/금기 사항이 없거나, 사용자가 "계속 추가"를 선택한 경우 실제 저장 및 알람 설정 진행
    await _performSaveAndScheduleAlarms(scheduleToSave);
  }

  /// 실제 DB 저장 및 알람 설정 로직 (기존 `saveSchedule`의 4, 5단계)
  Future<void> _performSaveAndScheduleAlarms(
    DrugSchedule scheduleToSave,
  ) async {
    int finalScheduleId;
    try {
      // 4. DB 저장 및 ID 확보
      final db = DrugDatabase.instance;
      if (widget.existingSchedule == null) {
        print("Inserting new schedule into DB for _performSave...");
        finalScheduleId = await db.insertSchedule(scheduleToSave);
        print("New schedule inserted. DB ID: $finalScheduleId");
      } else {
        print(
          "Updating existing schedule in DB (ID: ${widget.existingSchedule!.id!}) for _performSave...",
        );
        await db.updateSchedule(scheduleToSave);
        finalScheduleId = widget.existingSchedule!.id!;
        print("Schedule updated. DB ID: $finalScheduleId");
      }
      if (finalScheduleId <= 0) {
        throw Exception(
          "Invalid schedule ID received from database after save/update.",
        );
      }

      // 5. 알람 취소 및 예약 (AndroidAlarmManager 사용 기준)
      // (만약 alarm 패키지로 전환했다면 이 부분은 해당 패키지 로직으로 대체)
      if (widget.existingSchedule != null) {
        print(
          "Cancelling old alarms for schedule ID: ${widget.existingSchedule!.id!} using AndroidAlarmManager",
        );
        final oldSchedule = widget.existingSchedule!;
        final oldDays =
            oldSchedule.endDate.difference(oldSchedule.startDate).inDays;
        List<Future<void>> cancelFutures = [];
        for (var d = 0; d <= oldDays; d++) {
          for (var i = 0; i < oldSchedule.times.length; i++) {
            final oldAlarmId = oldSchedule.id! * 100 + d * 10 + i;
            print("... Adding cancel task for old alarm ID: $oldAlarmId");
            cancelFutures.add(AndroidAlarmManager.cancel(oldAlarmId));
          }
        }
        await Future.wait(cancelFutures);
        print("Finished cancelling old alarms.");
      }

      // 새 알람 예약
      print(
        "Scheduling new alarms for schedule ID: $finalScheduleId using AndroidAlarmManager",
      );
      final totalDays =
          scheduleToSave.endDate.difference(scheduleToSave.startDate).inDays;
      int scheduledCount = 0;
      final now = DateTime.now();
      List<Future<bool>> scheduleFutures = [];

      for (var d = 0; d <= totalDays; d++) {
        final day = scheduleToSave.startDate.add(Duration(days: d));
        for (var i = 0; i < scheduleToSave.times.length; i++) {
          final parts = scheduleToSave.times[i].split(':');
          final alarmTime = DateTime(
            day.year,
            day.month,
            day.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );

          if (alarmTime.isBefore(now)) {
            print('Skipping past alarm: $alarmTime');
            continue;
          }

          final alarmId = finalScheduleId * 100 + d * 10 + i;
          print(
            '... Attempting to schedule alarm: id=$alarmId, time=$alarmTime',
          );

          scheduleFutures.add(
            AndroidAlarmManager.oneShotAt(
              alarmTime,
              alarmId,
              alarmCallback, // @pragma('vm:entry-point') 함수
              exact: true,
              wakeup: true,
              allowWhileIdle: true,
              alarmClock: true,
              rescheduleOnReboot: true,
            ),
          );
        }
      }
      final results = await Future.wait(scheduleFutures);
      scheduledCount = results.where((success) => success).length;
      print(
        "Finished scheduling process. Total alarms scheduled: $scheduledCount / ${scheduleFutures.length}",
      );

      // SnackBar는 DrugManagementScreen에서 표시하므로 여기서는 호출하지 않음
      // 또는 필요시 여기서 다시 호출 가능 (반환값 이용 등)

      if (mounted) {
        print(
          "Popping ScheduleInputScreen with result: true after saving and scheduling.",
        );
        Navigator.pop(context, true); // 성공적으로 저장 및 예약 완료 시 true 반환
      }
    } catch (e) {
      print(
        '❌ Error during DB save or alarm scheduling in _performSaveAndScheduleAlarms: $e',
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('저장 또는 알람 설정 중 심각한 오류 발생: $e')));
      }
      // 여기서도 pop(false) 등으로 실패를 알릴 수 있음
      // if (mounted) Navigator.pop(context, false);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false); // 모든 작업(성공/실패) 완료 후 _isSaving 해제
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy.MM.dd');
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('${widget.drugName} 복용 설정'),
        backgroundColor: const Color(0xFFBCD4C6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // 복용 기간
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      "복용 기간",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      dateRange == null
                          ? '탭하여 기간 선택'
                          : '${fmt.format(dateRange!.start)} ~ ${fmt.format(DateTime(dateRange!.end.year, dateRange!.end.month, dateRange!.end.day))}',
                      style: TextStyle(
                        fontSize: 15,
                        color: dateRange == null ? Colors.grey : Colors.black,
                      ),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: pickDateRange,
                  ),
                  const SizedBox(height: 20),

                  // 하루 복용 횟수
                  Row(
                    children: [
                      const Text(
                        "하루 복용 횟수: ",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<int>(
                        value: frequency,
                        items:
                            [1, 2, 3, 4, 5]
                                .map(
                                  (n) => DropdownMenuItem(
                                    value: n,
                                    child: Text('$n회'),
                                  ),
                                )
                                .toList(),
                        onChanged: (v) {
                          if (v == null) return;
                          setState(() {
                            frequency = v;
                            final current = List.of(selectedTimes);
                            selectedTimes = List.generate(frequency, (i) {
                              if (i < current.length) return current[i];
                              int hour = 8 + i * 5;
                              if (hour >= 24) hour = 20 + (i % 3);
                              return TimeOfDay(hour: hour, minute: 0);
                            });
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // 복용 시간 설정
                  const Text(
                    "복용 시간 설정",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Column(
                    children: List.generate(frequency, (i) {
                      return ListTile(
                        title: Text('복용 시간 ${i + 1}'),
                        trailing: Text(
                          selectedTimes[i].format(context),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () => pickTime(i),
                      );
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _isSaving ? null : saveSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFBCD4C6),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.grey,
              ),
              child:
                  _isSaving
                      ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        ),
                      )
                      : const Text(
                        '저장하기',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
            ),
          ],
        ),
      ),
    );
  }

  // 문자열 파싱 (기존 코드 유지, 에러 처리 보강)
  TimeOfDay _parseTime(String t) {
    try {
      final hm = t.split(':');
      if (hm.length == 2) {
        return TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1]));
      }
      throw const FormatException("Invalid time format");
    } catch (e) {
      print("Error parsing time string '$t': $e");
      // 파싱 실패 시 안전한 기본값 반환
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }
}
