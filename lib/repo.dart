import 'dart:async';

import 'package:flutter_study/db.dart';
import 'package:flutter_study/lazy.dart';
import 'package:flutter_study/models.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Lazy<Future<Database>> defaultDb = Lazy(() => open());

Future<Database> open() async {
  var dir = await getApplicationDocumentsDirectory();
  return await openDatabase(join(dir.path, "decks.db"), version: 1,
      onCreate: (db, version) async {
    await db.execute("CREATE TABLE Decks (id INTEGER PRIMARY KEY, title TEXT)");
    await db.execute(
        "CREATE TABLE Cards (id INTEGER PRIMARY KEY, deck INTEGER, front TEXT, back TEXT, reviewed, interval INTEGER DEFAULT 0, difficulty INTEGER DEFAULT 0, FOREIGN KEY(deck) REFERENCES Decks(id) ON DELETE CASCADE)");
  });
}

class DeckRepository {
  final LiveTable _table;
  Stream<List<Deck>> decks;

  DeckRepository({Future<Database> db})
      : _table = LiveTable(db != null ? db : defaultDb()) {
    decks = _table
        .query(
            "SELECT Decks.id, Decks.title, count(Cards.deck) as cardCount FROM Decks LEFT OUTER JOIN Cards ON Cards.deck = Decks.id GROUP BY Decks.id, Decks.title")
        .map<List<Deck>>(toDecks);
  }

  static List<Deck> toDecks(List<Map<String, dynamic>> rows) {
    var decks = List<Deck>();
    for (var row in rows) {
      decks.add(Deck(
          id: row["id"], title: row["title"], cardCount: row["cardCount"]));
    }
    return decks;
  }

  Stream<Deck> deck(int deckId) {
    return _table.query("SELECT * FROM Decks WHERE id = ?", [deckId]).map(
        (rows) => toDecks(rows).first);
  }

  CardRepository cards(int deckId) {
    return CardRepository(deckId, this);
  }

  Future<Deck> insertDeck({@required String title}) async {
    var id =
        await _table.insert("INSERT INTO Decks (title) VALUES (?)", [title]);
    return Deck(id: id, title: title);
  }

  Future<int> updateDeckTitle(int deckId, String newTitle) {
    return _table
        .update("UPDATE Decks SET title = ? WHERE id = ?", [newTitle, deckId]);
  }

  Future<int> deleteDeck(int deckId) {
    return _table.delete("DELETE FROM Decks WHERE id = ?", [deckId]);
  }

  Future<int> resetDeck(int deckId) {
    return _table.update(
        "UPDATE Cards SET reviewed = null, interval = 0, difficulty = 0 WHERE deck = ?",
        [deckId]);
  }
}

class CardRepository {
  final int deckId;
  final LiveTable _table;
  Stream<List<Card>> cards;
  Stream<List<Card>> cardsToStudy;

  CardRepository(this.deckId, DeckRepository deckRepo, {Future<Database> db})
      : _table = LiveTable(db != null ? db : defaultDb(), [deckRepo._table]) {
    cards = _table.query("SELECT * FROM Cards WHERE deck = ?",
        [deckId]).map<List<Card>>(toCards);
    var now = DateTime.now().millisecondsSinceEpoch ~/ (60 * 1000);
    cardsToStudy = _table.query(
        "SELECT * FROM Cards WHERE deck = ? AND (reviewed is null OR (reviewed + interval) < $now)",
        [deckId]).map<List<Card>>(toCards);
  }

  static List<Card> toCards(List<Map<String, dynamic>> rows) {
    DateTime toDateTime(num minutes) {
      if (minutes == null) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch((minutes * 60 * 1000).toInt());
    }

    List<Card> cards = List();
    for (var row in rows) {
      cards.add(Card(
          id: row["id"],
          front: row["front"],
          back: row["back"],
          reviewed: toDateTime(row["reviewed"]),
          interval: Duration(minutes: row["interval"])));
    }
    return cards;
  }

  Future<Card> insertCard(int deckId,
      {@required String front, @required String back}) async {
    var id = await _table.insert(
        "INSERT INTO Cards (deck, front, back) VALUES (?,?,?)",
        [deckId, front, back]);
    return Card(id: id, front: front, back: back);
  }

  Future<int> updateCardContents(int cardId,
      {@required String front, @required String back}) {
    return _table.update("UPDATE Cards SET front = ?, back = ? WHERE id = ?",
        [front, back, cardId]);
  }

  Future<int> updateCardStats(int cardId,
      {DateTime reviewed, Duration interval, int difficulty}) {
    var fields = List<String>();
    var args = List();
    if (reviewed != null) {
      fields.add("reviewed = ?");
      args.add(reviewed.millisecondsSinceEpoch ~/ (60 * 1000));
    }
    if (interval != null) {
      fields.add("interval = ?");
      args.add(interval.inMinutes);
    }
    if (difficulty != null) {
      fields.add("difficulty = ?");
      args.add(difficulty);
    }
    args.add(cardId);
    return _table.update(
        "UPDATE Cards SET ${fields.join(", ")} WHERE id = ?", args);
  }

  Future<int> deleteCard(int cardId) {
    return _table.delete("DELETE FROM Cards WHERE id = ?", [cardId]);
  }
}
