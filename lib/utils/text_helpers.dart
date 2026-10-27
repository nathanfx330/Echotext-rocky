class TextHelpers {
  /// Lossless sentence chunks. Every input character belongs to exactly one
  /// chunk, which keeps editor offsets and read-along highlighting correct.
  /// A period is a terminator only before whitespace/end, not inside decimal
  /// numbers, hostnames or acronyms such as U.S.
  static List<String> splitIntoSentences(String text) {
    if (text.isEmpty) return [];

    final pieces = <String>[];
    var start = 0;
    var i = 0;

    while (i < text.length) {
      final char = text[i];

      // Newlines without punctuation also end playback chunks.
      if (char == '\n' || char == '\r') {
        final end = _consumeWhitespace(text, i + 1);
        pieces.add(text.substring(start, end));
        start = end;
        i = end;
        continue;
      }

      if (char == '.' || char == '?' || char == '!' || char == '\u2026') {
        var end = i + 1;
        // Keep punctuation clusters (including Unicode ellipsis) and closing
        // quotes/brackets in one chunk.
        while (end < text.length &&
            (text[end] == '.' || text[end] == '?' || text[end] == '!' ||
             text[end] == '\u2026')) {
          end++;
        }
        while (end < text.length &&
            _isClosingPunctuation(text[end])) {
          end++;
        }

        // If immediately followed by letters/digits, this is not a stop:
        // e.g. 3.5%, nathanielwestveer.com, U.S.
        if (end == text.length || _isWhitespace(text[end])) {
          final isProtectedDot = char == '.' &&
              _abbreviation.hasMatch(text.substring(start, i + 1));
          if (!isProtectedDot) {
            final nextStart = _consumeWhitespace(text, end);
            pieces.add(text.substring(start, nextStart));
            start = nextStart;
            i = nextStart;
            continue;
          }
        }
      }
      i++;
    }

    if (start < text.length) pieces.add(text.substring(start));
    return pieces;
  }

  static final RegExp _abbreviation = RegExp(
    r'(?<![A-Za-z0-9])(?:Mr|Mrs|Ms|Dr|Prof|Sr|Jr|e\.g|i\.e|vs|U\.S|U\.S\.A|inc|corp|st)\.$',
    caseSensitive: false,
  );

  static bool _isWhitespace(String c) =>
      c == ' ' || c == '\t' || c == '\n' || c == '\r';

  static bool _isClosingPunctuation(String c) =>
      c == '"' || c == '\u201D' || c == '\u2019' || c == "'" ||
      c == ')' || c == ']';

  static int _consumeWhitespace(String text, int index) {
    while (index < text.length && _isWhitespace(text[index])) {
      index++;
    }
    return index;
  }

  /// Return the *additional silence* inserted after this chunk.
  /// Two or more logical newlines denote a paragraph break; ordinary
  /// single newlines use the sentence gap. Both playback and WAV/SRT export
  /// call this same function so the pauses are configured consistently.
  static int pauseAfterChunk(
    String chunk, {
    required int sentenceGapMs,
    required int paragraphGapMs,
  }) {
    final paragraph = RegExp(r'\r?\n[ \t]*\r?\n').hasMatch(chunk);
    return paragraph ? paragraphGapMs : sentenceGapMs;
  }

  /// Strips AI markdown, bolding, headers, and optionally special characters/emojis
  static String quickClean(String text, {required bool stripSpecialChars}) {
    String currentText = text;
    
    if (stripSpecialChars) {
      currentText = currentText.replaceAll(RegExp(r'[^\p{L}\p{N}\p{P}\p{Z}\n]', unicode: true), '');
    }
    
    currentText = currentText.replaceAll(RegExp(r'\*\*|\*|__|_'), '');
    currentText = currentText.replaceAll(RegExp(r'###|##|#'), '');
    currentText = currentText.replaceAll(RegExp(r'^\s*Sure\b[!,]?\s*.*?:', multiLine: true, caseSensitive: false), '');
    
    return currentText;
  }

  /// Joins chopped text back into paragraphs (Fixes PDF copy-paste formatting)
  static String fixBrokenLines(String text, {required double minLineLength, required bool smartJoinLabels}) {
    List<String> lines = text.split('\n');
    List<String> result = [];
    String currentParagraph = "";
    
    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].trimRight();
      
      if (line.trim().isEmpty) {
        if (currentParagraph.isNotEmpty) {
          result.add(currentParagraph);
          currentParagraph = "";
        }
        result.add(""); 
        continue;
      }
      
      if (currentParagraph.isEmpty) {
        currentParagraph = line.trimLeft();
      } else {
        currentParagraph += " ${line.trimLeft()}";
      }
      
      bool shouldJoinToNext = false;
      
      if (line.length >= minLineLength.toInt()) {
        shouldJoinToNext = true; 
      } else if (smartJoinLabels && (line.length <= 3 || line.endsWith(':'))) {
        shouldJoinToNext = true; 
      }
      
      if (!shouldJoinToNext) {
        result.add(currentParagraph);
        currentParagraph = "";
      }
    }
    
    if (currentParagraph.isNotEmpty) {
      result.add(currentParagraph);
    }
    
    return result.join('\n').replaceAll(RegExp(r' {2,}'), ' ');
  }
}