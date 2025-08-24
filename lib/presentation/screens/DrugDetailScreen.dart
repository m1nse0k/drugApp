// DrugDetailScreen.dart
import 'package:drug/presentation/screens/schedule_input_screen.dart';
import 'package:flutter/material.dart';
import 'package:drug/data/database/drug_database.dart';
import 'package:drug/presentation/widgets/common_bottom_nav.dart';
import 'package:intl/intl.dart';

class DrugDetailScreen extends StatelessWidget {
  final Drug drug;
  final double score;
  final bool isSeniorMode; // <<< 시니어 모드 변수 추가

  const DrugDetailScreen({
    super.key,
    required this.drug,
    required this.score,
    required this.isSeniorMode, // <<< 생성자에 추가
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;

    // =================================================================
    // 시니어 모드에 따른 UI 값 동적 설정
    // =================================================================
    final double appBarTitleSize = isSeniorMode ? 26.0 : 22.0;
    final double addScheduleBtnFontSize = isSeniorMode ? 20.0 : 16.0;
    final double addScheduleBtnIconSize = isSeniorMode ? 24.0 : 20.0;
    final EdgeInsets addScheduleBtnPadding =
        isSeniorMode
            ? const EdgeInsets.symmetric(horizontal: 35, vertical: 18)
            : const EdgeInsets.symmetric(horizontal: 30, vertical: 15);
    final double sectionTitleSize = isSeniorMode ? 24.0 : 19.0;

    // 주의사항 텍스트 조합 (기존 코드 유지)
    String formattedPrecautions = [
      if (drug.atpnWarnQesitm != null && drug.atpnWarnQesitm!.isNotEmpty)
        "복용 전 경고:\n${drug.atpnWarnQesitm}",
      if (drug.atpnQesitm != null && drug.atpnQesitm!.isNotEmpty)
        "일반 주의사항:\n${drug.atpnQesitm}",
      if (drug.intrcQesitm != null && drug.intrcQesitm!.isNotEmpty)
        "상호작용:\n${drug.intrcQesitm}",
      if (drug.seQesitm != null && drug.seQesitm!.isNotEmpty)
        "주요 부작용:\n${drug.seQesitm}",
      if (drug.depositMethodQesitm != null &&
          drug.depositMethodQesitm!.isNotEmpty)
        "보관 방법:\n${drug.depositMethodQesitm}",
    ].join('\n\n');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          '알약 상세 정보',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: appBarTitleSize,
          ),
        ), // <<< 시니어 모드 적용
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              primaryColor.withOpacity(0.85),
              Colors.cyan.shade100.withOpacity(0.85),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SizedBox(
                height:
                    kToolbarHeight + MediaQuery.of(context).padding.top - 50,
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(30),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20.0, 25.0, 20.0, 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Card(
                            elevation: 5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child:
                                (drug.itemImage != null &&
                                        drug.itemImage!.isNotEmpty)
                                    ? Image.network(
                                      drug.itemImage!,
                                      fit: BoxFit.contain,
                                      errorBuilder:
                                          (c, e, s) => _buildErrorImage(),
                                    )
                                    : _buildErrorImage(),
                          ),
                        ),
                        const SizedBox(height: 30),
                        _buildInfoCard(
                          context: context,
                          isSeniorMode: isSeniorMode,
                          children: [
                            // <<< isSeniorMode 전달
                            _buildInfoRow(
                              "제품명",
                              drug.itemName ?? "-",
                              context: context,
                              isSeniorMode: isSeniorMode,
                            ), // <<< isSeniorMode 전달
                            _buildInfoRow(
                              "제조사",
                              drug.entpName ?? "-",
                              context: context,
                              isSeniorMode: isSeniorMode,
                            ), // <<< isSeniorMode 전달
                          ],
                        ),
                        const SizedBox(height: 25),
                        Center(
                          child: ElevatedButton.icon(
                            icon: Icon(
                              Icons.alarm_add,
                              color: Colors.white,
                              size: addScheduleBtnIconSize,
                            ), // <<< 시니어 모드 적용
                            label: Text(
                              '복용 일정 추가',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: addScheduleBtnFontSize,
                              ),
                            ), // <<< 시니어 모드 적용
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              padding: addScheduleBtnPadding, // <<< 시니어 모드 적용
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ScheduleInputScreen(
                                        itemSeq:
                                            int.tryParse(drug.itemSeq) ?? 0,
                                        drugName: drug.itemName ?? '알 수 없는 약',
                                        isSeniorMode:
                                            isSeniorMode, // <<< isSeniorMode 전달
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 25),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 4.0,
                            bottom: 10.0,
                          ),
                          child: Text(
                            "세부 정보",
                            style: Theme.of(
                              context,
                            ).textTheme.titleLarge?.copyWith(
                              color: Colors.grey[750],
                              fontSize: sectionTitleSize,
                            ),
                          ), // <<< 시니어 모드 적용
                        ),
                        _buildExpansionTile(
                          context: context,
                          title: "효능/효과",
                          icon: Icons.medical_services_rounded,
                          content: drug.efcyQesitm ?? "정보 없음",
                          isSeniorMode: isSeniorMode,
                        ), // <<< isSeniorMode 전달
                        _buildExpansionTile(
                          context: context,
                          title: "용법/용량",
                          icon: Icons.library_books_rounded,
                          content: drug.useMethodQesitm ?? "정보 없음",
                          isSeniorMode: isSeniorMode,
                        ), // <<< isSeniorMode 전달
                        _buildExpansionTile(
                          context: context,
                          title: "주의사항 및 보관",
                          icon: Icons.warning_amber_rounded,
                          content:
                              formattedPrecautions.isNotEmpty
                                  ? formattedPrecautions
                                  : "관련 정보가 없습니다.",
                          isSeniorMode: isSeniorMode,
                        ), // <<< isSeniorMode 전달
                        const SizedBox(height: 20),
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
        currentIndex: -1,
        onTap: (index) {
          if (index == 0)
            Navigator.pushNamedAndRemoveUntil(
              context,
              '/',
              (route) => route.isFirst,
            );
          else if (index == 1)
            Navigator.pushNamed(context, '/management');
        },
      ),
    );
  }

  // 이미지 에러 시 표시할 위젯
  Widget _buildErrorImage() => Container(
    height: 220,
    color: Colors.grey[200],
    child: Center(
      child: Icon(
        Icons.medication_liquid_outlined,
        color: Colors.grey[400],
        size: 70,
      ),
    ),
  );

  // 정보 행 위젯 (isSeniorMode 추가)
  Widget _buildInfoRow(
    String label,
    String value, {
    required BuildContext context,
    required bool isSeniorMode,
  }) {
    final double fontSize = isSeniorMode ? 19.5 : 15.5; // <<< 시니어 모드 적용
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Text(
              value,
              style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  // 정보 카드 위젯 (isSeniorMode 추가)
  Widget _buildInfoCard({
    required List<Widget> children,
    required BuildContext context,
    required bool isSeniorMode,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }

  // ExpansionTile 위젯 (isSeniorMode 추가)
  Widget _buildExpansionTile({
    required BuildContext context,
    required String title,
    required IconData icon,
    required String content,
    required bool isSeniorMode,
  }) {
    final Color tilePrimaryColor = Theme.of(context).primaryColor;
    final double titleSize = isSeniorMode ? 21.0 : 17.0; // <<< 시니어 모드 적용
    final double contentSize = isSeniorMode ? 19.0 : 15.0; // <<< 시니어 모드 적용
    final double iconSize = isSeniorMode ? 30.0 : 26.0; // <<< 시니어 모드 적용

    return Card(
      elevation: 1.5,
      margin: const EdgeInsets.symmetric(vertical: 7.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
        side: BorderSide(color: Colors.grey[200]!, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          iconColor: tilePrimaryColor,
          collapsedIconColor: Colors.grey[600],
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          leading: Icon(
            icon,
            color: tilePrimaryColor,
            size: iconSize,
          ), // <<< 시니어 모드 적용
          title: Text(
            title,
            style: TextStyle(
              fontSize: titleSize,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ), // <<< 시니어 모드 적용
          childrenPadding: const EdgeInsets.fromLTRB(18.0, 4.0, 18.0, 15.0),
          children: [
            SelectableText(
              content,
              style: TextStyle(
                fontSize: contentSize,
                height: 1.7,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.justify,
            ), // <<< 시니어 모드 적용
          ],
        ),
      ),
    );
  }
}
