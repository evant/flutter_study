import 'package:meta/meta.dart';

typedef bool Predicate<E>(E element);

class Deck {
  Deck({this.id, @required this.title, this.cardCount = 0});

  int id;
  String title;
  int cardCount;

  static Predicate<Deck> withId(int id) => (other) => other.id == id;
}

class Card {
  Card({this.id, @required this.front, @required this.back});

  int id;
  String front;
  String back;

  static Predicate<Card> withId(int id) => (other) => other.id == id;
}

