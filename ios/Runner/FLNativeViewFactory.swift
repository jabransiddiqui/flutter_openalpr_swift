//
//  FLNativeViewFactory.swift
//  Runner
//
//  Created by eShifa on 04/11/2021.
//

import Flutter
import UIKit


enum ChannelName {
  static let stopStreaming = "samples.flutter.io/stopStreaming"
  static let streaming = "samples.flutter.io/streaming"
}


enum MyFlutterErrorCode {
  static let unavailable = "UNAVAILABLE"
}


class FLNativeViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return FLNativeView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }
}

class FLNativeView: NSObject, FlutterPlatformView {
    private var _view: UIView

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        _view = UIView()
        super.init()
        // iOS views can be created here
        createNativeView(view: _view)
    }

    func view() -> UIView {
        return _view
    }

    func createNativeView(view _view: UIView){
        _view.backgroundColor = UIColor.blue
        let al : ALPRCameraManager = ALPRCameraManager(frame: _view.frame)
        self._view = al;
    }
}

