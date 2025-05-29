// lib/presentation/screens/drug_detail_screen.dart
import 'package:drug/presentation/screens/schedule_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:drug/data/database/drug_database.dart'; // Drug 모델 경로 확인
import 'package:drug/presentation/widgets/common_bottom_nav.dart'; // 위젯 경로 확인
import 'package:intl/intl.dart'; // 숫자 포맷팅 위해

class DrugDetailScreen extends StatelessWidget {
  final Drug drug; // 표시할 약 정보
  final double score; // 식별 정확도

  const DrugDetailScreen({super.key, required this.drug, required this.score});

  @override
  Widget build(BuildContext context) {
    final Color primaryColor =
        Theme.of(context).primaryColor; // main.dart에서 설정한 teal
    final scorePercent = NumberFormat.percentPattern("ko_KR").format(score);

    // 주의사항 관련 텍스트 필드들을 필터링하고 결합
    final precautionsList =
        [
          drug.atpnWarnQesitm, // 복용 전 경고
          drug.atpnQesitm, // 주의사항
          drug.intrcQesitm, // 상호작용
          drug.seQesitm, // 부작용
          drug.depositMethodQesitm, // 보관방법
        ].where((s) => s != null && s.isNotEmpty).toList(); // 빈 문자열이 아닌 것만 필터링

    // 각 주의사항 항목 앞에 머리글 추가 (선택 사항)
    String formattedPrecautions = "";
    if (precautionsList.isNotEmpty) {
      List<String> titledPrecautions = [];
      if (drug.atpnWarnQesitm != null && drug.atpnWarnQesitm!.isNotEmpty)
        titledPrecautions.add("복용 전 경고:\n${drug.atpnWarnQesitm}");
      if (drug.atpnQesitm != null && drug.atpnQesitm!.isNotEmpty)
        titledPrecautions.add("일반 주의사항:\n${drug.atpnQesitm}");
      if (drug.intrcQesitm != null && drug.intrcQesitm!.isNotEmpty)
        titledPrecautions.add("상호작용:\n${drug.intrcQesitm}");
      if (drug.seQesitm != null && drug.seQesitm!.isNotEmpty)
        titledPrecautions.add("주요 부작용:\n${drug.seQesitm}");
      if (drug.depositMethodQesitm != null &&
          drug.depositMethodQesitm!.isNotEmpty)
        titledPrecautions.add("보관 방법:\n${drug.depositMethodQesitm}");
      formattedPrecautions = titledPrecautions.join('\n\n');
    }

    return Scaffold(
      extendBodyBehindAppBar: true, // body가 AppBar 뒤까지 확장
      appBar: AppBar(
        title: const Text(
          '알약 상세 정보',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        backgroundColor: Colors.transparent, // AppBar 배경 투명
        elevation: 0, // AppBar 그림자 제거
        foregroundColor: Colors.white, // 아이콘 등 기본 색상
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 24),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '뒤로가기',
        ),
        centerTitle: true,
      ),
      body: Container(
        // 전체 화면 그라데이션 배경
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(0.85),
              Colors.cyan.shade100.withOpacity(0.85),
            ], // 약간 더 진한 그라데이션
            begin: Alignment.topCenter, // 그라데이션 방향 변경
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          // 시스템 UI 영역 피하기
          bottom: false, // 하단 네비게이션 바가 있으므로 SafeArea 하단은 false
          child: Column(
            children: [
              // AppBar 높이만큼의 공간을 만들어 AppBar와 내용이 겹치지 않도록 함
              SizedBox(
                height:
                    kToolbarHeight + MediaQuery.of(context).padding.top - 50,
              ), // 상태바 높이 고려, 약간 줄임

              Expanded(
                child: Container(
                  width: double.infinity,
                  // margin: const EdgeInsets.only(top: 10), // 상단 여백 조정 (필요 시)
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).scaffoldBackgroundColor, // 앱 기본 배경색
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12), // 그림자 약간 더 진하게
                        blurRadius: 12,
                        offset: const Offset(0, -3), // 그림자 위치 조정
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      20.0,
                      25.0,
                      20.0,
                      20.0,
                    ), // 패딩 조정
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch, // 자식 위젯들 가로로 꽉 채우기
                      children: [
                        // 1. 약 이미지
                        Center(
                          child: Card(
                            elevation: 5, // 그림자 강조
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child:
                                (drug.itemImage != null &&
                                        drug.itemImage!.isNotEmpty)
                                    ? Image.network(
                                      drug.itemImage!,
                                      // height: 200,
                                      fit: BoxFit.contain,
                                      loadingBuilder:
                                          (context, child, progress) =>
                                              progress == null
                                                  ? child
                                                  : const SizedBox(
                                                    height: 220,
                                                    child: Center(
                                                      child:
                                                          CircularProgressIndicator(),
                                                    ),
                                                  ),
                                      errorBuilder:
                                          (context, error, stack) => Container(
                                            height: 220,
                                            width:
                                                MediaQuery.of(
                                                  context,
                                                ).size.width *
                                                0.7,
                                            color: Colors.grey[200],
                                            child: Center(
                                              child: Icon(
                                                Icons
                                                    .medication_liquid_outlined,
                                                color: Colors.grey[400],
                                                size: 70,
                                              ),
                                            ),
                                          ),
                                    )
                                    : Container(
                                      height: 220,
                                      width:
                                          MediaQuery.of(context).size.width *
                                          0.7, // 너비 지정
                                      decoration: BoxDecoration(
                                        color: Colors.grey[100],
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.medication_liquid_outlined,
                                          color: Colors.grey[400],
                                          size: 70,
                                        ),
                                      ),
                                    ),
                          ),
                        ),
                        const SizedBox(height: 30),

                        // 2. 기본 정보 카드
                        _buildInfoCard(
                          context: context, // context 전달
                          children: [
                            _buildInfoRow(
                              "제품명",
                              drug.itemName ?? "-",
                              labelFlex: 2,
                              valueFlex: 4,
                              context: context,
                            ),
                            _buildInfoRow(
                              "제조사",
                              drug.entpName ?? "-",
                              labelFlex: 2,
                              valueFlex: 4,
                              context: context,
                            ),
                            // _buildInfoRow(
                            //   "식별 정확도",
                            //   scorePercent,
                            //   valueColor: primaryColor,
                            //   labelFlex: 2,
                            //   valueFlex: 4,
                            //   context: context,
                            // ),
                          ],
                        ),
                        const SizedBox(height: 25),

                        Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.alarm_add,
                              color: Colors.white,
                            ),
                            label: const Text(
                              '복용 일정 추가',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  Theme.of(context).primaryColor, // 앱의 주요 색상
                              padding: const EdgeInsets.symmetric(
                                horizontal: 30,
                                vertical: 15,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                              elevation: 3,
                            ),
                            onPressed: () {
                              print(
                                "Navigating to ScheduleInputScreen from DetailScreen with drug: ${drug.itemName} (itemSeq: ${drug.itemSeq})",
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ScheduleInputScreen(
                                        // itemSeq는 int 타입으로 변환하여 전달
                                        itemSeq:
                                            int.tryParse(drug.itemSeq) ?? 0,
                                        drugName: drug.itemName ?? '알 수 없는 약',
                                        // 새로운 일정을 추가하는 것이므로 existingSchedule은 null
                                      ),
                                ),
                              );
                            },
                          ),
                        ),

                        const SizedBox(height: 25),

                        // 3. 상세 정보 제목
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4.0,
                            bottom: 10.0,
                          ), // 제목 왼쪽 약간의 패딩
                          child: Text(
                            "세부 정보",
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[750],
                              fontSize: 19,
                            ),
                          ),
                        ),
                        _buildExpansionTile(
                          context: context,
                          title: "효능/효과", // 점 추가
                          icon: Icons.medical_services_rounded, // 아이콘 변경
                          content: drug.efcyQesitm ?? "정보 없음",
                        ),
                        _buildExpansionTile(
                          context: context,
                          title: "용법/용량", // 점 추가
                          icon: Icons.library_books_rounded, // 아이콘 변경
                          content: drug.useMethodQesitm ?? "정보 없음",
                        ),
                        _buildExpansionTile(
                          context: context,
                          title: "주의사항 및 보관", // 제목 통합
                          icon: Icons.warning_amber_rounded, // 아이콘 변경
                          content:
                              formattedPrecautions.isNotEmpty
                                  ? formattedPrecautions
                                  : "관련 정보가 없습니다.",
                        ),
                        const SizedBox(height: 20), // 하단 여백
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: CommonBottomNavBar(
        // 이 화면은 특정 탭에 속하지 않으므로, 어떤 인덱스를 활성화할지 결정해야 함
        // 예: 홈(0)으로 유지하거나, -1을 전달하여 아무것도 선택 안 되게 (CommonBottomNavBar 수정 필요)
        currentIndex:
            -1, // <<<=== -1로 설정하여 아무것도 선택 안 함 (CommonBottomNavBar에서 -1 처리 로직 추가 필요)
        onTap: (index) {
          if (index == 0)
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => route.isFirst,
            );
          else if (index == 1)
            Navigator.pushNamed(context, '/management');
          // else if (index == 2) Navigator.pushNamed(context, '/settings');
        },
      ),
    );
  }

  // 기본 정보 행 (Flex 조절 및 context 파라미터 추가)
  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    int labelFlex = 1,
    int valueFlex = 2,
    required BuildContext context,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9.0), // 세로 패딩 증가
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: labelFlex,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ), // 라벨 색상 변경
            ),
          ),
          const SizedBox(width: 12), // 간격 조절
          Expanded(
            flex: valueFlex,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 15.5,
                color:
                    valueColor ?? Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 기본 정보를 담는 Card 위젯
  Widget _buildInfoCard({
    required List<Widget> children,
    required BuildContext context,
  }) {
    return Card(
      elevation: 2, // 그림자 살짝 증가
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14.0),
      ), // 모서리 둥글기 증가
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 18.0,
          vertical: 12.0,
        ), // 내부 패딩 조절
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  // ExpansionTile 헬퍼 함수 (아이콘, 색상, 패딩 등 조정)
  Widget _buildExpansionTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String content,
  }) {
    final Color tilePrimaryColor = Theme.of(context).primaryColor;

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 7.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          highlightColor: tilePrimaryColor.withOpacity(0.1), // 탭 하이라이트 색상 미세하게
          splashColor: tilePrimaryColor.withOpacity(0.08), // 탭 스플래시 색상 미세하게
        ),
        child: ExpansionTile(
          backgroundColor: Colors.white,
          collapsedBackgroundColor: Colors.white,
          iconColor: tilePrimaryColor,
          collapsedIconColor: Colors.grey[600],
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ), // 내부 패딩 조절
          leading: Icon(icon, color: tilePrimaryColor, size: 26), // 아이콘 크기 및 색상
          title: Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            18.0,
            4.0,
            18.0,
            15.0,
          ), // 하단 패딩 증가
          children: [
            SelectableText(
              // <<<=== 내용 복사 가능하도록 SelectableText 사용
              content,
              style: TextStyle(
                fontSize: 15,
                height: 1.65,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.justify, // 양쪽 정렬 (선택 사항)
            ),
          ],
        ),
      ),
    );
  }
}
