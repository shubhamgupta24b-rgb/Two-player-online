import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/room/room_manager.dart';
import '../../core/ui/app_ui.dart';
import '../guess_person/widgets/gp_theme.dart' show GpButton, GpColors;
import '../lobby/lobby_screen.dart';

const _codeLength = 6;

class JoinRoomScreen extends StatefulWidget {
  const JoinRoomScreen({super.key});
  @override
  State<JoinRoomScreen> createState() => _JoinRoomScreenState();
}

class _JoinRoomScreenState extends State<JoinRoomScreen> {
  final ctrl = TextEditingController();
  final focus = FocusNode();
  bool busy = false;

  @override
  void initState() {
    super.initState();
    focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    ctrl.dispose();
    focus.dispose();
    super.dispose();
  }

  bool get _complete => ctrl.text.length == _codeLength;

  Future<void> _join() async {
    if (!_complete || busy) return;
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => busy = true);
    final err = await rm.join(ctrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => busy = false);
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    nav.pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LobbyScreen()), (r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 10),
              child: Row(children: [
                IconButton(tooltip: 'Back', onPressed: () => Navigator.maybePop(context), icon: const Icon(Icons.arrow_back_rounded, color: Colors.white70)),
                const Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('JOIN A ROOM', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 1)),
                    Text("Play together on your friends' phones", style: TextStyle(color: AppColors.muted, fontWeight: FontWeight.w600, fontSize: 12.5)),
                  ]),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Center(child: Text('🔑', style: TextStyle(fontSize: 56))),
                  const SizedBox(height: 10),
                  const Text('ENTER ROOM CODE', textAlign: TextAlign.center, style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 14)),
                  const SizedBox(height: 4),
                  const Text('Ask the host for the 6-letter code on their screen', textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  _CodeBoxes(ctrl: ctrl, focus: focus, onChanged: () => setState(() {}), onSubmit: _join),
                  const SizedBox(height: 24),
                  GpButton(busy ? 'JOINING…' : 'JOIN ROOM', icon: Icons.login_rounded, color: GpColors.accent, onPressed: _complete && !busy ? _join : null),
                  const SizedBox(height: 28),
                  const _Tip(icon: Icons.wifi_rounded, text: 'Everyone needs the same server (shown at the bottom of the home screen).'),
                  const SizedBox(height: 10),
                  const _Tip(icon: Icons.swap_horiz_rounded, text: 'The host picks the games: you stay in the room between rounds.'),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Six letter boxes; typing goes into an invisible text field laid over them.
class _CodeBoxes extends StatelessWidget {
  final TextEditingController ctrl;
  final FocusNode focus;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;
  const _CodeBoxes({required this.ctrl, required this.focus, required this.onChanged, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final text = ctrl.text;
    return LayoutBuilder(builder: (context, c) {
      final box = ((c.maxWidth - 5 * 8) / _codeLength).clamp(36.0, 58.0);
      return SizedBox(
        height: box * 1.2,
        child: Stack(children: [
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              for (var i = 0; i < _codeLength; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: box,
                  height: box * 1.2,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i < text.length ? const Color(0x33FFC93C) : AppColors.glass,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: i == text.length && focus.hasFocus ? AppColors.gold : (i < text.length ? AppColors.gold.withValues(alpha: 0.6) : AppColors.stroke),
                      width: 2,
                    ),
                  ),
                  child: Text(i < text.length ? text[i] : '', style: TextStyle(color: Colors.white, fontSize: box * 0.55, fontWeight: FontWeight.w900)),
                ),
              ],
            ]),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: ctrl,
                focusNode: focus,
                autofocus: true,
                maxLength: _codeLength,
                showCursor: false,
                enableInteractiveSelection: false,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')),
                  TextInputFormatter.withFunction((_, v) => v.copyWith(text: v.text.toUpperCase())),
                ],
                decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                onChanged: (_) => onChanged(),
                onSubmitted: (_) => onSubmit(),
              ),
            ),
          ),
        ]),
      );
    });
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Tip({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.glass, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.stroke)),
        child: Row(children: [
          Icon(icon, color: AppColors.muted, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: AppColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600))),
        ]),
      );
}
