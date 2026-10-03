import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../core/room/room_manager.dart';
import '../widgets/mp_ui.dart';
import 'mp_lobby_screen.dart';

class MpJoinRoomScreen extends StatefulWidget {
  const MpJoinRoomScreen({super.key});
  @override
  State<MpJoinRoomScreen> createState() => _MpJoinRoomScreenState();
}

class _MpJoinRoomScreenState extends State<MpJoinRoomScreen> {
  static const _codeLength = 6;
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    if (_ctrl.text.trim().isEmpty || _busy) return;
    final rm = context.read<RoomManager>();
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    final err = await rm.join(_ctrl.text);
    if (!mounted) return;
    if (err != null) {
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    nav.pushReplacement(MaterialPageRoute(builder: (_) => const MpLobbyScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final code = _ctrl.text.toUpperCase();
    return Theme(
      data: buildMpTheme(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Join Room', style: TextStyle(fontWeight: FontWeight.w800))),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const Icon(Icons.vpn_key_rounded, size: 48, color: AppColors.accent),
              const SizedBox(height: 12),
              const Text('Enter room code',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              const Text('Ask the host for the code on their screen',
                  textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
              const SizedBox(height: 28),
              // Visible code boxes; a hidden TextField underneath does the typing.
              GestureDetector(
                onTap: () => _focus.requestFocus(),
                child: Stack(children: [
                  Opacity(
                    opacity: 0,
                    child: TextField(
                      controller: _ctrl,
                      focusNode: _focus,
                      autofocus: true,
                      maxLength: _codeLength,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]'))],
                      onSubmitted: (_) => _join(),
                    ),
                  ),
                  Row(children: [
                    for (var i = 0; i < _codeLength; i++) ...[
                      Expanded(child: _CodeBox(char: i < code.length ? code[i] : '', active: i == code.length)),
                      if (i != _codeLength - 1) const SizedBox(width: 8),
                    ],
                  ]),
                ]),
              ),
              const Spacer(),
              BusyButton(label: 'JOIN ROOM', busy: _busy, onPressed: code.isEmpty ? null : _join),
            ]),
          ),
        ),
      ),
    );
  }
}

class _CodeBox extends StatelessWidget {
  final String char;
  final bool active;
  const _CodeBox({required this.char, required this.active});
  @override
  Widget build(BuildContext context) => AspectRatio(
        aspectRatio: 0.8,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: active ? AppColors.accent : AppColors.surfaceHigh, width: 2),
          ),
          child: Text(char, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        ),
      );
}
