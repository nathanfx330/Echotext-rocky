// lib/widgets/sheets/settings_sheet.dart
import 'package:flutter/material.dart';

import '../../models/voice_model.dart';
import '../dialogs/voice_picker_dialog.dart';

/// Favorite any Kokoro voice, quickly find favorites, and set reading speed.
class SettingsSheet extends StatelessWidget {
  final VoiceModel? selectedVoice;
  final List<VoiceModel> availableVoices;
  final Set<String> favoriteVoices;
  final double speechSpeed;
  final ValueChanged<VoiceModel> onVoiceSelected;
  final ValueChanged<String> onFavoriteToggled;
  final ValueChanged<double> onSpeedChanged;

  const SettingsSheet({
    super.key,
    required this.selectedVoice,
    required this.availableVoices,
    required this.favoriteVoices,
    required this.speechSpeed,
    required this.onVoiceSelected,
    required this.onFavoriteToggled,
    required this.onSpeedChanged,
  });

  Future<void> _chooseVoice(BuildContext context) async {
    final chosen = await showDialog<VoiceModel>(
      context: context,
      builder: (context) => VoicePickerDialog(
        voices: availableVoices,
        selectedVoice: selectedVoice,
        favoriteVoices: favoriteVoices,
        onFavoriteToggled: onFavoriteToggled,
      ),
    );
    if (chosen != null) onVoiceSelected(chosen);
  }

  @override
  Widget build(BuildContext context) {
    final currentFavorite = selectedVoice != null &&
        favoriteVoices.contains(selectedVoice!.path);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kokoro Voice Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Voice', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: availableVoices.isEmpty
                      ? null
                      : () => _chooseVoice(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    alignment: Alignment.centerLeft,
                    side: const BorderSide(color: Colors.white24),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          selectedVoice?.name ?? 'No Kokoro voices loaded',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.expand_more, color: Colors.white70),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: currentFavorite
                    ? 'Unstar current voice'
                    : 'Star current voice',
                onPressed: selectedVoice == null
                    ? null
                    : () => onFavoriteToggled(selectedVoice!.path),
                icon: Icon(
                  currentFavorite ? Icons.star : Icons.star_border,
                  color: currentFavorite
                      ? Colors.amber.shade300
                      : Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Starred voices appear first in the voice picker (' +
                favoriteVoices.length.toString() + ' starred).',
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          const SizedBox(height: 16),
          const Text('CPU inference · Conda: echotext-kokoro',
              style: TextStyle(fontSize: 12, color: Colors.white38)),
          const Divider(height: 24, color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Reading Speed',
                  style: TextStyle(color: Colors.white70)),
              Text(speechSpeed.toStringAsFixed(2) + '×'),
            ],
          ),
          Slider(
            value: speechSpeed,
            min: 0.5,
            max: 2.0,
            divisions: 15,
            label: speechSpeed.toStringAsFixed(2),
            onChanged: onSpeedChanged,
          ),
          const Text('Higher values speak faster.',
              style: TextStyle(fontSize: 12, color: Colors.white38)),
        ],
      ),
    );
  }
}
