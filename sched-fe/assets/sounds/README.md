# Splash Screen Sound Effect

## How to Add Sound to Splash Screen

1. **Add your sound file** to this directory:
   - File name: `splash.mp3` (or `splash.wav`)
   - Recommended: Short sound (0.5-1.5 seconds)
   - Suggested sounds:
     - Subtle chime/bell
     - Soft "whoosh" sound
     - Corporate brand sound
     - Notification beep

2. **Uncomment the sound code** in `lib/screens/animated_splash_screen.dart`:
   ```dart
   // Find this line (around line 109):
   // await _audioPlayer.play(AssetSource('sounds/splash.mp3'));

   // Remove the // to enable:
   await _audioPlayer.play(AssetSource('sounds/splash.mp3'));
   ```

3. **Rebuild the app** to include the sound file in the bundle.

## Recommended Sound Sources

- **Free Sound Libraries:**
  - Zapsplat: https://www.zapsplat.com/
  - Freesound: https://freesound.org/
  - Mixkit: https://mixkit.co/free-sound-effects/

- **AI Sound Generators:**
  - ElevenLabs Sound Effects
  - Suno Sound Effects

## Sound Specifications

- **Duration**: 0.5-1.5 seconds (short and professional)
- **Format**: MP3 or WAV
- **Volume**: Moderate (not too loud)
- **Style**: Corporate, clean, modern
- **File size**: < 50KB recommended

## Testing

After adding the sound:
1. Run the app on a real device (sound may not work in simulators)
2. Check device volume is on
3. Verify sound plays during splash screen fade-in
