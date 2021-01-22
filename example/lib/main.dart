import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:storages/storages.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  FixSizedStorage fixSizedStorage;

  @override
  void initState() {
    super.initState();
    run();
  }

  Future<void> run() async {
    Uint8List bytes = Uint8List(300 * 300 * 4);

    int key = 0;
    bool set = false;
    while (true) {
      fixSizedStorage = FixSizedStorage.fromId('example');
      await fixSizedStorage.init();

      var t1 = DateTime.now().microsecondsSinceEpoch;

      String keyStr = '$key';
      String value = await fixSizedStorage.get(keyStr);
      if (value == null) {
        String path = await fixSizedStorage.touch(keyStr);
        await File(path).writeAsBytes(bytes);
        set = await fixSizedStorage.set(keyStr, path);
      }

      ++key;

      var t2 = DateTime.now().microsecondsSinceEpoch;
      print('value ... $value, set ... $set, ${(t2 - t1) / 1000} ms');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
      ),
    );
  }
}
