// test/widget_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:echotext/utils/text_helpers.dart';

void main() {
  test('cleanup removes markdown markers', () {
    expect(TextHelpers.quickClean('**Hello** world',
        stripSpecialChars: false), 'Hello world');
  });
  test('Sure cleaner does not eat Surely', () {
    expect(
      TextHelpers.quickClean('Surely the answer is this: X',
          stripSpecialChars: false),
      'Surely the answer is this: X',
    );
    expect(
      TextHelpers.quickClean('Sure, here is the answer: X',
          stripSpecialChars: false),
      ' X',
    );
  });
  test('empty document has no sentences', () {
    expect(TextHelpers.splitIntoSentences(''), isEmpty);
  });

  test('decimals, percentages, and dollar values stay in one sentence', () {
    expect(TextHelpers.splitIntoSentences('The 3.5% rule was tested.'),
        ['The 3.5% rule was tested.']);
    expect(TextHelpers.splitIntoSentences(
        'The U.S. Treasury spent \$1.2 billion.'),
        ['The U.S. Treasury spent \$1.2 billion.']);
  });

  test('domain names and U.S. abbreviation do not split', () {
    expect(TextHelpers.splitIntoSentences(
        'Visit nathanielwestveer.com for more.'),
        ['Visit nathanielwestveer.com for more.']);
    expect(TextHelpers.splitIntoSentences(
        'Dr. Smith spoke to the U.S. Treasury. Then he left.'),
        ['Dr. Smith spoke to the U.S. Treasury. ', 'Then he left.']);
  });

  test('quotes and closing brackets stay with sentence punctuation', () {
    expect(TextHelpers.splitIntoSentences(
        'She said, "Go now." Then we did!'),
        ['She said, "Go now." ', 'Then we did!']);
    expect(TextHelpers.splitIntoSentences(
        'He asked, "Why?" She answered.'),
        ['He asked, "Why?" ', 'She answered.']);
    expect(TextHelpers.splitIntoSentences('See (note 3.) Next.'),
        ['See (note 3.) ', 'Next.']);
  });

  test('retains all whitespace and highlights offset mapping', () {
    const source = 'First line.\n\nSecond line!  Third?\nLast';
    final chunks = TextHelpers.splitIntoSentences(source);
    expect(chunks.join(), source);
    expect(chunks,
        ['First line.\n\n', 'Second line!  ', 'Third?\n', 'Last']);
  });

  test('ordinal 1st is not mistaken for St. abbreviation', () {
    const source = 'It was the 1st. Then the 2nd.';
    final chunks = TextHelpers.splitIntoSentences(source);
    expect(chunks, ['It was the 1st. ', 'Then the 2nd.']);
    expect(chunks.join(), source);
  });

  test('Unicode ellipsis ends a sentence but not a quoted closing mark', () {
    const source = 'Something changed… Then they left.';
    final chunks = TextHelpers.splitIntoSentences(source);
    expect(chunks, ['Something changed… ', 'Then they left.']);
    expect(chunks.join(), source);

    const quoted = 'He whispered, “Wait…” Then turned away.';
    final quotedChunks = TextHelpers.splitIntoSentences(quoted);
    expect(quotedChunks, ['He whispered, “Wait…” ', 'Then turned away.']);
    expect(quotedChunks.join(), quoted);
  });

  test('keeps known abbreviation tradeoffs and domain names intact', () {
    const text = 'The U.S. Then it stopped.';
    expect(TextHelpers.splitIntoSentences(text), [text]);
    expect(TextHelpers.splitIntoSentences('Dr. Smith arrived.'),
        ['Dr. Smith arrived.']);
    expect(TextHelpers.splitIntoSentences('See example.com… Then return.'),
        ['See example.com… ', 'Then return.']);
  });

  test('paragraph gap applies only to blank-line separators', () {
    int gap(String chunk) => TextHelpers.pauseAfterChunk(chunk,
        sentenceGapMs: 300, paragraphGapMs: 650);
    expect(gap('Sentence. '), 300);
    expect(gap('Paragraph.\n\n'), 650);
    expect(gap('One line\n'), 300);
    expect(gap('Paragraph.\r\n  \r\n'), 650);
  });
}
