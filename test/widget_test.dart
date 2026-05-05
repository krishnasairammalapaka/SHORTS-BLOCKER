import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shorts_blocker/main.dart';

const MethodChannel _methodChannel = MethodChannel('shorts_blocker/methods');
const MethodChannel _statsEventChannel =
  MethodChannel('shorts_blocker/stats_events');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, (call) async {
      switch (call.method) {
        case 'getBlockingEnabled':
          return true;
        case 'getStats':
          return {
            'attempts_today': 0,
            'blocks_today': 0,
            'limit_exceeded': false,
          };
        case 'isAccessibilityEnabled':
          return false;
        case 'isOverlayPermissionGranted':
          return false;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_statsEventChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_statsEventChannel, null);
  });

  testWidgets('App renders home and stats tabs', (WidgetTester tester) async {
    await tester.pumpWidget(const ShortsBlockerApp());
    await tester.pumpAndSettle();

    expect(find.text('FocusLoop'), findsWidgets);
    expect(find.text('Enable Shorts Blocking'), findsOneWidget);

    await tester.tap(find.text('Stats'));
    await tester.pumpAndSettle();

    expect(find.text('Attempts Today'), findsOneWidget);
    expect(find.text('Blocks Today'), findsOneWidget);
  });
}
