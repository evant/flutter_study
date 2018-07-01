import 'dart:async';
import 'dart:convert';

import 'package:flutter_study/lazy.dart';
import 'package:flutter_study/models.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:sqflite/sqflite.dart';
import 'package:streamqflite/streamqflite.dart';

Lazy<Future<StreamDatabase>> defaultDb = Lazy(() => open());
Lazy<Future<DeckRepository>> deckRepo =
    Lazy(() => defaultDb().then((db) => DeckRepository(db)));

Stream<S> flatMapStream<T, S>(Future<T> future, Stream<S> mapper(T t)) =>
    Observable.fromFuture(future).flatMap(mapper);

const String NOT_GIVEN = "<NOT_GIVEN>";

Future<StreamDatabase> open() async {
  var dir = await getApplicationDocumentsDirectory();
  return StreamDatabase(await openDatabase(join(dir.path, "decks.db"),
      version: 4, onCreate: (db, version) async {
    if (version < 3) {
      await db.execute("CREATE TABLE Decks ("
          "id INTEGER PRIMARY KEY,"
          "title TEXT)");
    } else {
      await db.execute("CREATE TABLE Decks ("
          "id INTEGER PRIMARY KEY,"
          "title TEXT,"
          "cardFrontLanguage TEXT,"
          "cardBackLanguage TEXT)");
    }
    if (version < 2) {
      await db.execute("CREATE TABLE Cards ("
          "id INTEGER PRIMARY KEY,"
          "deck INTEGER,"
          "front TEXT,"
          "back TEXT,"
          "reviewed INTEGER,"
          "interval INTEGER DEFAULT 0,"
          "difficulty INTEGER DEFAULT 0,"
          "FOREIGN KEY(deck) REFERENCES Decks(id) ON DELETE CASCADE)");
    } else if (version < 4) {
      await db.execute("CREATE TABLE Cards ("
          "id INTEGER PRIMARY KEY,"
          "deck INTEGER,"
          "front TEXT,"
          "back TEXT,"
          "notes TEXT,"
          "reviewed INTEGER,"
          "interval INTEGER DEFAULT 0,"
          "difficulty INTEGER DEFAULT 0,"
          "FOREIGN KEY(deck) REFERENCES Decks(id) ON DELETE CASCADE)");
    } else {
      await db.execute("CREATE TABLE Cards ("
          "id INTEGER PRIMARY KEY,"
          "deck INTEGER,"
          "front TEXT,"
          "back TEXT,"
          "notes TEXT,"
          "reviewed INTEGER,"
          "interval INTEGER DEFAULT 0,"
          "difficulty INTEGER DEFAULT 0,"
          "alternatives TEXT DEFAULT '[]',"
          "FOREIGN KEY(deck) REFERENCES Decks(id) ON DELETE CASCADE)");
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
      if (oldVersion < 4 && newVersion >= 4) {
        await db.execute(
            "ALTER TABLE Cards ADD COLUMN alternatives TEXT DEFAULT '[]'");
      }
    }
  }));
}

class DeckRepository {
  StreamDatabase _db;

  DeckRepository(StreamDatabase db) : _db = db;

  Stream<List<Deck>> get decks => _db.createRawQuery(
        ["Decks", "Cards"],
        "SELECT Decks.id, Decks.title, Decks.cardFrontLanguage, Decks.cardBackLanguage, count(Cards.deck) as reviewCount "
            "FROM Decks "
            "LEFT OUTER JOIN ("
            "SELECT * FROM Cards WHERE ${cardsToReviewQueryFragment(
            DateTime.now())}"
            ") as Cards "
            "ON Cards.deck = Decks.id "
            "GROUP BY Decks.id, Decks.title",
      ).mapToList(toDeck);

  static String cardsToReviewQueryFragment(DateTime now) {
    var nowMinutes = now.millisecondsSinceEpoch ~/ (60 * 1000);
    return "(Cards.reviewed + Cards.interval) < $nowMinutes";
  }

  static Deck toDeck(Map<String, dynamic> row) {
    return Deck(
      id: row["id"] as int,
      title: row["title"] as String,
      reviewCount: row["reviewCount"] as int,
      cardFrontLanguage: row["cardFrontLanguage"] as String,
      cardBackLanguage: row["cardBackLanguage"] as String,
    );
  }

  Stream<Deck> deck(int deckId) {
    return _db.createQuery("Decks",
        where: "id = ?", whereArgs: [deckId]).mapToOne(toDeck);
  }

  CardRepository cards(int deckId) {
    return CardRepository(_db, deckId: deckId, deckRepo: this);
  }

  Future<Deck> insertDeck({@required String title}) async {
    var id = await _db.insert("Decks", {"title": title});
    return Deck(id: id, title: title);
  }

  Future<int> updateDeck(int deckId,
      {String title = NOT_GIVEN,
      String cardFrontLanguage = NOT_GIVEN,
      String cardBackLanguage = NOT_GIVEN}) {
    var values = Map<String, Object>();
    if (title != NOT_GIVEN) {
      values["title"] = title;
    }
    if (cardFrontLanguage != NOT_GIVEN) {
      values["cardFrontLanguage"] = cardFrontLanguage;
    }
    if (cardBackLanguage != NOT_GIVEN) {
      values["cardBackLanguage"] = cardBackLanguage;
    }
    return _db
        .update("Decks", values, where: "id = ?", whereArgs: [deckId]);
  }

  Future<int> deleteDeck(int deckId) {
    return _db.delete("Decks", where: "id = ?", whereArgs: [deckId]);
  }

  Future<int> resetDeck(int deckId) {
    return _db.update("Cards",
        {"reviewed": null, "interval": 0, "difficulty": 0},
        where: "deck = ?", whereArgs: [deckId]);
  }
}

class CardRepository {
  final StreamDatabase _db;
  final DeckRepository deckRepo;
  final int deckId;

  CardRepository(StreamDatabase db,
      {@required this.deckId, @required this.deckRepo})
      : _db = db;

  Stream<List<Card>> get cards => _db.createQuery("Cards",
      where: "deck = ?", whereArgs: [deckId]).mapToList(toCard);

  static Card toCard(Map<String, dynamic> row) {
    DateTime toDateTime(num minutes) {
      if (minutes == null) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch((minutes * 60 * 1000).toInt());
    }

    return Card(
      id: row["id"] as int,
      front: row["front"] as String,
      back: row["back"] as String,
      alternatives: (json.decode(row["alternatives"] as String ?? '[]') as List)
          .map<String>((dynamic item) => item as String).toList(),
      notes: row["notes"] as String,
      reviewed: toDateTime(row["reviewed"] as num),
      interval: Duration(minutes: row["interval"] as int),
      difficulty: row["difficulty"] as int,
    );
  }

  Future<Card> insertCard(int deckId,
      {@required String front,
      @required String back,
      @required List<String> alternatives,
      @required String notes}) async {
    var id = await _db.insert("Cards", {
      "deck": deckId,
      "front": front,
      "back": back,
      "alternatives": json.encode(alternatives),
      "notes": notes,
    });
    return Card(
        id: id,
        front: front,
        back: back,
        alternatives: alternatives,
        notes: notes);
  }

  Future<int> updateCardContents(int cardId,
      {@required String front,
      @required String back,
      @required List<String> alternatives,
      @required String notes}) {
    return _db.update(
        "Cards",
        {
          "front": front,
          "back": back,
          "alternatives": json.encode(alternatives),
          "notes": notes,
        },
        where: "id = ?",
        whereArgs: [cardId]);
  }

  Future<int> updateCardStats(int cardId,
      {DateTime reviewed, Duration interval, int difficulty}) {
    var values = Map<String, Object>();
    if (reviewed != null) {
      values["reviewed"] = reviewed.millisecondsSinceEpoch ~/ (60 * 1000);
    }
    if (interval != null) {
      values["interval"] = interval.inMinutes;
    }
    if (difficulty != null) {
      values["difficulty"] = difficulty;
    }
    return _db
        .update("Cards", values, where: "id = ?", whereArgs: [cardId]);
  }

  Future<int> deleteCard(int cardId) {
    return _db.delete("Cards", where: "id = ?", whereArgs: [cardId]);
  }
}
