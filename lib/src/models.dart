/// CPU power mode hint passed through to Paddle Lite.
/// Mirrors `paddle::lite_api::PowerMode` (see `ppredictor.cpp`).
enum CpuPower {
  high('LITE_POWER_HIGH'),
  low('LITE_POWER_LOW'),
  full('LITE_POWER_FULL'),
  noBind('LITE_POWER_NO_BIND'),
  randHigh('LITE_POWER_RAND_HIGH'),
  randLow('LITE_POWER_RAND_LOW');

  const CpuPower(this.value);
  final String value;
}
