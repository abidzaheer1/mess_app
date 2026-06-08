import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_models.dart';
import '../../repositories/mess_repository.dart';
import '../../widgets/common.dart';
import '../../theme/app_theme.dart';
import '../../widgets/voice_note_player.dart';
import '../../widgets/voice_note_recorder.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.repo,
    required this.messId,
    required this.profile,
    this.eventId,
    this.title,
  });

  final MessRepository repo;
  final String messId;
  final UserProfile profile;
  final String? eventId;
  final String? title;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _markRead());
  }

  Future<void> _markRead() async {
    if (widget.eventId != null) return;
    try {
      await widget.repo.markMessChatRead(widget.messId, widget.profile.uid);
    } catch (_) {}
  }

  @override
  void dispose() {
    _markRead();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await widget.repo.sendChatMessage(
        messId: widget.messId,
        senderUid: widget.profile.uid,
        senderName: widget.profile.displayName,
        text: text,
        eventId: widget.eventId,
      );
      _input.clear();
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendVoice(VoiceRecording rec) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await widget.repo.sendChatMessage(
        messId: widget.messId,
        senderUid: widget.profile.uid,
        senderName: widget.profile.displayName,
        voiceBytes: rec.bytes,
        voiceContentType: rec.contentType,
        voiceDurationMs: rec.durationMs,
        eventId: widget.eventId,
      );
    } catch (e) {
      if (mounted) showSnackError(context, e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.title ?? 'Mess chat';
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(title),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(20),
          child: Padding(
            padding: EdgeInsets.only(bottom: 6),
            child: Text(
              '60-day message history',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<Member?>(
                stream: widget.repo.memberStream(widget.messId, widget.profile.uid),
                builder: (context, memberSnap) {
                  if (memberSnap.hasData && memberSnap.data == null) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'You need to be an approved mess member to use chat.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    );
                  }
                  return StreamBuilder<List<ChatMessage>>(
                stream: widget.repo.chatStream(widget.messId),
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text('Could not load chat: ${snap.error}'),
                      ),
                    );
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snap.data!.where((m) {
                    if (widget.eventId == null) {
                      return m.eventId == null || m.eventId!.isEmpty;
                    }
                    return m.eventId == widget.eventId;
                  }).toList();

                  if (messages.isEmpty) {
                    return Center(
                      child: Text(
                        widget.eventId == null
                            ? 'Say hi! Messages older than 60 days are removed automatically.'
                            : 'No messages yet for this event.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.onSurfaceVariant,
                            ),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scroll,
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    itemCount: messages.length,
                    itemBuilder: (context, i) {
                      final msg = messages[i];
                      return _ChatBubble(
                        message: msg,
                        isMe: msg.senderUid == widget.profile.uid,
                      );
                    },
                  );
                },
              );
                },
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _input,
                builder: (context, value, _) {
                  final hasText = value.text.trim().isNotEmpty;
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          enabled: !_sending,
                          minLines: 1,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Message',
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                          onSubmitted: (_) => _sendText(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (hasText)
                        IconButton.filled(
                          tooltip: 'Send',
                          onPressed: _sending ? null : _sendText,
                          icon: const Icon(Icons.send_rounded),
                        )
                      else
                        VoiceNoteRecorder(busy: _sending, onRecorded: _sendVoice),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat.jm();
    final time = timeFmt.format(DateTime.fromMillisecondsSinceEpoch(message.createdAt));

    if (message.isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.warningSurface,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              message.text ?? '',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      );
    }

    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bg = isMe ? AppColors.primaryDark : Colors.white;
    final fg = isMe ? Colors.white : AppColors.onSurface;
    final tint = isMe ? Colors.white : AppColors.primaryDark;

    return Align(
      alignment: align,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: Radius.circular(isMe ? 4 : 16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
          ),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Text(
                message.senderName,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            const SizedBox(height: 2),
            if (message.isVoice)
              VoiceNotePlayer(
                audioBase64: message.audioBase64!,
                contentType: message.audioContentType ?? 'audio/wav',
                durationMs: message.audioDurationMs,
                tint: tint,
              )
            else
              Text(
                message.text ?? '',
                style: TextStyle(color: fg, fontSize: 15),
              ),
            const SizedBox(height: 4),
            Text(
              time,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isMe ? Colors.white70 : AppColors.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
