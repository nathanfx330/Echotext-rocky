// lib/services/kokoro_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/voice_model.dart';
import '../utils/text_helpers.dart';

/// Persistent CPU-only Kokoro engine. Python and its dependencies live strictly
/// within the existing echotext-kokoro Conda environment.
/// The original Piper service is retained separately for future fallback.
class KokoroService {
  final AudioPlayer audioPlayer = AudioPlayer();
  final Map<int, Completer<Map<String, dynamic>>> _pending = {};
  final Set<String> _tempAudio = {};
  final List<VoiceModel> availableVoices = [];

  Process? _process;
  Completer<void>? _ready;
  Completer<void>? _playCompleter;
  StreamSubscription<void>? _completionSubscription;
  String _lastError = '';
  String _root = '';
  int _requestId = 0;
  int _playbackId = 0;
  int _exportId = 0;
  bool isInitialized = false;
  bool _disposed = false;

  /// Notify the UI when the persistent Python engine unexpectedly exits.
  void Function(String reason)? onUnexpectedExit;

  KokoroService() {
    _completionSubscription = audioPlayer.onPlayerComplete.listen((_) {
      final current = _playCompleter;
      if (current != null && !current.isCompleted) current.complete();
    });
  }

  String get runtimeDescription => _root.isEmpty ? 'Kokoro (not configured)' : _root;

  Future<void> init() async {
    if (_disposed) throw StateError('KokoroService already disposed');
    if (isInitialized) return;

    final execDir = File(Platform.resolvedExecutable).parent.path;
    final configuredRoot = Platform.environment['ECHOTEXT_KOKORO_ROOT'];
    final roots = [
      if (configuredRoot != null && configuredRoot.isNotEmpty) configuredRoot,
      Directory.current.path,
      execDir,
    ];
    String? root;
    for (final candidate in roots) {
      final file = File(p.join(candidate, 'scripts', 'kokoro_worker.py'));
      if (file.existsSync()) {
        root = Directory(candidate).absolute.path;
        break;
      }
    }
    if (root == null) {
      throw StateError(
        'Missing scripts/kokoro_worker.py; launch from the EchoText Rocky '
        'project or a complete release bundle.',
      );
    }
    _root = root;

    final model = File(p.join(_root, 'kokoro', 'kokoro-v1.0.onnx'));
    final voices = File(p.join(_root, 'kokoro', 'voices-v1.0.bin'));
    if (!model.existsSync() || !voices.existsSync()) {
      throw StateError(
        'Kokoro model or voice bank missing. '
        'Run: bash scripts/download-kokoro.sh',
      );
    }

    final home = Platform.environment['HOME'] ?? '';
    final condaPrefix = Platform.environment['CONDA_PREFIX'];
    final override = Platform.environment['ECHOTEXT_KOKORO_PYTHON'];
    final candidates = [
      if (override != null && override.isNotEmpty) override,
      if (condaPrefix != null && p.basename(condaPrefix) == 'echotext-kokoro')
        p.join(condaPrefix, 'bin', 'python'),
      p.join(home, 'miniconda3', 'envs', 'echotext-kokoro', 'bin', 'python'),
      p.join(home, 'anaconda3', 'envs', 'echotext-kokoro', 'bin', 'python'),
      p.join(home, 'miniforge3', 'envs', 'echotext-kokoro', 'bin', 'python'),
      p.join(home, 'miniconda', 'envs', 'echotext-kokoro', 'bin', 'python'),
    ];

    String? python;
    for (final candidate in candidates) {
      if (File(candidate).existsSync()) {
        python = File(candidate).absolute.path;
        break;
      }
    }
    if (python == null) {
      throw StateError(
        'Conda Python echotext-kokoro was not found. '
        'Run scripts/setup-kokoro.sh, or set ECHOTEXT_KOKORO_PYTHON.',
      );
    }

    final prefix = p.dirname(p.dirname(python));
    final env = <String, String>{
      'CONDA_PREFIX': prefix,
      'CONDA_DEFAULT_ENV': 'echotext-kokoro',
      'PATH': p.join(prefix, 'bin') + ':' + (Platform.environment['PATH'] ?? ''),
    };
    _ready = Completer<void>();
    _lastError = '';
    try {
      final process = await Process.start(
        python,
        [
          '-u', p.join(_root, 'scripts', 'kokoro_worker.py'),
          '--serve',
          '--model', model.path,
          '--voices', voices.path,
        ],
        workingDirectory: _root,
        environment: env,
      );
      _process = process;

      process.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(_onWorkerLine, onError: _failWorker);

      process.stderr.transform(utf8.decoder).listen((chunk) {
        _lastError = (_lastError + chunk);
        if (_lastError.length > 3000) {
          _lastError = _lastError.substring(_lastError.length - 3000);
        }
        stderr.write(chunk);
      });

      process.exitCode.then((code) {
        // An older process must not invalidate a freshly restarted worker.
        if (!identical(_process, process)) return;
        final hadInitialized = isInitialized;
        _process = null;
        isInitialized = false;
        final error = StateError(
          'Kokoro worker exited ($code). ' + _lastError,
        );
        _failWorker(error);
        if (!_disposed && hadInitialized) {
          onUnexpectedExit?.call(error.toString());
        }
      });

      await _ready!.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          process.kill();
          throw TimeoutException('Kokoro startup timed out. ' + _lastError);
        },
      );
    } catch (_) {
      _process?.kill();
      _process = null;
      isInitialized = false;
      rethrow;
    }
  }

  void _onWorkerLine(String line) {
    Map<String, dynamic> message;
    try {
      message = Map<String, dynamic>.from(jsonDecode(line) as Map);
    } catch (_) {
      stderr.writeln('Unexpected Kokoro response: ' + line);
      return;
    }

    if (message['ready'] == true && message['ok'] == true) {
      availableVoices
        ..clear()
        ..addAll(
          (message['voices'] as List<dynamic>? ?? const [])
              .map((item) => item.toString())
              .map((id) => VoiceModel(name: id.replaceAll('_', ' · '), path: id)),
        );
      availableVoices.sort((a, b) => a.name.compareTo(b.name));
      isInitialized = true;
      final ready = _ready;
      if (ready != null && !ready.isCompleted) ready.complete();
      return;
    }

    final id = message['id'];
    if (id is int) {
      final waiting = _pending.remove(id);
      if (waiting != null && !waiting.isCompleted) waiting.complete(message);
    }
  }

  void _failWorker(Object error) {
    final ready = _ready;
    if (ready != null && !ready.isCompleted) ready.completeError(error);
    for (final c in _pending.values) {
      if (!c.isCompleted) c.completeError(error);
    }
    _pending.clear();
  }

  Future<Map<String, dynamic>> _request(Map<String, dynamic> request) async {
    if (!isInitialized || _process == null) {
      throw StateError('Kokoro worker is not ready. ' + _lastError);
    }
    final id = ++_requestId;
    final waiter = Completer<Map<String, dynamic>>();
    _pending[id] = waiter;
    try {
      _process!.stdin.writeln(jsonEncode({...request, 'id': id}));
      await _process!.stdin.flush();
    } catch (_) {
      _pending.remove(id);
      rethrow;
    }
    final reply = await waiter.future;
    if (reply['ok'] != true) {
      throw StateError('Kokoro error: ' + (reply['error']?.toString() ?? 'unknown'));
    }
    return reply;
  }

  Future<String> _synthesize({
    required String text,
    required String voice,
    required double speed,
    required String output,
  }) async {
    final response = await _request({
      'cmd': 'synthesize',
      'text': text.trim(),
      'voice': voice,
      'speed': speed,
      'path': output,
    });
    final file = File(response['path']?.toString() ?? output);
    if (!await file.exists() || await file.length() <= 44) {
      throw StateError('Kokoro did not produce a usable WAV.');
    }
    return file.path;
  }

  Future<void> playChunks(
    List<String> chunks, {
    required String voice,
    required double speed,
    required int sentenceGapMs,
    required int paragraphGapMs,
    required void Function(int) onChunkStart,
    int startIndex = 0,
  }) async {
    final myId = ++_playbackId;
    final temp = await getTemporaryDirectory();
    Future<String?>? next;
    for (var i = startIndex; i < chunks.length; i++) {
      if (myId != _playbackId) break;
      final file = next == null
          ? await _generateChunk(chunks[i], i, temp.path, voice, speed, myId)
          : await next;
      if (myId != _playbackId) break;

      next = i + 1 < chunks.length
          ? _generateChunk(chunks[i + 1], i + 1, temp.path, voice, speed, myId)
          : null;
      // Observe errors even if Stop cancels playback before the prefetch
      // future is awaited on the next iteration.
      next?.ignore();

      if (file == null) continue; // Blank or punctuation-only sentence.
      onChunkStart(i);
      final completion = Completer<void>();
      _playCompleter = completion;
      try {
        await audioPlayer.play(DeviceFileSource(file));
        await completion.future;
      } finally {
        if (identical(_playCompleter, completion)) _playCompleter = null;
        await _deleteTemp(file);
      }
      if (i + 1 < chunks.length && myId == _playbackId) {
        final gapMs = TextHelpers.pauseAfterChunk(
          chunks[i],
          sentenceGapMs: sentenceGapMs,
          paragraphGapMs: paragraphGapMs,
        );
        if (gapMs > 0) {
          await Future<void>.delayed(Duration(milliseconds: gapMs));
        }
      }
    }
    next?.ignore();
  }

  Future<String?> _generateChunk(
    String text, int index, String dir, String voice, double speed, int id,
  ) async {
    if (!text.contains(RegExp(r'[a-zA-Z0-9\p{L}]', unicode: true))) return null;
    if (id != _playbackId) return null;
    final file = p.join(dir, 'echotext_kokoro_chunk_' +
        id.toString() + '_' + index.toString() + '.wav');
    _tempAudio.add(file);
    try {
      final result = await _synthesize(
        text: text, voice: voice, speed: speed, output: file,
      );
      if (id != _playbackId) {
        await _deleteTemp(file);
        return null;
      }
      return result;
    } catch (_) {
      await _deleteTemp(file);
      rethrow;
    }
  }

  Future<void> _deleteTemp(String path) async {
    _tempAudio.remove(path);
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  // Keep the original WAV/SRT mathematical stitching engine below.

  String _formatSrtTime(int totalMilliseconds) {
    int hours = totalMilliseconds ~/ 3600000;
    int minutes = (totalMilliseconds % 3600000) ~/ 60000;
    int seconds = (totalMilliseconds % 60000) ~/ 1000;
    int milliseconds = totalMilliseconds % 1000;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')},${milliseconds.toString().padLeft(3, '0')}';
  }

  String _formatETA(int totalMilliseconds) {
    if (totalMilliseconds < 0) return "00:00";
    int totalSeconds = totalMilliseconds ~/ 1000;
    int hours = totalSeconds ~/ 3600;
    int minutes = (totalSeconds % 3600) ~/ 60;
    int seconds = totalSeconds % 60;
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  int _findChunk(Uint8List b, String chunkId) {
    if (b.length < 12) return -1;
    int offset = 12;
    while (offset + 8 <= b.length) {
      String id = String.fromCharCodes(b.sublist(offset, offset + 4));
      int size = ByteData.view(b.buffer).getUint32(offset + 4, Endian.little);
      if (id == chunkId) return offset;
      offset += 8 + size; 
    }
    return -1;
  }

  Future<bool> generateToFile(
    String text,
    String outputPath, {
    required String voice,
    required double speed,
    required int sentenceGapMs,
    required int paragraphGapMs,
    List<String>? exportChunks,
    bool isSubtitlesRequested = false,
    void Function(int current, int total, String eta)? onProgress,
  }) async {
    if (!isInitialized) throw StateError('Kokoro has not initialized');
    final parts = (exportChunks ?? TextHelpers.splitIntoSentences(text))
        .where((s) => s.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return false;

    final myId = ++_exportId;
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final totalCount = parts.length;
    final tempWavPaths = <String>[];
    final started = DateTime.now();

    try {
      for (var i = 0; i < totalCount; i++) {
        if (myId != _exportId) throw StateError('Export cancelled');
        final file = p.join(tempDir.path,
            'echotext_kokoro_export_' + timestamp.toString() +
            '_' + i.toString() + '.wav');
        tempWavPaths.add(file);
        _tempAudio.add(file);
        await _synthesize(
          text: parts[i], voice: voice, speed: speed, output: file,
        );
        final elapsedMs = DateTime.now().difference(started).inMilliseconds;
        final remainingMs = ((elapsedMs / (i + 1)) *
            (totalCount - i - 1)).round();
        onProgress?.call(i + 1, totalCount, _formatETA(remainingMs));
      }
      if (myId != _exportId) throw StateError('Export cancelled');
    } catch (_) {
      for (final file in tempWavPaths) {
        await _deleteTemp(file);
      }
      rethrow;
    }

    // --- STITCHING & VAD PHASE (Super fast RAM math) ---
    int srtIndex = 1;
    StringBuffer srtContent = StringBuffer();
    StringBuffer errorLog = StringBuffer(); 
    
    File rawAudioTempFile = File(p.join(tempDir.path, 'temp_raw_audio_$timestamp.tmp'));
    var rawSink = rawAudioTempFile.openWrite();
    
    int totalDataBytes = 0;
    String? previousSpokenChunk;
    int? sampleRate, numChannels, bitsPerSample, byteRate, blockAlign;

    for (int i = 0; i < totalCount; i++) {
      File chunkFile = File(tempWavPaths[i]);
      String textChunk = parts[i];

      if (await chunkFile.exists() && await chunkFile.length() >= 44) {
        var bytes = await chunkFile.readAsBytes();
        int fmtOffset = _findChunk(bytes, 'fmt ');
        int dataOffset = _findChunk(bytes, 'data');
        
        if (fmtOffset != -1 && dataOffset != -1) {
          ByteData view = ByteData.view(bytes.buffer);
          if (sampleRate == null) {
            numChannels = view.getUint16(fmtOffset + 10, Endian.little);
            sampleRate = view.getUint32(fmtOffset + 12, Endian.little);
            byteRate = view.getUint32(fmtOffset + 16, Endian.little);
            blockAlign = view.getUint16(fmtOffset + 20, Endian.little);
            bitsPerSample = view.getUint16(fmtOffset + 22, Endian.little);
          }
          
          int dataSize = view.getUint32(dataOffset + 4, Endian.little);
          int actualAvailable = bytes.length - (dataOffset + 8);
          int readSize = (dataSize < actualAvailable && dataSize > 0) ? dataSize : actualAvailable;
          readSize = readSize - (readSize % blockAlign!);
          
          if (readSize > 0) {
            Uint8List audioData = bytes.sublist(dataOffset + 8, dataOffset + 8 + readSize);
            
            // PCM VAD Stripper
            if (bitsPerSample == 16 && audioData.length >= blockAlign!) {
              ByteData chunkView = ByteData.view(audioData.buffer, audioData.offsetInBytes, audioData.length);
              int threshold = 150, firstAudible = 0;
              for (int j = 0; j <= audioData.length - blockAlign!; j += blockAlign!) {
                if (chunkView.getInt16(j, Endian.little).abs() > threshold) { firstAudible = j; break; }
              }
              
              int lastAudible = audioData.length - blockAlign!;
              if (lastAudible < 0) lastAudible = 0;
              for (int j = audioData.length - blockAlign!; j >= firstAudible; j -= blockAlign!) {
                if (chunkView.getInt16(j, Endian.little).abs() > threshold) { lastAudible = j; break; }
              }
              
              int padBytes = (byteRate! * 0.03).toInt();
              padBytes = padBytes - (padBytes % blockAlign!); 
              firstAudible = (firstAudible - padBytes).clamp(0, audioData.length).toInt();
              lastAudible = (lastAudible + padBytes).clamp(0, audioData.length - blockAlign!).toInt();
              
              if (lastAudible >= firstAudible) {
                audioData = audioData.sublist(firstAudible, lastAudible + blockAlign!);
                int minBytes = (byteRate! * 0.05).toInt(); 
                minBytes = minBytes - (minBytes % blockAlign!); 
                if (audioData.length < minBytes) audioData = Uint8List(0); 
              } else {
                audioData = Uint8List(0); 
              }
            }

            if (audioData.isNotEmpty) {
              // Add actual zero PCM frames *between* successfully generated
              // sentences, before the next SRT start timestamp is recorded.
              // This keeps gaps on the same audio timeline as subtitles.
              if (previousSpokenChunk != null) {
                final gapMs = TextHelpers.pauseAfterChunk(
                  previousSpokenChunk,
                  sentenceGapMs: sentenceGapMs,
                  paragraphGapMs: paragraphGapMs,
                );
                final silentFrames = ((gapMs * sampleRate!) / 1000).round();
                final silentBytes = silentFrames * blockAlign!;
                if (silentBytes > 0) {
                  rawSink.add(Uint8List(silentBytes));
                  totalDataBytes += silentBytes;
                }
              }

              int startBytes = totalDataBytes;
              rawSink.add(audioData);
              totalDataBytes += audioData.length;
              previousSpokenChunk = textChunk;
              
              int startMs = (startBytes * 1000) ~/ byteRate!;
              int endMs = (totalDataBytes * 1000) ~/ byteRate!;
              int displayEndMs = endMs - 15; 
              if (displayEndMs <= startMs) displayEndMs = startMs + 10;
              
              String safeText = textChunk.trim().replaceAll(RegExp(r'\s+'), ' ');
              srtContent.writeln(srtIndex++);
              srtContent.writeln('${_formatSrtTime(startMs)} --> ${_formatSrtTime(displayEndMs)}');
              srtContent.writeln(safeText);
              srtContent.writeln(); 
            } else {
              errorLog.writeln('CHUNK $i FAILED: VAD removed all audio. TEXT: $textChunk\n');
            }
          } else {
            errorLog.writeln('CHUNK $i FAILED: WAV valid but 0 bytes. TEXT: $textChunk\n');
          }
        } else {
          errorLog.writeln('CHUNK $i FAILED: No fmt/data chunks. TEXT: $textChunk\n');
        }
        await chunkFile.delete();
        _tempAudio.remove(chunkFile.path);
      } else {
        errorLog.writeln('CHUNK $i FAILED: Kokoro failed to generate chunk. TEXT: $textChunk\n');
      }
    }
    
    await rawSink.flush();
    await rawSink.close();
    
    // FINAL MASTER FILE GENERATION
    if (sampleRate != null && totalDataBytes > 0) {
       File finalWavFile = File(outputPath);
       var finalSink = finalWavFile.openWrite();
       
       var header = ByteData(44);
       header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46); 
       header.setUint32(4, totalDataBytes + 36, Endian.little);
       header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45); 
       header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20); 
       header.setUint32(16, 16, Endian.little);
       header.setUint16(20, 1, Endian.little);
       header.setUint16(22, numChannels!, Endian.little);
       header.setUint32(24, sampleRate!, Endian.little);
       header.setUint32(28, byteRate!, Endian.little);
       header.setUint16(32, blockAlign!, Endian.little);
       header.setUint16(34, bitsPerSample!, Endian.little);
       header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61); 
       header.setUint32(40, totalDataBytes, Endian.little);
       
       finalSink.add(header.buffer.asUint8List());
       await finalSink.addStream(rawAudioTempFile.openRead());
       await finalSink.flush();
       await finalSink.close();
       
       if (isSubtitlesRequested) {
         String srtPath = outputPath.replaceAll(RegExp(r'\.wav$', caseSensitive: false), '.srt');
         if (srtPath == outputPath) srtPath += '.srt'; 
         await File(srtPath).writeAsString(srtContent.toString());
       }
       
       if (errorLog.isNotEmpty) {
         String logPath = outputPath.replaceAll(RegExp(r'\.wav$', caseSensitive: false), '_errors.log');
         if (logPath == outputPath) logPath += '_errors.log';
         await File(logPath).writeAsString("ECHO TEXT GENERATION ERRORS\n===========================\n\n${errorLog.toString()}");
       }
    }
    
    if (await rawAudioTempFile.exists()) await rawAudioTempFile.delete();
    
    return totalDataBytes > 0 && errorLog.isEmpty;
  }


  Future<void> stop() async {
    _playbackId++;
    _exportId++;
    final waiting = _playCompleter;
    if (waiting != null && !waiting.isCompleted) waiting.complete();
    await audioPlayer.stop();
  }

  void dispose() {
    _disposed = true;
    unawaited(stop());
    final proc = _process;
    _process = null;
    proc?.kill();
    _failWorker(StateError('Kokoro service disposed'));
    unawaited(_completionSubscription?.cancel());
    unawaited(audioPlayer.dispose());
    for (final file in _tempAudio.toList()) {
      unawaited(_deleteTemp(file));
    }
  }
}
