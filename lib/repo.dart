import 'dart:async';

import 'package:flutter_study/db.dart';
import 'package:flutter_study/lazy.dart';
import 'package:flutter_study/models.dart';
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
        "CREATE TABLE Cards (id INTEGER PRIMARY KEY, deck INTEGER, front TEXT, back TEXT, FOREIGN KEY(deck) REFERENCES Decks(id) ON DELETE CASCADE)");
  });
}

class DeckRepository {
  final LiveTable _table;
  Stream<List<Deck>> decks;

  DeckRepository({Future<Database> db})
      : _table = LiveTable(
            db != null ? db : defaultDb(), "SELECT Decks.id, Decks.title, count(Cards.deck) as cardCount FROM Decks LEFT OUTER JOIN Cards ON Cards.deck = Decks.id GROUP BY Decks.id, Decks.title") {
    decks = _table.stream.map<List<Deck>>((result) {
      var decks = List<Deck>();
      for (var row in result) {
        decks.add(Deck(id: row["id"], title: row["title"], cardCount: row["cardCount"]));
      }
      return decks;
    });
  }

  CardRepository cards(int deckId) {
    return CardRepository(deckId, this);
  }

  Future<Deck> insertDeck({String title}) async {
    var id =
        await _table.insert("INSERT INTO Decks (title) VALUES (?)", [title]);
    return Deck(id: id, title: title);
  }

  Future<int> updateDeckTitle(int deckId, String newTitle) {
    return _table.insert(
        "REPLACE INTO Decks (id, title) VALUES (?,?)",
        [deckId, newTitle]);
  }

  Future<int> deleteDeck(int deckId) {
    return _table.delete("DELETE FROM Decks WHERE id = ?", [deckId]);
  }
}

class CardRepository {
  final int deckId;
  final LiveTable _table;
  Stream<List<Card>> cards;

  CardRepository(this.deckId, DeckRepository deckRepo, {Future<Database> db})
      : _table = LiveTable(db != null ? db : defaultDb(),
            "SELECT id, front, back FROM Cards WHERE deck = ?", [deckId], [deckRepo._table]) {
    cards = _table.stream.map<List<Card>>((result) {
      List<Card> cards = List();
      for (var row in result) {
        cards.add(Card(id: row["id"], front: row["front"], back: row["back"]));
      }
      return cards;
    });
  }

  Future<Card> insertCard(int deckId, {String front, String back}) async {
    var id = await _table.insert(
        "INSERT INTO Cards (deck, front, back) VALUES (?,?,?)",
        [deckId, front, back]);
    return Card(id: id, front: front, back: back);
  }

  Future<int> updateCard(int cardId, {String front, String back}) {
    return _table.insert(
        "INSERT INTO Cards (id, front, back) VALUES (?,?,?) ON CONFLICT REPLACE",
        [cardId, front, back]);
  }

  Future<int> deleteCard(int cardId) {
    return _table.delete("DELETE FROM Cards WHERE id = ?", [cardId]);
  }
}
