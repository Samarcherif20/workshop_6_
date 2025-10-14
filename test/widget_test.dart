import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:waiting_room_app_5/main.dart';
import 'package:waiting_room_app_5/queue_provider.dart';
import 'package:waiting_room_app_5/models/client.dart';

@GenerateMocks([QueueProvider])
import 'widget_test.mocks.dart';

void main() {
  testWidgets('Counter increments smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our counter starts at 0.
    expect(find.text('0'), findsOneWidget);
    expect(find.text('1'), findsNothing);

    // Tap the '+' icon and trigger a frame.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // Verify that our counter has incremented.
    expect(find.text('0'), findsNothing);
    expect(find.text('1'), findsOneWidget);
  });

  testWidgets('Displays location when available', (WidgetTester tester) async {
    final provider = MockQueueProvider();
    when(provider.clients).thenReturn([
      Client(
        id: '1',
        name: 'Sam',
        lat: 51.5074,
        lng: -0.1278,
        createdAt: DateTime.now(),
      )
    ]);
    
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const WaitingRoomApp(),
      ),
    );
    
    expect(find.text('Sam'), findsOneWidget);
    expect(find.textContaining('51.5074'), findsOneWidget);
  });
}