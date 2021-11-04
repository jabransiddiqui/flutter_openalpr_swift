import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    
    private var eventSink: FlutterEventSink?
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)
        
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
