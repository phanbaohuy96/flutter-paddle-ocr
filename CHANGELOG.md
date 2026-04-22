## 0.0.1

* Initial release — Android only (arm64-v8a).
* Reuses PaddleOCR's `deploy/android_demo/` C++/Java verbatim (Paddle Lite v2.10).
* Dart API: `PaddleOcr.create`, `recognize`, `dispose`; `OcrResult`, `CpuPower`.
* iOS is a stub; all methods return `PlatformException(UNIMPLEMENTED)`.
