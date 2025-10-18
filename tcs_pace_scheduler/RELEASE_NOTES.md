# Release Notes

This file contains the release notes for the next version to be released.
All build scripts (Android, iOS, Windows, Linux, macOS) and GitHub Actions workflow read from this file to ensure consistency across all platforms.

## How to Use

Before building a new release:
1. Update the "Next Release" section below with your changes
2. Run the build script (it will use these notes automatically)
3. The notes will be deployed to Firebase App Distribution and/or GitHub Releases

---

## Next Release

### Changes
- Bug fixes and improvements
- Performance optimizations

### Features
- Initial release

### Bug Fixes
- Various stability improvements

---

## Previous Releases

### v1.0.11 (Build 35) - 2025-01-XX
- Fixed Linux keyring authentication error with automatic fallback to SharedPreferences
- Added proper branding across all platforms (name, icons, descriptions)
- Generated multiple Linux distribution formats (AppImage, Flatpak, Snap)
- Improved build scripts with comprehensive documentation

### v1.0.10 (Build 29)
- Fixed infinite loading dialogs
- Improved navigation flow
- Enhanced notification handling
