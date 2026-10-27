// test/voice_favorites_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:echotext/models/voice_model.dart';
import 'package:echotext/utils/voice_favorites.dart';
import 'package:echotext/widgets/dialogs/voice_picker_dialog.dart';

void main() {
  final voices = <VoiceModel>[
    VoiceModel(name: 'af · heart', path: 'af_heart'),
    VoiceModel(name: 'bm · george', path: 'bm_george'),
    VoiceModel(name: 'af · bella', path: 'af_bella'),
  ];

  test('fresh installations favorite heart; saved empty means no favorites', () {
    expect(VoiceFavorites.restore(null), {'af_heart'});
    expect(VoiceFavorites.restore([]), isEmpty);
    expect(VoiceFavorites.restore(['bm_george']), {'bm_george'});
  });

  test('favorites sort first, then alphabetically', () {
    final ordered = VoiceFavorites.ordered(voices, {'bm_george', 'af_heart'});
    expect(ordered.map((v) => v.path), [
      'af_heart', 'bm_george', 'af_bella',
    ]);
  });

  test('search and favorites-only filtering use stable IDs', () {
    final only = VoiceFavorites.ordered(
      voices, {'af_heart'}, query: 'AF_', favoritesOnly: true,
    );
    expect(only.map((v) => v.path), ['af_heart']);
    final query = VoiceFavorites.ordered(voices, {}, query: 'GEORGE');
    expect(query.single.path, 'bm_george');
  });

  testWidgets('voice picker stars a voice without selecting it', (tester) async {
    final favorites = {'af_heart'};
    final updated = <String>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: VoicePickerDialog(
          voices: voices,
          selectedVoice: voices.first,
          favoriteVoices: favorites,
          onFavoriteToggled: updated.add,
        ),
      ),
    ));
    expect(find.text('1 starred'), findsOneWidget);
    await tester.tap(find.byTooltip('Star bm_george'));
    await tester.pump();
    expect(updated, ['bm_george']);
    expect(find.text('2 starred'), findsOneWidget);
    expect(find.byTooltip('Unstar bm_george'), findsOneWidget);
    await tester.tap(find.text('Starred only'));
    await tester.pumpAndSettle();
    expect(find.text('bm · george'), findsOneWidget);
    expect(find.text('af · bella'), findsNothing);
  });
}
