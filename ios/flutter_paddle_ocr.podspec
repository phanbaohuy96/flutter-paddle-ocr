#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_paddle_ocr.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_paddle_ocr'
  s.version          = '0.0.1'
  s.summary          = 'On-device OCR for Flutter, powered by PaddleOCR + Paddle Lite.'
  s.description      = <<-DESC
On-device OCR for Flutter, powered by PaddleOCR + Paddle Lite. iOS implementation pending.
                       DESC
  s.homepage         = 'https://github.com/phanbaohuy96/flutter-paddle-ocr'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Huy Phan' => 'baohuy.phan1996@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end
