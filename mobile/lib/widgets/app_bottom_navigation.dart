import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class AppBottomNavigation extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const AppBottomNavigation({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onChanged,
      indicatorColor: const Color(0xFFDDEBFF),
      backgroundColor: Colors.white,
      destinations: const [
        NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.favorite_rounded), label: 'Favorites'),
        NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
      ],
      labelTextStyle: WidgetStateProperty.all(const TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w800, color: ClayColors.text)),
    );
  }
}
