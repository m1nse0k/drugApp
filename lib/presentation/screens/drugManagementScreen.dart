// drugManagementScreen.dart
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:drug/presentation/widgets/common_bottom_nav.dart';
import 'package:drug/presentation/screens/schedule_input_screen.dart';
import 'package:drug/data/database/drug_database.dart';
import 'package:intl/intl.dart';

class DrugManagementScreen extends StatefulWidget {
  // isSeniorMode 파라미터 추가
  final bool isSeniorMode;

  const DrugManagementScreen({super.key, required this.isSeniorMode});

  @override
  State<DrugManagementScreen> createState() => _DrugManagementScreenState();
}

class _DrugManagementScreenState extends State<DrugManagementScreen> {
  final dbInstance = DrugDatabase.instance;
  List<DrugSchedule> scheduleList = [];
  Map<String, Drug> drugMap = {};
  bool _isLoading = true;
  bool deleteMode = false;
  Set<int> selectedForDelete = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    // ... (기존 _loadData 함수 코드는 변경 없음)
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        dbInstance.getAllDrugs(),
        dbInstance.getAllSchedules(),
      ]);
      final drugs = results[0] as List<Drug>;
      final schedules = results[1] as List<DrugSchedule>;
      Map<String, Drug> tempDrugMap = {
        for (var drug in drugs) drug.itemSeq.toString(): drug,
      };
      if (!mounted) return;
      setState(() {
        scheduleList = schedules;
        drugMap = tempDrugMap;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 로딩 중 오류 발생: $e')));
      }
    }
  }

  void openDrugSelectorDialog() async {
    if (_isLoading) return;
    final allDrugs = drugMap.values.toList();
    if (!mounted) return;

    final selectedDrug = await showDialog<Drug>(
      context: context,
      // isSeniorMode를 DrugSelectorDialog로 전달
      builder:
          (ctx) => DrugSelectorDialog(
            allDrugs: allDrugs,
            isSeniorMode: widget.isSeniorMode,
          ),
    );

    if (selectedDrug != null) {
      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (_) => ScheduleInputScreen(
                itemSeq: int.tryParse(selectedDrug.itemSeq) ?? 0,
                drugName: selectedDrug.itemName ?? '알 수 없는 약',
                // isSeniorMode를 ScheduleInputScreen으로 전달
                isSeniorMode: widget.isSeniorMode,
              ),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 복용 일정이 성공적으로 추가되었습니다.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadData();
      }
    }
  }

  void onLongPressItem(int scheduleId) {
    setState(() {
      deleteMode = true;
      selectedForDelete.add(scheduleId);
    });
  }

  void onTapItem(DrugSchedule schedule) async {
    // ... (기존 onTapItem 함수의 로직 부분은 대부분 유지)
    final scheduleId = schedule.id;
    if (scheduleId == null) return;

    if (deleteMode) {
      setState(() {
        if (selectedForDelete.contains(scheduleId)) {
          selectedForDelete.remove(scheduleId);
          if (selectedForDelete.isEmpty) deleteMode = false;
        } else {
          selectedForDelete.add(scheduleId);
        }
      });
    } else {
      final matchedDrug =
          drugMap[schedule.itemSeq.toString()] ??
          Drug(itemSeq: schedule.itemSeq.toString(), itemName: '알 수 없는 약');

      final result = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder:
              (_) => ScheduleInputScreen(
                itemSeq: schedule.itemSeq,
                drugName: matchedDrug.itemName ?? '알 수 없는 약',
                existingSchedule: schedule,
                // isSeniorMode를 ScheduleInputScreen으로 전달
                isSeniorMode: widget.isSeniorMode,
              ),
        ),
      );

      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✏️ 복용 일정이 수정되었습니다.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        await _loadData();
      }
    }
  }

  void deleteSelectedSchedules() async {
    // ... (기존 deleteSelectedSchedules 함수 코드는 변경 없음)
    if (selectedForDelete.isEmpty) {
      setState(() => deleteMode = false);
      return;
    }

    final count = selectedForDelete.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('삭제 확인'),
            content: Text('$count개의 복용 일정을 삭제하시겠습니까?\n설정된 알람도 함께 취소됩니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('삭제', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    try {
      List<Future<void>> deleteFutures = [];
      List<Future<void>> cancelAlarmFutures = [];
      for (final id in selectedForDelete) {
        final scheduleToDelete = scheduleList.firstWhere((s) => s.id == id);
        final days =
            scheduleToDelete.endDate
                .difference(scheduleToDelete.startDate)
                .inDays;
        for (var d = 0; d <= days; d++) {
          for (var i = 0; i < scheduleToDelete.times.length; i++) {
            final alarmId = id * 100 + d * 10 + i;
            cancelAlarmFutures.add(AndroidAlarmManager.cancel(alarmId));
          }
        }
        deleteFutures.add(dbInstance.deleteSchedule(id));
      }
      await Future.wait(cancelAlarmFutures);
      await Future.wait(deleteFutures);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('🗑️ $count개의 일정이 삭제되었습니다.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 중 오류 발생: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          deleteMode = false;
          selectedForDelete.clear();
        });
        await _loadData();
      }
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
    final double addScheduleBtnFontSize = isSeniorMode ? 20.0 : 16.0;
    final double addScheduleBtnIconSize = isSeniorMode ? 26.0 : 22.0;
    final double addScheduleBtnPadding = isSeniorMode ? 18.0 : 12.0;
    final double emptyIconSize = isSeniorMode ? 80.0 : 60.0;
    final double emptyTitleSize = isSeniorMode ? 22.0 : 17.0;
    final double emptySubtitleSize = isSeniorMode ? 18.0 : 15.0;
    final double listItemTitleSize = isSeniorMode ? 20.0 : 16.5;
    final double listItemSubtitleSize = isSeniorMode ? 17.0 : 13.8;
    final double leadingImageSize = isSeniorMode ? 65.0 : 55.0;
    final double leadingIconSize = isSeniorMode ? 40.0 : 30.0;

    return Scaffold(
      backgroundColor: const Color(0xFFBCD4C6),
      appBar: AppBar(
        elevation: 0,
        title: Text(
          deleteMode ? '${selectedForDelete.length}개 선택됨' : '복약 관리',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: appBarTitleSize, // <<< 시니어 모드 적용
          ),
        ),
        backgroundColor: const Color(0xFFBCD4C6),
        leading: IconButton(
          icon: Icon(
            deleteMode ? Icons.close : Icons.arrow_back_ios_new,
            color: Colors.white,
            size: isSeniorMode ? 30 : 24, // <<< 시니어 모드 적용
          ),
          onPressed: () {
            if (deleteMode) {
              setState(() {
                deleteMode = false;
                selectedForDelete.clear();
              });
            } else {
              Navigator.pop(context);
            }
          },
        ),
        actions:
            deleteMode
                ? [
                  IconButton(
                    padding: EdgeInsets.only(right: 15),
                    icon: Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.white,
                      size: isSeniorMode ? 40 : 35, // <<< 시니어 모드 적용
                    ),
                    tooltip: '선택한 항목 삭제',
                    onPressed:
                        selectedForDelete.isNotEmpty
                            ? deleteSelectedSchedules
                            : null,
                  ),
                ]
                : [],
      ),
      body: SafeArea(
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              if (!deleteMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: InkWell(
                    onTap: openDrugSelectorDialog,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        vertical: addScheduleBtnPadding, // <<< 시니어 모드 적용
                        horizontal: 16.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal[100]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle,
                            size: addScheduleBtnIconSize, // <<< 시니어 모드 적용
                            color: Colors.teal,
                          ),
                          SizedBox(
                            width: isSeniorMode ? 12 : 8,
                          ), // <<< 시니어 모드 적용
                          Text(
                            '새 복용 일정 추가',
                            style: TextStyle(
                              fontSize: addScheduleBtnFontSize, // <<< 시니어 모드 적용
                              fontWeight: FontWeight.w600,
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child:
                      scheduleList.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: emptyIconSize, // <<< 시니어 모드 적용
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  '등록된 복용 일정이 없습니다.',
                                  style: TextStyle(
                                    fontSize: emptyTitleSize, // <<< 시니어 모드 적용
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '상단의 버튼을 눌러 추가해보세요.',
                                  style: TextStyle(
                                    fontSize:
                                        emptySubtitleSize, // <<< 시니어 모드 적용
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            itemCount: scheduleList.length,
                            itemBuilder: (context, index) {
                              final schedule = scheduleList[index];
                              final drug =
                                  drugMap[schedule.itemSeq.toString()] ??
                                  Drug(
                                    itemSeq: schedule.itemSeq.toString(),
                                    itemName: '알 수 없는 약',
                                  );
                              final bool isSelected =
                                  deleteMode &&
                                  schedule.id != null &&
                                  selectedForDelete.contains(schedule.id);

                              return Card(
                                elevation: isSelected ? 6 : 2,
                                margin: const EdgeInsets.symmetric(
                                  vertical: 7,
                                  horizontal: 5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side:
                                      isSelected
                                          ? BorderSide(
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.primary,
                                            width: 2,
                                          )
                                          : BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 0.8,
                                          ),
                                ),
                                child: ListTile(
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical:
                                        isSeniorMode ? 15 : 10, // <<< 시니어 모드 적용
                                    horizontal: 15,
                                  ),
                                  onTap: () => onTapItem(schedule),
                                  onLongPress:
                                      schedule.id != null
                                          ? () => onLongPressItem(schedule.id!)
                                          : null,
                                  leading:
                                      deleteMode
                                          ? Icon(
                                            isSelected
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            color:
                                                isSelected
                                                    ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                    : Colors.grey[400],
                                            size:
                                                isSeniorMode
                                                    ? 34
                                                    : 28, // <<< 시니어 모드 적용
                                          )
                                          : ((drug.itemImage != null &&
                                                  drug.itemImage!.isNotEmpty)
                                              ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  drug.itemImage!,
                                                  width:
                                                      leadingImageSize, // <<< 시니어 모드 적용
                                                  height:
                                                      leadingImageSize, // <<< 시니어 모드 적용
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (c, e, s) => const Icon(
                                                        Icons.broken_image,
                                                        size: 35,
                                                      ),
                                                ),
                                              )
                                              : CircleAvatar(
                                                radius:
                                                    leadingImageSize /
                                                    2, // <<< 시니어 모드 적용
                                                backgroundColor:
                                                    Colors.teal[50],
                                                child: Icon(
                                                  Icons.medication_liquid,
                                                  color: Colors.teal[700],
                                                  size:
                                                      leadingIconSize, // <<< 시니어 모드 적용
                                                ),
                                              )),
                                  title: Text(
                                    drug.itemName ?? '이름 없는 약',
                                    style: TextStyle(
                                      fontSize:
                                          listItemTitleSize, // <<< 시니어 모드 적용
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 5.0),
                                    child: Text(
                                      '기간: ${fmt.format(schedule.startDate)} ~ ${fmt.format(schedule.endDate)}\n'
                                      '시간: 하루 ${schedule.frequency}회 (${schedule.times.join(", ")})',
                                      style: TextStyle(
                                        fontSize:
                                            listItemSubtitleSize, // <<< 시니어 모드 적용
                                        color: Colors.grey[800],
                                        height: 1.4, // <<< 시니어 모드 적용 (줄간격)
                                      ),
                                    ),
                                  ),
                                  trailing:
                                      deleteMode
                                          ? null
                                          : Icon(
                                            Icons.edit_note,
                                            size:
                                                isSeniorMode
                                                    ? 36
                                                    : 30, // <<< 시니어 모드 적용
                                            color: Colors.grey[500],
                                          ),
                                ),
                              );
                            },
                          ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CommonBottomNavBar(
        currentIndex: 1,
        onTap: (idx) {
          if (idx == 0) {
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          }
        },
      ),
    );
  }
}

// DrugSelectorDialog도 isSeniorMode를 받도록 수정
class DrugSelectorDialog extends StatefulWidget {
  final List<Drug> allDrugs;
  final bool isSeniorMode; // <<< 시니어 모드 변수 추가

  const DrugSelectorDialog({
    super.key,
    required this.allDrugs,
    required this.isSeniorMode,
  });

  @override
  State<DrugSelectorDialog> createState() => _DrugSelectorDialogState();
}

class _DrugSelectorDialogState extends State<DrugSelectorDialog> {
  String search = '';

  @override
  Widget build(BuildContext context) {
    final filtered =
        search.isEmpty
            ? widget.allDrugs
            : widget.allDrugs
                .where(
                  (d) => (d.itemName ?? '').toLowerCase().contains(
                    search.toLowerCase(),
                  ),
                )
                .toList();

    // =================================================================
    // 다이얼로그 내부 UI 동적 설정
    // =================================================================
    final isSeniorMode = widget.isSeniorMode;
    final double titleSize = isSeniorMode ? 24.0 : 20.0;
    final double hintSize = isSeniorMode ? 18.0 : 14.0;
    final double itemTitleSize = isSeniorMode ? 19.0 : 16.0;
    final double itemSubtitleSize = isSeniorMode ? 16.0 : 13.0;
    final double leadingImageSize = isSeniorMode ? 50.0 : 40.0;

    return AlertDialog(
      title: Text(
        '복용할 약 선택',
        style: TextStyle(fontSize: titleSize),
      ), // <<< 시니어 모드 적용
      contentPadding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              style: TextStyle(fontSize: hintSize), // <<< 시니어 모드 적용
              decoration: InputDecoration(
                hintText: '약 이름으로 검색...',
                hintStyle: TextStyle(fontSize: hintSize), // <<< 시니어 모드 적용
                prefixIcon: Icon(Icons.search, size: isSeniorMode ? 26 : 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onChanged: (val) => setState(() => search = val),
            ),
            const SizedBox(height: 10),
            Expanded(
              child:
                  filtered.isEmpty
                      ? Center(
                        child: Text(
                          '검색 결과가 없습니다.',
                          style: TextStyle(fontSize: hintSize),
                        ),
                      ) // <<< 시니어 모드 적용
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final drug = filtered[i];
                          return ListTile(
                            leading:
                                (drug.itemImage != null &&
                                        drug.itemImage!.isNotEmpty)
                                    ? Image.network(
                                      drug.itemImage!,
                                      width: leadingImageSize, // <<< 시니어 모드 적용
                                      height: leadingImageSize, // <<< 시니어 모드 적용
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (_, __, ___) =>
                                              Icon(Icons.medication),
                                    )
                                    : Icon(
                                      Icons.medication_outlined,
                                      size: leadingImageSize,
                                    ), // <<< 시니어 모드 적용
                            title: Text(
                              drug.itemName ?? '이름 없음',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: itemTitleSize,
                              ), // <<< 시니어 모드 적용
                            ),
                            subtitle: Text(
                              drug.entpName ?? '제조사 정보 없음',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: itemSubtitleSize,
                              ), // <<< 시니어 모드 적용
                            ),
                            onTap: () => Navigator.pop(context, drug),
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(
            '취소',
            style: TextStyle(fontSize: isSeniorMode ? 18 : 14),
          ), // <<< 시니어 모드 적용
        ),
      ],
    );
  }
}
