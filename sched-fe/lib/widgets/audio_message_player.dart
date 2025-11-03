import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';
import 'download_helper_stub.dart'
    if (dart.library.html) 'download_helper_web.dart'
    if (dart.library.io) 'download_helper_io.dart';

class AudioMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final String fileName;
  final int? durationMs; // Duration from backend in milliseconds (null = extract on client)
  final bool isCurrentUser; // For color inversion

  const AudioMessagePlayer({
    super.key,
    required this.audioUrl,
    required this.fileName,
    this.durationMs,
    required this.isCurrentUser,
  });

  // Generate unique seed from filename for consistent waveform
  int get waveformSeed {
    int hash = 0;
    for (int i = 0; i < fileName.length; i++) {
      hash = ((hash << 5) - hash) + fileName.codeUnitAt(i);
      hash = hash & hash; // Convert to 32bit integer
    }
    return hash.abs();
  }

  @override
  State<AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<AudioMessagePlayer> {
  AudioPlayer? _audioPlayer; // Lazy: only created on play
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration? _extractedDuration; // Client-extracted duration if backend failed
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  // Duration: backend first, then client-extracted, then zero
  Duration get _duration {
    if (widget.durationMs != null) {
      return Duration(milliseconds: widget.durationMs!);
    }
    return _extractedDuration ?? Duration.zero;
  }

  @override
  void initState() {
    super.initState();
    // Client-side extraction DISABLED - causing crashes
    // Backend must provide duration
    if (widget.durationMs == null) {
      debugPrint('[AudioPlayer] ⚠️ Backend duration null for: ${widget.fileName}');
    }
  }

  void _setupAudioPlayer(AudioPlayer player) {
    _positionSubscription = player.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });

    _playerStateSubscription = player.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state == PlayerState.playing;
        });

        if (state == PlayerState.completed) {
          player.seek(Duration.zero);
          setState(() {
            _position = Duration.zero;
            _isPlaying = false;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _playerStateSubscription?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_audioPlayer == null) {
        // First play - create player
        debugPrint('[AudioPlayer] 🎵 Creating player on-demand for: ${widget.fileName}');

        final player = AudioPlayer();
        _audioPlayer = player;
        _setupAudioPlayer(player);

        // Load audio source
        await player.setSourceUrl(widget.audioUrl);

        // Start playing
        await player.resume();
      } else {
        // Player exists - toggle play/pause
        if (_isPlaying) {
          await _audioPlayer!.pause();
        } else {
          await _audioPlayer!.resume();
        }
      }
    } catch (e) {
      debugPrint('[AudioPlayer] ❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao reproduzir áudio')),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _downloadAudio() async {
    try {
      // Download file - web implementation will handle the download automatically
      await downloadFile(widget.audioUrl, widget.fileName, []);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Downloading ${widget.fileName}')),
        );
      }
    } catch (e) {
      debugPrint('[AudioPlayer] Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to download audio')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    // INVERTED colors compared to text messages:
    // - When I send audio (isCurrentUser=true): use RECEIVED message color (lighter #2F2F2F)
    // - When I receive audio (isCurrentUser=false): use SENT message color (darker #222222)
    final backgroundColor = widget.isCurrentUser
        ? const Color(0xFF2F2F2F)  // Lighter (like received text)
        : const Color(0xFF222222); // Darker (like sent text)

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Play/Pause Button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform visualization
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Waveform bars (static, real representation)
                SizedBox(
                  height: 32,
                  child: CustomPaint(
                    painter: WaveformPainter(
                      progress: progress,
                      isPlaying: _isPlaying,
                      seed: widget.waveformSeed,
                    ),
                    size: Size.infinite,
                  ),
                ),
                const SizedBox(height: 4),

                // Time display
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Download button - ONLY for attachments (not recorded audio)
          // Recorded audio has fileName starting with "audio_"
          if (!widget.fileName.startsWith('audio_')) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _downloadAudio,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.download,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double progress;
  final bool isPlaying;
  final int seed;

  WaveformPainter({
    required this.progress,
    required this.isPlaying,
    required this.seed,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = 40;
    final barWidth = 2.0;
    final spacing = (size.width - (barCount * barWidth)) / (barCount - 1);

    final playedPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    final unplayedPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = barWidth
      ..strokeCap = StrokeCap.round;

    // Generate unique waveform heights based on seed
    final random = Random(seed);
    final heights = List.generate(barCount, (index) {
      // Use seed-based random for unique but consistent pattern
      final randFactor1 = random.nextDouble();
      final randFactor2 = random.nextDouble();
      final randFactor3 = random.nextDouble();

      // Create natural-looking waveform with peaks and valleys
      final baseHeight = (index / barCount) * 2.0;
      final wave1 = sin((index + randFactor1 * 10) * 0.5) * (0.3 + randFactor1 * 0.3);
      final wave2 = cos((index + randFactor2 * 10) * 0.8) * (0.2 + randFactor2 * 0.2);
      final wave3 = sin((index + randFactor3 * 10) * 1.2) * (0.15 + randFactor3 * 0.15);

      // Combine waves for unique pattern per audio file
      var height = 0.25 + (sin(baseHeight) * 0.35) + wave1 + wave2 + wave3;

      return height.clamp(0.15, 1.0);
    });

    for (int i = 0; i < barCount; i++) {
      final x = i * (barWidth + spacing) + barWidth / 2;
      final barProgress = i / barCount;
      final isPlayed = barProgress <= progress;

      final height = heights[i] * size.height;
      final y1 = (size.height - height) / 2;
      final y2 = y1 + height;

      canvas.drawLine(
        Offset(x, y1),
        Offset(x, y2),
        isPlayed ? playedPaint : unplayedPaint,
      );
    }
  }

  @override
  bool shouldRepaint(WaveformPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
