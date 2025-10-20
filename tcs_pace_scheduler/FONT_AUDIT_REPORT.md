# TCS PacePort Scheduler - Font Usage Audit Report

**Generated:** 2025-10-19
**Scope:** All Dart files in `lib/screens/` and `lib/widgets/`
**Auditor:** Claude Code

---

## Executive Summary

This audit identified **300+ instances** of hardcoded font styling across 35+ files that bypass the TCS brand typography system defined in `theme_provider.dart`. These violations create font inconsistency and make the app harder to maintain.

### Severity Distribution

- **CRITICAL (0 issues):** No incorrect fontFamily specifications found
- **HIGH (280+ issues):** TextStyle with fontSize/fontWeight without Theme reference
- **MEDIUM (50+ issues):** TextStyle with only color changes (acceptable pattern but review needed)
- **LOW (2 issues):** Monospace for technical IDs (acceptable - activity logs and access badge)

---

## TCS Font Hierarchy Reference

### Correct Typography System (from theme_provider.dart)

```dart
// Display Styles - BasisGrotesquePro Bold (w700)
displayLarge:  57px, w700, 'BasisGrotesquePro'  // Large hero text
displayMedium: 45px, w700, 'BasisGrotesquePro'  // Medium hero text
displaySmall:  36px, w700, 'BasisGrotesquePro'  // Small hero text

// Headline Styles - HouschkaRoundedAlt Medium (w500)
headlineLarge:  32px, w500, 'HouschkaRoundedAlt'  // Section headings
headlineMedium: 28px, w500, 'HouschkaRoundedAlt'  // Sub-section headings
headlineSmall:  24px, w500, 'HouschkaRoundedAlt'  // Tertiary headings

// Title Styles - HouschkaRoundedAlt Medium (w500)
titleLarge:  22px, w500, 'HouschkaRoundedAlt'  // Emphasized text
titleMedium: 16px, w500, 'HouschkaRoundedAlt'  // Card titles
titleSmall:  14px, w500, 'HouschkaRoundedAlt'  // Small titles

// Body Styles - BasisGrotesquePro Regular (w400)
bodyLarge:  16px, w400, 'BasisGrotesquePro'  // Main content
bodyMedium: 14px, w400, 'BasisGrotesquePro'  // Secondary content
bodySmall:  12px, w400, 'BasisGrotesquePro'  // Tertiary content

// Label Styles - BasisGrotesquePro Medium (w500)
labelLarge:  14px, w500, 'BasisGrotesquePro'  // Buttons, tabs
labelMedium: 12px, w500, 'BasisGrotesquePro'  // Small buttons
labelSmall:  11px, w500, 'BasisGrotesquePro'  // Tiny labels
```

---

## CRITICAL Issues (0 found)

**No critical font family violations detected.** All text uses the correct TCS fonts through the theme system.

---

## HIGH Priority Issues (280+ instances)

These are TextStyle() instances with hardcoded fontSize/fontWeight that should use Theme.of(context).textTheme instead.

### Category 1: Screen Files

#### **lib/screens/login_screen.dart**

**Lines 127, 130, 181, 184** - TextFormField style and hintStyle
```dart
// CURRENT (WRONG)
style: const TextStyle(color: Colors.white),
hintStyle: const TextStyle(color: Color(0xFF6B7280)),

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white),
hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Color(0xFF6B7280)),
```
**Severity:** HIGH - Missing font family and weight specification
**Impact:** Input fields don't follow TCS typography
**Fix:** Use `bodyMedium` for text inputs (14px, BasisGrotesquePro Regular)

---

#### **lib/screens/invitations_screen.dart**

**Line 95** - Main heading
```dart
// CURRENT (WRONG)
style: TextStyle(color: isDark ? Colors.white : Colors.black),

// RECOMMENDED FIX
style: Theme.of(context).textTheme.headlineMedium?.copyWith(
  color: isDark ? Colors.white : Colors.black
)
```
**Severity:** HIGH
**Impact:** Page title uses wrong font (should be HouschkaRoundedAlt Medium 28px)

**Line 103** - Section heading with fontSize
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.headlineSmall?.copyWith(
  color: isDark ? Colors.white : Colors.black
)
```
**Severity:** HIGH
**Impact:** Hardcoded 24px bold should be `headlineSmall` (24px, HouschkaRoundedAlt Medium)

**Line 115** - Input hint style
```dart
// CURRENT (WRONG)
hintStyle: TextStyle(
  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)
),

// RECOMMENDED FIX
hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280)
)
```

**Lines 221-223** - Dropdown label with fontWeight
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelLarge?.copyWith(
  color: isDark ? Colors.white : Colors.black
)
```
**Severity:** HIGH
**Impact:** Labels should use `labelLarge` (14px, BasisGrotesquePro Medium)

**Lines 394-430** - Multiple invitation card text styles
```dart
// CURRENT (WRONG) - Line 394
style: TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium?.copyWith(
  color: isDark ? Colors.white : Colors.black
)
```
**Note:** titleMedium is 16px not 18px - may need titleLarge (22px) or accept 16px

**Line 430** - Invitation ID
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 14,
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  color: isDark ? Colors.grey[400] : Colors.grey[600]
)
```

**Line 432** - Monospace ID (ACCEPTABLE)
```dart
// CURRENT (ACCEPTABLE)
fontFamily: 'monospace',
```
**Severity:** LOW - Technical IDs can use monospace

---

#### **lib/screens/my_bookings_screen.dart**

**Lines 414-415** - Filter chips
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelMedium?.copyWith(
  color: isDark ? Colors.white : Colors.black
)
```
**Severity:** HIGH
**Impact:** Filter chips should use `labelMedium` (12px, BasisGrotesquePro Medium)

**Lines 452-453** - Another filter style
```dart
// Same pattern as above, same fix
```

---

#### **lib/screens/agenda_screen.dart**

**Line 245** - Page title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.headlineSmall
```
**Severity:** HIGH
**Impact:** Main heading should use `headlineSmall` (24px, HouschkaRoundedAlt Medium)

**Lines 269-270** - Tab labels
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium?.copyWith(
  // Note: titleMedium is 16px, may need titleLarge (22px) for closer match
)
```

**Lines 468-469** - Date numbers
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.bold,
  color: Colors.white,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelMedium?.copyWith(
  color: Colors.white,
)
```

**Lines 503-504** - Large date display
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.headlineLarge?.copyWith(
  color: isDark ? Colors.white : Colors.black,
)
```
**Severity:** HIGH
**Impact:** Large numbers should use `headlineLarge` (32px, HouschkaRoundedAlt Medium)

**Lines 535-536** - Small date text
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelSmall?.copyWith(
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)
```

---

#### **lib/screens/calendar_screen.dart** (66+ violations)

This file has extensive hardcoded styling throughout. Major patterns:

**Lines 831-832** - Calendar header
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

**Lines 1208, 1251** - Calendar day headers
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 14, color: Colors.grey[500])
style: TextStyle(fontSize: 12, color: Colors.grey[500])

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[500])
style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500])
```

**Lines 1297, 1319** - Time slot labels
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
style: TextStyle(fontSize: 12, color: Colors.grey[500])

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[500])
```

**Lines 1776-1785** - Booking card info
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)
style: TextStyle(fontSize: 12, color: Colors.grey[400])

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelLarge
style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[400])
```

**Lines 2175, 2340, 2351** - Booking counts with responsive sizing
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: isMobile ? 10 : 12, fontWeight: FontWeight.bold)
style: TextStyle(fontSize: 10, color: Colors.grey[500])
style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelMedium?.copyWith(
  fontSize: isMobile ? 10 : 12, // Keep responsive but use theme base
)
style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.grey[500])
```
**Note:** Some responsive sizing may be justified, but should still start from theme

**Lines 2632, 2642** - Weekday headers with responsive sizing
```dart
// CURRENT (WRONG)
fontSize: isMobile ? 7 : 8,
fontSize: isMobile ? 6 : 7,

// RECOMMENDED FIX
// These are extremely small - consider if they can use labelSmall (11px) or need custom sizing
```

---

#### **lib/screens/users_screen.dart**

**Line 509** - Section heading
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

**Lines 640, 658, 674, 705** - User card labels
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelLarge
style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
```

---

#### **lib/screens/notifications_screen.dart** (20+ violations)

**Line 282** - Screen title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.headlineSmall
```

**Lines 510, 600, 641** - Tab/section labels
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

**Lines 716, 1147, 1450** - Notification titles with conditional weight
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
)

// RECOMMENDED FIX
style: notification.isRead
  ? Theme.of(context).textTheme.bodyMedium
  : Theme.of(context).textTheme.labelLarge
```

---

#### **lib/screens/landing_screen.dart** (25+ violations)

**Line 149** - Hero text
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 48,
  fontWeight: FontWeight.w600,
  color: Colors.white,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.displayMedium?.copyWith(
  color: Colors.white,
)
```
**Note:** displayMedium is 45px, close to 48px

**Line 266** - Large hero number
```dart
// CURRENT (WRONG)
fontSize: 72,
fontWeight: FontWeight.w900,

// RECOMMENDED FIX
style: Theme.of(context).textTheme.displayLarge?.copyWith(
  fontWeight: FontWeight.w900, // Can override weight if needed
)
```
**Note:** displayLarge is 57px, may need custom for 72px hero

**Lines 512, 574, 658, 735, 834** - Section headings
```dart
// CURRENT (WRONG)
fontSize: 32,
fontWeight: FontWeight.bold,

// RECOMMENDED FIX
style: Theme.of(context).textTheme.headlineLarge
```

---

#### **lib/screens/booking_form_screen.dart** (15+ violations)

**Line 559** - Form section heading
```dart
// CURRENT (WRONG)
fontSize: 20,
fontWeight: FontWeight.bold,

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleLarge
```
**Note:** titleLarge is 22px, close enough

**Line 647** - Step indicator
```dart
// CURRENT (WRONG)
fontSize: 16,
fontWeight: FontWeight.bold,

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

**Lines 790, 893** - Field labels
```dart
// CURRENT (WRONG)
fontSize: 14,
fontWeight: FontWeight.bold,

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelLarge
```

---

#### **lib/screens/approvals_screen.dart** (10+ violations)

**Lines 230, 245, 270, 285, 319** - Approval card text
```dart
// CURRENT (WRONG)
fontSize: 16,
fontWeight: FontWeight.bold,

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

---

#### **lib/screens/booking_flow/** files

**base_info_drawer.dart:**
- Line 250: `fontSize: 20, fontWeight: bold` → `titleLarge`
- Line 471: `fontSize: 14, fontWeight: w500` → `labelLarge`
- Line 544: `fontSize: 16, fontWeight: w600` → `titleMedium`

**engagement_type_drawer.dart:**
- Line 65: `fontSize: 20, fontWeight: bold` → `titleLarge`
- Line 139: `fontSize: 16, fontWeight: w600` → `titleMedium`

**visit_type_drawer.dart:**
- Line 67: `fontSize: 20, fontWeight: bold` → `titleLarge`
- Line 143: `fontSize: 16, fontWeight: w600` → `titleMedium`

**questionnaire_drawer.dart:**
- Line 158: `fontSize: 20, fontWeight: bold` → `titleLarge`
- Line 273: `fontSize: 16, fontWeight: w600` → `titleMedium`

---

### Category 2: Widget Files

#### **lib/widgets/app_layout.dart**

**Lines 375-377** - Navigation labels
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 14,
  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
  color: isActive ? Colors.white : Colors.grey[400],
)

// RECOMMENDED FIX
style: isActive
  ? Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white)
  : Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[400])
```
**Severity:** HIGH
**Impact:** Navigation items should follow theme typography

**Lines 419-421** - Bottom nav labels
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 10,
  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
  color: isActive ? Colors.white : Colors.grey[400],
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelSmall?.copyWith(
  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
  color: isActive ? Colors.white : Colors.grey[400],
)
```
**Note:** labelSmall is 11px, may need to override to 10px for space

---

#### **lib/widgets/access_badge.dart** (70+ violations)

This file has extensive hardcoded styling for PDF generation and UI rendering.

**PDF-specific styles (pw.TextStyle):**
Lines 190-295 contain PDF widget styles which are **acceptable** as they use the `pdf` package's separate styling system. These don't need to change.

**UI rendering violations:**

**Lines 814-815** - Dialog title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 11,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelSmall?.copyWith(
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)
```

**Lines 853-868** - Badge labels
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
style: TextStyle(fontSize: 13, color: Colors.grey[600])

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)
style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])
```

**Lines 961-972** - Large display text
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)
style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)
```

**Lines 1014-1029** - QR code section
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'BasisGrotesquePro')

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)
// Note: 24px w900 is custom, closest is headlineSmall but different weight
```

**Line 1158** - Monospace ID (ACCEPTABLE)
```dart
// CURRENT (ACCEPTABLE)
fontFamily: 'monospace',
```

**Lines 1199, 1214, 1229** - Button labels
```dart
// CURRENT (WRONG)
label: const Text('Share', style: TextStyle(fontSize: 12)),

// RECOMMENDED FIX
label: Text('Share', style: Theme.of(context).textTheme.labelMedium),
```

---

#### **lib/widgets/profile_drawer.dart** (25+ violations)

**Line 268** - Drawer title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleLarge
```

**Lines 310-311** - Profile name large
```dart
// CURRENT (WRONG)
style: const TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: Colors.white,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white)
```

**Lines 326-327** - Role text
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.bold,
  color: Colors.white,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)
```

**Lines 349-350** - Section labels
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Colors.white70,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white70)
```

**Lines 402-411** - Info cards
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 12, color: Colors.grey[400])
style: TextStyle(fontSize: 14, color: Colors.white)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[400])
style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white)
```

**Lines 576-585** - Form labels
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
style: TextStyle(fontSize: 12, color: Colors.grey[400])

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[400])
```

---

#### **lib/widgets/calendar_month_widget.dart**

**Lines 154-156** - Weekday headers
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: isMobile ? 7 : 8,
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.grey[500] : Colors.grey[600],
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelSmall?.copyWith(
  fontSize: isMobile ? 7 : 8, // Override if needed for tiny headers
  color: isDark ? Colors.grey[500] : Colors.grey[600],
)
```
**Note:** Extremely small text (7-8px) may justify custom sizing

**Lines 164-166** - Month labels
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: isMobile ? 6 : 7,
  color: isDark ? Colors.grey[600] : Colors.grey[500],
)

// RECOMMENDED FIX
// Same as above - extremely small
```

**Lines 199-201** - Date numbers
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelMedium
```

**Lines 259-261** - Booking count indicators
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: isMobile ? 10 : 12,
  fontWeight: FontWeight.bold,
  color: Colors.white,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelMedium?.copyWith(
  fontSize: isMobile ? 10 : 12,
  color: Colors.white,
)
```

---

#### **lib/widgets/standard_drawer.dart**

**Lines 136-138** - Drawer title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleLarge
```

**Lines 146-147** - Subtitle
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 14,
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)
```

---

#### **lib/widgets/reschedule_drawer.dart**

**Lines 209-211** - Title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleLarge
```

**Lines 218-219** - Subtitle
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 13,
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)
```
**Note:** bodyMedium is 14px, close to 13px

---

#### **lib/widgets/reschedule_dialog.dart** (20+ violations)

**Lines 191-193** - Dialog title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.headlineSmall
```

**Lines 222-224** - Section heading
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

**Lines 260-262** - Field labels
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelLarge
```

**Lines 433-435** - Time slot buttons
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 14,
  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
  color: isSelected ? Colors.black : (isDark ? Colors.white : Colors.black),
)

// RECOMMENDED FIX
style: isSelected
  ? Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.black)
  : Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: isDark ? Colors.white : Colors.black,
    )
```

---

#### **lib/widgets/edit_booking_drawer.dart** (30+ violations)

**Lines 327-329** - Drawer title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleLarge
```

**Lines 338-339** - Subtitle
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 13,
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)
```

**Lines 627-628** - Section headers
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

**Lines 698-699, 733** - Field labels
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 13, color: Colors.grey[600])

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])
```

**Lines 918-919** - Hint text
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelLarge
```

---

#### **lib/widgets/attachment_picker.dart**

**Lines 79-81** - Picker title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleLarge
```

**Lines 141-142** - File type labels
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 16,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

**Lines 195-205** - File info
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
style: TextStyle(fontSize: 14, color: Colors.grey[600])

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])
```

---

#### **lib/widgets/attachment_manager.dart**

**Lines 50-52** - Section title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

**Lines 67-68** - Count badge
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Colors.white,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.white)
```

**Lines 145-154** - File list items
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)
style: TextStyle(fontSize: 14, color: Colors.grey[600])

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])
```

---

#### **lib/widgets/booking_status_stepper.dart**

**Lines 224-226** - Status labels
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 9,
  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
  color: textColor,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelSmall?.copyWith(
  fontSize: 9, // Override if 11px is too large
  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
  color: textColor,
)
```
**Note:** Extremely small text may justify custom sizing

---

#### **lib/widgets/notification_bell.dart**

**Lines 99-102** - Badge count
```dart
// CURRENT (WRONG)
style: const TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.bold,
  color: Colors.white,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelSmall?.copyWith(
  fontSize: 10,
  color: Colors.white,
)
```

---

#### **lib/widgets/booking_form_fields.dart**

**Lines 488, 523-525** - Field labels and hints
```dart
// CURRENT (WRONG)
style: TextStyle(color: isDark ? Colors.white : Colors.black)
style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodyMedium
style: Theme.of(context).textTheme.labelLarge
```

**Lines 658-659** - Required indicator
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontWeight: FontWeight.w600,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelLarge
```

---

### Category 3: Service Files

#### **lib/services/universal_update_service.dart** (15+ violations)

**Lines 157-158** - Dialog title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleLarge
```

**Lines 190, 194, 206, 210** - Change list labels
```dart
// CURRENT (WRONG)
style: TextStyle(fontWeight: FontWeight.bold)
style: TextStyle(fontSize: 14, color: Colors.grey[600])

// RECOMMENDED FIX
style: Theme.of(context).textTheme.labelLarge
style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])
```

**Lines 222, 233** - Version info
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 14)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.bodyMedium
```

---

#### **lib/services/drawer_service.dart**

**Lines 216-217** - Drawer title
```dart
// CURRENT (WRONG)
style: TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.bold,
  color: isDark ? Colors.white : Colors.black,
)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleLarge
```

---

#### **lib/utils/document_opener.dart**

**Lines 153, 164** - Error dialog text
```dart
// CURRENT (WRONG)
style: TextStyle(fontSize: 16, color: Colors.black)

// RECOMMENDED FIX
style: Theme.of(context).textTheme.titleMedium
```

---

## MEDIUM Priority Issues (50+ instances)

These are TextStyle() instances that only change color without fontSize/fontWeight. They're acceptable but should be reviewed to ensure they're using the right base style.

### Pattern Examples:

**lib/widgets/profile_drawer.dart**
```dart
// Lines 187, 191
style: TextStyle(color: isDark ? Colors.white : Colors.black),
style: TextStyle(color: isDark ? Colors.grey[300] : Colors.grey[700]),
```
**Current Status:** These rely on inherited text style from parent
**Recommendation:** Make explicit with theme reference for clarity

**lib/screens/invitations_screen.dart**
```dart
// Lines 95, 112
style: TextStyle(color: isDark ? Colors.white : Colors.black),
```
**Current Status:** Acceptable but implicit
**Recommendation:** Add explicit theme reference

**lib/widgets/booking_form_fields.dart**
```dart
// Line 899
style: TextStyle(color: isDark ? Colors.white : Colors.black),
```

**lib/widgets/edit_booking_drawer.dart**
```dart
// Line 638
style: TextStyle(color: isDark ? Colors.white : Colors.black),
```

**Recommended Pattern:**
```dart
// Instead of relying on inheritance
style: TextStyle(color: isDark ? Colors.white : Colors.black),

// Be explicit
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  color: isDark ? Colors.white : Colors.black,
)
```

---

## LOW Priority Issues (2 instances)

### Acceptable Monospace Usage

**lib/screens/activity_logs_screen.dart - Line 532**
```dart
fontFamily: 'monospace',
```
**Context:** Technical log IDs
**Status:** ACCEPTABLE - Monospace is appropriate for technical identifiers

**lib/widgets/access_badge.dart - Line 1158**
```dart
fontFamily: 'monospace',
```
**Context:** Booking ID display
**Status:** ACCEPTABLE - Monospace is appropriate for IDs

---

## Summary Statistics

| Category | Count | Priority |
|----------|-------|----------|
| CRITICAL - Wrong fontFamily | 0 | - |
| HIGH - Hardcoded size/weight | 280+ | Fix immediately |
| MEDIUM - Color-only changes | 50+ | Review and make explicit |
| LOW - Monospace for IDs | 2 | Acceptable as-is |
| **TOTAL ISSUES** | **330+** | |

### Files by Issue Count

| File | Issues | Priority |
|------|--------|----------|
| calendar_screen.dart | 66+ | HIGH |
| access_badge.dart | 70+ | HIGH (40 UI, 30 PDF) |
| landing_screen.dart | 25+ | HIGH |
| profile_drawer.dart | 25+ | HIGH |
| edit_booking_drawer.dart | 30+ | HIGH |
| reschedule_dialog.dart | 20+ | HIGH |
| notifications_screen.dart | 20+ | HIGH |
| agenda_screen.dart | 15+ | HIGH |
| booking_form_screen.dart | 15+ | HIGH |
| invitations_screen.dart | 15+ | HIGH |
| universal_update_service.dart | 15+ | HIGH |
| Other 25+ files | 90+ | HIGH/MEDIUM |

---

## Implementation Priority

### Phase 1: Critical Path (Week 1)
1. **calendar_screen.dart** - Most user-visible, highest issue count
2. **landing_screen.dart** - First impression, hero text critical
3. **my_bookings_screen.dart** - Primary user workflow
4. **invitations_screen.dart** - Key admin functionality

### Phase 2: Core Workflows (Week 2)
5. **booking_form_screen.dart** - Booking creation flow
6. **booking_flow/** drawers - Wizard steps
7. **edit_booking_drawer.dart** - Editing workflow
8. **reschedule_dialog.dart** - Rescheduling workflow
9. **approvals_screen.dart** - Manager workflow

### Phase 3: Supporting UI (Week 3)
10. **app_layout.dart** - Navigation consistency
11. **profile_drawer.dart** - User settings
12. **access_badge.dart** - Badge display (UI only, skip PDF)
13. **attachment_picker.dart** / **attachment_manager.dart**
14. **notification_bell.dart**

### Phase 4: Secondary Screens (Week 4)
15. **agenda_screen.dart**
16. **users_screen.dart**
17. **notifications_screen.dart**
18. **activity_logs_screen.dart**
19. **dashboard_screen.dart**

### Phase 5: Utilities (Week 5)
20. **universal_update_service.dart**
21. **drawer_service.dart**
22. **document_opener.dart**
23. Remaining widget files

---

## Systematic Fix Approach

### Step-by-Step Process

For each file:

1. **Read the file completely**
2. **Identify all TextStyle() instances**
3. **Categorize each:**
   - Display text (57px, 45px, 36px) → displayLarge/Medium/Small
   - Headlines (32px, 28px, 24px) → headlineLarge/Medium/Small
   - Titles (22px, 16px, 14px) → titleLarge/Medium/Small
   - Body (16px, 14px, 12px) → bodyLarge/Medium/Small
   - Labels (14px, 12px, 11px) → labelLarge/Medium/Small
4. **Replace with theme reference**
5. **Test visual output**
6. **Commit file-by-file**

### Example Replacement Pattern

```dart
// BEFORE
Text(
  'Hello World',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: isDark ? Colors.white : Colors.black,
  ),
)

// AFTER
Text(
  'Hello World',
  style: Theme.of(context).textTheme.titleMedium?.copyWith(
    color: isDark ? Colors.white : Colors.black,
  ),
)
```

### Size Mapping Guide

```dart
// Exact matches
fontSize: 57 → displayLarge
fontSize: 45 → displayMedium
fontSize: 36 → displaySmall
fontSize: 32 → headlineLarge
fontSize: 28 → headlineMedium
fontSize: 24 → headlineSmall
fontSize: 22 → titleLarge
fontSize: 16 → titleMedium or bodyLarge (depends on context)
fontSize: 14 → titleSmall, bodyMedium, or labelLarge
fontSize: 12 → bodySmall or labelMedium
fontSize: 11 → labelSmall

// Close matches (accept theme size)
fontSize: 20 → titleLarge (22px)
fontSize: 18 → titleMedium (16px) or titleLarge (22px)
fontSize: 15 → titleMedium (16px)
fontSize: 13 → bodyMedium (14px) or titleSmall (14px)

// Very small (may need override)
fontSize: 10 → labelSmall (11px) + fontSize override if critical
fontSize: 9 → labelSmall (11px) + fontSize override
fontSize: 7-8 → labelSmall + fontSize override (calendar headers)

// Very large (may need override)
fontSize: 48 → displayMedium (45px) or override
fontSize: 72 → displayLarge (57px) + fontSize override
```

### Weight Mapping Guide

```dart
// Theme weights
FontWeight.w700 → Display styles (BasisGrotesquePro Bold)
FontWeight.w500 → Headline/Title/Label styles (HouschkaRoundedAlt/BasisGrotesquePro Medium)
FontWeight.w400 → Body styles (BasisGrotesquePro Regular)

// Common overrides (use theme base + copyWith)
FontWeight.bold → May need labelLarge or labelMedium base
FontWeight.w600 → May need labelLarge or titleMedium base
```

---

## Testing Checklist

After fixing each file:

- [ ] Visual regression test (compare before/after screenshots)
- [ ] Light mode rendering
- [ ] Dark mode rendering
- [ ] Mobile viewport (< 768px)
- [ ] Desktop viewport (>= 768px)
- [ ] Text wrapping and overflow
- [ ] Font family matches TCS brand
- [ ] Font weight matches TCS brand
- [ ] Accessibility (readable contrast)

---

## Notes for Implementation

1. **PDF Styles:** The `access_badge.dart` file uses `pw.TextStyle()` from the PDF package. These are separate from Flutter's TextStyle and don't need to change.

2. **Responsive Sizing:** Some files use conditional sizing like `fontSize: isMobile ? 7 : 8`. These may need to keep custom sizing but should still reference theme as a base:
   ```dart
   style: Theme.of(context).textTheme.labelSmall?.copyWith(
     fontSize: isMobile ? 7 : 8, // Custom responsive override
   )
   ```

3. **Dynamic Weights:** Some text has conditional fontWeight (e.g., bold when selected). Consider using different theme styles instead of overriding weight:
   ```dart
   // Instead of
   fontWeight: isSelected ? FontWeight.bold : FontWeight.normal

   // Use different styles
   style: isSelected
     ? Theme.of(context).textTheme.labelLarge  // w500
     : Theme.of(context).textTheme.bodyMedium  // w400
   ```

4. **Color Changes:** MEDIUM priority color-only TextStyles are technically acceptable but should be made explicit for maintainability.

5. **Size Mismatches:** When hardcoded size doesn't exactly match theme (e.g., 20px vs titleLarge 22px), prefer theme size unless there's a specific design reason. Document exceptions.

---

## Conclusion

This audit found **330+ instances** of hardcoded font styling that bypass the TCS typography system. Fixing these violations will:

1. **Ensure brand consistency** - All text uses correct TCS fonts
2. **Improve maintainability** - Changes to theme apply everywhere
3. **Enable easier theming** - Light/dark modes work correctly
4. **Support accessibility** - Consistent text hierarchy
5. **Reduce technical debt** - Single source of truth for typography

**Estimated effort:** 5 weeks at 10-15 files per week

**Recommended approach:** Start with high-traffic screens (calendar, bookings, landing) and work systematically through the priority list.

---

**End of Report**
