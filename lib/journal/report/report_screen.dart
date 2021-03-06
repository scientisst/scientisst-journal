import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:scientisst_journal/data/history_entry.dart';
import 'package:scientisst_journal/journal/report/input/accelerometer_input.dart';
import 'package:scientisst_journal/journal/report/report_entries_list.dart';
import 'package:share/share.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:buttons_tabbar/buttons_tabbar.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:scientisst_journal/data/report/entries/report_entry.dart';
import 'package:scientisst_journal/journal/report/cards/report_entry_card.dart';
import 'package:scientisst_journal/journal/report/input/text_input.dart';
import 'package:scientisst_journal/journal/report/input/camera_input.dart';
import 'package:scientisst_journal/journal/report/input/image_input.dart';
import 'package:scientisst_journal/utils/database/database.dart';
import 'package:flutter_svg/flutter_svg.dart';

const ANIMATION_DURATION = Duration(milliseconds: 250);
const BAR_MIN_HEIGHT = 88.0;

class ReportScreen extends StatefulWidget {
  const ReportScreen(this.report, {Key key}) : super(key: key);

  final Report report;

  @override
  _ReportScreenState createState() => _ReportScreenState();
}

abstract class ReportScreenState extends State<ReportScreen> {
  TextEditingController _titleController;
  bool _editTitle = false;
  bool _panning = false;
  FocusNode _titleFocus = FocusNode();
  double _halfOffset = 0;
  Duration _animationDuration = Duration.zero;
  final List<Tab> _tabs = [
    Tab(
      icon: Icon(Icons.message),
    ),
    Tab(
      icon: Icon(Icons.camera_alt),
    ),
    Tab(
      icon: Icon(Icons.photo),
    ),
    Tab(
      icon: SvgPicture.asset(
        "assets/icons/sensors/accelerometer.svg",
        semanticsLabel: 'Accelerometer',
        width: 28,
        height: 28,
        color: Colors.black,
      ),
    ),
  ];
  List<Widget> _tabViews;
  List<ReportEntry> _entries = [];
  StreamSubscription<List<ReportEntry>> _stream;
  ScrollController _scrollController = ScrollController();
  TabController _tabController;
}

class _ReportScreenState extends ReportScreenState
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabs.length,
      vsync: this,
    );
    _tabViews = [
      TextInput(_addNote),
      CameraInput(_addImage),
      ImageInput(_addImage),
      AccelerometerInput(_addAccelerometer),
    ];
    _titleController = TextEditingController(text: widget.report.title);
    _stream = ReportFunctions.getReportEntries(widget.report.id)
        .listen((List<ReportEntry> entries) {
      setState(() => _entries = entries);
      _scrollToBottom();
    });

    _tabController.addListener(_raiseBottom);
  }

  @override
  void dispose() {
    _stream?.cancel();
    super.dispose();
  }

  void _raiseBottom() {
    FocusScope.of(context).unfocus();
    if (_halfOffset > 0) {
      setState(() {
        _halfOffset = 0;
      });
    }
  }

  void _toggleEditTitle() {
    _titleController.text = _titleController.text.trim();
    if (_editTitle) {
      ReportFunctions.changeTitle(widget.report.id, _titleController.text);
    } else {
      _titleFocus.requestFocus();
    }
    setState(() {
      _editTitle = !_editTitle;
    });
  }

  Future<void> _addNote(String text) async {
    if (text.isNotEmpty) {
      await ReportFunctions.addReportNote(widget.report.id, text);
    }
  }

  Future<void> _addImage(Uint8List imageBytes) async {
    if (imageBytes != null && imageBytes.isNotEmpty) {
      await ReportFunctions.addReportImage(widget.report.id, imageBytes);
    }
  }

  Future<void> _addAccelerometer(File file, List<String> labels) async {
    if (file != null && file.existsSync()) {
      await ReportFunctions.addReportAccelerometer(
          widget.report.id, file, labels);
      file.delete();
    }
  }

  void _scrollToBottom() => _scrollController.animateTo(
        0,
        duration: Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _appBar,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double halfHeight = constraints.maxHeight / 2;
            if (!_panning) {
              if (_halfOffset < -halfHeight / 2) {
                _halfOffset = -halfHeight;
              } else if (_halfOffset >= halfHeight / 2) {
                if (!_editTitle) FocusScope.of(context).unfocus();
                _halfOffset = halfHeight;
              } else {
                _halfOffset = 0;
              }
            }
            return GestureDetector(
              onPanStart: (_) {
                _panning = true;
                _animationDuration = Duration.zero;
              },
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
                setState(() {
                  _panning = false;
                  _animationDuration = ANIMATION_DURATION;
                });
              },
              child: Stack(
                children: [
                  AnimatedContainer(
                    constraints: BoxConstraints(
                      minHeight: halfHeight,
                      maxHeight: halfHeight * 2 - BAR_MIN_HEIGHT,
                    ),
                    height: halfHeight + _halfOffset,
                    duration: _animationDuration,
                    child: ReportEntriesList(_entries, _scrollController),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: AnimatedContainer(
                      constraints: const BoxConstraints(
                        minHeight: BAR_MIN_HEIGHT,
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
                            child: GestureDetector(
                              onTap: _raiseBottom,
                              child: ButtonsTabBar(
                                controller: _tabController,
                                tabs: _tabs,
                                contentPadding: EdgeInsets.zero,
                                backgroundColor: Theme.of(context).primaryColor,
                                unselectedBackgroundColor: Colors.grey[300],
                                labelStyle: TextStyle(color: Colors.black),
                                duration: 150,
                              ),
                            ),
                          ),
                          halfHeight - _halfOffset - BAR_MIN_HEIGHT > 64
                              ? Expanded(
                                  child: TabBarView(
                                      controller: _tabController,
                                      children: _tabViews),
                                )
                              : Container(),
                        ],
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
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                cursorColor: Colors.white,
                decoration: InputDecoration.collapsed(hintText: ""),
              )
            : Text(_titleController.text.trim()),
        actions: [
          IconButton(
            icon: Icon(_editTitle ? Icons.check : Icons.edit),
            onPressed: _toggleEditTitle,
          ),
          _optionsMenu,
        ],
      );

  PopupMenuButton get _optionsMenu => PopupMenuButton<Function>(
        icon: Icon(
          Icons.more_vert,
        ),
        onSelected: (function) => function(),
        itemBuilder: (BuildContext context) => <PopupMenuEntry<Function>>[
          PopupMenuItem<Function>(
            value: _saveAs,
            child: _optionsEntry(
              "Save As",
              Icon(Icons.save),
            ),
          ),
          PopupMenuItem<Function>(
            value: _export,
            child: _optionsEntry(
              "Share",
              Icon(Icons.share),
            ),
          ),
          PopupMenuItem<Function>(
            value: _delete,
            child: _optionsEntry(
              "Delete",
              Icon(Icons.delete),
            ),
          )
        ],
      );

  Widget _optionsEntry(String text, Widget icon) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTheme(
              data: IconThemeData(
                color: Colors.grey,
              ),
              child: icon),
          SizedBox(width: 16),
          Text(text)
        ],
      );

  Future<void> _saveAs() async {
    if (await Permission.storage.request().isGranted) {
      String result = await FilePicker.platform.getDirectoryPath();
      if (result != null) {
        await ReportFunctions.exportReport(widget.report.id, path: result);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Saved!"),
          ),
        );
      } else {
        // User canceled the picker
      }
    }
  }

  Future<void> _export() async {
    File file = await ReportFunctions.exportReport(widget.report.id);
    Share.shareFiles([file.path], text: _titleController.text.trim());
  }

  Future<void> _delete() async {
    final bool delete = await showDialog(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: Text("Delete Report"),
            content: Text("This data will be permanently lost."),
            actions: [
              CupertinoDialogAction(
                child: Text(
                  "Cancel",
                ),
                isDefaultAction: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
              CupertinoDialogAction(
                child: Text(
                  "Delete",
                ),
                isDestructiveAction: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;
    if (delete) {
      Navigator.of(context).popUntil((Route route) => route.isFirst);
      Database.deleteHistoryEntry(widget.report.id);
    }
  }
}
