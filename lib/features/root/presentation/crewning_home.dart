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
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_selectedIndex]), centerTitle: true),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const StatusScreen(),
          RunningScreen(focusRequests: _runningFocusRequests),
          const CrewScreen(),
          const MyPageScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            label: '크루닝',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_run_outlined),
            label: '러닝',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups_outlined),
            label: '크루',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: '마이페이지',
          ),
        ],
      ),
    );
  }
}
