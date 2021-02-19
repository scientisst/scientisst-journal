import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:flutter/material.dart';
import 'package:scientisst_db/scientisst_db.dart';
import 'package:scientisst_journal/data/report.dart';
import 'package:scientisst_journal/data/reportEntry.dart';
import 'package:scientisst_journal/journal/textInput.dart';
import 'package:scientisst_journal/utils/database.dart';

const ANIMATION_DURATION = Duration(milliseconds: 250);

class ReportWidget extends StatefulWidget {
  const ReportWidget(this.report, {Key key}) : super(key: key);

  final Report report;

  @override
  _ReportWidgetState createState() => _ReportWidgetState();
}

class _ReportWidgetState extends State<ReportWidget> {
  TextEditingController _titleController;
  bool _editTitle = false;
  FocusNode _titleFocus = FocusNode();
  double _halfOffset = 0;
  Duration _animationDuration = Duration.zero;
  List<Tab> _tabs = [
    Tab(
      icon: Icon(Icons.message),
    ),
    Tab(
      icon: Icon(Icons.camera),
    ),
  ];
  List<Widget> _tabViews;

  @override
  void initState() {
    super.initState();
    _tabViews = [
      TextInput(_addNote),
      Center(
        child: Container(),
      ),
    ];

    _titleController = TextEditingController(text: widget.report.title);
  }

  void _toggleEditTitle() {
    _titleController.text = _titleController.text.trim();
    if (_editTitle) {
      ScientISSTdb.instance
          .collection("history")
          .document(widget.report.id)
          .updateData(
        {
          "title": _titleController.text,
        },
      );
    } else {
      _titleFocus.requestFocus();
    }
    setState(() {
      _editTitle = !_editTitle;
    });
  }

  void _addNote(String text) async {
    if (text.isNotEmpty) {
      await Database.addReportNote(widget.report.id, text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double halfHeight = constraints.maxHeight / 2;
            return GestureDetector(
              onPanStart: (_) => _animationDuration = Duration.zero,
              onPanUpdate: (DragUpdateDetails details) {
                final double dy = details.delta.dy;
                if (_halfOffset + dy >= -halfHeight &&
                    _halfOffset + dy < halfHeight) {
                  setState(() {
                    _halfOffset += details.delta.dy;
                  });
                }
              },
              onPanEnd: (_) {
                double newOffset = _halfOffset;
                if (_halfOffset < -halfHeight / 2) {
                  newOffset = -halfHeight;
                } else if (_halfOffset >= halfHeight / 2) {
                  newOffset = halfHeight;
                } else {
                  newOffset = 0;
                }
                setState(() {
                  _animationDuration = ANIMATION_DURATION;
                  _halfOffset = newOffset;
                });
              },
              child: Stack(
                children: [
                  AnimatedContainer(
                    constraints: BoxConstraints(minHeight: halfHeight),
                    height: halfHeight + _halfOffset,
                    duration: _animationDuration,
                    child: StreamBuilder(
                      stream: Database.getReportEntries(widget.report.id),
                      builder: (context,
                              AsyncSnapshot<List<ReportEntry>> snap) =>
                          snap.hasError || snap.data == null
                              ? Container()
                              : ListView.builder(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  itemCount: snap.data.length,
                                  itemBuilder: (context, index) {
                                    final ReportEntry entry = snap.data[index];
                                    return Card(
                                      elevation: 4,
                                      child: Container(
                                        padding: EdgeInsets.all(8),
                                        constraints: BoxConstraints(
                                          maxHeight: 254,
                                          minHeight: 64,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              entry.text,
                                            ),
                                            SizedBox(
                                              height: 8,
                                            ),
                                            Text(
                                              entry.timestamp.toIso8601String(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      constraints: const BoxConstraints(
                        minHeight: 88,
                      ),
                      decoration: const BoxDecoration(
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                              color: Colors.black38,
                              blurRadius: 10.0,
                              offset: Offset(0.0, 0.5))
                        ],
                        color: Colors.white,
                      ),
                      height: halfHeight - _halfOffset,
                      duration: _animationDuration,
                      child: DefaultTabController(
                        length: _tabs.length,
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(360),
                                child: Container(
                                  width: 80,
                                  height: 8,
                                  color: Colors.grey[300],
                                ),
                              ),
                            ),
                            SizedBox(
                              height: 64,
                              child: ButtonsTabBar(
                                tabs: _tabs,
                                contentPadding: EdgeInsets.zero,
                                backgroundColor: Theme.of(context).primaryColor,
                                unselectedBackgroundColor: Colors.grey[400],
                                unselectedLabelStyle:
                                    TextStyle(color: Colors.white),
                                duration: 150,
                              ),
                            ),
                            Expanded(
                              child: TabBarView(children: _tabViews),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  AppBar get _appBar => AppBar(
        title: _editTitle
            ? TextField(
                controller: _titleController,
                focusNode: _titleFocus,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration.collapsed(hintText: ""),
              )
            : Text(_titleController.text),
        actions: [
          IconButton(
            icon: Icon(_editTitle ? Icons.check : Icons.edit),
            onPressed: _toggleEditTitle,
          ),
          IconButton(icon: Icon(Icons.more_vert), onPressed: () {}),
        ],
      );
}