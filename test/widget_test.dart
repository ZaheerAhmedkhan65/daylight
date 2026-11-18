import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:todo_app/main.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('shows the daily task list', (tester) async {
    await tester.pumpWidget(const PlannerApp());
    await tester.pumpAndSettle();

    expect(find.text('Review homepage concepts'), findsOneWidget);
    expect(find.text('Pick up groceries'), findsOneWidget);
  });

  testWidgets('can create and save a task', (tester) async {
    await tester.pumpWidget(const PlannerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create task'));
    await tester.pumpAndSettle();
    expect(find.text('ONE SMALL STEP FORWARD'), findsOneWidget);
    expect(find.text('NEW TASK'), findsNothing);
    expect(find.text('New task'), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('task-title')),
      'Send the proposal',
    );
    await tester.tap(find.text('Create task'));
    await tester.pumpAndSettle();

    expect(find.text('Send the proposal'), findsOneWidget);
  });

  testWidgets('editor uses project color and dark date and time values', (
    tester,
  ) async {
    await tester.pumpWidget(const PlannerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create task'));
    await tester.pumpAndSettle();

    final projectValue = tester.widget<Text>(find.text('Studio'));
    expect(projectValue.style?.color, const Color(0xFF8A69D6));
    expect(
      tester.widget<Text>(find.text('10:00 AM')).style?.color,
      const Color(0xFF302D34),
    );
  });

  testWidgets('can navigate to projects', (tester) async {
    await tester.pumpWidget(const PlannerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Projects').last);
    await tester.pumpAndSettle();

    expect(find.text('Your spaces'), findsOneWidget);
    expect(find.text('Wellbeing'), findsOneWidget);
    final navigationBar = tester.widget<NavigationBar>(
      find.byType(NavigationBar),
    );
    expect(navigationBar.indicatorColor, const Color(0xFFE5DEFA));
    expect(
      tester.widget<Icon>(find.byIcon(Icons.dashboard)).color,
      const Color(0xFF7654D8),
    );
  });

  testWidgets('subtask add button is enabled only for non-empty text', (
    tester,
  ) async {
    await tester.pumpWidget(const PlannerApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Create task'));
    await tester.pumpAndSettle();

    final addSubtaskFinder = find.byKey(
      const Key('add-subtask'),
      skipOffstage: false,
    );
    IconButton addButton() => tester.widget<IconButton>(addSubtaskFinder);
    expect(addButton().onPressed, isNull);

    final subtaskInput = find.byKey(const Key('subtask-input'));
    await tester.scrollUntilVisible(
      subtaskInput,
      300,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    await tester.enterText(subtaskInput, '   ');
    await tester.pump();
    expect(addButton().onPressed, isNull);

    await tester.enterText(subtaskInput, 'Prepare notes');
    await tester.pump();
    expect(addButton().onPressed, isNotNull);

    await tester.ensureVisible(addSubtaskFinder);
    await tester.pumpAndSettle();
    await tester.tap(addSubtaskFinder);
    await tester.pump();
    expect(find.text('Prepare notes'), findsOneWidget);
    expect(addButton().onPressed, isNull);
  });
}
