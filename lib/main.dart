import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  static const MethodChannel methodChannel =
      MethodChannel('samples.flutter.io/stopStreaming');
  static const EventChannel eventChannel =
      EventChannel('samples.flutter.io/streaming');

  @override
  void initState() {
    super.initState();
    eventChannel.receiveBroadcastStream().listen((event) {
      print(event["plat_no"]);
      //print(map["base64_image"]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final String viewType = '<platform-view-type>';
    final Map<String, dynamic> creationParams = <String, dynamic>{};
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      // return widget on Android.
      case TargetPlatform.iOS:
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.title),
          ),
          body: UiKitView(
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
          ),
          floatingActionButton: FloatingActionButton(
                  onPressed: _stopStreaming,
                  child: const Icon(Icons.stop),
                ),
        );
      default:
        throw UnsupportedError("Unsupported platform view");
    }
  }

  Future<void> _stopStreaming() async {
    try {
      final int? result = await methodChannel.invokeMethod('stopStreaming');
      print(result);
    } on PlatformException {
      print(e);
    }
    setState(() {});
  }
}
