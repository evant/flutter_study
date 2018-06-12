import 'package:meta/meta.dart';

typedef bool Predicate<E>(E element);

class Deck {
  Deck({this.id, @required this.title, this.cardCount = 0});

  final int id;
  final String title;
  final int cardCount;

  static Predicate<Deck> withId(int id) => (other) => other.id == id;
}

class Card {
  Card({
    this.id,
    @required this.front,
    @required this.back,
    this.reviewed,
    this.interval = Duration.zero,
    this.difficulty = 0,
  });

  final int id;
  final String front;
  final String back;
  final DateTime reviewed;
  final Duration interval;
  final int difficulty;

  static Predicate<Card> withId(int id) => (other) => other.id == id;

  Card copy({DateTime reviewed}) => Card(
        id: this.id,
        front: this.front,
        back: this.back,
        reviewed: reviewed ?? this.reviewed,
        interval: this.interval,
        difficulty: this.difficulty,
      );
}

const List<Duration> INTERVALS = [
  Duration(minutes: 15),
  Duration(hours: 36),
  Duration(days: 7),
  Duration(days: 30),
];

Duration nextInterval(Duration interval) {
  for (var targetInterval in INTERVALS) {
    if (targetInterval > interval) {
      return targetInterval;
    }
  }
  return INTERVALS.last;
}
