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
                  deck: deck,
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
                                      deck: deck,
                                    )));
                      })
                  : null);
        });
  }
}

class EditDeck extends StatefulWidget {
  final String title;
  final DeckRepository repo;
  final Deck deck;
  final CardRepository cardRepo;

  EditDeck({
    Key key,
    @required this.title,
    @required this.repo,
    @required this.deck,
  })  : cardRepo = repo.cards(deck.id),
        super(key: key);

  deleteDeck() {
    repo.deleteDeck(deck.id);
  }

  @override
  State<StatefulWidget> createState() => _EditDeckState();
}

class _EditDeckState extends State<EditDeck> {
  final GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();
  final GlobalKey<FormState> _formKey = new GlobalKey<FormState>();

  addCards(BuildContext context) {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => AddCards(
                  deck: widget.deck,
                  repo: widget.cardRepo,
                )));
  }

  editTitle(BuildContext context) {
//    showDialog(context: _scaffoldKey.currentState.context, builder: (context) {
//      return AlertDialog
//        pad(Form(
//          key: _formKey,
//          child: TextFormField(
//            autofocus: true,
//            controller: TextEditingController(text: widget.deck.title),
//            validator: notEmpty,
//            onSaved: (text) {
//              widget.repo.updateDeckTitle(widget.deck.id, text);
//            },
//          ),
//        ));
//    });
  }

  saveTitle(BuildContext context) {
    if (_formKey.currentState.validate()) {
      _formKey.currentState.save();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(widget.deck.title),
        actions: <Widget>[
          IconButton(
            tooltip: "Edit Title",
            icon: Icon(Icons.edit),
            onPressed: () => editTitle(context),
          ),
          PopupMenuButton(
            itemBuilder: (context) {
              return [
                PopupMenuItem(
                  child: Text("Delete"),
                )
              ];
            },
            onSelected: (value) {
              widget.deleteDeck();
              Navigator.pop(context);
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
                        children: <Widget>[Text(card.front), Text(card.back)],
                      ),
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => EditCard(
                                      deck: widget.deck,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        icon: Icon(Icons.add),
        label: Text("Add Cards"),
        onPressed: () => addCards(context),
      ),
    );
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

  insertCard({String front, String back}) {
    repo.insertCard(deck.id, front: front, back: back);
  }

  @override
  State<StatefulWidget> createState() => _AddCardsState();
}

class _AddCardsState extends State<AddCards> {
  final GlobalKey<CardFormState> formKey = new GlobalKey<CardFormState>();

  bool addCard() {
    var state = formKey.currentState;
    if (state.validate()) {
      state.save();
      widget.insertCard(front: state.cardFront, back: state.cardBack);
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
            CardForm(key: formKey),
            Expanded(child: Container()),
            ButtonBar(
              children: <Widget>[
                FlatButton(
                  child: Text("Next"),
                  onPressed: addCard,
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

  updateCard({String front, String back}) {
    repo.updateCard(card.id, front: front, back: back);
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
          children: <Widget>[
            CardForm(key: formKey, card: widget.card),
            Expanded(child: Container()),
            ButtonBar(
              children: <Widget>[
                FlatButton(
                    child: Text("Save"),
                    onPressed: () {
                      var state = formKey.currentState;
                      if (state.validate()) {
                        state.save();
                        widget.updateCard(
                            front: state.cardFront, back: state.cardBack);
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
  String cardFront;
  String cardBack;

  bool validate() => _formKey.currentState.validate();

  save() => _formKey.currentState.save();

  @override
  void initState() {
    super.initState();
    var card = widget.card;
    cardFront = card != null ? card.front : "";
    cardBack = card != null ? card.back : "";
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        key: _formKey,
        child: pad(Column(
          children: <Widget>[
            TextFormField(
              decoration: InputDecoration(labelText: "Front"),
              controller: TextEditingController(text: cardFront),
              autofocus: true,
              validator: notEmpty,
              onSaved: (text) {
                cardFront = text;
              },
            ),
            TextFormField(
              decoration: InputDecoration(labelText: "Back"),
              controller: TextEditingController(text: cardBack),
              validator: notEmpty,
              onSaved: (text) {
                cardBack = text;
              },
            ),
          ],
        )));
  }
}

class DeckShuffler {
  const DeckShuffler();

  List<Card> shuffled(List<Card> cards) {
    var shuffled = List.from<Card>(cards);
    shuffled.shuffle();
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
          return StudyDeckContent(appBar: appBar, cards: snapshot.data);
        } else {
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

  const StudyDeckContent(
      {Key key,
      @required this.appBar,
      @required this.cards,
      this.shuffler = const DeckShuffler()})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _StudyDeckContentState();
}

class _StudyDeckContentState extends State<StudyDeckContent> {
  List<Card> shuffledCardsToStudy;
  int currentCard = -1;
  List<Card> choices;
  int selectedChoice;
  bool inReview = false;

  @override
  void initState() {
    super.initState();
    shuffledCardsToStudy = widget.shuffler.shuffled(widget.cards);
    pickCard();
  }

  pickCard() {
    setState(() {
      currentCard++;
      selectedChoice = null;
      choices = widget.shuffler
          .pickChoices(widget.cards, shuffledCardsToStudy[currentCard].id);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: widget.appBar,
      body: Column(
        children: <Widget>[
          progress(context),
          Expanded(child: inReview ? review(context) : multipleChoice(context))
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        label: Text("Check"),
        icon: Icon(Icons.check),
        onPressed: null,
      ),
    );
  }

  Widget progress(BuildContext context) {
    return LinearProgressIndicator(
        value: currentCard / shuffledCardsToStudy.length);
  }

  Widget multipleChoice(BuildContext context) {
    var radioChoices = List<Widget>();
    for (int index = 0; index < choices.length; index++) {
      radioChoices.add(RadioListTile(
        value: choices[index].id,
        groupValue: selectedChoice,
        title: Text(choices[index].back),
        onChanged: (value) {
          setState(() {
            selectedChoice = value;
          });
        },
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Expanded(
            child: Center(
                child: pad(Text(shuffledCardsToStudy[currentCard].front,
                    style: Theme.of(context).textTheme.display1)))),
        Column(children: radioChoices),
        pad(RaisedButton(
          child: Text("Check"),
          onPressed: selectedChoice != null
              ? () {
                  if (shuffledCardsToStudy
                          .firstWhere(Card.withId(selectedChoice))
                          .back ==
                      shuffledCardsToStudy[currentCard].back) {
                    Scaffold.of(context).showSnackBar(
                        snackBar(context, "Correct!", Colors.greenAccent));
                    next(context);
                  } else {
                    Scaffold.of(context).showSnackBar(
                        snackBar(context, "Wrong!", Colors.redAccent));
                    setState(() {
                      inReview = true;
                    });
                  }
                }
              : null,
        ))
      ],
    );
  }

  next(BuildContext context) {
    if (currentCard < shuffledCardsToStudy.length - 1) {
      pickCard();
    } else {
      Navigator.pop(context);
    }
  }

  Widget review(BuildContext context) => Review(
      card: widget.cards[currentCard],
      finishReview: () {
        setState(() {
          inReview = false;
        });
        next(context);
      });

  SnackBar snackBar(BuildContext context, String text, Color color) {
    return SnackBar(
      backgroundColor: Theme.of(context).primaryColor,
      content: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(text, style: TextStyle(color: color, inherit: true))),
    );
  }
}

class Review extends StatelessWidget {
  final Card card;
  final Function finishReview;

  const Review({Key key, @required this.card, @required this.finishReview})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      pad(Center(child: Text(card.front))),
      Expanded(
          child: Center(
              child: Text(
        card.back,
        style: Theme.of(context).textTheme.display1,
      ))),
      pad(RaisedButton(
        child: Text("Continue"),
        onPressed: finishReview,
      ))
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
