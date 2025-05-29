import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:drug/presentation/widgets/common_bottom_nav.dart'; // 위젯 경로 확인
import 'package:drug/presentation/screens/schedule_input_screen.dart'; // 화면 경로 확인
import 'package:drug/data/database/drug_database.dart'; // DB 모델 및 인스턴스 경로 확인
import 'package:intl/intl.dart'; // 날짜 포맷팅

class DrugManagementScreen extends StatefulWidget {
  const DrugManagementScreen({super.key});

  @override
  State<DrugManagementScreen> createState() => _DrugManagementScreenState();
}

class _DrugManagementScreenState extends State<DrugManagementScreen> {
  // DB 인스턴스를 직접 사용
  final dbInstance = DrugDatabase.instance;

  List<DrugSchedule> scheduleList = [];
  // 약 정보를 빠르게 찾기 위한 Map (Key: itemSeq String, Value: Drug 객체)
  Map<String, Drug> drugMap = {};
  bool _isLoading = true; // 데이터 로딩 상태 표시 플래그
  bool deleteMode = false; // 삭제 모드 활성화 여부
  Set<int> selectedForDelete = {}; // 삭제를 위해 선택된 schedule.id 저장

  @override
  void initState() {
    super.initState();
    print("DrugManagementScreen: initState - Loading initial data...");
    _loadData();
  }

  // 데이터베이스에서 약 및 스케줄 정보를 로드하는 함수
  Future<void> _loadData() async {
    if (!mounted) return; // 위젯이 마운트되지 않았으면 중단
    setState(() {
      _isLoading = true; // 로딩 시작 상태 업데이트
    });
    print("DrugManagementScreen: _loadData - Fetching drugs and schedules...");
    try {
      // 약 목록과 스케줄 목록을 동시에 가져옴
      final results = await Future.wait([
        dbInstance.getAllDrugs(),
        dbInstance.getAllSchedules(),
      ]);

      // 결과 타입 캐스팅
      final drugs = results[0] as List<Drug>;
      final schedules = results[1] as List<DrugSchedule>;

      // 약 목록(List<Drug>)을 itemSeq를 키로 하는 Map<String, Drug>으로 변환
      Map<String, Drug> tempDrugMap = {};
      for (final drug in drugs) {
        // itemSeq는 String 타입으로 DB에 저장되거나 여기서 변환되어야 함
        tempDrugMap[drug.itemSeq.toString()] = drug;
      }
      print(
        "DrugManagementScreen: _loadData - Created drugMap with ${tempDrugMap.length} entries.",
      );

      if (!mounted) return; // 비동기 작업 후 위젯 상태 확인

      // 상태 업데이트: 스케줄 리스트, 약 맵, 로딩 상태 변경
      setState(() {
        scheduleList = schedules;
        drugMap = tempDrugMap;
        _isLoading = false; // 로딩 완료
        print(
          "DrugManagementScreen: _loadData - Data loaded. Schedules: ${schedules.length}",
        );
      });
    } catch (e) {
      print("❌ DrugManagementScreen: Error loading data: $e");
      if (mounted) {
        setState(() => _isLoading = false); // 오류 시에도 로딩 상태 해제
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('데이터 로딩 중 오류 발생: $e')));
      }
    }
  }

  // 약 선택 다이얼로그를 열고 새 스케줄 입력 화면으로 이동하는 함수
  void openDrugSelectorDialog() async {
    print(
      "DrugManagementScreen: openDrugSelectorDialog - Opening drug selector...",
    );
    if (_isLoading) return; // 로딩 중에는 실행 방지

    final allDrugs = drugMap.values.toList(); // Map에서 약 목록 가져오기
    if (!mounted) return;

    final selectedDrug = await showDialog<Drug>(
      context: context,
      builder: (ctx) => DrugSelectorDialog(allDrugs: allDrugs),
    );

    if (selectedDrug != null) {
      print(
        "DrugManagementScreen: Drug selected: ${selectedDrug.itemName}, Navigating to ScheduleInputScreen (new)...",
      );
      // ScheduleInputScreen에서 결과(저장 성공 여부)를 받기 위해 await 사용
      final result = await Navigator.push<bool>(
        // 반환 타입 명시 (bool)
        context,
        MaterialPageRoute(
          builder:
              (_) => ScheduleInputScreen(
                // itemSeq는 int 타입이어야 함 (ScheduleInputScreen 및 DB 모델 확인)
                itemSeq: int.tryParse(selectedDrug.itemSeq) ?? 0,
                drugName: selectedDrug.itemName ?? '알 수 없는 약',
                // existingSchedule: null (새 스케줄)
              ),
        ),
      );

      print(
        "DrugManagementScreen: Returned from ScheduleInputScreen (new). Result: $result",
      );
      // ScheduleInputScreen에서 true를 반환하면 (저장 성공 시) SnackBar 표시 및 데이터 새로고침
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 복용 일정이 성공적으로 추가되었습니다.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print(
          "DrugManagementScreen: New schedule likely added, reloading data...",
        );
        await _loadData(); // SnackBar 표시 후 데이터 로드
      } else {
        print(
          "DrugManagementScreen: No changes made or user cancelled in ScheduleInputScreen (new).",
        );
      }
    } else {
      print("DrugManagementScreen: Drug selection cancelled.");
    }
  }

  // 스케줄 항목을 길게 눌렀을 때 삭제 모드로 진입/항목 선택하는 함수
  void onLongPressItem(int scheduleId) {
    print(
      "DrugManagementScreen: onLongPressItem - Entering delete mode for schedule ID: $scheduleId",
    );
    setState(() {
      deleteMode = true;
      selectedForDelete.add(scheduleId);
    });
  }

  // 스케줄 항목을 탭했을 때의 동작 (삭제 모드 / 수정 모드)
  void onTapItem(DrugSchedule schedule) async {
    final scheduleId = schedule.id;
    if (scheduleId == null) {
      print(
        "❌ DrugManagementScreen: onTapItem - Error: Tapped schedule has null ID.",
      );
      return;
    }

    if (deleteMode) {
      // 삭제 모드: 선택 토글
      print(
        "DrugManagementScreen: onTapItem (Delete Mode) - Toggled selection for schedule ID: $scheduleId",
      );
      setState(() {
        if (selectedForDelete.contains(scheduleId)) {
          selectedForDelete.remove(scheduleId);
          if (selectedForDelete.isEmpty) {
            deleteMode = false; // 선택 항목 없으면 삭제 모드 해제
          }
        } else {
          selectedForDelete.add(scheduleId);
        }
      });
    } else {
      // 수정 모드: 스케줄 수정 화면으로 이동
      print(
        "DrugManagementScreen: onTapItem (Edit Mode) - Finding drug for itemSeq: ${schedule.itemSeq} using Map",
      );
      // Map을 사용하여 약 정보 조회
      final matchedDrug =
          drugMap[schedule.itemSeq.toString()] ??
          Drug(
            itemSeq: schedule.itemSeq.toString(),
            itemName: '알 수 없는 약',
            entpName: 'null',
            efcyQesitm: 'null',
            useMethodQesitm: 'null',
            atpnWarnQesitm: 'null',
            atpnQesitm: 'null',
            intrcQesitm: 'null',
            seQesitm: 'null',
            depositMethodQesitm: 'null',
            openDe: 'null',
            updateDe: 'null',
            itemImage: 'null',
            bizno: 0,
            ingredients: 'null',
          );

      print(
        "DrugManagementScreen: onTapItem (Edit Mode) - Drug found: ${matchedDrug.itemName}. Navigating to ScheduleInputScreen (edit)...",
      );
      final result = await Navigator.push<bool>(
        // 결과(bool) 받음
        context,
        MaterialPageRoute(
          builder:
              (_) => ScheduleInputScreen(
                itemSeq: schedule.itemSeq,
                drugName: matchedDrug.itemName ?? '알 수 없는 약',
                existingSchedule: schedule, // 기존 스케줄 전달
              ),
        ),
      );

      print(
        "DrugManagementScreen: Returned from ScheduleInputScreen (edit). Result: $result",
      );
      // 수정 성공 시 (true 반환) SnackBar 표시 및 데이터 새로고침
      if (result == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✏️ 복용 일정이 수정되었습니다.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        print(
          "DrugManagementScreen: Schedule likely edited, reloading data...",
        );
        await _loadData(); // SnackBar 표시 후 데이터 로드
      } else {
        print(
          "DrugManagementScreen: No changes made or user cancelled in ScheduleInputScreen (edit).",
        );
      }
    }
  }

  // 선택된 스케줄들을 삭제하는 함수
  void deleteSelectedSchedules() async {
    if (selectedForDelete.isEmpty) {
      print(
        "DrugManagementScreen: deleteSelectedSchedules - No schedules selected.",
      );
      setState(() => deleteMode = false);
      return;
    }

    final count = selectedForDelete.length;
    print(
      "DrugManagementScreen: deleteSelectedSchedules - Attempting to delete $count schedules...",
    );

    // 삭제 확인 다이얼로그
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

    if (confirm != true) {
      print(
        "DrugManagementScreen: deleteSelectedSchedules - Deletion cancelled by user.",
      );
      return;
    }

    print(
      "DrugManagementScreen: deleteSelectedSchedules - User confirmed deletion.",
    );

    try {
      List<Future<void>> deleteFutures = [];
      List<Future<void>> cancelAlarmFutures = [];

      for (final id in selectedForDelete) {
        // 알람 취소를 위해 스케줄 정보 찾기 (현재 로드된 리스트에서)
        DrugSchedule? scheduleToDelete;
        for (final schedule in scheduleList) {
          if (schedule.id == id) {
            scheduleToDelete = schedule;
            break;
          }
        }

        if (scheduleToDelete != null) {
          // 해당 스케줄의 모든 알람 취소 작업 추가
          final days =
              scheduleToDelete.endDate
                  .difference(scheduleToDelete.startDate)
                  .inDays;
          for (var d = 0; d <= days; d++) {
            for (var i = 0; i < scheduleToDelete.times.length; i++) {
              final alarmId = id * 100 + d * 10 + i;
              print(
                "... Adding cancel task for alarm ID: $alarmId (from schedule ID: $id)",
              );
              cancelAlarmFutures.add(AndroidAlarmManager.cancel(alarmId));
            }
          }
        } else {
          print("⚠️ ... Could not find schedule $id in list to cancel alarms.");
        }

        // DB 삭제 작업 추가
        print("... Adding delete task for schedule ID: $id");
        deleteFutures.add(dbInstance.deleteSchedule(id));
      }

      // 알람 취소 및 DB 삭제 병렬 실행
      print(
        "... Executing alarm cancellations (${cancelAlarmFutures.length} tasks)...",
      );
      await Future.wait(cancelAlarmFutures);
      print("... Executing DB deletions (${deleteFutures.length} tasks)...");
      await Future.wait(deleteFutures);
      print("... Finished deletion process.");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ $count개의 일정이 삭제되었습니다.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print("❌ DrugManagementScreen: Error during deletion process: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('삭제 중 오류 발생: $e')));
      }
    } finally {
      // 완료 후 상태 초기화 및 데이터 리로드
      if (mounted) {
        setState(() {
          deleteMode = false;
          selectedForDelete.clear();
        });
        // 삭제 후에는 항상 데이터를 다시 로드하여 최신 상태 반영
        await _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 날짜 포맷터
    final fmt = DateFormat('yyyy.MM.dd');

    return Scaffold(
      // AppBar 배경색과 통일
      backgroundColor: const Color(0xFFBCD4C6),
      appBar: AppBar(
        elevation: 0, // AppBar 그림자 제거
        title: Text(
          // 삭제 모드일 때 선택된 항목 수 표시
          deleteMode ? '${selectedForDelete.length}개 선택됨' : '복약 관리',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFFBCD4C6), // AppBar 배경색
        // 뒤로가기/닫기 버튼
        leading: IconButton(
          icon: Icon(
            deleteMode ? Icons.close : Icons.arrow_back_ios_new,
            color: Colors.white,
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
        // 삭제 모드일 때 삭제 버튼 표시
        actions:
            deleteMode
                ? [
                  IconButton(
                    padding: EdgeInsets.only(right: 15),
                    icon: const Icon(
                      Icons.delete_sweep_outlined,
                      color: Colors.white,
                      size: 35,
                    ),
                    tooltip: '선택한 항목 삭제',
                    // 선택된 항목이 있을 때만 버튼 활성화
                    onPressed:
                        selectedForDelete.isNotEmpty
                            ? deleteSelectedSchedules
                            : null,
                  ),
                ]
                : [], // 삭제 모드 아닐 때는 액션 없음
      ),
      body: SafeArea(
        child: Container(
          // 내용 영역 컨테이너
          clipBehavior: Clip.antiAlias, // borderRadius 적용 위함
          decoration: const BoxDecoration(
            color: Colors.white, // 흰색 배경
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ), // 위쪽 모서리 둥글게
          ),
          child: Column(
            children: [
              // '새 복용 일정 추가' 버튼 (삭제 모드가 아닐 때만 표시)
              if (!deleteMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: InkWell(
                    onTap: openDrugSelectorDialog, // 탭하면 다이얼로그 열기
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 16.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.teal[50], // 약간의 배경색
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.teal[100]!), // 얇은 테두리
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle,
                            size: 22,
                            color: Colors.teal,
                          ), // 아이콘 변경
                          SizedBox(width: 8),
                          Text(
                            '새 복용 일정 추가',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.teal, // 색상 변경
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 로딩 중일 때 표시되는 인디케이터
              if (_isLoading)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 15),
                        Text("데이터를 불러오는 중입니다..."),
                      ],
                    ),
                  ),
                )
              // 로딩 완료 후 스케줄 목록 또는 안내 메시지 표시
              else
                Expanded(
                  child:
                      scheduleList.isEmpty
                          // 등록된 일정이 없을 때 안내 메시지
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 60,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 15),
                                Text(
                                  '등록된 복용 일정이 없습니다.',
                                  style: TextStyle(
                                    fontSize: 17,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  '상단의 (+) 버튼을 눌러 추가해보세요.',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          )
                          // 등록된 일정이 있을 때 ListView 표시
                          : ListView.builder(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            itemCount: scheduleList.length,
                            itemBuilder: (context, index) {
                              final schedule = scheduleList[index];
                              final scheduleId = schedule.id; // Null 가능성 확인

                              // Map을 사용하여 약 정보 조회 (O(1) 시간 복잡도)
                              final drug =
                                  drugMap[schedule.itemSeq.toString()] ??
                                  Drug(
                                    itemSeq: schedule.itemSeq.toString(),
                                    itemName: '알 수 없는 약',
                                    entpName: '',
                                    efcyQesitm: '',
                                    useMethodQesitm: '',
                                    atpnWarnQesitm: '',
                                    atpnQesitm: '',
                                    intrcQesitm: '',
                                    seQesitm: '',
                                    depositMethodQesitm: '',
                                    openDe: '',
                                    updateDe: '',
                                    itemImage: '',
                                    bizno: 0,
                                    ingredients: '',
                                  );

                              // 현재 항목이 삭제를 위해 선택되었는지 확인
                              final bool isSelected =
                                  deleteMode &&
                                  scheduleId != null &&
                                  selectedForDelete.contains(scheduleId);

                              // 각 스케줄 항목을 Card 위젯으로 표시
                              return Card(
                                elevation: isSelected ? 6 : 2, // 선택 시 그림자 강조
                                margin: const EdgeInsets.symmetric(
                                  vertical: 7,
                                  horizontal: 5,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    12,
                                  ), // 모서리 둥글기 증가
                                  side:
                                      isSelected // 선택 시 테두리 표시
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
                                          ), // 기본 얇은 테두리
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                    horizontal: 15,
                                  ),
                                  onTap:
                                      () => onTapItem(
                                        schedule,
                                      ), // 탭 시 수정 또는 선택 토글
                                  onLongPress:
                                      scheduleId != null
                                          ? () => onLongPressItem(scheduleId)
                                          : null, // 롱 프레스 시 삭제 모드 진입
                                  // 왼쪽 아이콘/이미지
                                  leading:
                                      deleteMode
                                          ? Icon(
                                            // 삭제 모드: 체크 아이콘
                                            isSelected
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            color:
                                                isSelected
                                                    ? Theme.of(
                                                      context,
                                                    ).colorScheme.primary
                                                    : Colors.grey[400],
                                            size: 28,
                                          )
                                          : ((drug.itemImage != null && drug.itemImage!.isNotEmpty) // 평소 모드: 약 이미지 또는 기본 아이콘
                                              ? ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child: Image.network(
                                                  drug.itemImage!,
                                                  width: 55,
                                                  height: 55,
                                                  fit: BoxFit.cover,
                                                  loadingBuilder:
                                                      (
                                                        context,
                                                        child,
                                                        progress,
                                                      ) =>
                                                          progress == null
                                                              ? child
                                                              : const Center(
                                                                child: SizedBox(
                                                                  width: 20,
                                                                  height: 20,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                  ),
                                                                ),
                                                              ),
                                                  errorBuilder:
                                                      (context, error, stack) =>
                                                          const Icon(
                                                            Icons.broken_image,
                                                            size: 35,
                                                            color: Colors.grey,
                                                          ),
                                                ),
                                              )
                                              : CircleAvatar(
                                                radius: 28,
                                                backgroundColor:
                                                    Colors.teal[50],
                                                child: Icon(
                                                  Icons.medication_liquid,
                                                  color: Colors.teal[700],
                                                  size: 30,
                                                ),
                                              )),
                                  // 제목: 약 이름
                                  title: Text(
                                    drug.itemName ?? '이름 없는 약',
                                    style: const TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w600,
                                    ), // 약간 더 굵게
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  // 부제목: 복용 기간 및 시간 정보
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 5.0),
                                    child: Text(
                                      '기간: ${fmt.format(schedule.startDate)} ~ ${fmt.format(DateTime(schedule.endDate.year, schedule.endDate.month, schedule.endDate.day))}\n' // 종료일은 날짜까지만
                                      '시간: 하루 ${schedule.frequency}회 (${schedule.times.join(", ")})',
                                      style: TextStyle(
                                        fontSize: 13.8,
                                        color: Colors.grey[800],
                                        height: 1.3,
                                      ), // 줄간격 조정
                                    ),
                                  ),
                                  // 오른쪽 끝 아이콘 (삭제 모드 아닐 때만)
                                  trailing:
                                      deleteMode
                                          ? null
                                          : Icon(
                                            Icons.edit_note,
                                            size: 30,
                                            color: Colors.grey[500],
                                          ), // 수정 아이콘으로 변경
                                ),
                              );
                            },
                          ),
                ),
            ],
          ),
        ),
      ),
      // 하단 네비게이션 바 (고정)
      bottomNavigationBar: CommonBottomNavBar(
        currentIndex: 1, // 복약 관리 화면이므로 1번 인덱스
        onTap: (idx) {
          if (idx == 0) {
            // 홈 화면으로 이동 (스택 초기화)
            Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
          } else if (idx == 1) {
            // 이미 보관함 화면이므로 아무것도 안 함
          }
        },
      ),
    );
  }
}

class DrugSelectorDialog extends StatefulWidget {
  final List<Drug> allDrugs;
  const DrugSelectorDialog({super.key, required this.allDrugs});

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
                  (d) =>
                      (d.itemName ?? '').toLowerCase().contains(search.toLowerCase()),
                )
                .toList();

    return AlertDialog(
      title: const Text('복용할 약 선택'),
      contentPadding: const EdgeInsets.fromLTRB(15, 10, 15, 10),
      content: SizedBox(
        width: double.maxFinite,
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: '약 이름으로 검색...',
                prefixIcon: const Icon(Icons.search, size: 20),
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
                      ? const Center(child: Text('검색 결과가 없습니다.'))
                      : ListView.builder(
                        shrinkWrap: true,
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final drug = filtered[i];
                          return ListTile(
                            leading:
                                (drug.itemImage != null && drug.itemImage!.isNotEmpty)
                                    ? Image.network(
                                      drug.itemImage!,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (_, __, ___) =>
                                              const Icon(Icons.medication),
                                    )
                                    : const Icon(Icons.medication_outlined),
                            title: Text(
                              drug.itemName ?? '이름 없음',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              drug.entpName ?? '제조사 정보 없음',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
          child: const Text('취소'),
        ),
      ],
    );
  }
}
