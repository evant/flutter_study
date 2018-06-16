import 'package:meta/meta.dart';

typedef bool Predicate<E>(E element);

class Deck {
  Deck({this.id, @required this.title, this.cardCount = 0, this.cardFrontLanguage, this.cardBackLanguage});

  final int id;
  final String title;
  final int cardCount;
  final String cardFrontLanguage;
  final String cardBackLanguage;

  static Predicate<Deck> withId(int id) => (other) => other.id == id;
}

class Card {
  Card({
    this.id,
    @required this.front,
    @required this.back,
    this.notes,
    this.reviewed,
    this.interval = Duration.zero,
    this.difficulty = 0,
  });

  final int id;
  final String front;
  final String back;
  final String notes;
  final DateTime reviewed;
  final Duration interval;
  final int difficulty;

  bool get hasNotes => notes != null && notes.isNotEmpty;

  static Predicate<Card> withId(int id) => (other) => other.id == id;

  Card copy({DateTime reviewed, int difficulty, Duration interval}) => Card(
        id: this.id,
        front: this.front,
        back: this.back,
        notes: this.notes,
        reviewed: reviewed ?? this.reviewed,
        interval: interval ?? this.interval,
        difficulty: difficulty ?? this.difficulty,
      );

  Card upgrade() {
    if (difficulty == 0 && interval >= INTERVALS[1]) {
      return copy(difficulty: 1, interval: INTERVALS.first);
    } else {
      return copy(interval: nextInterval(interval));
    }
  }

  Card reset() {
    return copy(difficulty: 0, interval: INTERVALS.first);
  }
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
