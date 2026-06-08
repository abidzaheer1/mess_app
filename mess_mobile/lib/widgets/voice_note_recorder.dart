import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:record/record.dart';

import '../theme/app_theme.dart';
import 'web_blob_reader_stub.dart'
    if (dart.library.js_interop) 'web_blob_reader.dart';

class VoiceRecording {
  const VoiceRecording({
    required this.bytes,
    required this.contentType,
    required this.durationMs,
  });

  final Uint8List bytes;
  final String contentType;
  final int durationMs;
}

/// Mic button — press and hold to record (up to 30s), release to send.
class VoiceNoteRecorder extends StatefulWidget {
  const VoiceNoteRecorder({
    super.key,
    required this.onRecorded,
    this.busy = false,
  });

  final ValueChanged<VoiceRecording> onRecorded;
  final bool busy;

  @override
  State<VoiceNoteRecorder> createState() => _VoiceNoteRecorderState();
}

class _VoiceNoteRecorderState extends State<VoiceNoteRecorder> {
  static const Duration _maxDuration = Duration(seconds: 30);
  static const Duration _minDuration = Duration(milliseconds: 400);

  AudioRecorder? _recorder;
  bool _recording = false;
  bool _starting = false;
  bool _cancelled = false;
  int? _activePointer;
  DateTime? _startedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;
  StreamSubscription<Uint8List>? _audioSub;
  final List<int> _audioChunks = [];

  @override
  void dispose() {
    _ticker?.cancel();
    _audioSub?.cancel();
    final recorder = _recorder;
    if (recorder != null) {
      unawaited(recorder.dispose());
    }
    super.dispose();
  }

  AudioRecorder _ensureRecorder() => _recorder ??= AudioRecorder();

  Future<void> _start() async {
    if (widget.busy || _recording || _starting) return;
    _starting = true;
    _cancelled = false;
    try {
      final recorder = _ensureRecorder();
      if (!await recorder.hasPermission()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Microphone permission required. Allow mic access in browser or device settings.',
              ),
            ),
          );
        }
        return;
      }

      _audioChunks.clear();

      if (kIsWeb) {
        await recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.wav,
            sampleRate: 16000,
            numChannels: 1,
            bitRate: 128000,
          ),
          path: '',
        );
      } else {
        const config = RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          bitRate: 64000,
          sampleRate: 16000,
          numChannels: 1,
        );
        final stream = await recorder.startStream(config);
        _audioSub = stream.listen(_audioChunks.addAll);
      }

      if (!mounted) return;
      setState(() {
        _recording = true;
        _startedAt = DateTime.now();
        _elapsed = Duration.zero;
      });

      _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) async {
        if (!mounted || _startedAt == null) return;
        setState(() => _elapsed = DateTime.now().difference(_startedAt!));
        if (_elapsed >= _maxDuration) {
          await _stop(send: true);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start recording: $e')),
        );
      }
      setState(() => _recording = false);
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop({required bool send}) async {
    if (!_recording && !_starting) return;
    _ticker?.cancel();
    _ticker = null;

    final duration = _elapsed;
    final cancelled = _cancelled;
    final recorder = _recorder;

    Uint8List? wav;
    try {
      if (recorder == null) return;

      if (kIsWeb) {
        final path = await recorder.stop();
        if (path != null && path.isNotEmpty) {
          wav = await readWebBlobUrl(path);
        }
      } else {
        await recorder.stop();
        await _audioSub?.cancel();
        _audioSub = null;
        if (!cancelled && send && duration >= _minDuration && _audioChunks.isNotEmpty) {
          wav = _pcm16ToWav(
            Uint8List.fromList(_audioChunks),
            sampleRate: 16000,
            numChannels: 1,
          );
        }
        _audioChunks.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording failed: $e')),
        );
      }
    }

    if (!mounted) return;
    setState(() {
      _recording = false;
      _starting = false;
      _activePointer = null;
    });

    if (!send || cancelled || duration < _minDuration) return;
    if (wav == null || wav.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio captured. Hold longer and try again.')),
        );
      }
      return;
    }

    widget.onRecorded(VoiceRecording(
      bytes: wav,
      contentType: 'audio/wav',
      durationMs: duration.inMilliseconds,
    ));
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.busy || _activePointer != null) return;
    _activePointer = event.pointer;
    unawaited(_start());
  }

  void _onPointerUp(PointerUpEvent event) {
    if (_activePointer != event.pointer) return;
    unawaited(_stop(send: true));
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (_activePointer != event.pointer) return;
    _cancelled = true;
    unawaited(_stop(send: false));
  }

  @override
  Widget build(BuildContext context) {
    final color = _recording ? Colors.red : AppColors.primaryDark;
    final secs = _elapsed.inSeconds;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: widget.busy ? null : _onPointerDown,
      onPointerUp: widget.busy ? null : _onPointerUp,
      onPointerCancel: widget.busy ? null : _onPointerCancel,
      child: Tooltip(
        message: _recording ? 'Release to send' : 'Hold to record voice note',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: _recording ? 0.18 : 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _recording ? Icons.fiber_manual_record_rounded : Icons.mic_rounded,
                color: color,
                size: 22,
              ),
              if (_recording) ...[
                const SizedBox(width: 6),
                Text('${secs}s', style: TextStyle(color: color, fontWeight: FontWeight.w700)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Uint8List _pcm16ToWav(
  Uint8List pcm, {
  required int sampleRate,
  required int numChannels,
}) {
  const bitsPerSample = 16;
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final dataLength = pcm.length;
  final fileLength = 36 + dataLength;

  final header = BytesBuilder();
  void writeStr(String s) => header.add(s.codeUnits);
  void writeInt32LE(int v) {
    final b = ByteData(4)..setInt32(0, v, Endian.little);
    header.add(b.buffer.asUint8List());
  }

  void writeInt16LE(int v) {
    final b = ByteData(2)..setInt16(0, v, Endian.little);
    header.add(b.buffer.asUint8List());
  }

  writeStr('RIFF');
  writeInt32LE(fileLength);
  writeStr('WAVE');
  writeStr('fmt ');
  writeInt32LE(16);
  writeInt16LE(1);
  writeInt16LE(numChannels);
  writeInt32LE(sampleRate);
  writeInt32LE(byteRate);
  writeInt16LE(blockAlign);
  writeInt16LE(bitsPerSample);
  writeStr('data');
  writeInt32LE(dataLength);
  header.add(pcm);

  return header.toBytes();
}
