// lib/widgets/dialogs/voice_picker_dialog.dart
import 'package:flutter/material.dart';

import '../../models/voice_model.dart';
import '../../utils/voice_favorites.dart';

/// Search all Kokoro voices, star any voice without selecting it, and choose
/// the active voice by clicking its row. Favorites always appear first.
class VoicePickerDialog extends StatefulWidget {
  final List<VoiceModel> voices;
  final VoiceModel? selectedVoice;
  final Set<String> favoriteVoices;
  final ValueChanged<String> onFavoriteToggled;

  const VoicePickerDialog({
    super.key,
    required this.voices,
    required this.selectedVoice,
    required this.favoriteVoices,
    required this.onFavoriteToggled,
  });

  @override
  State<VoicePickerDialog> createState() => _VoicePickerDialogState();
}

class _VoicePickerDialogState extends State<VoicePickerDialog> {
  late final Set<String> _favorites;
  bool _favoritesOnly = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _favorites = {...widget.favoriteVoices};
  }

  void _toggleStar(String voiceId) {
    setState(() {
      if (!_favorites.add(voiceId)) _favorites.remove(voiceId);
    });
    widget.onFavoriteToggled(voiceId);
  }

  @override
  Widget build(BuildContext context) {
    final shown = VoiceFavorites.ordered(
      widget.voices,
      _favorites,
      query: _query,
      favoritesOnly: _favoritesOnly,
    );
    return Dialog(
      backgroundColor: const Color(0xFF242424),
      child: SizedBox(
        width: 480,
        height: 550,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Kokoro voices',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600)),
                  ),
                  IconButton(
                    tooltip: 'Close voice picker',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search voices',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  FilterChip(
                    label: const Text('Starred only'),
                    avatar: const Icon(Icons.star, size: 18),
                    selected: _favoritesOnly,
                    onSelected: (value) =>
                        setState(() => _favoritesOnly = value),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _favorites.length.toString() + ' starred',
                    style: const TextStyle(color: Colors.white54),
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: shown.isEmpty
                    ? const Center(
                        child: Text('No matching voices',
                            style: TextStyle(color: Colors.white54)),
                      )
                    : ListView.builder(
                        itemCount: shown.length,
                        itemBuilder: (context, index) {
                          final voice = shown[index];
                          final starred = _favorites.contains(voice.path);
                          final selected =
                              widget.selectedVoice?.path == voice.path;
                          return ListTile(
                            dense: true,
                            selected: selected,
                            selectedTileColor: Colors.white10,
                            leading: selected
                                ? const Icon(Icons.check_circle_outline,
                                    color: Colors.white70)
                                : const SizedBox(width: 24),
                            title: Text(voice.name),
                            subtitle: Text(voice.path,
                                style: const TextStyle(
                                    color: Colors.white38, fontSize: 11)),
                            trailing: IconButton(
                              tooltip: starred
                                  ? 'Unstar ' + voice.path
                                  : 'Star ' + voice.path,
                              icon: Icon(
                                starred ? Icons.star : Icons.star_border,
                                color: starred
                                    ? Colors.amber.shade300
                                    : Colors.white54,
                              ),
                              onPressed: () => _toggleStar(voice.path),
                            ),
                            onTap: () => Navigator.of(context).pop(voice),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a voice to use it. Star the voices you want to keep.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
