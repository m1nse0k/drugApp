import 'package:flutter/material.dart';

class CommonBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CommonBottomNavBar({
    super.key,
    this.currentIndex = 0, // 기본값은 0
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final Color unselectedColor = Colors.grey.shade500;

    // currentIndex가 -1일 경우 처리
    int effectiveCurrentIndex = currentIndex;
    Color effectiveSelectedItemColor = primaryColor;

    if (currentIndex < 0 || currentIndex >= 3) {
      // 유효하지 않은 인덱스일 경우 (3은 items.length)
      effectiveCurrentIndex = 0; // 내부적으로는 첫 번째 탭을 가리키도록 함 (오류 방지)
      effectiveSelectedItemColor = unselectedColor; // 시각적으로는 선택 안 된 것처럼 보이게
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: BottomNavigationBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // --- !!! 수정된 currentIndex 및 selectedItemColor 사용 !!! ---
        currentIndex: effectiveCurrentIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: effectiveSelectedItemColor, // <<<=== 수정됨
        unselectedItemColor: unselectedColor,
        // ----------------------------------------------------
        iconSize: 28,
        selectedFontSize: 13,
        unselectedFontSize: 12,
        items: <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(
              currentIndex == 0 ? Icons.home_filled : Icons.home_outlined,
            ), // 선택 시 채워진 아이콘
            label: '홈',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              currentIndex == 1
                  ? Icons.inventory_2
                  : Icons.inventory_2_outlined,
            ), // 선택 시 채워진 아이콘
            label: '보관함',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              currentIndex == 2 ? Icons.settings : Icons.settings_outlined,
            ), // 선택 시 채워진 아이콘
            label: '설정',
          ),
        ],
      ),
    );
  }
}
