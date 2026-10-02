import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_voice_recorder_ui/flutter_voice_recorder_ui.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Voice Recorder Demo',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFECE5DD),
      ),
      home: const ChatDemoPage(),
    );
  }
}

class ChatDemoPage extends StatefulWidget {
  const ChatDemoPage({super.key});

  @override
  State<ChatDemoPage> createState() => _ChatDemoPageState();
}

class _ChatDemoPageState extends State<ChatDemoPage> {
  final _messages = <_ChatMessage>[
    const _ChatMessage(
      text: 'Hold the mic to record. Slide left to cancel.',
      isMe: false,
      time: '10:02',
    ),
    const _ChatMessage(
      text: 'Slide up on the mic to lock — then pause or send.',
      isMe: false,
      time: '10:03',
    ),
  ];

  int _totalBytes = 0;
  String? _status;
  bool _isRecording = false;
  bool _isLocked = false;

  void _onComplete(VoiceRecorderResult result) {
    result.bytesStream.listen(
      (Uint8List chunk) {
        if (!mounted) return;
        setState(() => _totalBytes += chunk.length);
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _messages.add(
            _ChatMessage(
              text:
                  'Voice note (${result.durationMs ~/ 1000}s) — $_totalBytes bytes PCM',
              isMe: true,
              time: _now(),
            ),
          );
          _status = null;
          _totalBytes = 0;
        });
      },
    );
    setState(() => _status = 'Sending…');
  }

  String _now() {
    final n = DateTime.now();
    return '${n.hour}:${n.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice chat'),
        backgroundColor: const Color(0xFF075E54),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              itemCount: _messages.length,
              itemBuilder: (context, i) => _Bubble(message: _messages[i]),
            ),
          ),
          if (_status != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                _status!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          _ChatInputBar(
            isRecording: _isRecording,
            isLocked: _isLocked,
            onRecordingStateChanged: (v) => setState(() => _isRecording = v),
            onRecordingLockedChanged: (v) => setState(() => _isLocked = v),
            onRecordingComplete: _onComplete,
            onRecordingCancelled: () => setState(() => _status = 'Cancelled'),
            onPermissionDenied: () =>
                setState(() => _status = 'Mic permission denied'),
          ),
        ],
      ),
    );
  }
}

class _ChatInputBar extends StatelessWidget {
  const _ChatInputBar({
    required this.isRecording,
    required this.isLocked,
    required this.onRecordingStateChanged,
    required this.onRecordingLockedChanged,
    required this.onRecordingComplete,
    required this.onRecordingCancelled,
    required this.onPermissionDenied,
  });

  final bool isRecording;
  final bool isLocked;
  final ValueChanged<bool> onRecordingStateChanged;
  final ValueChanged<bool> onRecordingLockedChanged;
  final void Function(VoiceRecorderResult) onRecordingComplete;
  final VoidCallback onRecordingCancelled;
  final VoidCallback onPermissionDenied;

  static const _lockRail = 96.0;
  static const _lockedH = 108.0;

  @override
  Widget build(BuildContext context) {
    final extraTop = isLocked
        ? _lockedH - 48.0
        : (isRecording ? _lockRail : 0.0);

    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8 + extraTop,
        bottom: 8 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.bottomRight,
        clipBehavior: Clip.none,
        children: [
          IgnorePointer(
            ignoring: isRecording || isLocked,
            child: Opacity(
              opacity: isRecording || isLocked ? 0 : 1,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(
                      Icons.emoji_emotions_outlined,
                      color: Color(0xFF8696A0),
                    ),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 40, minHeight: 48),
                  ),
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 48),
                      margin: const EdgeInsets.only(right: 58),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Message',
                        style: TextStyle(
                          color: Color(0xFF8696A0),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: isRecording || isLocked ? 0 : null,
            right: 0,
            bottom: 0,
            width: isRecording || isLocked ? null : 58,
            child:  VoiceRecorderButton(
              size: 45,
              micColor: Colors.white,
              pillColor: Colors.white,
              waveformColor: Colors.green,
              timerColor: Colors.black,
              recordingIndicatorColor: Colors.red,
              micBackgroundColor: Colors.black,
              pillMicGap: 12,
              cancelSlideThreshold: 96,
              lockSlideThreshold: 48,
              enableLock: true,
              hapticFeedback: true,
              config: const VoiceRecorderConfig(
                sampleRate: 24000,        // Match your API's expected rate
                numChannels: 1,
                // encoder: AudioEncoder.pcm16bits,
              ),
              onRecordingStateChanged: onRecordingStateChanged,
              onRecordingLockedChanged: onRecordingLockedChanged,
              onRecordingComplete: onRecordingComplete,
              onRecordingCancelled: onRecordingCancelled,
              onPermissionDenied: onPermissionDenied,
            )


            /*8VoiceRecorderButton(
              size: 56,
              pillMicGap: 12,
              onRecordingStateChanged: onRecordingStateChanged,
              onRecordingLockedChanged: onRecordingLockedChanged,
              onRecordingComplete: onRecordingComplete,
              onRecordingCancelled: onRecordingCancelled,
              onPermissionDenied: onPermissionDenied,
            ),**/
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
  });

  final String text;
  final bool isMe;
  final String time;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final align = message.isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.isMe ? const Color(0xFFD9FDD3) : Colors.white;

    return Align(
      alignment: align,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(message.text, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 4),
            Text(
              message.time,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
