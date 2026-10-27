// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:echotext/utils/text_helpers.dart';
void main() {
  test('cleanup removes markdown markers', () {
    expect(TextHelpers.quickClean('**Hello** world', stripSpecialChars: false), 'Hello world');
  });
  test('empty document has no sentences', () {
    expect(TextHelpers.splitIntoSentences(''), isEmpty);
  });
}
