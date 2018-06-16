import 'dart:async';

import 'package:flutter_study/db.dart';
import 'package:flutter_study/lazy.dart';
import 'package:flutter_study/models.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Lazy<Future<Database>> defaultDb = Lazy(() => open());

const String NOT_GIVEN = "<NOT_GIVEN>";

Future<Database> open() async {
  var dir = await getApplicationDocumentsDirectory();
  return await openDatabase(join(dir.path, "decks.db"), version: 3,
      onCreate: (db, version) async {
    if (version < 3) {
      await db
          .execute("CREATE TABLE Decks (id INTEGER PRIMARY KEY, title TEXT)");
    } else {
      await db.execute(
          "CREATE TABLE Decks (id INTEGER PRIMARY KEY, title TEXT, cardFrontLanguage TEXT, cardBackLanguage TEXT)");
    }
    if (version < 2) {
      await db.execute(
          "CREATE TABLE Cards (id INTEGER PRIMARY KEY, deck INTEGER, front TEXT, back TEXT, reviewed INTEGER, interval INTEGER DEFAULT 0, difficulty INTEGER DEFAULT 0, FOREIGN KEY(deck) REFERENCES Decks(id) ON DELETE CASCADE)");
    } else {
      await db.execute(
          "CREATE TABLE Cards (id INTEGER PRIMARY KEY, deck INTEGER, front TEXT, back TEXT, notes TEXT, reviewed INTEGER, interval INTEGER DEFAULT 0, difficulty INTEGER DEFAULT 0, FOREIGN KEY(deck) REFERENCES Decks(id) ON DELETE CASCADE)");
    }
  }, onUpgrade: (db, oldVersion, newVersion) async {
    if (oldVersion != newVersion) {
      if (oldVersion < 2 && newVersion >= 2) {
        await db.execute("ALTER TABLE Cards ADD COLUMN notes TEXT");
      }
      if (oldVersion < 3 && newVersion >= 3) {
        await db.execute("ALTER TABLE Decks ADD COLUMN cardFrontLanguage TEXT");
        await db.execute("ALTER TABLE Decks ADD COLUMN cardBackLanguage TEXT");
      }
    }
  });
}

class DeckRepository {
  final LiveTable _table;
  Stream<List<Deck>> decks;

  DeckRepository({Future<Database> db})
      : _table = LiveTable(db != null ? db : defaultDb()) {
    var now = DateTime.now().millisecondsSinceEpoch ~/ (60 * 1000);
    decks = _table
        .query(
            "SELECT Decks.id, Decks.title, Decks.cardFrontLanguage, Decks.CardBackLanguage, count(Cards.deck) as cardCount FROM Decks LEFT OUTER JOIN (SELECT * FROM Cards WHERE Cards.reviewed is null OR (Cards.reviewed + Cards.interval) < $now) as Cards ON Cards.deck = Decks.id GROUP BY Decks.id, Decks.title")
        .map<List<Deck>>(toDecks);
  }

  static List<Deck> toDecks(List<Map<String, dynamic>> rows) {
    var decks = List<Deck>();
    for (var row in rows) {
      decks.add(Deck(
        id: row["id"],
        title: row["title"],
        cardCount: row["cardCount"],
        cardFrontLanguage: row["cardFrontLanguage"],
        cardBackLanguage: row["cardBackLanguage"],
      ));
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

  Future<int> updateDeck(int deckId,
      {String title = NOT_GIVEN, String cardFrontLanguage = NOT_GIVEN, String cardBackLanguage = NOT_GIVEN}) {
    var fields = List<String>();
    var args = List();
    if (title != NOT_GIVEN) {
      fields.add("title = ?");
      args.add(title);
    }
    if (cardFrontLanguage != NOT_GIVEN) {
      fields.add("cardFrontLanguage = ?");
      args.add(cardFrontLanguage);
    }
    if (cardBackLanguage != NOT_GIVEN) {
      fields.add("cardBackLanguage = ?");
      args.add(cardBackLanguage);
    }
    args.add(deckId);
    return _table.update(
        "UPDATE Decks SET ${fields.join(", ")} WHERE id = ?", args);
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
        notes: row["notes"],
        reviewed: toDateTime(row["reviewed"]),
        interval: Duration(minutes: row["interval"]),
        difficulty: row["difficulty"],
      ));
    }
    return cards;
  }

  Future<Card> insertCard(int deckId,
      {@required String front, @required String back, String notes}) async {
    var id = await _table.insert(
        "INSERT INTO Cards (deck, front, back, notes) VALUES (?,?,?,?)",
        [deckId, front, back, notes]);
    return Card(id: id, front: front, back: back, notes: notes);
  }

  Future<int> updateCardContents(int cardId,
      {@required String front, @required String back, String notes}) {
    return _table.update(
        "UPDATE Cards SET front = ?, back = ?, notes = ? WHERE id = ?",
        [front, back, notes, cardId]);
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
