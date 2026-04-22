import 'package:flutter/services.dart';

export 'src/models.dart';

import 'src/models.dart';

const _channel = MethodChannel('flutter_paddle_ocr');

/// On-device OCR engine backed by PaddleOCR + Paddle Lite.
///
/// Create one instance per set of models you load, then call [recognize]
/// repeatedly. Call [dispose] when done to release native memory.
class PaddleOcr {
  PaddleOcr._(this._instanceId);

  final int _instanceId;
  bool _disposed = false;

  /// Loads the detection/recognition (and optional classification) models.
  ///
  /// Paths must be absolute on-device file paths — typically obtained by
  /// copying bundled assets into the app's documents directory, or by
  /// downloading models at first launch.
  ///
  /// [labelPath] is the character dictionary (`ppocr_keys_v1.txt` /
  /// `ic15_dict.txt` / etc. — shipped alongside PP-OCR models).
  static Future<PaddleOcr> create({
    required String detModelPath,
    required String recModelPath,
    required String labelPath,
    String? clsModelPath,
    int cpuThreadNum = 4,
    CpuPower cpuPower = CpuPower.high,
    bool useOpenCL = false,
  }) async {
    final id = await _channel.invokeMethod<int>('create', {
      'detModelPath': detModelPath,
      'recModelPath': recModelPath,
      'clsModelPath': clsModelPath ?? '',
      'labelPath': labelPath,
      'cpuThreadNum': cpuThreadNum,
      'cpuPower': cpuPower.value,
      'useOpenCL': useOpenCL,
    });
    return PaddleOcr._(id!);
  }

  /// Runs OCR on the given image.
  ///
  /// [imageBytes] accepts any format the host platform can decode (PNG, JPEG,
  /// BMP, WebP, HEIF on newer Android, etc.).
  Future<List<OcrResult>> recognize(
    Uint8List imageBytes, {
    int maxSideLen = 960,
    bool runDetection = true,
    bool runClassification = false,
    bool runRecognition = true,
  }) async {
    _checkNotDisposed();
    final raw = await _channel.invokeListMethod<dynamic>('recognize', {
      'instanceId': _instanceId,
      'imageBytes': imageBytes,
      'maxSideLen': maxSideLen,
      'runDetection': runDetection,
      'runClassification': runClassification,
      'runRecognition': runRecognition,
    });
    return (raw ?? const [])
        .cast<Map<dynamic, dynamic>>()
        .map(OcrResult.fromMap)
        .toList(growable: false);
  }

  /// Releases native resources. Safe to call more than once.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _channel.invokeMethod<void>('dispose', {'instanceId': _instanceId});
  }

  void _checkNotDisposed() {
    if (_disposed) {
      throw StateError('PaddleOcr instance has been disposed');
    }
  }
}

/// Shape of one recognized text region.
class OcrResult {
  const OcrResult({
    required this.text,
    required this.confidence,
    required this.points,
    this.isUpsideDown,
    this.angleConfidence,
  });

  /// Recognized string.
  final String text;

  /// Recognition confidence in `[0, 1]`.
  final double confidence;

  /// Polygon (usually 4 points) bounding the text in source-image pixels.
  final List<Offset> points;

  /// `true` if the text was detected as upside-down (180°). Null when angle
  /// classification was not run.
  final bool? isUpsideDown;

  /// Confidence of the angle classification, if run.
  final double? angleConfidence;

  factory OcrResult.fromMap(Map<dynamic, dynamic> map) {
    final rawPoints = (map['points'] as List?) ?? const [];
    return OcrResult(
      text: map['text'] as String? ?? '',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      points: rawPoints
          .cast<List<dynamic>>()
          .map((p) => Offset((p[0] as num).toDouble(), (p[1] as num).toDouble()))
          .toList(growable: false),
      isUpsideDown: map['isUpsideDown'] as bool?,
      angleConfidence: (map['angleConfidence'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() =>
      'OcrResult("$text", confidence: ${confidence.toStringAsFixed(3)}, '
      'points: $points)';
}
