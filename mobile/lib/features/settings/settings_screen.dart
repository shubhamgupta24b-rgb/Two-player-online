import 'package:flutter/material.dart';

import '../../core/settings/app_settings.dart';
import '../../core/ui/app_flavor.dart';
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

class HelpRulesScreen extends StatelessWidget {
  const HelpRulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.homeLight,
      builder: (context, _) {
        final colors = HomeColors.of(context);
        final body = TextStyle(fontFamily: Fonts.body, fontSize: 15, height: 1.4, fontWeight: FontWeight.w700, color: colors.text);
        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            backgroundColor: colors.bg,
            foregroundColor: colors.text,
            elevation: 0,
            title: Text('Help & Rules', style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w800, color: colors.text)),
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
            Text('During a game, tap ? or How to play. That opens the rules for the game you are in.', style: body),
            const SizedBox(height: 12),
            Text('Opening the rules does not reset the timer, score, turn, or connection.', style: body),
            const SizedBox(height: 12),
            Text('Online starts a room, joins a code, or finds an open room. Same Device plays on this phone.', style: body),
          ]),
        );
      },
    );
  }
}

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppSettings.homeLight,
      builder: (context, _) {
        final colors = HomeColors.of(context);
        final body = TextStyle(fontFamily: Fonts.body, fontSize: 15, height: 1.4, fontWeight: FontWeight.w700, color: colors.text);
        return Scaffold(
          backgroundColor: colors.bg,
          appBar: AppBar(
            backgroundColor: colors.bg,
            foregroundColor: colors.text,
            elevation: 0,
            title: Text('About', style: TextStyle(fontFamily: Fonts.body, fontWeight: FontWeight.w800, color: colors.text)),
          ),
          body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
            Text(appName, style: TextStyle(fontFamily: Fonts.display, fontSize: 28, color: colors.text)),
            const SizedBox(height: 8),
            Text('Version $appVersionLabel', style: body),
            const SizedBox(height: 12),
            Text('A name on this phone is a guest profile. It is not an online account.', style: body),
            const SizedBox(height: 12),
            Text('Wins on the online leaderboard come from finished matches on the server. Rankings saved on this phone are labeled as this phone.', style: body),
          ]),
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
