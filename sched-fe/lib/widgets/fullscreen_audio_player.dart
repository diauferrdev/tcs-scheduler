import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';
import 'dart:math';

/// Fullscreen audio player with waveform for media viewer
/// Automatically extracts duration from the audio file
class FullscreenAudioPlayer extends StatefulWidget {
  final String audioUrl;
  final String fileName;

  const FullscreenAudioPlayer({
    super.key,
    required this.audioUrl,
    required this.fileName,
  });

  @override
  State<FullscreenAudioPlayer> createState() => _FullscreenAudioPlayerState();
}

class _FullscreenAudioPlayerState extends State<FullscreenAudioPlayer> {
  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = true;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _playerStateSubscription;

  // Generate unique seed from filename for consistent waveform
  int get _waveformSeed {
    int hash = 0;
    for (int i = 0; i < widget.fileName.length; i++) {
      hash = ((hash << 5) - hash) + widget.fileName.codeUnitAt(i);
      hash = hash & hash;
    }
    return hash.abs();
  }

  @override
  void initState() {
    super.initState();
    _initAudioPlayer();
  }

  Future<void> _initAudioPlayer() async {
    try {
      final player = AudioPlayer();
      _audioPlayer = player;

      // Setup listeners
      _positionSubscription = player.onPositionChanged.listen((position) {
        if (mounted) {
          setState(() {
            _position = position;
          });
        }
      });

      _durationSubscription = player.onDurationChanged.listen((duration) {
        if (mounted) {
          setState(() {
            _duration = duration;
            _isLoading = false;
          });
          debugPrint('[FullscreenAudioPlayer] Duration loaded: ${_formatDuration(duration)}');
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

      // Load audio to get duration
      await player.setSourceUrl(widget.audioUrl);

      // Fallback: if duration is not loaded after 2 seconds, stop loading
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      debugPrint('[FullscreenAudioPlayer] Error initializing: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    if (_audioPlayer == null) return;

    try {
      if (_isPlaying) {
        await _audioPlayer!.pause();
      } else {
        await _audioPlayer!.resume();
      }
    } catch (e) {
      debugPrint('[FullscreenAudioPlayer] Playback error: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final progress = _duration.inMilliseconds > 0
        ? _position.inMilliseconds / _duration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF2F2F2F),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // File name
          Text(
            widget.fileName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 32),

          // Play/Pause Button
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.black,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Waveform visualization
          SizedBox(
            height: 60,
            child: CustomPaint(
              painter: WaveformPainter(
                progress: progress,
                isPlaying: _isPlaying,
                seed: _waveformSeed,
              ),
              size: Size.infinite,
            ),
          ),
          const SizedBox(height: 16),

          // Progress slider
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
              thumbColor: Colors.white,
              overlayColor: Colors.white.withValues(alpha: 0.2),
            ),
            child: Slider(
              value: progress.clamp(0.0, 1.0),
              onChanged: (value) async {
                final newPosition = Duration(
                  milliseconds: (_duration.inMilliseconds * value).round(),
                );
                await _audioPlayer?.seek(newPosition);
              },
            ),
          ),

          // Time display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(_position),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _formatDuration(_duration),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
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
    final barCount = 50;
    final barWidth = 3.0;
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
      final randFactor1 = random.nextDouble();
      final randFactor2 = random.nextDouble();
      final randFactor3 = random.nextDouble();

      final baseHeight = (index / barCount) * 2.0;
      final wave1 = sin((index + randFactor1 * 10) * 0.5) * (0.3 + randFactor1 * 0.3);
      final wave2 = cos((index + randFactor2 * 10) * 0.8) * (0.2 + randFactor2 * 0.2);
      final wave3 = sin((index + randFactor3 * 10) * 1.2) * (0.15 + randFactor3 * 0.15);

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
