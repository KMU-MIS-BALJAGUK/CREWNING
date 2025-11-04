import 'package:flutter/material.dart';

import 'package:crewning/features/crew/presentation/crew_screen.dart';
import 'package:crewning/features/profile/presentation/my_page_screen.dart';
import 'package:crewning/features/running/presentation/running_screen.dart';
import 'package:crewning/features/status/presentation/status_screen.dart';

class CrewningHome extends StatefulWidget {
  const CrewningHome({super.key});

  @override
  State<CrewningHome> createState() => _CrewningHomeState();
}

class _CrewningHomeState extends State<CrewningHome> {
  int _selectedIndex = 0;
  final ValueNotifier<int> _runningFocusRequests = ValueNotifier<int>(0);

  static const _titles = ['크루닝', '러닝', '크루', '마이페이지'];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    if (index == 1) {
      _runningFocusRequests.value += 1;
    }
  }

  @override
  void dispose() {
    _runningFocusRequests.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shadowColor = Theme.of(context).colorScheme.shadow.withOpacity(0.08);
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: Colors.black12),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const StatusScreen(),
          RunningScreen(focusRequests: _runningFocusRequests),
          const CrewScreen(),
          const MyPageScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: shadowColor,
              blurRadius: 14,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
            hoverColor: Colors.transparent,
          ),
          child: BottomNavigationBar(
            enableFeedback: false,
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.white,
            selectedItemColor: const Color(0xFF2AA8FF),
            unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
            selectedIconTheme: const IconThemeData(color: Color(0xFF2AA8FF)),
            showUnselectedLabels: true,
            items: [
              _NavItem(icon: Icons.map_outlined, label: '크루닝'),
              _NavItem(icon: Icons.directions_run_outlined, label: '러닝'),
              _NavItem(icon: Icons.groups_outlined, label: '크루'),
              _NavItem(icon: Icons.person_outline, label: '마이페이지'),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends BottomNavigationBarItem {
  _NavItem({required IconData icon, required String label})
      : super(
          icon: Icon(icon),
          activeIcon: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0x332AA8FF),
              borderRadius: const BorderRadius.all(Radius.circular(12)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Icon(icon, color: const Color(0xFF2AA8FF)),
            ),
          ),
          label: label,
        );
}
