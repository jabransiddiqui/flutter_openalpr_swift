# flutter_openalpr

[OpenALPR](https://github.com/openalpr/openalpr) integration for Flutter. Provides a camera component that recognizes license plates in real-time. Supports iOS only for time being.

<img alt="OpenALPR iOS Demo Video" src="https://cdn-images-1.medium.com/max/800/1*u1nTJMFc34aDLTPCIr0-cQ.gif" width=200 height=350 />

## Requirements

- iOS 9+

## Integration

### Integration libs in xCode

Start by adding the classes and frameworks to you xCode project.

```sh
Copy below folder and files:

         Runner/classes <- Folder
         Runner/runtime_data <- Folder 
         Runner/frameworks <- Folder 
         Runner/openalpr.conf <- File
         Runner/FLNativeViewFactory.swift <- File

Import below refreneces to your 'Runner-Bridging-Header.h' File

#include "ALPRCamera.h"
#include "ALPRCameraManager.h"

Add Below code to your 'AppDelegate.swift'
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
       ....
        
        weak var registrar = self.registrar(forPlugin: "plugin-name")
        
        let factory = FLNativeViewFactory(messenger: registrar!.messenger())
        self.registrar(forPlugin: "<plugin-name>")!.register(
            factory,
            withId: "<platform-view-type>")
        
        guard let controller = window?.rootViewController as? FlutterViewController else {
            fatalError("rootViewController is not type FlutterViewController")
        }
        let stopChannel = FlutterMethodChannel(name: ChannelName.stopStreaming,
                                               binaryMessenger: controller.binaryMessenger)
        stopChannel.setMethodCallHandler({(call: FlutterMethodCall, result: FlutterResult) -> Void in
            if call.method == "stopStreaming" {
                NotificationCenter.default.post(name: Notification.Name("stopStreaming"), object: nil)
                result(Int(1))
            }else if  call.method == "startStreaming" {
                NotificationCenter.default.post(name: Notification.Name("startStreaming"), object: nil)
                result(Int(1))
            }else {
                result(FlutterMethodNotImplemented)
            }
           
        })
        
        let chargingChannel = FlutterEventChannel(name: ChannelName.streaming,
                                                  binaryMessenger: controller.binaryMessenger)
        chargingChannel.setStreamHandler(self)
        
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    
    public func onListen(withArguments arguments: Any?,
                         eventSink: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = eventSink
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(self.onStreaming),
            name: Notification.Name("onStreaming"),
            object: nil)
        return nil
    }
    
    @objc private func onStreaming(notification: NSNotification) {
        guard let eventSink = eventSink else {
            return
        }
        if let dict = notification.userInfo as NSDictionary? {
            eventSink(dict)
        }
        
    }
    
    
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        NotificationCenter.default.removeObserver(self)
        eventSink = nil
        return nil
    }
}

```


### iOS Specific Setup


#### Camera Permissions

- Add an entry for `NSCameraUsageDescription` in your `info.plist` explaining why your app will use the camera. If you forget to add this, your app will crash!

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  ...
 	<key>NSCameraUsageDescription</key>
 	<string>We use your camera for license plate recognition to make it easier for you to add your vehicle.</string>
</dict>
```

#### Bitcode

Because the OpenCV binary framework release is compiled without bitcode, the other frameworks built by this script are also built without it, which ultimately means your Xcode project also cannot be built with bitcode enabled. [Per this message](http://stackoverflow.com/a/32728516/868173), it sounds like we want this feature disabled for OpenCV anyway.

To disable bitcode in your project:

- In `Build Settings` → `Build Options`, search for `Enable Bitcode` and set it to `No`.



## Usage in Flutter

OpenALPR exposes a camera component (based on [react-native-camera](https://github.com/lwansbrough/react-native-camera)) that is optimized to run OpenALPR image processing on a live camera stream and send stream of image in base64 and plate number in characters form when a plate is recognized.

```dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      //print(event["base64_image"]);
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

```

### Options

#### `zoom`

The zoon of the camera (Android only). Can be :

0 to 99

#### `aspect`

The aspect ratio of the camera. Can be one of:

- `Aspect.stretch`
- `Aspect.fit`
- `Aspect.fill`

#### `captureQuality`

The resolution at which video frames are captured and analyzed. For completeness, several options are provided. However, it is strongly recommended that you stick with one of the following for the best frame rates and accuracy:

- `CaptureQuality.medium` (480x360)
- `CaptureQuality.480p` (640x480)

#### `country`

Specifies which OpenALPR config file to load, corresponding to the country whose plates you wish to recognize. Currently supported values are:

- `au`
- `br`
- `eu`
- `fr`
- `gb`
- `kr`
- `mx`
- `sg`
- `us`
- `vn2`

#### `stream Channel`

This will received on flutter:

- `plat_no`, representing the recognized license plate string
- `base64_image`, image in form of base64 string

#### `plateOutlineColor`

Hex string specifying the color of the border to draw around the recognized plate. Example: `#ff0000` for red.

#### `showPlateOutline`

This draws an outline over the recognized plate

#### `touchToFocus`

This focuses the camera where the user taps


## Credits

- OpenALPR built from [OpenALPR-iOS](https://github.com/twelve17/openalpr-ios)
- Project scaffold based on [react-native-camera](https://github.com/lwansbrough/react-native-camera)


