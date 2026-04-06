import 'package:flutter/material.dart';
import 'package:flutter_project/pages/messenger/messenger_page.dart';
import 'package:flutter_project/pages/profile/profile_page.dart';
import 'package:flutter_project/pages/teacher/teachers_page.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_project/design/colors.dart';
import 'package:flutter_project/design/icons.dart';
import 'package:flutter_project/pages/schedule/schedule_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const SchedulePage(),
    const MessengerPage(),
    const TeachersPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: [
          _buildNavItem(AppIcons.schedule, 0),
          _buildNavItem(AppIcons.messenger, 1),
          _buildNavItem(AppIcons.teacher, 2),
          _buildNavItem(AppIcons.profile, 3),
        ],
      ),
    );
  }

  BottomNavigationBarItem _buildNavItem(String path, int index) {
    final isSelected = _selectedIndex == index;
    return BottomNavigationBarItem(
      icon: SvgPicture.asset(
        path,
        colorFilter: ColorFilter.mode(
          isSelected ? currentIcon : textColor,
          BlendMode.srcIn,
        ),
        height: 28,
        width: 28,
      ),
      label: '',
    );
  }
}