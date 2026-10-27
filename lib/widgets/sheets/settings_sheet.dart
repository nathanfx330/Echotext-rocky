// lib/widgets/sheets/settings_sheet.dart
import 'package:flutter/material.dart';
import '../../models/voice_model.dart';

/// Kokoro voice IDs, not Piper model file paths. Higher speed speaks faster.
class SettingsSheet extends StatelessWidget {
  final VoiceModel? selectedVoice;
  final List<VoiceModel> availableVoices;
  final double speechSpeed;
  final ValueChanged<VoiceModel> onVoiceSelected;
  final ValueChanged<double> onSpeedChanged;

  const SettingsSheet({
    super.key,
    required this.selectedVoice,
    required this.availableVoices,
    required this.speechSpeed,
    required this.onVoiceSelected,
    required this.onSpeedChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kokoro Voice Settings',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          const Text('Voice', style: TextStyle(color: Colors.white70)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<VoiceModel>(
                isExpanded: true,
                value: selectedVoice,
                dropdownColor: const Color(0xFF2C2C2C),
                hint: const Text('No Kokoro voices loaded'),
                items: availableVoices.map((voice) {
                  return DropdownMenuItem<VoiceModel>(
                    value: voice,
                    child: Text(voice.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (voice) {
                  if (voice != null) onVoiceSelected(voice);
                },
              ),
            ),
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
