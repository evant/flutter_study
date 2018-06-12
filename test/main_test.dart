// This is a basic Flutter widget test.
// To perform an interaction with a widget in your test, use the WidgetTester utility that Flutter
// provides. For example, you can send tap and scroll gestures. You can also use WidgetTester to
// find child widgets in the widget tree, read text, and verify that the values of widget properties
// are correct.

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_study/main.dart';
import 'package:flutter_study/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Study', () {
    testWidgets('Correct answer shows snackbar and navigates to next card',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StudyDeckContent(
        appBar: AppBar(),
        cards: [
          Card(id: 0, front: 'front1', back: 'back1'),
          Card(id: 1, front: 'front2', back: 'back2'),
          Card(id: 2, front: 'front3', back: 'back3'),
          Card(id: 3, front: 'front4', back: 'back4'),
        ],
        shuffler: MockDeckShuffler(),
      ))));

      await tester.tap(find.text('back1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SnackBar, 'Correct!'), findsOneWidget);
      expect(find.text('front2'), findsOneWidget);
    });

    testWidgets('Incorrect answer shows review screen', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: StudyDeckContent(
        appBar: AppBar(),
        cards: [
          Card(id: 0, front: 'front1', back: 'back1'),
          Card(id: 1, front: 'front2', back: 'back2'),
          Card(id: 2, front: 'front3', back: 'back3'),
          Card(id: 3, front: 'front4', back: 'back4'),
        ],
        shuffler: MockDeckShuffler(),
      ))));

      await tester.tap(find.text('back2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(SnackBar, 'Wrong!'), findsOneWidget);
      expect(find.text('front1'), findsOneWidget);
      expect(find.text('back1'), findsOneWidget);
    });
  });
}

class MockDeckShuffler implements DeckShuffler {
  @override
  List<Card> shuffled(List<Card> cards) => cards;

  @override
  List<Card> pickChoices(List<Card> cards, int correctCardId, {int count: 4}) {
    var index = cards.indexWhere(Card.withId(correctCardId));
    var result = List<Card>();
    for (var i = 0; i < count; i++) {
      result.add(cards[(index + i) % cards.length]);
    }
    return result;
  }
}
