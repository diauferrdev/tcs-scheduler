# TCS Font Standardization - Implementation Guide

## Quick Reference: Font Mapping Table

### Complete Theme TextStyle Mapping

| Text Type | Old Hardcoded Style | New Theme Style | Font Used |
|-----------|---------------------|-----------------|-----------|
| **App Bar Titles** | `fontSize: 20, fontWeight: bold` | `titleLarge` | Houschka Rounded Alt Medium |
| **Page Headers** | `fontSize: 24-28, fontWeight: bold` | `headlineMedium` | Houschka Rounded Alt Medium |
| **Section Headings** | `fontSize: 18, fontWeight: bold` | `headlineSmall` | Houschka Rounded Alt Medium |
| **Card Titles** | `fontSize: 16, fontWeight: bold` | `titleMedium` | Houschka Rounded Alt Medium |
| **Small Titles** | `fontSize: 14, fontWeight: bold` | `titleSmall` | Houschka Rounded Alt Medium |
| **Chart Titles** | `fontSize: 18-22, fontWeight: bold` | `headlineLarge` | Houschka Rounded Alt Medium |
| **Body Text** | `fontSize: 16` | `bodyLarge` | Basis Grotesque Pro Regular |
| **Regular Text** | `fontSize: 14` | `bodyMedium` | Basis Grotesque Pro Regular |
| **Small Text** | `fontSize: 12-13` | `bodySmall` | Basis Grotesque Pro Regular |
| **Buttons** | `fontSize: 16-18, fontWeight: w600` | `labelLarge` | Basis Grotesque Pro Medium |
| **Form Labels** | `fontSize: 14, fontWeight: w500` | `labelMedium` | Basis Grotesque Pro Medium |
| **Small Labels** | `fontSize: 11-12, fontWeight: w500` | `labelSmall` | Basis Grotesque Pro Medium |

## Code Examples

### Example 1: Login Screen Title
```dart
// BEFORE
Text(
  'Scheduler',
  style: TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.bold,
    color: Colors.white,
  ),
)

// AFTER
Text(
  'Scheduler',
  style: Theme.of(context).textTheme.titleLarge?.copyWith(
    color: Colors.white,
  ),
)
```

### Example 2: Error Messages
```dart
// BEFORE
Text(
  'Email is required',
  style: TextStyle(
    fontSize: 12,
    color: Colors.red,
  ),
)

// AFTER
Text(
  'Email is required',
  style: Theme.of(context).textTheme.bodySmall?.copyWith(
    color: Colors.red,
  ),
)
```

### Example 3: Button Labels
```dart
// BEFORE
Text(
  'Login',
  style: TextStyle(
    fontWeight: FontWeight.w600,
  ),
)

// AFTER
Text(
  'Login',
  style: Theme.of(context).textTheme.labelLarge,
)
```

### Example 4: Section Headers
```dart
// BEFORE
Text(
  'New Requests',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: isDark ? Colors.white : Colors.black,
  ),
)

// AFTER
Text(
  'New Requests',
  style: Theme.of(context).textTheme.titleMedium?.copyWith(
    color: isDark ? Colors.white : Colors.black,
  ),
)
```

### Example 5: Form Field Labels
```dart
// BEFORE
Text(
  'Email',
  style: TextStyle(fontSize: 14, color: Colors.white),
)

// AFTER
Text(
  'Email',
  style: Theme.of(context).textTheme.labelMedium?.copyWith(
    color: Colors.white,
  ),
)
```

## Systematic Update Process

### Step 1: Identify Text Type
Look at the context to determine which theme style to use:
- Is it a heading? → Use `headlineXxx` or `titleXxx`
- Is it body content? → Use `bodyXxx`
- Is it a label or button? → Use `labelXxx`

### Step 2: Map Font Weight
- `FontWeight.bold` or `FontWeight.w600-w900` → Use heading/title styles
- `FontWeight.w500` → Use label styles
- `FontWeight.normal` or no weight → Use body styles

### Step 3: Map Font Size
Use the table above to match old fontSize to new theme style.

### Step 4: Preserve Color
Always use `.copyWith(color: ...)` to preserve custom colors:
```dart
Theme.of(context).textTheme.bodyMedium?.copyWith(
  color: isDark ? Colors.grey[400] : Colors.grey[600],
)
```

## Files Successfully Updated

### ✅ Completed Files (5 files):

1. **lib/screens/login_screen.dart**
   - ✅ "Scheduler" title → `titleLarge`
   - ✅ Email/Password labels → `labelMedium`
   - ✅ Login button → `labelLarge`
   - ✅ Demo credentials → `labelSmall` / `bodySmall`

2. **lib/screens/my_bookings_screen.dart**
   - ✅ Error headings → `headlineSmall`
   - ✅ Section headers → `titleMedium`
   - ✅ Error text → `bodyMedium`
   - ✅ Dialog titles → `titleLarge`
   - ✅ Dialog content → `bodyMedium`

3. **lib/widgets/app_layout.dart**
   - ✅ Header "Scheduler" → `titleLarge`

4. **lib/widgets/booking_card.dart**
   - ✅ Company name → `titleMedium`
   - ✅ Date/time → `bodySmall`

5. **lib/screens/dashboard_screen.dart**
   - ⚠️ Partially updated (needs completion)

## Remaining Work

### High-Priority Files (Order by Visual Impact):

1. **lib/screens/calendar_screen.dart** (101 TextStyles)
   - Booking tiles, time slots, date headers
   - Most frequently used screen

2. **lib/screens/booking_details_screen.dart** (60 TextStyles)
   - Company details, form fields, status displays
   - Critical user workflow

3. **lib/widgets/access_badge.dart** (43 TextStyles)
   - Permission badges throughout app
   - Highly visible component

4. **lib/screens/users_screen.dart** (28 TextStyles)
   - User list, roles, permissions
   - Admin interface

5. **lib/screens/notifications_screen.dart** (25 TextStyles)
   - Notification list, timestamps, actions

6. **lib/screens/booking_form_screen.dart** (23 TextStyles)
   - New booking creation form
   - Important user journey

### Medium-Priority Files:

7. **lib/screens/activity_logs_screen.dart** (19 TextStyles)
8. **lib/screens/landing_screen.dart** (18 TextStyles)
9. **lib/screens/invitations_screen.dart** (18 TextStyles)
10. **lib/widgets/edit_booking_drawer.dart** (17 TextStyles)
11. **lib/widgets/profile_drawer.dart** (15 TextStyles)
12. **lib/services/universal_update_service.dart** (15 TextStyles)
13. **lib/screens/agenda_screen.dart** (15 TextStyles)
14. **lib/widgets/reschedule_dialog.dart** (12 TextStyles)

### Low-Priority Files:

15-35. Remaining drawer/utility files (1-9 TextStyles each)

## Batch Update Script

For efficiency, you can use this find-and-replace pattern for common cases:

### Pattern 1: Title Text (Bold, 16-20px)
```bash
# Find:
TextStyle(\s*fontSize:\s*(\d+),\s*fontWeight:\s*FontWeight\.bold

# Context check: If fontSize 18-22 → headlineSmall
# Context check: If fontSize 16-18 → titleMedium
# Replace with appropriate theme style
```

### Pattern 2: Body Text (Regular, 12-16px)
```bash
# Find:
TextStyle(\s*fontSize:\s*14

# Replace:
Theme.of(context).textTheme.bodyMedium
```

### Pattern 3: Label Text (Medium weight, 12-16px)
```bash
# Find:
TextStyle(\s*fontSize:\s*14,\s*fontWeight:\s*FontWeight\.w[56]00

# Replace:
Theme.of(context).textTheme.labelMedium
```

## Testing Checklist

After updating each file, verify:

- [ ] No compilation errors (`flutter analyze`)
- [ ] Text appears with correct font (Houschka/Basis Grotesque)
- [ ] Font sizes are appropriate for context
- [ ] Colors still work (dark/light mode)
- [ ] No text overflow issues
- [ ] Hierarchy looks correct (headings stand out)

## Common Pitfalls

### ❌ Don't Do This:
```dart
// Removing const breaks performance
const Text('Hello', style: TextStyle(fontSize: 14))

// Becomes:
Text('Hello', style: Theme.of(context).textTheme.bodyMedium)  // Not const anymore
```

### ✅ Do This Instead:
```dart
// Keep const where possible
Text(
  'Hello',
  style: Theme.of(context).textTheme.bodyMedium,
)
// Flutter will optimize this anyway
```

### ❌ Don't Forget copyWith for Colors:
```dart
// Wrong - loses color customization
style: Theme.of(context).textTheme.bodyMedium

// Correct - preserves color
style: Theme.of(context).textTheme.bodyMedium?.copyWith(
  color: Colors.red,
)
```

## Performance Considerations

### Theme Styles Are Cached
```dart
// This is efficient - theme is looked up once
final titleStyle = Theme.of(context).textTheme.titleLarge;
// Use titleStyle multiple times
```

### Avoid Repeated Theme Lookups in Loops
```dart
// ❌ Bad - theme lookup in every iteration
for (var item in items) {
  Text(item, style: Theme.of(context).textTheme.bodyMedium);
}

// ✅ Good - lookup once
final bodyStyle = Theme.of(context).textTheme.bodyMedium;
for (var item in items) {
  Text(item, style: bodyStyle);
}
```

## Final Statistics

### Current Progress:
- **Files Updated**: 5 / 35 (14%)
- **TextStyles Updated**: ~25 / 555 (4.5%)
- **High-Impact Files Updated**: 2 / 6 (33%)

### Estimated Completion Time:
- **Remaining Work**: ~530 TextStyle updates
- **Average per File**: 15-20 TextStyles
- **Estimated Time**: 8-12 hours for full completion

### Priority Completion (Top 6 Files):
- **Remaining Work**: ~282 TextStyles
- **Estimated Time**: 4-6 hours
- **Impact**: 80% of visual improvement

## Next Immediate Actions

1. **Complete dashboard_screen.dart** (50 remaining)
   - Update stat cards
   - Update chart titles
   - Update legend items

2. **Update calendar_screen.dart** (101 remaining)
   - Update booking tiles
   - Update time slot labels
   - Update date headers

3. **Update booking_details_screen.dart** (60 remaining)
   - Update company info section
   - Update form field labels
   - Update status displays

## Verification Commands

```bash
# Check for remaining hardcoded TextStyles
grep -r "TextStyle(" lib/ --include="*.dart" | wc -l

# Find files with most TextStyles remaining
grep -r "TextStyle(" lib/ --include="*.dart" | cut -d: -f1 | sort | uniq -c | sort -rn | head -20

# Verify no compilation errors
flutter analyze

# Run tests to ensure nothing broke
flutter test
```

---

**Status**: Foundation Complete ✅
**Next Steps**: Continue systematic updates following priority order above
**Goal**: 100% theme-based text styling across all 65+ Dart files

*Updated: 2025-10-19*
