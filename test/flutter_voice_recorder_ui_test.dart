import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_voice_recorder_ui/flutter_voice_recorder_ui.dart';

void main() {
  group('VoiceRecorderButton', () {
    testWidgets('renders idle mic icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceRecorderButton(onRecordingComplete: (_) {}),
          ),
        ),
      );
      expect(find.byIcon(Icons.mic_none), findsOneWidget);
    });

    testWidgets('renders custom idle mic icon', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceRecorderButton(
              onRecordingComplete: (_) {},
              idleMicIcon: Icons.mic_external_on,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.mic_external_on), findsOneWidget);
      expect(find.byIcon(Icons.mic_none), findsNothing);
    });

    testWidgets('respects custom idleMicBackgroundColor', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceRecorderButton(
              onRecordingComplete: (_) {},
              micBackgroundColor: Colors.blue,
            ),
          ),
        ),
      );
      final container = tester.widget<Container>(
        find.ancestor(
          of: find.byIcon(Icons.mic_none),
          matching: find.byType(Container),
        ),
      );
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.blue);
    });

    testWidgets('respects custom size', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VoiceRecorderButton(
              onRecordingComplete: (_) {},
              size: 80,
            ),
          ),
        ),
      );
      final sizedBox = tester.widget<SizedBox>(find.byType(SizedBox).first);
      expect(sizedBox.height, 80);
    });
  });

  group('WaveformPainter', () {
    test('shouldRepaint reacts to amplitude changes', () {
      final a = WaveformPainter(amplitudes: [0.1, 0.2], barColor: Colors.red);
      final b = WaveformPainter(amplitudes: [0.3, 0.4], barColor: Colors.red);
      expect(b.shouldRepaint(a), isTrue);
    });

    test('shouldRepaint false when nothing changes', () {
      final amps = [0.1, 0.2];
      final a = WaveformPainter(amplitudes: amps, barColor: Colors.red);
      final b = WaveformPainter(amplitudes: amps, barColor: Colors.red);
      expect(b.shouldRepaint(a), isFalse);
    });
  });

  group('VoiceRecorderConfig', () {
    test('defaults are tuned for voice-AI streaming', () {
      const cfg = VoiceRecorderConfig();
      expect(cfg.sampleRate, 16000);
      expect(cfg.numChannels, 1);
    });
  });
}
