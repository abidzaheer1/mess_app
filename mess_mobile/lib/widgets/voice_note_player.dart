import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class VoiceNotePlayer extends StatefulWidget {
  const VoiceNotePlayer({
    super.key,
    required this.audioBase64,
    required this.contentType,
    this.durationMs,
    this.tint,
  });

  final String audioBase64;
  final String contentType;
  final int? durationMs;
  final Color? tint;

  @override
  State<VoiceNotePlayer> createState() => _VoiceNotePlayerState();
}

class _VoiceNotePlayerState extends State<VoiceNotePlayer> {
  final AudioPlayer _player = AudioPlayer();
  Duration? _total;
  Duration _position = Duration.zero;
  bool _playing = false;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlayerState>? _stateSub;
  StreamSubscription<void>? _completeSub;

  @override
  void initState() {
    super.initState();
    if (widget.durationMs != null) {
      _total = Duration(milliseconds: widget.durationMs!);
    }
    _posSub = _player.onPositionChanged.listen((d) {
      if (!mounted) return;
      setState(() => _position = d);
    });
    _stateSub = _player.onPlayerStateChanged.listen((s) {
      if (!mounted) return;
      setState(() => _playing = s == PlayerState.playing);
    });
    _completeSub = _player.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _playing = false;
        _position = Duration.zero;
      });
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _completeSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_playing) {
      await _player.pause();
      return;
    }
    try {
      final bytes = base64Decode(widget.audioBase64);
      await _player.play(BytesSource(Uint8List.fromList(bytes), mimeType: widget.contentType));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not play voice note: $e')),
      );
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return '${m.toString().padLeft(1, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.tint ?? AppColors.primaryDark;
    final progress = (_total == null || _total!.inMilliseconds == 0)
        ? 0.0
        : (_position.inMilliseconds / _total!.inMilliseconds).clamp(0.0, 1.0);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          customBorder: const CircleBorder(),
          onTap: _toggle,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: tint, shape: BoxShape.circle),
            child: Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: Colors.white, size: 22),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 120,
          child: LinearProgressIndicator(
            value: progress == 0 ? null : progress,
            color: tint,
            backgroundColor: tint.withValues(alpha: 0.18),
            minHeight: 4,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _total == null ? _fmt(_position) : _fmt(_total! - _position),
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()], fontSize: 12),
        ),
      ],
    );
  }
}
