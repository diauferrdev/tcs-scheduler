# Release Workflow Guide

Quick reference for releasing new versions of TCS Pace Scheduler.

## 🎯 Quick Start

### 1. Update Release Notes
```bash
bash scripts/update-release-notes.sh
```
Or manually edit `RELEASE_NOTES.md`

### 2. Build & Deploy

**For Mobile:**
```bash
# Android
bash scripts/build/android.sh patch  # or minor, major

# iOS (on macOS)
bash scripts/build/ios.sh patch
```
→ Automatically deploys to Firebase App Distribution

**For Desktop:**
```bash
git tag v1.0.0
git push --tags
```
→ GitHub Actions automatically builds all platforms and creates release

## 📋 Complete Workflow

### Step-by-Step Process

**1. Prepare Release Notes**
```bash
# Interactive wizard (recommended)
bash scripts/update-release-notes.sh

# Or edit manually
nano RELEASE_NOTES.md
```

Update the "Next Release" section with:
- Changes
- Features
- Bug Fixes

**2. Choose Your Platform**

#### Option A: Mobile Release (Firebase App Distribution)

**Android:**
```bash
cd tcs_pace_scheduler
bash scripts/build/android.sh patch  # Bug fixes
bash scripts/build/android.sh minor  # New features
bash scripts/build/android.sh major  # Breaking changes
```

**iOS:** (requires macOS)
```bash
cd tcs_pace_scheduler
bash scripts/build/ios.sh patch
```

What happens:
- ✅ Version incremented in `pubspec.yaml`
- ✅ Backend `version.ts` updated
- ✅ APK/IPA built
- ✅ **Automatically deployed to Firebase App Distribution**
- ✅ Git commit and tag created
- ✅ Testers receive notification

#### Option B: Desktop Release (GitHub Releases)

```bash
# Make sure release notes are updated first!
git tag v1.0.0
git push --tags
```

What happens:
- ✅ GitHub Actions workflow triggered
- ✅ Windows, Linux, macOS built in parallel
- ✅ GitHub Release created automatically
- ✅ All artifacts uploaded
- ✅ Release notes from `RELEASE_NOTES.md` used

## 🔑 Key Points

### Single Source of Truth
All platforms use `RELEASE_NOTES.md`:
- Android → Firebase App Distribution
- iOS → Firebase App Distribution
- Windows → GitHub Releases
- Linux → GitHub Releases
- macOS → GitHub Releases

### Version Numbering
```
1.2.3+45
│ │ │  │
│ │ │  └─ Build number (auto-incremented)
│ │ └──── Patch (bug fixes)
│ └────── Minor (new features)
└──────── Major (breaking changes)
```

### Build Types
- `patch`: 1.0.0 → 1.0.1 (bug fixes)
- `minor`: 1.0.0 → 1.1.0 (new features)
- `major`: 1.0.0 → 2.0.0 (breaking changes)

## 📦 Distribution Summary

| Platform | Method | Command | Notes |
|----------|--------|---------|-------|
| Android | Firebase | `./scripts/build/android.sh patch` | Automatic deployment |
| iOS | Firebase | `./scripts/build/ios.sh patch` | Requires macOS |
| Windows | GitHub | `git tag v1.0.0 && git push --tags` | Automated via Actions |
| Linux | GitHub | `git tag v1.0.0 && git push --tags` | Automated via Actions |
| macOS | GitHub | `git tag v1.0.0 && git push --tags` | Automated via Actions |

## ⚠️ Important Notes

1. **Always update `RELEASE_NOTES.md` first!**
   - Mobile scripts read from it
   - GitHub Actions reads from it
   - Ensures consistency across all platforms

2. **Mobile and Desktop are separate workflows**
   - Mobile: Run build scripts → Firebase App Distribution
   - Desktop: Push tag → GitHub Actions → GitHub Releases

3. **Don't commit build artifacts**
   - APK/IPA files are uploaded to Firebase
   - Desktop builds are uploaded to GitHub Releases
   - All build outputs are in `.gitignore`

## 🐛 Troubleshooting

**Release notes not showing up?**
- Make sure you updated `RELEASE_NOTES.md` before building
- Check the "Next Release" section has content

**Firebase deployment failed?**
- Check Firebase CLI is installed: `firebase --version`
- Check you're logged in: `firebase login`
- App IDs are hardcoded in scripts

**GitHub Actions failed?**
- Check Actions tab in GitHub repository
- Ensure tag matches `v*.*.*` pattern
- Check workflow file: `.github/workflows/release.yml`

## 📚 Related Files

- `RELEASE_NOTES.md` - Centralized release notes
- `scripts/update-release-notes.sh` - Interactive update tool
- `scripts/lib/get-release-notes.sh` - Helper library
- `scripts/build/android.sh` - Android build script
- `scripts/build/ios.sh` - iOS build script
- `.github/workflows/release.yml` - Desktop automation
- `BUILD_DISTRIBUTION.md` - Detailed distribution guide
