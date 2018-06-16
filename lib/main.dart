import 'package:flutter/material.dart' hide Card;
import 'package:flutter_study/models.dart';
import 'package:flutter_study/repo.dart';

void main() => runApp(App());

class App extends StatelessWidget {
  final DeckRepository repo = DeckRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        title: 'Flutter Study',
        theme: ThemeData(
          accentColor: Colors.blueAccent,
          brightness: Brightness.dark,
        ),
        home: HomePage(repo: repo));
  }
}

typedef Widget LoadingWidgetBuilder<T>(BuildContext context, T data);
typedef Widget ChromeBuilder(BuildContext context, Widget body);

class LoadingContent<T> extends StatelessWidget {
  final AsyncSnapshot<T> snapshot;
  final LoadingWidgetBuilder builder;

  const LoadingContent({Key key, this.snapshot, this.builder})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    var content;
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
  final DeckRepository repo;

  const HomePage({Key key, this.repo}) : super(key: key);

  studyDeck(BuildContext context, Deck deck) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => StudyDeck(deck: deck, repo: repo)));
  }

  editDeck(BuildContext context, Deck deck) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => EditDeck(
                  title: "Edit Deck",
                  repo: repo,
                  deckId: deck.id,
                )));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: repo.decks,
        builder: (context, snapshot) {
          return Scaffold(
              appBar: AppBar(title: Text('Flutter Study')),
              body: LoadingContent(
                  snapshot: snapshot,
                  builder: (context, decks) {
                    return Column(children: <Widget>[
                      Expanded(
                          child: ListView.builder(
                        itemCount: decks.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: new Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(decks[index].title),
                                Text(decks[index].cardCount.toString()),
                              ],
                            ),
                            onTap: () {
                              if (decks[index].cardCount > 0) {
                                studyDeck(context, decks[index]);
                              } else {
                                editDeck(context, decks[index]);
                              }
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
                        var deck = await repo.insertDeck(
                            title: "Deck ${snapshot.data.length + 1}");
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => EditDeck(
                                      title: 'New Deck',
                                      repo: repo,
                                      deckId: deck.id,
                                    )));
                      })
                  : null);
        });
  }
}

class EditDeck extends StatefulWidget {
  final String title;
  final DeckRepository repo;
  final int deckId;
  final CardRepository cardRepo;

  EditDeck({
    Key key,
    @required this.title,
    @required this.repo,
    @required this.deckId,
  })  : cardRepo = repo.cards(deckId),
        super(key: key);

  deleteDeck() {
    repo.deleteDeck(deckId);
  }

  resetDeck() {
    repo.resetDeck(deckId);
  }

  @override
  State<StatefulWidget> createState() => _EditDeckState();
}

class _EditDeckState extends State<EditDeck> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  addCards(BuildContext context, Deck deck) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddCards(
                  deck: deck,
                  repo: widget.cardRepo,
                )));
  }

  editTitle(BuildContext context, Deck deck) {
    var context = _scaffoldKey.currentState.context;
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            content: pad(Form(
              key: _formKey,
              child: TextFormField(
                autofocus: true,
                controller: TextEditingController(text: deck.title),
                validator: notEmpty,
                onSaved: (text) {
                  widget.repo.updateDeckTitle(deck.id, text);
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

  saveTitle(BuildContext context) {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return new StreamBuilder(
        stream: widget.repo.deck(widget.deckId),
        builder: (context, snapshot) {
          var deck = snapshot.data;
          return Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: snapshot.hasData ? Text(deck.title) : null,
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
                        child: Text("Delete"),
                        value: 0,
                      ),
                      PopupMenuItem(
                        child: Text("Reset"),
                        value: 1,
                      )
                    ];
                  },
                  onSelected: (value) {
                    if (value == 0) {
                      widget.deleteDeck();
                      Navigator.pop(context);
                    } else if (value == 1) {
                      widget.resetDeck();
                    }
                  },
                ),
              ],
            ),
            body: Column(children: <Widget>[
              Expanded(
                  child: StreamBuilder(
                stream: widget.cardRepo.cards,
                builder: (context, snapshot) {
                  return LoadingContent(
                    snapshot: snapshot,
                    builder: (context, cards) {
                      return ListView.builder(
                        itemCount: cards.length,
                        itemBuilder: (context, index) {
                          var card = cards[index];
                          return ListTile(
                            title: new Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: <Widget>[
                                Text(card.front),
                                Text(card.back)
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
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

class AddCards extends StatefulWidget {
  AddCards({
    Key key,
    @required this.deck,
    @required this.repo,
  }) : super(key: key);

  final Deck deck;
  final CardRepository repo;

  insertCard({String front, String back, String notes}) {
    repo.insertCard(deck.id, front: front, back: back, notes: notes);
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
          children: <Widget>[
            Expanded(
                child: SingleChildScrollView(child: CardForm(key: formKey))),
            ButtonBar(
              children: <Widget>[
                FlatButton(
                  child: Text("Next"),
                  onPressed: () {
                    if (addCard()) {
                      formKey.currentState.clear();
                    }
                  },
                ),
                FlatButton(
                    child: Text("Done"),
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
  final CardRepository repo;

  deleteCard() {
    repo.deleteCard(card.id);
  }

  updateCard({String front, String back, String notes}) {
    repo.updateCardContents(card.id, front: front, back: back, notes: notes);
  }

  @override
  State<StatefulWidget> createState() => _EditCardState();
}

class _EditCardState extends State<EditCard> {
  final GlobalKey<CardFormState> formKey = new GlobalKey<CardFormState>();

  delete(BuildContext context) {
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

  bool validate() => _formKey.currentState.validate();

  clear() {
    cardFront.clear();
    cardBack.clear();
    cardNotes.clear();
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
    cardFront.text = card != null ? card.front : "";
    cardBack.text = card != null ? card.back : "";
    cardNotes.text = card != null ? card.notes : "";
  }

  @override
  void dispose() {
    frontFocusNode.dispose();
    cardFront.dispose();
    cardBack.dispose();
    cardNotes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: pad(Column(
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
  final DeckRepository repo;
  final CardRepository cardRepo;

  StudyDeck(
      {@required this.deck,
      @required this.repo,
      this.shuffler = const DeckShuffler()})
      : cardRepo = repo.cards(deck.id);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: cardRepo.cards,
      builder: (context, snapshot) {
        var appBar = AppBar(title: Text(deck.title));
        if (snapshot.hasData) {
          return StudyDeckContent(
              appBar: appBar, cards: snapshot.data, repo: cardRepo);
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
  final Widget appBar;
  final List<Card> cards;
  final DeckShuffler shuffler;
  final CardRepository repo;

  const StudyDeckContent(
      {Key key,
      @required this.appBar,
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
  Answer answer;

  get inReview => inFirstReview || inReReview;

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

  pickCard() {
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
    var content;
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

  check(BuildContext context, String answer) {
    //TODO: dart doesn't have a proper unicode solution wtf?
    if (answer.toLowerCase() == card.back.toLowerCase()) {
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

  next(BuildContext context, {bool correct}) {
    if (correct != null) {
      var updatedCard = correct ? card.upgrade() : card.reset();
      widget.repo.updateCardStats(card.id,
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

  finishReview(BuildContext context) {
    var correct = inReReview ? false : null;
    setState(() {
      inFirstReview = false;
      inReReview = false;
    });
    next(context, correct: correct);
  }

  Widget review(BuildContext context) => Review(card: card);

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
  final List<Card> cards;
  final Card card;
  final Answer answer;
  final AnswerChanged answerChanged;

  const Question({
    Key key,
    @required this.cards,
    @required this.card,
    @required this.answerChanged,
    this.answer,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    var child;
    if (card.difficulty == 0) {
      child = MultipleChoice(
          cards: cards,
          card: card,
          answer: answer,
          answerChanged: answerChanged);
    } else {
      child = TextResponse(
          card: card, answer: answer, answerChanged: answerChanged);
    }

    return Column(
      children: <Widget>[
        Expanded(
            child: Center(
                child: pad(Text(card.front,
                    style: Theme.of(context).textTheme.display1)))),
        Expanded(child: child)
      ],
    );
  }
}

typedef AnswerChanged(Answer answer);

class Answer {
  final String text;
  final dynamic value;

  Answer({@required this.text, this.value});
}

class MultipleChoice extends StatefulWidget {
  final List<Card> cards;
  final Card card;
  final Answer answer;
  final AnswerChanged answerChanged;
  final DeckShuffler shuffler;

  MultipleChoice({
    Key key,
    @required this.cards,
    @required this.card,
    @required this.answerChanged,
    this.answer,
    shuffler,
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
      radioChoices.add(RadioListTile(
        value: card.id,
        groupValue: widget.answer != null ? widget.answer.value : null,
        title: Text(card.back + (card.hasNotes ? " (${card.notes})" : '')),
        onChanged: (value) {
          widget.answerChanged(Answer(
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
  final Answer answer;
  final AnswerChanged answerChanged;

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
  final Card card;

  const Review({Key key, @required this.card}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      pad(Center(
          child: Text(
        card.front,
        style: Theme.of(context).textTheme.display1,
        textAlign: TextAlign.center,
      ))),
      Expanded(
          child: new Padding(
        padding: const EdgeInsets.only(bottom: 44.0),
        child: Center(
            child: Text(
          card.back + (card.hasNotes ? "\n(${card.notes})" : ''),
          style: Theme.of(context).textTheme.display2,
          textAlign: TextAlign.center,
        )),
      )),
    ]);
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
