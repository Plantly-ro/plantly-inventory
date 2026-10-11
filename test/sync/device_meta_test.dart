import 'package:flutter_test/flutter_test.dart';
import 'package:plantly_inventory/sync/device_meta_io.dart';

void main() {
  String? Function(String) props(Map<String, String> m) => (k) => m[k];

  test('Android device name = manufacturer + model (not just "Android")', () {
    expect(androidModelName(props({'ro.product.model': 'Pixel 8', 'ro.product.manufacturer': 'Google'})), 'Google Pixel 8');
    expect(androidModelName(props({'ro.product.model': 'SM-S918B', 'ro.product.manufacturer': 'samsung'})), 'Samsung SM-S918B');
  });

  test('model already naming the maker is not doubled', () {
    expect(androidModelName(props({'ro.product.model': 'OnePlus 12', 'ro.product.manufacturer': 'OnePlus'})), 'OnePlus 12');
  });

  test('no model → null (caller falls back to "Android"); no maker → model', () {
    expect(androidModelName(props({})), isNull);
    expect(androidModelName(props({'ro.product.model': '  '})), isNull);
    expect(androidModelName(props({'ro.product.model': 'Pixel 8'})), 'Pixel 8');
  });
}
