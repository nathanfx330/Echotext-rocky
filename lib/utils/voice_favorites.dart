// lib/utils/voice_favorites.dart
import '../models/voice_model.dart';

/// Store Kokoro favorites by stable voice ID rather than display name.
/// A missing preference means a new installation; an explicitly empty saved
/// list means the user removed all favorites.
class VoiceFavorites {
  static const preferencesKey = 'kokoro_favorite_voices';
  static const initialFavorite = 'af_heart';

  static Set<String> restore(List<String>? saved) =>
      saved == null ? <String>{initialFavorite} : saved.toSet();

  static List<VoiceModel> ordered(
    Iterable<VoiceModel> voices,
    Set<String> favorites, {
    String query = '',
    bool favoritesOnly = false,
  }) {
    final search = query.trim().toLowerCase();
    final matches = voices.where((voice) {
      if (favoritesOnly && !favorites.contains(voice.path)) return false;
      if (search.isEmpty) return true;
      return voice.name.toLowerCase().contains(search) ||
          voice.path.toLowerCase().contains(search);
    }).toList();

    matches.sort((a, b) {
      final aFavorite = favorites.contains(a.path);
      final bFavorite = favorites.contains(b.path);
      if (aFavorite != bFavorite) return aFavorite ? -1 : 1;
      final nameOrder =
          a.name.toLowerCase().compareTo(b.name.toLowerCase());
      return nameOrder != 0 ? nameOrder : a.path.compareTo(b.path);
    });
    return matches;
  }
}
