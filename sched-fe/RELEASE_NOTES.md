# TCS Pace Scheduler - Release Notes

This file tracks release notes for upcoming versions. The "Next Release" section is automatically included in build distributions.

---

## Next Release

### Features
- Animated splash screen with progressive logo fill effect
- Professional 3-second startup animation with smooth transitions
- Native splash screen support for Android 12+ and iOS
- Enhanced visual experience with black background and white animated logo

### Bug Fixes
- Fixed SEO helper dart:html import error on mobile platforms
- Implemented conditional imports for web-only functionality
- Resolved build compatibility issues across all platforms

### Improvements
- Optimized app startup sequence with SplashMaster integration
- Added fade and scale animations for polished user experience
- Created platform-specific stub implementations for cross-platform compatibility

---

## Previous Releases

### v1.1.16 (Build 56)
- Complete web PWA icon set for all sizes (72, 96, 128, 384px)
- Added PWA shortcut icons for Calendar, Bookings, and Dashboard
- All fonts verified and working across all platforms

### v1.1.15 (Build 54)
- Restored missing build scripts (android.sh, web.sh)
- All build automation scripts recovered from previous commits

### v1.1.14 (Build 52)
- Eliminated duplicate notifications across browser and mobile
- Removed emojis from notification messages
- Fixed My Bookings screen reactivity with loading states
- Resolved Babylon.js blocking app startup

### v1.1.13 (Build 51)
- Fixed notification system architecture

### v1.1.11 (Build 49)
- Show blocked period reasons in booking time picker

### v1.1.10 (Build 48)
- Resolved duplicate notifications
- Improved IE/PE availability validation
