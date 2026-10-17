import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/ui/components.dart';
import '../home/home_chrome.dart';
import '../privacy/privacy_screen.dart';
import '../records/records_screen.dart';

/// Matches `mobile/pubspec.yaml` `version:`.
const appVersionLabel = '0.1.0+1';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.homeLight,
      builder: (context, _) {
        final colors = HomeColors.of(context);
        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            backgroundColor: colors.bg,
            foregroundColor: colors.text,
            elevation: 0,
            title: Text('Settings', style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w800, color: colors.text)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              SettingSwitch(
                emoji: '💡',
                label: 'Light theme',
                hint: 'Same switch as the lamp on the home screen',
                value: AppSettings.homeLight.value,
                onChanged: AppSettings.setHomeLight,
                color: colors.blue,
              ),
              SettingsPanel(showPreferences: true, color: colors.blue),
              const SizedBox(height: 8),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(kTouchTarget, kTouchTarget), foregroundColor: colors.text),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrivacyScreen())),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Privacy Policy', style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w800, color: colors.text)),
                ),
              ),
              Text('Version $appVersionLabel', style: TextStyle(fontFamily: Fonts.body, fontSize: 13, fontWeight: FontWeight.w700, color: colors.muted)),
            ],
          ),
        );
      },
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.homeLight,
      builder: (context, _) {
        final colors = HomeColors.of(context);
        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            backgroundColor: colors.bg,
            foregroundColor: colors.text,
            elevation: 0,
            title: Text('Profile', style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w800, color: colors.text)),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const SettingsPanel(showProfile: true, showPreferences: false),
              const SizedBox(height: 12),
              TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(kTouchTarget, kTouchTarget), foregroundColor: colors.text),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsScreen())),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('My records', style: TextStyle(fontFamily: Fonts.body, fontSize: 15, fontWeight: FontWeight.w800, color: colors.text)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
