// schedule_input_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:drug/core/alarm_manager.dart';
import 'package:drug/data/database/drug_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';

class ScheduleInputScreen extends StatefulWidget {
  final int itemSeq;
  final String drugName;
  final DrugSchedule? existingSchedule;
  final bool isSeniorMode; // <<< 시니어 모드 변수 추가

  const ScheduleInputScreen({
    super.key,
    required this.itemSeq,
    required this.drugName,
    this.existingSchedule,
    required this.isSeniorMode, // <<< 생성자에 추가
  });

  @override
  State<ScheduleInputScreen> createState() => _ScheduleInputScreenState();
}

class _ScheduleInputScreenState extends State<ScheduleInputScreen> {
  DateTimeRange? dateRange;
  int frequency = 1;
  List<TimeOfDay> selectedTimes = [const TimeOfDay(hour: 8, minute: 0)];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSchedule != null) {
      final sched = widget.existingSchedule!;
      final endDateAdjusted =
          DateTime(sched.endDate.year, sched.endDate.month, sched.endDate.day, 23, 59, 59);
      dateRange = DateTimeRange(start: sched.startDate, end: endDateAdjusted);
      frequency = sched.frequency;
      selectedTimes = sched.times.map(_parseTime).toList();
    }
  }

  // ... (권한 요청 관련 함수 _openAppSettings, _checkAndRequestPermissions, _showPermissionDialog 등은 변경 없음)
  Future<void> _openAppSettings() async {
    await openAppSettings();
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (!Platform.isAndroid) return true;
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    List<Permission> permissionsToRequest = [];
    bool permissionsGranted = true;

    if (deviceInfo.version.sdkInt >= 31) {
      if (!await Permission.scheduleExactAlarm.isGranted) {
        await _showPermissionDialog(
            title: '정확한 알람 권한 필요',
            content: '정확한 시간에 알림을 받으려면, 앱 설정에서 "알람 및 리마인더" 권한을 허용해주세요.');
        return false;
      }
    }

    if (deviceInfo.version.sdkInt >= 33) {
      if (!await Permission.notification.isGranted) {
        permissionsToRequest.add(Permission.notification);
      }
    }

    if (permissionsToRequest.isNotEmpty) {
      Map<Permission, PermissionStatus> statuses =
          await permissionsToRequest.request();
      statuses.forEach((permission, status) {
        if (!status.isGranted) permissionsGranted = false;
      });
    }
    if (!permissionsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 작동에 필요한 권한이 거부되었습니다.')));
    }
    return permissionsGranted;
  }

  Future<void> _showPermissionDialog(
      {required String title, required String content}) async {
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await _openAppSettings();
              },
              child: const Text('설정 열기')),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('나중에')),
        ],
      ),
    );
  }


  Future<void> pickDateRange() async {
    // ... (기존 pickDateRange 함수 코드는 변경 없음)
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: DateTime(now.year + 1, now.month, now.day),
      initialDateRange: dateRange,
      helpText: '복용 시작일과 종료일을 선택하세요',
      saveText: '확인',
    );
    if (range != null) {
      final adjustedEnd = DateTime(
          range.end.year, range.end.month, range.end.day, 23, 59, 59);
      setState(
          () => dateRange = DateTimeRange(start: range.start, end: adjustedEnd));
    }
  }

  Future<void> pickTime(int index) async {
    // ... (기존 pickTime 함수 코드는 변경 없음)
    final time = await showTimePicker(
        context: context,
        initialTime: selectedTimes[index],
        helpText: '복용 시간 ${index + 1} 선택');
    if (time != null) setState(() => selectedTimes[index] = time);
  }

  Future<void> saveSchedule() async {
    // ... (기존 saveSchedule 함수 코드는 변경 없음, 내부 _performSaveAndScheduleAlarms 호출 로직 유지)
    if (_isSaving) return;
    setState(() => _isSaving = true);

    if (dateRange == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('복용 기간을 선택해주세요.')));
      setState(() => _isSaving = false);
      return;
    }
    bool permissionsGranted = await _checkAndRequestPermissions();
    if (!permissionsGranted) {
      setState(() => _isSaving = false);
      return;
    }
    final timesAsString = selectedTimes
        .map((t) =>
            '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}')
        .toList();
    final scheduleToSave = DrugSchedule(
        id: widget.existingSchedule?.id,
        itemSeq: widget.itemSeq,
        startDate: dateRange!.start,
        endDate: dateRange!.end,
        frequency: frequency,
        times: timesAsString);

    await _performSaveAndScheduleAlarms(scheduleToSave);
  }

  Future<void> _performSaveAndScheduleAlarms(DrugSchedule scheduleToSave) async {
    // ... (기존 _performSaveAndScheduleAlarms 함수 코드는 변경 없음, DB 저장 및 알람 설정 로직 유지)
    int finalScheduleId;
    try {
      final db = DrugDatabase.instance;
      if (widget.existingSchedule == null) {
        finalScheduleId = await db.insertSchedule(scheduleToSave);
      } else {
        await db.updateSchedule(scheduleToSave);
        finalScheduleId = widget.existingSchedule!.id!;
      }
      if (finalScheduleId <= 0) throw Exception("Invalid schedule ID");

      if (widget.existingSchedule != null) {
        final oldSchedule = widget.existingSchedule!;
        final oldDays =
            oldSchedule.endDate.difference(oldSchedule.startDate).inDays;
        for (var d = 0; d <= oldDays; d++) {
          for (var i = 0; i < oldSchedule.times.length; i++) {
            final oldAlarmId = oldSchedule.id! * 100 + d * 10 + i;
            await AndroidAlarmManager.cancel(oldAlarmId);
          }
        }
      }

      final totalDays =
          scheduleToSave.endDate.difference(scheduleToSave.startDate).inDays;
      final now = DateTime.now();
      for (var d = 0; d <= totalDays; d++) {
        final day = scheduleToSave.startDate.add(Duration(days: d));
        for (var i = 0; i < scheduleToSave.times.length; i++) {
          final parts = scheduleToSave.times[i].split(':');
          final alarmTime = DateTime(day.year, day.month, day.day,
              int.parse(parts[0]), int.parse(parts[1]));
          if (alarmTime.isBefore(now)) continue;
          final alarmId = finalScheduleId * 100 + d * 10 + i;
          await AndroidAlarmManager.oneShotAt(alarmTime, alarmId, alarmCallback,
              exact: true,
              wakeup: true,
              allowWhileIdle: true,
              alarmClock: true,
              rescheduleOnReboot: true);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('저장 또는 알람 설정 중 오류 발생: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('yyyy.MM.dd');
    final isSeniorMode = widget.isSeniorMode; // <<< 시니어 모드 변수

    // =================================================================
    // 시니어 모드에 따른 UI 값 동적 설정
    // =================================================================
    final double appBarTitleSize = isSeniorMode ? 22.0 : 18.0;
    final double sectionTitleSize = isSeniorMode ? 20.0 : 16.0;
    final double sectionContentSize = isSeniorMode ? 19.0 : 15.0;
    final double timePickerTextSize = isSeniorMode ? 22.0 : 18.0;
    final double saveButtonHeight = isSeniorMode ? 60.0 : 50.0;
    final double saveButtonFontSize = isSeniorMode ? 22.0 : 18.0;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${widget.drugName} 복용 설정',
          style: TextStyle(fontSize: appBarTitleSize), // <<< 시니어 모드 적용
        ),
        backgroundColor: const Color(0xFFBCD4C6),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(isSeniorMode ? 24 : 20), // <<< 시니어 모드 적용
        child: Column(
          children: [
            Expanded(
              child: ListView(
                children: [
                  // 복용 기간
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      "복용 기간",
                      style: TextStyle(
                        fontSize: sectionTitleSize, // <<< 시니어 모드 적용
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(
                      dateRange == null
                          ? '탭하여 기간 선택'
                          : '${fmt.format(dateRange!.start)} ~ ${fmt.format(dateRange!.end)}',
                      style: TextStyle(
                        fontSize: sectionContentSize, // <<< 시니어 모드 적용
                        color: dateRange == null ? Colors.grey : Colors.black,
                      ),
                    ),
                    trailing: Icon(Icons.calendar_today, size: isSeniorMode ? 30 : 24), // <<< 시니어 모드 적용
                    onTap: pickDateRange,
                  ),
                  SizedBox(height: isSeniorMode ? 30 : 20), // <<< 시니어 모드 적용

                  // 하루 복용 횟수
                  Row(
                    children: [
                      Text(
                        "하루 복용 횟수: ",
                        style: TextStyle(
                          fontSize: sectionTitleSize, // <<< 시니어 모드 적용
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      // DropdownButton의 폰트 크기를 키우기 위해 스타일 적용
                      DropdownButton<int>(
                        value: frequency,
                        style: TextStyle(
                            fontSize: sectionTitleSize, color: Colors.black), // <<< 시니어 모드 적용
                        items: [1, 2, 3, 4, 5]
                            .map((n) => DropdownMenuItem(
                                  value: n,
                                  child: Text(' $n회'),
                                ))
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
                  SizedBox(height: isSeniorMode ? 20 : 10), // <<< 시니어 모드 적용

                  // 복용 시간 설정
                  Text(
                    "복용 시간 설정",
                    style: TextStyle(
                        fontSize: sectionTitleSize, // <<< 시니어 모드 적용
                        fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Column(
                    children: List.generate(frequency, (i) {
                      return ListTile(
                        title: Text('복용 시간 ${i + 1}',
                            style: TextStyle(fontSize: sectionContentSize)), // <<< 시니어 모드 적용
                        trailing: Text(
                          selectedTimes[i].format(context),
                          style: TextStyle(
                            fontSize: timePickerTextSize, // <<< 시니어 모드 적용
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
                minimumSize: Size(double.infinity, saveButtonHeight), // <<< 시니어 모드 적용
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                disabledBackgroundColor: Colors.grey,
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 3))
                  : Text(
                      '저장하기',
                      style: TextStyle(
                          color: Colors.white, fontSize: saveButtonFontSize), // <<< 시니어 모드 적용
                    ),
            ),
          ],
        ),
      ),
    );
  }

  TimeOfDay _parseTime(String t) {
    try {
      final hm = t.split(':');
      return TimeOfDay(hour: int.parse(hm[0]), minute: int.parse(hm[1]));
    } catch (e) {
      return const TimeOfDay(hour: 8, minute: 0);
    }
  }
}