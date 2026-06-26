import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_helix/theme/helix_theme.dart';
import 'package:flutter_helix/widgets/helix/helix_action_dock.dart';
import 'package:flutter_helix/widgets/helix/helix_metric_chip.dart';
import 'package:flutter_helix/widgets/helix/helix_preview_card.dart';
import 'package:flutter_helix/widgets/helix/helix_segmented_tabs.dart';
import 'package:flutter_helix/widgets/helix/helix_status_badge.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    theme: HelixTheme.darkTheme,
    home: Scaffold(backgroundColor: HelixTheme.background, body: child),
  );

  testWidgets('HelixStatusBadge renders label and status marker', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const Center(
          child: HelixStatusBadge(label: 'ready', tone: HelixStatusTone.ready),
        ),
      ),
    );

    expect(find.text('READY'), findsOneWidget);
    expect(find.byType(HelixStatusBadge), findsOneWidget);
  });

  testWidgets('HelixSegmentedTabs invokes index changes', (tester) async {
    var selectedIndex = 0;

    await tester.pumpWidget(
      wrap(
        StatefulBuilder(
          builder: (context, setState) {
            return HelixSegmentedTabs(
              labels: const ['Monitor', 'Archive', 'Projects'],
              selectedIndex: selectedIndex,
              onChanged: (index) => setState(() => selectedIndex = index),
            );
          },
        ),
      ),
    );

    expect(find.text('Archive'), findsOneWidget);

    await tester.tap(find.text('Projects'));
    await tester.pumpAndSettle();

    expect(selectedIndex, 2);
  });

  testWidgets('HelixActionDock renders enabled send and record controls', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Status update?');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);
    var sendCount = 0;
    var recordCount = 0;

    await tester.pumpWidget(
      wrap(
        Center(
          child: HelixActionDock(
            controller: controller,
            focusNode: focusNode,
            hintText: 'Ask',
            inputEnabled: true,
            isRecording: false,
            isBusy: false,
            onSend: () => sendCount++,
            onRecordTap: () => recordCount++,
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isTrue);
    expect(find.byKey(const Key('home-composer-input-shell')), findsOneWidget);
    expect(find.byKey(const Key('home-composer-send-button')), findsOneWidget);
    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);

    await tester.tap(find.byKey(const Key('home-composer-send-button')));
    await tester.tap(find.byIcon(Icons.mic_rounded));
    await tester.pump();

    expect(sendCount, 1);
    expect(recordCount, 1);
  });

  testWidgets('HelixActionDock disables input while recording', (tester) async {
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      wrap(
        Center(
          child: HelixActionDock(
            controller: controller,
            focusNode: focusNode,
            hintText: 'Recording',
            inputEnabled: false,
            isRecording: true,
            isBusy: false,
            onSend: () {},
            onRecordTap: () {},
          ),
        ),
      ),
    );

    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);
    expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
  });

  testWidgets('HelixPreviewCard and HelixMetricChip render reusable content', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        const Center(
          child: HelixPreviewCard(
            label: 'Session',
            icon: Icons.notes_rounded,
            child: Wrap(
              children: [
                HelixMetricChip(icon: Icons.timer_outlined, label: '12 min'),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.text('SESSION'), findsOneWidget);
    expect(find.text('12 min'), findsOneWidget);
    expect(find.byIcon(Icons.notes_rounded), findsOneWidget);
    expect(find.byIcon(Icons.timer_outlined), findsOneWidget);
  });
}
