
import 'package:flutter_test/flutter_test.dart';
import 'package:inventorio/core/models/meta.dart';

void main() {
  test('should not build meta without uid', () async {
    final builder = MetaBuilder();
    expect(() => builder.build(), throwsA(isA<UnsupportedError>()));
  });

  test('should build meta from map', () async {
    final builder = MetaBuilder.fromMeta(Meta.fromJson({'uuid': 'uuid'}));
    final meta = builder.build();
    expect(meta.uuid, 'uuid');
  });
}