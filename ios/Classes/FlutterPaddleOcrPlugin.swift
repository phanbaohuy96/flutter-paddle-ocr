import Flutter
import UIKit

// iOS is not yet implemented. Tracking port of
// https://github.com/PaddlePaddle/Paddle-Lite-Demo/tree/develop/ocr/ios/ppocr_demo
// (PaddleOCR's own deploy/ios_demo/ is a stub pointing at that repo).
public class FlutterPaddleOcrPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "flutter_paddle_ocr",
      binaryMessenger: registrar.messenger()
    )
    let instance = FlutterPaddleOcrPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "create", "recognize", "dispose":
      result(FlutterError(
        code: "UNIMPLEMENTED",
        message: "iOS support for flutter_paddle_ocr is not yet implemented.",
        details: nil
      ))
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
