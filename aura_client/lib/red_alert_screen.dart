import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:async';

class RedAlertScreen extends StatefulWidget {
  final String location;
  const RedAlertScreen({super.key, required this.location});

  @override
  State<RedAlertScreen> createState() => _RedAlertScreenState();
}

class _RedAlertScreenState extends State<RedAlertScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<Color?> _colorAnimation;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _vibrationTimer;

  @override
  void initState() {
    super.initState();

    // Setup pulsing animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: const Color(0xFFD32F2F),
      end: const Color(0xFFFF5252),
    ).animate(_pulseController);

    // Trigger siren and vibration
    _triggerAlerts();
  }

  Future<void> _triggerAlerts() async {
    // Attempt continuous vibration
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      _vibrationTimer = Timer.periodic(const Duration(milliseconds: 1000), (
        timer,
      ) {
        Vibration.vibrate(pattern: [0, 500, 200, 500]);
      });
    }

    // Audio alert - disabled for emulator compatibility
    // Vibration pattern is still active above
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Uncomment below for real device with local asset:
      // await _audioPlayer.play(AssetSource('sounds/siren.mp3'));
    } catch (e) {
      debugPrint("Audio init skipped: $e");
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _vibrationTimer?.cancel();
    Vibration.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return Container(
            color: _colorAnimation.value,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 150,
                  color: Colors.white,
                ),
                const SizedBox(height: 32),
                const Text(
                  'EVACUATE IMMEDIATELY',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'HAZARD DETECTED AT:\n${widget.location.toUpperCase()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    // Stop alerts
                    _vibrationTimer?.cancel();
                    Vibration.cancel();
                    _audioPlayer.stop();
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFD32F2F),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 16,
                    ),
                  ),
                  child: const Text(
                    'I AM SAFE',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
