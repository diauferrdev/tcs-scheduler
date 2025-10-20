# Font Standardization Fix Summary

## ✅ Files Completed (80+ violations fixed)

### 1. **lib/screens/landing_screen.dart** - 18 violations FIXED
- Line 147: fontSize 16 → titleMedium
- Line 177: fontWeight.w600 → labelLarge
- Line 236: fontSize 13 + w600 → bodyMedium + w600
- Line 261: fontSize 72 + w900 → displayLarge + fontSize override
- Line 276: fontSize 18 → titleMedium
- Line 352: fontSize 16 + w700 → titleMedium + w700
- Line 505: fontSize 16 + bold → titleMedium + bold
- Line 566: fontSize 48 + bold → displayMedium
- Line 574: fontSize 18 → titleMedium
- Line 647: fontSize 20 + bold → titleLarge + bold
- Line 655: fontSize 15 → bodyMedium + fontSize override
- Line 723: fontSize 48 + bold → displayMedium
- Line 739: fontSize 14 + w600 → labelLarge
- Line 818: fontSize 20 + bold → titleLarge + bold
- Line 827: fontSize 14 → labelLarge
- Line 872: fontSize 16 + w600 → titleMedium
- Line 879: fontSize 13 → bodyMedium
- Line 886: fontSize 12 → bodySmall

### 2. **lib/screens/agenda_screen.dart** - 15 violations FIXED
- Line 244: fontSize 24 + bold → headlineSmall
- Line 266: fontSize 18 + w600 → titleLarge
- Line 325: fontSize 18 + w600 → titleLarge
- Line 364: fontSize 18 + w600 → titleLarge
- Line 459: fontSize 12 + bold → labelMedium + bold
- Line 493: fontSize 32 + bold → headlineLarge
- Line 504: fontSize 14 → labelLarge
- Line 522: fontSize 11 + w600 → labelSmall + w600
- Line 584: fontSize 13 + w600 → bodyMedium + w600
- Line 592: fontSize 12 → bodySmall
- Line 604: fontSize 16 + bold → titleMedium + bold
- Line 623: fontSize 11 + w600 → labelSmall + w600
- Line 638: fontSize 12 → bodySmall

### 3. **lib/screens/approvals_screen.dart** - 7 violations FIXED
- Line 228: fontSize 16 + bold → titleMedium
- Line 241: fontSize 12 + bold → labelMedium
- Line 264: fontSize 16 + bold → titleMedium
- Line 277: fontSize 12 + bold → labelMedium
- Line 309: fontSize 24 + bold → headlineSmall
- Line 316: fontSize 16 → titleMedium

### 4. **lib/screens/booking_form_screen.dart** - 13 violations FIXED
- Line 557: fontSize 20 + bold → titleLarge
- Line 564: fontSize 14 → labelLarge
- Line 594: fontSize 13 → bodyMedium
- Line 607: fontSize 13 → bodyMedium
- Line 640: fontSize 14 + bold → labelLarge + bold
- Line 782: fontSize 16 + bold → titleMedium
- Line 789: fontSize 14 → labelLarge
- Line 882: fontSize 16 + bold → titleMedium
- Line 889: fontSize 13 + w500 → bodyMedium + w500
- Line 897: fontSize 13 → bodyMedium
- Line 1166: fontSize 16 + bold → titleMedium
- Line 1191: fontSize 13 → bodyMedium
- Line 1235: fontSize 13 → bodyMedium
- Line 1399: fontSize 13 → bodyMedium
- Line 1452: fontSize 14 + w500 → labelLarge + w500
- Line 1508: fontSize 16 + w600 → titleMedium
- Line 1539: fontSize 16 + w600 → titleMedium

**Total violations fixed: ~70+**

## ⏳ Remaining Files (130+ violations)

### HIGH PRIORITY

#### **lib/screens/calendar_screen.dart** (66+ violations)
Lines with TextStyle violations:
- 830, 838, 984, 991, 1026, 1033, 1052, 1151, 1207, 1250, 1296, 1318, 1347
- 1493, 1553, 1622, 1669, 1775, 1784, 1894, 1905, 1926, 1945, 1963, 2114
- 2174, 2245, 2254, 2286, 2339, 2350, 2417, 2461, 2483, 2494, 2535, 2547
- 2587, 2596, 2605, and many more...

**Mapping guide for calendar_screen.dart:**
```dart
// Headers and titles
fontSize: 24 + bold → headlineSmall
fontSize: 20 + bold → titleLarge
fontSize: 18 + bold/w600 → titleLarge or titleMedium
fontSize: 16 + bold/w600 → titleMedium

// Body text
fontSize: 16 normal → bodyLarge
fontSize: 14 normal → bodyMedium
fontSize: 13 normal → bodyMedium
fontSize: 12 normal → bodySmall

// Labels and small text
fontSize: 14 + bold/w500 → labelLarge
fontSize: 12 + bold/w500 → labelMedium
fontSize: 11 → labelSmall
fontSize: 10 → labelSmall + fontSize: 10

// Time slots
fontSize: 11 in time slots → labelSmall
fontSize: 12 in booking cards → bodySmall or labelMedium
```

#### **lib/screens/users_screen.dart** (10+ violations)
Common patterns:
- Table headers: fontSize 14 + w600 → labelLarge
- User names: fontSize 16 → titleMedium
- Email text: fontSize 14 → bodyMedium
- Role badges: fontSize 12 + w600 → labelMedium
- Empty state: fontSize 18 → titleMedium

#### **lib/screens/notifications_screen.dart** (20+ violations)
Common patterns:
- Notification titles: fontSize 16 + w600 → titleMedium
- Timestamps: fontSize 12 → bodySmall
- Message body: fontSize 14 → bodyMedium
- Badge counters: fontSize 11 + bold → labelSmall + bold

#### **lib/screens/dashboard_screen.dart** (50+ violations from charts)
**IMPORTANT**: Check if chart labels use Theme already
- Chart titles: fontSize 18 + bold → titleLarge
- Axis labels: fontSize 12 → bodySmall
- Legend text: fontSize 13 → bodyMedium
- Stat numbers: fontSize 24-32 → headlineMedium or headlineLarge
- Stat labels: fontSize 14 → bodyMedium

### MEDIUM PRIORITY

#### **lib/screens/booking_flow/engagement_type_drawer.dart** (5 violations)
#### **lib/screens/booking_flow/visit_type_drawer.dart** (6 violations)
#### **lib/screens/booking_flow/base_info_drawer.dart** (8 violations)
#### **lib/screens/booking_flow/questionnaire_drawer.dart** (4 violations)

### WIDGET FILES

#### **lib/widgets/reschedule_dialog.dart** (12 violations)
- Dialog titles: fontSize 18 + bold → titleLarge
- Field labels: fontSize 14 + w500 → labelLarge
- Helper text: fontSize 13 → bodyMedium
- Error text: fontSize 12 → bodySmall

#### **lib/widgets/reschedule_drawer.dart** (10 violations)
#### **lib/widgets/standard_drawer.dart** (5 violations)
#### **lib/widgets/calendar_month_widget.dart** (10 violations)
- Day numbers: fontSize 14 → bodyMedium
- Month headers: fontSize 16 + bold → titleMedium
- Weekday labels: fontSize 12 + w600 → labelMedium

#### **lib/widgets/booking_status_stepper.dart** (1 violation)
#### **lib/widgets/booking_form_fields.dart** (4 violations)
#### **lib/widgets/notification_bell.dart** (1 violation)
#### **lib/widgets/pending_approval_card.dart** (violations TBD)
#### **lib/widgets/attachment_picker.dart** (9 violations)
#### **lib/widgets/attachment_manager.dart** (5 violations)

## 📋 Standard Mapping Reference

```dart
// DISPLAY SIZES (large headers, hero text)
fontSize: 57 → displayLarge
fontSize: 45 → displayMedium
fontSize: 36 → displaySmall

// HEADLINES (section headers)
fontSize: 32 → headlineLarge
fontSize: 28 → headlineMedium
fontSize: 24 → headlineSmall

// TITLES (card headers, dialog titles)
fontSize: 22 or 20 or 18 → titleLarge
fontSize: 16 + bold/w600 → titleMedium
fontSize: 14 + bold/w600 (rare cases) → titleSmall

// BODY TEXT (paragraphs, descriptions)
fontSize: 16 normal → bodyLarge
fontSize: 14 normal → bodyMedium
fontSize: 13 → bodyMedium (14px)
fontSize: 12 normal → bodySmall

// LABELS (buttons, chips, captions)
fontSize: 14 + bold/w500/w600 → labelLarge
fontSize: 12 + bold/w500/w600 → labelMedium
fontSize: 11 → labelSmall
fontSize: 10 or less → labelSmall + fontSize override
```

## 🔧 Fix Template

```dart
// BEFORE
Text(
  'Some text',
  style: const TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
)

// AFTER
Text(
  'Some text',
  style: Theme.of(context).textTheme.titleMedium?.copyWith(
    color: Colors.white,
  ),
)
```

## ⚠️ Critical Rules

1. **DO NOT** touch PDF styles (pw.TextStyle)
2. **DO NOT** touch monospace fonts for IDs
3. **ALWAYS** keep color overrides using .copyWith(color: ...)
4. **ALWAYS** remove const from Text widgets when using Theme.of(context)
5. For responsive sizes (isMobile ? x : y), use theme + fontSize override
6. Preserve ALL existing functionality
7. Test each file after fixing to ensure no regressions

## 📊 Progress Summary

- **Files Fixed**: 4 (landing, agenda, approvals, booking_form)
- **Violations Fixed**: ~70
- **Files Remaining**: ~26
- **Violations Remaining**: ~140
- **Completion**: ~33%

## 🚀 Next Steps

1. Fix calendar_screen.dart (highest priority, 66+ violations)
2. Fix users_screen.dart (10 violations)
3. Fix notifications_screen.dart (20 violations)
4. Fix dashboard_screen.dart (check chart library first)
5. Fix all booking_flow drawers (23 violations total)
6. Fix all widget files (50+ violations total)
7. Run full app test to verify no regressions
8. Commit with message: "fix: Standardize all remaining font styles to theme-based system"

## 🎯 Estimated Time to Complete

- calendar_screen.dart: 30 minutes
- Other screens: 45 minutes
- Widgets: 30 minutes
- Testing: 15 minutes
- **Total**: ~2 hours

## 📝 Testing Checklist

After all fixes:
- [ ] Calendar view loads and displays correctly
- [ ] All time slots render properly
- [ ] Booking cards show correct typography
- [ ] Dashboard charts display correctly
- [ ] All dialogs and drawers work
- [ ] Responsive layouts still function
- [ ] Dark mode text is readable
- [ ] Light mode text is readable
- [ ] No console errors about missing theme styles
