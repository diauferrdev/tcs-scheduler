# TCS Logo Assets

## Logo Organization

### TCS Pace Scheduler Logos (with "Scheduler" text)
Used in app headers, landing page header, and login screen.

- `tcs-pace-logo-w.svg` - White version with "Scheduler" text
- `tcs-pace-logo-b.svg` - Black version with "Scheduler" text
- `tcs-pace-logo.svg` - Original version

### TCS Pace Logos (without "Scheduler" text)
Used in badges, tickets, and print materials.

- `tcs-pace-logo-only-w.svg` - White version without text
- `tcs-pace-logo-only-b.svg` - Black version without text

### TATA Corporate Logos (with "TATA" text)
For formal corporate communications.

- `tcs-tata-logo-blue.svg` - Official TATA blue color
- `tcs-tata-logo-w.svg` - White version
- `tcs-tata-logo-b.svg` - Black version

### TATA Icon Only (no text)
For compact displays and icons.

- `tcs-tata-icon-blue.svg` - Official TATA blue color
- `tcs-tata-icon-w.svg` - White version
- `tcs-tata-icon-b.svg` - Black version

### Legacy Assets (deprecated)
These should no longer be used in new code:

- `tcs-logo-w.svg` - Old small TCS logo (white)
- `tcs-logo-b.svg` - Old small TCS logo (black)
- `Tata_logo.svg` - Old TATA logo

## Usage Guidelines

### App Layout & Headers
```dart
SvgPicture.asset(
  isDark ? 'assets/logos/tcs-pace-logo-w.svg' : 'assets/logos/tcs-pace-logo-b.svg',
  height: 32,
)
```

### Access Badges & Tickets
```dart
SvgPicture.asset(
  isDark ? 'assets/logos/tcs-pace-logo-only-w.svg' : 'assets/logos/tcs-pace-logo-only-b.svg',
  height: 40,
)
```

### PDF Generation
```dart
final logoSvg = await rootBundle.loadString('assets/logos/tcs-pace-logo-only-b.svg');
```

### Landing Page Footer
```dart
SvgPicture.asset('assets/logos/tcs-pace-logo-w.svg', height: 32)
```
