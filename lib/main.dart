import 'dart:async';

import 'package:flutter/material.dart' hide Card;
import 'package:flutter_study/lazy.dart';
import 'package:flutter_study/models.dart';
import 'package:flutter_study/repo.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:rxdart/rxdart.dart';

void main() => runApp(App());

Lazy<Tts> tts = Lazy(() => Tts(FlutterTts()));

class Foo {
  final String bar;

  const Foo([this.bar = "const"]);
}

String nonConst() => "nonConst";

class Tts {
  final FlutterTts _tts;

  Tts(FlutterTts tts) : _tts = tts;

  Future<List<String>> get languages async => (await _tts.getLanguages)
      .map<String>((dynamic language) => language.toString())
      .toList();

  void speak(String text, {String language}) async {
    if (language != null) {
      await _tts.setLanguage(language);
    }
    await _tts.speak(text);
  }
}

class App extends StatelessWidget {
  final Future<DeckRepository> repo =
      defaultDb().then((db) => DeckRepository(db));

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Study',
        theme: ThemeData(
          accentColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        home: HomePage());
  }
}

typedef Widget LoadingWidgetBuilder<T>(BuildContext context, T data);
typedef Widget ChromeBuilder(BuildContext context, Widget body);

class LoadingContent<T> extends StatelessWidget {
  final AsyncSnapshot<T> snapshot;
  final LoadingWidgetBuilder<T> builder;

  const LoadingContent({Key key, this.snapshot, this.builder})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (snapshot.hasData) {
      content = builder(context, snapshot.data);
    } else {
      if (snapshot.hasError) {
        print(snapshot.error);
      }
      content = Center(child: CircularProgressIndicator());
    }
    return content;
  }
}

class HomePage extends StatelessWidget {
  const HomePage({Key key}) : super(key: key);

  void studyDeck(BuildContext context, Deck deck) {
    Navigator.push<StudyDeck>(context,
        MaterialPageRoute(builder: (context) => StudyDeck(deck: deck)));
  }

  void editDeck(BuildContext context, Deck deck) {
    Navigator.push<EditDeck>(
        context,
        MaterialPageRoute(
            builder: (context) => EditDeck(
                  title: "Edit Deck",
                  deckId: deck.id,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Deck>>(
        stream: flatMapStream(deckRepo(), (DeckRepository repo) => repo.decks),
        builder: (context, snapshot) {
          return Scaffold(
              appBar: AppBar(title: Text('Flutter Study')),
              body: LoadingContent(
                  snapshot: snapshot,
                  builder: (context, List<Deck> decks) {
                    return Column(children: [
                      Expanded(
                          child: ListView.builder(
                        itemCount: decks.length,
                        itemBuilder: (context, index) {
                          var contents = <Widget>[Text(decks[index].title)];
                          if (decks[index].reviewCount > 0) {
                            contents.add(Container(
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(100.0),
                                    color: Theme.of(context).accentColor),
                                child: new Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 4.0, horizontal: 8.0),
                                  child: Text("review",
                                      style: Theme
                                          .of(context)
                                          .accentTextTheme
                                          .body1),
                                )));
                          }
                          return ListTile(
                            title: Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: contents,
                            ),
                            onTap: () {
                              studyDeck(context, decks[index]);
                            },
                            onLongPress: () {
                              editDeck(context, decks[index]);
                            },
                          );
                        },
                      ))
                    ]);
                  }),
              floatingActionButton: snapshot.hasData
                  ? FloatingActionButton(
                      child: Icon(Icons.add),
                      onPressed: () async {
                        var deck = await (await deckRepo()).insertDeck(
                            title: "Deck ${snapshot.data.length + 1}");
                        Navigator.push<EditDeck>(
                            context,
                            MaterialPageRoute(
                                builder: (context) => EditDeck(
                                      title: 'New Deck',
                                      deckId: deck.id,
                                    )));
                      })
                  : null);
        });
  }
}

class EditDeck extends StatefulWidget {
  final String title;
  final int deckId;
  final Future<CardRepository> cardRepo;

  EditDeck({
    Key key,
    @required this.title,
    @required this.deckId,
  })  : cardRepo = deckRepo().then((repo) => repo.cards(deckId)),
        super(key: key);

  void deleteDeck() async {
    await (await deckRepo()).deleteDeck(deckId);
  }

  void resetDeck() async {
    await (await deckRepo()).resetDeck(deckId);
  }

  @override
  State<StatefulWidget> createState() => _EditDeckState();
}

class _EditDeckState extends State<EditDeck> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  void addCards(BuildContext context, Deck deck) {
    Navigator.push<AddCards>(
        context,
        MaterialPageRoute(
            builder: (context) => AddCards(
                  deck: deck,
                  repo: widget.cardRepo,
                )));
  }

  void editTitle(BuildContext context, Deck deck) {
    var context = _scaffoldKey.currentState.context;
    showDialog<void>(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: pad(Form(
              key: _formKey,
              child: TextFormField(
                autofocus: true,
                controller: TextEditingController(text: deck.title),
                validator: notEmpty,
                onSaved: (text) async {
                  await (await deckRepo()).updateDeck(deck.id, title: text);
                },
              ),
            )),
            actions: <Widget>[
              FlatButton(
                child: Text("Save"),
                onPressed: () {
                  if (_formKey.currentState.validate()) {
                    _formKey.currentState.save();
                    Navigator.pop(context);
                  }
                },
              )
            ],
          );
        });
  }

  void saveTitle(BuildContext context) {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      Navigator.pop(context);
    }
  }

  Stream<DeckData> _deckData() {
    return flatMapStream<CardRepository, DeckData>(widget.cardRepo, (repo) {
      Stream<Deck> deckStream = repo.deckRepo.deck(widget.deckId);
      Stream<List<Card>> cardsStream = repo.cards;
      return Observable(deckStream).switchMap<DeckData>((deck) =>
          cardsStream.map((cards) => DeckData(deck: deck, cards: cards)));
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DeckData>(
        stream: _deckData(),
        builder: (context, snapshot) {
          final data = snapshot.data;
          final deck = data != null ? data.deck : null;
          final cards = data != null ? data.cards : null;
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: snapshot.hasData
                  ? Text("${deck.title} (${cards.length})")
                  : null,
              actions: <Widget>[
                IconButton(
                  tooltip: "Edit Title",
                  icon: Icon(Icons.edit),
                  onPressed: () => editTitle(context, deck),
                ),
                PopupMenuButton(
                  itemBuilder: (context) {
                    return [
                      PopupMenuItem(
                        child: Text("Settings"),
                        value: 2,
                      ),
                      PopupMenuItem(
                        child: Text("Delete"),
                        value: 0,
                      ),
                      PopupMenuItem(
                        child: Text("Reset"),
                        value: 1,
                      )
                    ];
                  },
                  onSelected: (int value) {
                    if (value == 0) {
                      widget.deleteDeck();
                      Navigator.pop(context);
                    } else if (value == 1) {
                      widget.resetDeck();
                    } else if (value == 2) {
                      Navigator.push<DeckSettings>(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  DeckSettings(deckId: deck.id)));
                    }
                  },
                ),
              ],
            ),
            body: Column(children: <Widget>[
              Expanded(
                  child: LoadingContent<DeckData>(
                snapshot: snapshot,
                builder: (context, _) {
                  return ListView.builder(
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      var card = cards[index];
                      return ListTile(
                        title: new Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            runSpacing: 8.0,
                            children: [
                              Text(card.front,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text(card.back,
                                  maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        onTap: () {
                          Navigator.push<EditCard>(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => EditCard(
                                        deck: deck,
                                        card: cards[index],
                                        repo: widget.cardRepo,
                                      )));
                        },
                      );
                    },
                  );
                },
              )),
            ]),
            floatingActionButtonLocation:
                FloatingActionButtonLocation.centerFloat,
            floatingActionButton: FloatingActionButton.extended(
              icon: Icon(Icons.add),
              label: Text("Add Cards"),
              onPressed: () => addCards(context, deck),
            ),
          );
        });
  }
}

class DeckData {
  final Deck deck;
  final List<Card> cards;

  DeckData({@required this.deck, @required this.cards});
}

class DeckSettings extends StatelessWidget {
  final int deckId;

  const DeckSettings({Key key, @required this.deckId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Deck Settings")),
        body: StreamBuilder<Deck>(
          stream: flatMapStream(
              deckRepo(), (DeckRepository repo) => repo.deck(deckId)),
          builder: (context, snapshot) {
            return LoadingContent<Deck>(
              snapshot: snapshot,
              builder: (context, deck) => FutureBuilder<List<String>>(
                    future: tts().languages,
                    builder: (context, snapshot) {
                      return LoadingContent<List<String>>(
                          snapshot: snapshot,
                          builder: (context, languages) {
                            List<DropdownMenuItem<String>> items = List();
                            items.add(DropdownMenuItem<String>(
                                child: Text("Default")));
                            for (var language in languages) {
                              items.add(DropdownMenuItem<String>(
                                  child: Text(language), value: language));
                            }
                            return pad(Column(children: [
                              Text("Text To Speach",
                                  style: Theme.of(context).textTheme.headline),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Card Fronts"),
                                    DropdownButton<String>(
                                      items: items,
                                      value: deck.cardFrontLanguage,
                                      onChanged: (value) async {
                                        if (deck.cardBackLanguage == null) {
                                          await (await deckRepo()).updateDeck(
                                              deckId,
                                              cardFrontLanguage: value,
                                              cardBackLanguage: value);
                                        } else {
                                          await (await deckRepo()).updateDeck(
                                              deckId,
                                              cardFrontLanguage: value);
                                        }
                                      },
                                    ),
                                  ]),
                              Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Card Backs"),
                                    DropdownButton<String>(
                                      items: items,
                                      value: deck.cardBackLanguage,
                                      onChanged: (value) async {
                                        await (await deckRepo()).updateDeck(
                                            deckId,
                                            cardBackLanguage: value);
                                      },
                                    ),
                                  ]),
                            ]));
                          });
                    },
                  ),
            );
          },
        ));
  }
}

class AddCards extends StatefulWidget {
  AddCards({
    Key key,
    @required this.deck,
    @required this.repo,
  }) : super(key: key);

  final Deck deck;
  final Future<CardRepository> repo;

  void insertCard(
      {String front,
      String back,
      List<String> alternatives,
      String notes}) async {
    await (await repo).insertCard(deck.id,
        front: front, back: back, alternatives: alternatives, notes: notes);
  }

  @override
  State<StatefulWidget> createState() => _AddCardsState();
}

class _AddCardsState extends State<AddCards> {
  final GlobalKey<CardFormState> formKey = new GlobalKey<CardFormState>();

  bool addCard() {
    var state = formKey.currentState;
    if (state.validate()) {
      widget.insertCard(
        front: state.cardFront.text,
        back: state.cardBack.text,
        alternatives: state.cardAlternatives
            .map((controller) => controller.text)
            .toList(),
        notes: state.cardNotes.text,
      );
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text(widget.deck.title)),
        body: Column(
          children: [
            Expanded(
                child: SingleChildScrollView(child: CardForm(key: formKey))),
            ButtonBar(
              children: [
                FlatButton(
                  child: Text("NEXT"),
                  onPressed: () {
                    if (addCard()) {
                      formKey.currentState.clear();
                    }
                  },
                ),
                FlatButton(
                    child: Text("DONE"),
                    onPressed: () {
                      if (addCard()) {
                        Navigator.pop(context);
                      }
                    })
              ],
            )
          ],
        ));
  }
}

class EditCard extends StatefulWidget {
  EditCard({
    Key key,
    @required this.deck,
    @required this.card,
    @required this.repo,
  }) : super(key: key);

  final Deck deck;
  final Card card;
  final Future<CardRepository> repo;

  void deleteCard() async {
    await (await repo).deleteCard(card.id);
  }

  void updateCard(
      {String front,
      String back,
      List<String> alternatives,
      String notes}) async {
    await (await repo).updateCardContents(card.id,
        front: front, back: back, alternatives: alternatives, notes: notes);
  }

  @override
  State<StatefulWidget> createState() => _EditCardState();
}

class _EditCardState extends State<EditCard> {
  final GlobalKey<CardFormState> formKey = new GlobalKey<CardFormState>();

  void delete(BuildContext context) {
    widget.deleteCard();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text(widget.deck.title),
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.delete),
              onPressed: () => delete(context),
            )
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                  child: CardForm(key: formKey, card: widget.card)),
            ),
            ButtonBar(
              children: <Widget>[
                FlatButton(
                    child: Text("Save"),
                    onPressed: () {
                      var state = formKey.currentState;
                      if (state.validate()) {
                        widget.updateCard(
                            front: state.cardFront.text,
                            back: state.cardBack.text,
                            alternatives: state.cardAlternatives
                                .map((controller) => controller.text)
                                .toList(),
                            notes: state.cardNotes.text);
                        Navigator.pop(context);
                      }
                    }),
              ],
            )
          ],
        ));
  }
}

class CardForm extends StatefulWidget {
  CardForm({Key key, this.card}) : super(key: key);
  final Card card;

  @override
  State<StatefulWidget> createState() => CardFormState();
}

class CardFormState extends State<CardForm> {
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();
  FocusNode frontFocusNode;
  TextEditingController cardFront;
  TextEditingController cardBack;
  TextEditingController cardNotes;
  List<TextEditingController> cardAlternatives;

  bool validate() => _formKey.currentState.validate();

  void clear() {
    cardFront.clear();
    cardBack.clear();
    cardNotes.clear();
    for (var cardAlternative in cardAlternatives) {
      cardAlternative.clear();
    }
    FocusScope.of(context).requestFocus(frontFocusNode);
  }

  @override
  void initState() {
    super.initState();
    var card = widget.card;
    frontFocusNode = FocusNode();
    cardFront = TextEditingController();
    cardBack = TextEditingController();
    cardNotes = TextEditingController();
    cardAlternatives = [];
    cardFront.text = card != null ? card.front : "";
    cardBack.text = card != null ? card.back : "";
    cardNotes.text = card != null ? card.notes : "";
    if (card != null) {
      for (var alternative in card.alternatives) {
        cardAlternatives.add(TextEditingController(text: alternative));
      }
    }
  }

  @override
  void dispose() {
    frontFocusNode.dispose();
    cardFront.dispose();
    cardBack.dispose();
    cardNotes.dispose();
    for (var cardAlternative in cardAlternatives) {
      cardAlternative.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var alternatives = List<TextFormField>();
    for (var i = 0; i < cardAlternatives.length; i++) {
      var controller = cardAlternatives[i];
      alternatives.add(TextFormField(
        controller: controller,
        decoration: InputDecoration(
            suffixIcon: IconButton(
                icon: Icon(Icons.delete),
                onPressed: () {
                  setState(() {
                    cardAlternatives.removeAt(i);
                  });
                })),
        validator: notEmpty,
      ));
    }
    return Form(
        key: _formKey,
        child: pad(Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            TextFormField(
              decoration: InputDecoration(labelText: "Front"),
              controller: cardFront,
              autofocus: true,
              focusNode: frontFocusNode,
              validator: notEmpty,
            ),
            TextFormField(
              controller: cardBack,
              decoration: InputDecoration(labelText: "Back"),
              validator: notEmpty,
            ),
            Column(children: alternatives),
            FlatButton(
              child: Text("ADD ALTERNATIVE"),
              onPressed: () {
                setState(() {
                  cardAlternatives.add(TextEditingController());
                });
              },
            ),
            TextFormField(
              controller: cardNotes,
              decoration: InputDecoration(labelText: "Notes"),
            ),
          ],
        )));
  }
}

class DeckShuffler {
  const DeckShuffler();

  List<Card> shuffled(List<Card> cards) {
    var shuffled = List<Card>();
    var reviewed = cards.where((card) => card.reviewed != null);
    // Start with cards that need to be reviewed.
    var cardsToReview = reviewed.where(
        (card) => card.reviewed.add(card.interval).isBefore(DateTime.now()));
    shuffled.addAll(cardsToReview);
    shuffled.shuffle();
    // Only include new cards if at least 85% of cards are on at least the third
    // interval or we have less than 10 cards reviewed.
    // The goal is to only dole out new cards when existing cards are
    // sufficiently studied.
    var reviewedCount = reviewed.length;
    var studiedCount =
        reviewed.where((card) => card.interval >= INTERVALS[2]).length;
    if (reviewedCount < 10 || studiedCount / reviewedCount >= 0.85) {
      // Include new cards twice: first just to review, then again shuffled.
      // Limit new cards to 10
      var newCards = cards.where((card) => card.reviewed == null).take(10);
      var shuffledNewCards = List.of<Card>(
          newCards.map((card) => card.copy(reviewed: DateTime.now())));
      shuffledNewCards.shuffle();
      shuffled.addAll(newCards);
      shuffled.addAll(shuffledNewCards);
    }
    return shuffled;
  }

  List<Card> pickChoices(List<Card> cards, int correctCardId, {int count = 4}) {
    var cardsWithoutCurrent = List.from<Card>(cards);
    var correctIndex =
        cardsWithoutCurrent.indexWhere(Card.withId(correctCardId));
    var correct = cardsWithoutCurrent.removeAt(correctIndex);
    cardsWithoutCurrent.shuffle();
    var choices = List.from<Card>(cardsWithoutCurrent.take(count - 1));
    choices.add(correct);
    choices.shuffle();
    return choices;
  }
}

class StudyDeck extends StatelessWidget {
  final DeckShuffler shuffler;
  final Deck deck;
  final Future<CardRepository> cardRepo;

  StudyDeck({@required this.deck, this.shuffler = const DeckShuffler()})
      : cardRepo = deckRepo().then((repo) => repo.cards(deck.id));

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Card>>(
      stream: flatMapStream(cardRepo, (CardRepository repo) => repo.cards),
      builder: (context, snapshot) {
        var appBar = AppBar(title: Text(deck.title));
        if (snapshot.hasData) {
          return StudyDeckContent(
            appBar: appBar,
            deck: deck,
            cards: snapshot.data,
            repo: cardRepo,
          );
        } else {
          if (snapshot.hasError) {
            print(snapshot.error);
          }
          return Scaffold(
            appBar: appBar,
            body: Center(child: CircularProgressIndicator()),
          );
        }
      },
    );
  }
}

class StudyDeckContent extends StatefulWidget {
  final PreferredSizeWidget appBar;
  final Deck deck;
  final List<Card> cards;
  final DeckShuffler shuffler;
  final Future<CardRepository> repo;

  const StudyDeckContent(
      {Key key,
      @required this.appBar,
      @required this.deck,
      @required this.cards,
      @required this.repo,
      this.shuffler = const DeckShuffler()})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _StudyDeckContentState();
}

class _StudyDeckContentState extends State<StudyDeckContent>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  AnimationController controller;
  Animation<double> progress;

  List<Card> shuffledCardsToStudy;
  int cardIndex = -1;
  bool inFirstReview = false;
  bool inReReview = false;
  Answer<dynamic> answer;

  bool get inReview => inFirstReview || inReReview;

  Card get card => cardIndex < shuffledCardsToStudy.length
      ? shuffledCardsToStudy[cardIndex]
      : null;

  @override
  void initState() {
    super.initState();
    shuffledCardsToStudy = widget.shuffler.shuffled(widget.cards);
    pickCard();
  }

  @override
  dispose() {
    controller.dispose();
    super.dispose();
  }

  void pickCard() {
    setState(() {
      answer = null;
      cardIndex++;
      inFirstReview = card != null ? card.reviewed == null : false;
      controller = AnimationController(
          duration: const Duration(milliseconds: 300), vsync: this);
      progress = Tween(
              begin: progress != null ? progress.value : 0.0,
              end: cardIndex / shuffledCardsToStudy.length)
          .animate(
              CurvedAnimation(curve: Curves.fastOutSlowIn, parent: controller));
      controller.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (card == null) {
      content = Center(
          child: Text("Done!", style: Theme.of(context).textTheme.display1));
    } else if (inReview) {
      content = review(context);
    } else {
      content = question(context);
    }
    return Scaffold(
      key: _scaffoldKey,
      appBar: widget.appBar,
      body: Column(
        children: <Widget>[
          AnimatedBuilder(
              animation: progress,
              builder: (context, _) =>
                  LinearProgressIndicator(value: progress.value)),
          Expanded(child: content)
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: inReview
          ? reviewActionButton(context)
          : questionActionButton(context),
    );
  }

  Widget question(BuildContext context) {
    return Question(
      deck: widget.deck,
      cards: widget.cards,
      card: card,
      answer: answer,
      answerChanged: (answer) {
        setState(() {
          this.answer = answer;
        });
      },
    );
  }

  FloatingActionButton reviewActionButton(BuildContext context) {
    return FloatingActionButton.extended(
      label: Text("Continue"),
      icon: Icon(Icons.navigate_next),
      onPressed: () {
        finishReview(context);
      },
    );
  }

  FloatingActionButton questionActionButton(BuildContext context) {
    if (answer == null) {
      return null;
    }
    return FloatingActionButton.extended(
      label: Text("Check"),
      icon: Icon(Icons.check),
      onPressed: () {
        check(context, answer.text);
      },
    );
  }

  void check(BuildContext context, String answer) {
    //TODO: dart doesn't have a proper unicode solution wtf?
    if (_isCorrect(card, answer)) {
      _scaffoldKey.currentState
          .showSnackBar(snackBar(context, "Correct!", Colors.greenAccent));
      next(context, correct: true);
    } else {
      _scaffoldKey.currentState
          .showSnackBar(snackBar(context, "Wrong!", Colors.redAccent));
      setState(() {
        inReReview = true;
      });
    }
  }

  static bool _isCorrect(Card card, String answer) {
    if (_answerMatches(card.back, answer)) {
      return true;
    }
    for (var alternative in card.alternatives) {
      if (_answerMatches(alternative, answer)) {
        return true;
      }
    }
    return false;
  }

  static bool _answerMatches(String correct, String answer) {
    //TODO: dart doesn't have a proper unicode solution wtf?
    if (answer.toLowerCase() == correct.toLowerCase()) {
      return true;
    } else {
      return false;
    }
  }

  void next(BuildContext context, {bool correct}) async {
    if (correct != null) {
      var updatedCard = correct ? card.upgrade() : card.reset();
      await (await widget.repo).updateCardStats(card.id,
          reviewed: DateTime.now(),
          difficulty: updatedCard.difficulty,
          interval: updatedCard.interval);
    }
    pickCard();
    if (cardIndex >= shuffledCardsToStudy.length) {
      progress.addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          Navigator.pop(context);
        }
      });
    }
  }

  void finishReview(BuildContext context) {
    var correct = inReReview ? false : null;
    setState(() {
      inFirstReview = false;
      inReReview = false;
    });
    next(context, correct: correct);
  }

  Widget review(BuildContext context) => Review(deck: widget.deck, card: card);

  SnackBar snackBar(BuildContext context, String text, Color color) {
    return SnackBar(
      backgroundColor: Theme.of(context).primaryColor,
      content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(text, style: TextStyle(color: color, inherit: true))),
    );
  }
}

class Question extends StatelessWidget {
  final Deck deck;
  final List<Card> cards;
  final Card card;
  final Answer<dynamic> answer;
  final AnswerChanged<dynamic> answerChanged;

  const Question({
    Key key,
    @required this.deck,
    @required this.cards,
    @required this.card,
    @required this.answerChanged,
    this.answer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget child;
    if (card.difficulty == 0) {
      child = MultipleChoice(
          cards: cards,
          card: card,
          answer: answer as Answer<int>,
          answerChanged: answerChanged);
    } else {
      child = TextResponse(
          card: card, answer: answer, answerChanged: answerChanged);
    }

    return Column(
      children: <Widget>[
        Expanded(
            child: Center(
                child: SingleChildScrollView(
                  child: pad(ReadOnTap(
                      read: card.front,
                      language: deck.cardFrontLanguage,
                      child: Text(card.front,
                          style: Theme.of(context).textTheme.display1))),
                ))),
        Expanded(child: child)
      ],
    );
  }
}

typedef AnswerChanged<T>(Answer<T> answer);

class Answer<T> {
  final String text;
  final T value;

  Answer({@required this.text, this.value});
}

class MultipleChoice extends StatefulWidget {
  final List<Card> cards;
  final Card card;
  final Answer<int> answer;
  final AnswerChanged<int> answerChanged;
  final DeckShuffler shuffler;

  MultipleChoice({
    Key key,
    @required this.cards,
    @required this.card,
    @required this.answerChanged,
    this.answer,
    DeckShuffler shuffler,
  })  : this.shuffler = shuffler ?? DeckShuffler(),
        super(key: key);

  @override
  State<StatefulWidget> createState() => _MultipleChoice();
}

class _MultipleChoice extends State<MultipleChoice> {
  List<Card> choices = List();

  @override
  Widget build(BuildContext context) {
    if (widget.answer == null) {
      choices = widget.shuffler.pickChoices(widget.cards, widget.card.id);
    }
    var radioChoices = List<Widget>();
    for (int index = 0; index < choices.length; index++) {
      var card = choices[index];
      radioChoices.add(RadioListTile<int>(
        value: card.id,
        groupValue: widget.answer != null ? widget.answer.value : null,
        title: Text(card.back + (card.hasNotes ? " (${card.notes})" : '')),
        onChanged: (value) {
          widget.answerChanged(Answer<int>(
              value: value, text: choices.firstWhere(Card.withId(value)).back));
        },
      ));
    }
    return Column(
      children: radioChoices,
    );
  }
}

class TextResponse extends StatefulWidget {
  final Card card;
  final Answer<void> answer;
  final AnswerChanged<void> answerChanged;

  const TextResponse({
    Key key,
    @required this.card,
    @required this.answerChanged,
    this.answer,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _TextResponseState();
}

class _TextResponseState extends State<TextResponse> {
  TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.answer == null) {
      controller.clear();
    }
    return pad(TextField(
        autofocus: true,
        controller: controller,
        onChanged: (answer) {
          widget.answerChanged(answer.isNotEmpty ? Answer(text: answer) : null);
        }));
  }
}

class Review extends StatelessWidget {
  final Deck deck;
  final Card card;

  Review({Key key, @required this.deck, @required this.card}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      pad(Center(
          child: ReadOnTap(
        read: card.front,
        language: deck.cardFrontLanguage,
        child: Text(
          card.front,
          style: Theme.of(context).textTheme.display1,
          textAlign: TextAlign.center,
        ),
      ))),
      Expanded(
          child: new Padding(
        padding: const EdgeInsets.only(bottom: 44.0),
        child: Center(
            child: ReadOnTap(
          read: card.back,
          language: deck.cardBackLanguage,
          child: Text(
            card.back + (card.hasNotes ? "\n(${card.notes})" : ''),
            style: Theme.of(context).textTheme.display2,
            textAlign: TextAlign.center,
          ),
        )),
      )),
    ]);
  }
}

class ReadOnTap extends StatelessWidget {
  final String read;
  final String language;
  final Widget child;

  const ReadOnTap({Key key, this.read, this.language, @required this.child})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        child: child,
        onTap: () {
          tts().speak(read, language: language);
        });
  }
}

Widget pad(Widget child) =>
    Padding(padding: const EdgeInsets.all(16.0), child: child);

String notEmpty(String text) {
  if (text.trim().length == 0) {
    return 'Must not be empty';
  } else {
    return null;
  }
}
