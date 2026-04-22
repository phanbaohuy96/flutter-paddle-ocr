import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui show Image;

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_paddle_ocr/flutter_paddle_ocr.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

// PP-OCRv2 slim mobile bundle (det_db.nb + rec_crnn.nb + cls.nb) + Chinese dict.
// Mirrors PaddleOCR/deploy/android_demo/app/build.gradle.
const _modelArchiveUrl = 'https://paddleocr.bj.bcebos.com/PP-OCRv2/lite/ch_PP-OCRv2.tar.gz';
const _dictArchiveUrl = 'https://paddleocr.bj.bcebos.com/dygraph_v2.0/lite/ch_dict.tar.gz';

void main() => runApp(const _App());

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'flutter_paddle_ocr example',
        theme: ThemeData(colorSchemeSeed: const Color(0xFF3B85F5), useMaterial3: true),
        home: const _HomePage(),
      );
}

class _HomePage extends StatefulWidget {
  const _HomePage();
  @override
  State<_HomePage> createState() => _HomePageState();
}

enum _Phase { loading, ready, running, error }

class _HomePageState extends State<_HomePage> {
  PaddleOcr? _ocr;
  _Phase _phase = _Phase.loading;
  String _status = 'Loading models...';
  _Output? _output;

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _ocr?.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    try {
      final dir = await getApplicationSupportDirectory();
      final modelsDir = Directory('${dir.path}/paddle_ocr')..createSync(recursive: true);

      final det = File('${modelsDir.path}/det_db.nb');
      final rec = File('${modelsDir.path}/rec_crnn.nb');
      final cls = File('${modelsDir.path}/cls.nb');
      final dict = File('${modelsDir.path}/ppocr_keys_v1.txt');

      if (!det.existsSync() || !rec.existsSync() || !cls.existsSync()) {
        setState(() => _status = 'Downloading PP-OCRv2 models (~7 MB)...');
        await _downloadAndExtract(_modelArchiveUrl, modelsDir);
      }
      if (!dict.existsSync()) {
        setState(() => _status = 'Downloading Chinese dictionary...');
        await _downloadAndExtract(_dictArchiveUrl, modelsDir);
      }

      setState(() => _status = 'Initializing OCR engine...');
      _ocr = await PaddleOcr.create(
        detModelPath: det.path,
        recModelPath: rec.path,
        clsModelPath: cls.path,
        labelPath: dict.path,
      );
      setState(() {
        _phase = _Phase.ready;
        _status = 'Ready — pick an image to run OCR';
      });
    } catch (e, st) {
      setState(() {
        _phase = _Phase.error;
        _status = 'Setup failed: $e\n$st';
      });
    }
  }

  Future<void> _downloadAndExtract(String url, Directory into) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} downloading $url');
    }
    final archive = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(response.bodyBytes));
    for (final entry in archive) {
      if (!entry.isFile) continue;
      // Strip the leading "ch_PP-OCRv2/" / "ch_dict/" directory so files land
      // directly under the app's models directory.
      final slash = entry.name.indexOf('/');
      final name = slash >= 0 ? entry.name.substring(slash + 1) : entry.name;
      if (name.isEmpty) continue;
      File('${into.path}/$name')
        ..parent.createSync(recursive: true)
        ..writeAsBytesSync(entry.content as List<int>);
    }
  }

  Future<void> _pickAndRecognize() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await _runOcr(await picked.readAsBytes());
  }

  Future<void> _runSample() async {
    final data = await rootBundle.load('assets/samples/sample.jpg');
    await _runOcr(data.buffer.asUint8List());
  }

  Future<void> _runOcr(Uint8List bytes) async {
    final ocr = _ocr;
    if (ocr == null || _phase == _Phase.running) return;
    setState(() {
      _phase = _Phase.running;
      _status = 'Running OCR...';
      _output = null;
    });
    try {
      final sw = Stopwatch()..start();
      final results = await ocr.recognize(bytes, runClassification: true);
      sw.stop();
      // Decode once up-front so the preview widget doesn't re-decode on every rebuild.
      final image = await decodeImageFromList(bytes);
      setState(() {
        _phase = _Phase.ready;
        _output = _Output(bytes: bytes, image: image, results: results);
        _status = 'Found ${results.length} regions in ${sw.elapsedMilliseconds} ms';
      });
    } catch (e) {
      setState(() {
        _phase = _Phase.ready;
        _status = 'Recognition failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final canRun = _phase == _Phase.ready;
    return Scaffold(
      appBar: AppBar(title: const Text('flutter_paddle_ocr')),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _fab('sample', Icons.auto_awesome, 'Run sample', canRun ? _runSample : null),
          const SizedBox(height: 12),
          _fab('pick', Icons.photo_library, 'Pick image', canRun ? _pickAndRecognize : null),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(_status, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (_output != null) ...[
            Expanded(
              flex: 2,
              child: InteractiveViewer(child: _ImageWithBoxes(output: _output!)),
            ),
            if (_output!.results.isNotEmpty)
              Expanded(
                flex: 1,
                child: ListView.separated(
                  itemCount: _output!.results.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final r = _output!.results[i];
                    return ListTile(
                      dense: true,
                      title: Text(r.text),
                      subtitle: Text('conf=${r.confidence.toStringAsFixed(2)}'),
                    );
                  },
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _fab(String tag, IconData icon, String label, VoidCallback? onPressed) =>
      FloatingActionButton.extended(
        heroTag: tag,
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      );
}

class _Output {
  const _Output({required this.bytes, required this.image, required this.results});
  final Uint8List bytes;
  final ui.Image image;
  final List<OcrResult> results;
}

class _ImageWithBoxes extends StatelessWidget {
  const _ImageWithBoxes({required this.output});
  final _Output output;

  @override
  Widget build(BuildContext context) {
    final w = output.image.width.toDouble();
    final h = output.image.height.toDouble();
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Image.memory(output.bytes, width: w, height: h),
            CustomPaint(size: Size(w, h), painter: _BoxPainter(output.results)),
          ],
        ),
      ),
    );
  }
}

class _BoxPainter extends CustomPainter {
  _BoxPainter(this.results);
  final List<OcrResult> results;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = const Color(0xFF3B85F5)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = const Color(0x333B85F5)
      ..style = PaintingStyle.fill;
    for (final r in results) {
      if (r.points.length < 2) continue;
      final path = Path()..moveTo(r.points.first.dx, r.points.first.dy);
      for (final p in r.points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      path.close();
      canvas.drawPath(path, fill);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_BoxPainter oldDelegate) => oldDelegate.results != results;
}
