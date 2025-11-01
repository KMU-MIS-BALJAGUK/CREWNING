import 'package:flutter/material.dart';

import 'package:crewning/features/crew/presentation/crew_screen.dart';
import 'package:crewning/features/home/presentation/home_screen.dart';
import 'package:crewning/features/profile/presentation/my_page_screen.dart';

class CrewningHome extends StatefulWidget {
  const CrewningHome({super.key});

  @override
  State<CrewningHome> createState() => _CrewningHomeState();
}

class _CrewningHomeState extends State<CrewningHome> {
  int _selectedIndex = 0;

  static const _titles = ['홈', '크루', '마이페이지'];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HomeScreen(),
          CrewScreen(),
          MyPageScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            label: '홈',
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
