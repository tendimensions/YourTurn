# UI Guidelines for YourTurn

## Design Philosophy

- **Simple and Intuitive**: Turn tracking should be effortless
- **Immediate Feedback**: Visual indicators for current turn
- **Minimal Distractions**: Focus on the game, not the app
- **Accessible**: Large touch targets, clear contrast, screen reader support

## Color Palette

### Primary Colors

```dart
// Brand Colors
static const primaryColor = Color(0xFF2196F3);      // Blue - Primary actions
static const primaryDark = Color(0xFF1976D2);       // Blue Dark - Headers
static const primaryLight = Color(0xFFBBDEFB);      // Blue Light - Backgrounds

// Accent Colors
static const accentColor = Color(0xFFFF5722);       // Orange - Current turn indicator
static const accentLight = Color(0xFFFFCCBC);       // Orange Light - Highlights
```

### Semantic Colors

```dart
// Status Colors
static const successGreen = Color(0xFF4CAF50);      // Success states
static const warningYellow = Color(0xFFFFC107);     // Warnings
static const errorRed = Color(0xFFF44336);          // Errors
static const infoBlue = Color(0xFF2196F3);          // Information
```

### Neutral Colors

```dart
// Grayscale
static const backgroundLight = Color(0xFFFAFAFA);   // Light mode background
static const backgroundDark = Color(0xFF121212);    // Dark mode background
static const cardBackground = Color(0xFFFFFFFF);    // Card surfaces
static const dividerColor = Color(0xFFE0E0E0);      // Dividers and borders
static const textPrimary = Color(0xFF212121);       // Primary text
static const textSecondary = Color(0xFF757575);     // Secondary text
static const textDisabled = Color(0xFFBDBDBD);      // Disabled text
```

## Typography

### Text Styles

```dart
// Headers
static const headlineLarge = TextStyle(
  fontSize: 32,
  fontWeight: FontWeight.bold,
  color: textPrimary,
);

static const headlineMedium = TextStyle(
  fontSize: 24,
  fontWeight: FontWeight.w600,
  color: textPrimary,
);

// Body Text
static const bodyLarge = TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.normal,
  color: textPrimary,
);

static const bodyMedium = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.normal,
  color: textSecondary,
);

// Labels
static const labelLarge = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  letterSpacing: 0.5,
  color: textPrimary,
);

// Player Names (special emphasis)
static const playerName = TextStyle(
  fontSize: 18,
  fontWeight: FontWeight.w600,
  color: textPrimary,
);
```

## Spacing System

### Consistent Spacing

```dart
// Use multiples of 8 for consistency
static const spacingXs = 4.0;    // Extra small
static const spacingS = 8.0;     // Small
static const spacingM = 16.0;    // Medium (default)
static const spacingL = 24.0;    // Large
static const spacingXl = 32.0;   // Extra large
static const spacingXxl = 48.0;  // Extra extra large
```

### Usage

```dart
// Padding
Padding(
  padding: EdgeInsets.all(spacingM),
  child: Text('Content'),
)

// Spacing between widgets
SizedBox(height: spacingL),

// List item padding
ListTile(
  contentPadding: EdgeInsets.symmetric(
    horizontal: spacingM,
    vertical: spacingS,
  ),
)
```

## Component Styles

### Buttons

#### Primary Button

```dart
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: primaryColor,
    foregroundColor: Colors.white,
    padding: EdgeInsets.symmetric(
      horizontal: spacingL,
      vertical: spacingM,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    elevation: 2,
  ),
  child: Text('Primary Action'),
)
```

#### Secondary Button

```dart
OutlinedButton(
  onPressed: () {},
  style: OutlinedButton.styleFrom(
    foregroundColor: primaryColor,
    side: BorderSide(color: primaryColor, width: 2),
    padding: EdgeInsets.symmetric(
      horizontal: spacingL,
      vertical: spacingM,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  ),
  child: Text('Secondary Action'),
)
```

#### Text Button

```dart
TextButton(
  onPressed: () {},
  style: TextButton.styleFrom(
    foregroundColor: primaryColor,
    padding: EdgeInsets.symmetric(
      horizontal: spacingM,
      vertical: spacingS,
    ),
  ),
  child: Text('Tertiary Action'),
)
```

### Cards

#### Standard Card

```dart
Card(
  elevation: 2,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: EdgeInsets.all(spacingM),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Card Title', style: headlineMedium),
        SizedBox(height: spacingS),
        Text('Card content', style: bodyMedium),
      ],
    ),
  ),
)
```

#### Player Card

```dart
Card(
  elevation: isCurrentTurn ? 4 : 1,
  color: isCurrentTurn ? accentLight : cardBackground,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
    side: isCurrentTurn 
      ? BorderSide(color: accentColor, width: 2)
      : BorderSide.none,
  ),
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: primaryColor,
      child: Text(playerInitial),
    ),
    title: Text(playerName, style: playerName),
    trailing: isCurrentTurn 
      ? Icon(Icons.arrow_forward, color: accentColor)
      : null,
  ),
)
```

### Input Fields

#### Text Input

```dart
TextField(
  decoration: InputDecoration(
    labelText: 'Player Name',
    hintText: 'Enter your name',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
    ),
    contentPadding: EdgeInsets.symmetric(
      horizontal: spacingM,
      vertical: spacingM,
    ),
  ),
)
```

### Icons and Indicators

#### Current Turn Indicator

```dart
// Large, prominent indicator
Icon(
  Icons.play_arrow,
  color: accentColor,
  size: 32,
)

// Or animated pulse
AnimatedContainer(
  duration: Duration(milliseconds: 500),
  width: isCurrentTurn ? 48 : 32,
  height: isCurrentTurn ? 48 : 32,
  decoration: BoxDecoration(
    color: accentColor,
    shape: BoxShape.circle,
  ),
  child: Icon(Icons.play_arrow, color: Colors.white),
)
```

#### Connection Status

```dart
// Connected
Icon(Icons.wifi, color: successGreen, size: 24)

// Connecting
CircularProgressIndicator(
  valueColor: AlwaysStoppedAnimation(primaryColor),
  strokeWidth: 2,
)

// Disconnected
Icon(Icons.wifi_off, color: errorRed, size: 24)
```

## Layout Patterns

### Screen Structure

```dart
Scaffold(
  appBar: AppBar(
    title: Text('Screen Title'),
    elevation: 0,
    backgroundColor: primaryColor,
  ),
  body: SafeArea(
    child: Padding(
      padding: EdgeInsets.all(spacingM),
      child: Column(
        children: [
          // Content
        ],
      ),
    ),
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: () {},
    child: Icon(Icons.add),
    backgroundColor: accentColor,
  ),
)
```

### List Layout

```dart
ListView.separated(
  itemCount: players.length,
  separatorBuilder: (context, index) => Divider(height: spacingS),
  itemBuilder: (context, index) {
    final player = players[index];
    return PlayerTile(
      player: player,
      isCurrentTurn: index == currentTurnIndex,
    );
  },
)
```

### Grid Layout

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 2,
    childAspectRatio: 1.5,
    crossAxisSpacing: spacingM,
    mainAxisSpacing: spacingM,
  ),
  itemCount: items.length,
  itemBuilder: (context, index) {
    return Card(/* ... */);
  },
)
```

## Animations

### Standard Transitions

```dart
// Page transitions
PageRouteBuilder(
  pageBuilder: (context, animation, secondaryAnimation) => NewScreen(),
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    return FadeTransition(
      opacity: animation,
      child: child,
    );
  },
)

// Widget animations
AnimatedOpacity(
  opacity: isVisible ? 1.0 : 0.0,
  duration: Duration(milliseconds: 300),
  child: child,
)

AnimatedContainer(
  duration: Duration(milliseconds: 300),
  curve: Curves.easeInOut,
  // Animated properties
)
```

### Turn Change Animation

```dart
// Pulse effect when turn changes
TweenAnimationBuilder<double>(
  tween: Tween(begin: 1.0, end: 1.2),
  duration: Duration(milliseconds: 500),
  curve: Curves.easeInOut,
  builder: (context, scale, child) {
    return Transform.scale(
      scale: scale,
      child: Icon(Icons.play_arrow, color: accentColor),
    );
  },
)
```

## Responsive Design

### Breakpoints

```dart
// Screen size breakpoints
static const mobileBreakpoint = 600.0;
static const tabletBreakpoint = 960.0;

// Usage
final screenWidth = MediaQuery.of(context).size.width;
final isMobile = screenWidth < mobileBreakpoint;
final isTablet = screenWidth >= mobileBreakpoint && 
                 screenWidth < tabletBreakpoint;
```

### Adaptive Layouts

```dart
// Responsive padding
final padding = isMobile ? spacingM : spacingXl;

// Responsive grid columns
final crossAxisCount = isMobile ? 2 : 4;

// Responsive font sizes
final fontSize = isMobile ? 14.0 : 16.0;
```

## Accessibility

### Minimum Touch Targets

```dart
// Minimum 48x48 logical pixels
static const minTouchTarget = 48.0;

// Usage
SizedBox(
  width: minTouchTarget,
  height: minTouchTarget,
  child: IconButton(
    icon: Icon(Icons.add),
    onPressed: () {},
  ),
)
```

### Semantic Labels

```dart
Semantics(
  label: 'Current turn: Alice',
  button: false,
  child: PlayerTile(player: alice, isCurrentTurn: true),
)

// Icon buttons
IconButton(
  icon: Icon(Icons.add),
  tooltip: 'Add player',
  onPressed: () {},
)
```

### Color Contrast

- Ensure 4.5:1 contrast ratio for normal text
- Ensure 3:1 contrast ratio for large text (18pt+)
- Don't rely on color alone for information
- Use icons and labels in addition to color

## Dark Mode Support

### Theme Configuration

```dart
ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primaryColor: primaryDark,
  scaffoldBackgroundColor: backgroundDark,
  cardColor: Color(0xFF1E1E1E),
  // ... other dark theme properties
);

// Usage
MaterialApp(
  theme: lightTheme,
  darkTheme: darkTheme,
  themeMode: ThemeMode.system, // Follow system setting
)
```

## UI Testing Checklist

- [ ] Works on both iOS and Android
- [ ] Works in both portrait and landscape
- [ ] Works on various screen sizes (small, medium, large)
- [ ] Looks good in light mode
- [ ] Looks good in dark mode
- [ ] Touch targets are at least 48x48
- [ ] Text is readable (contrast, size)
- [ ] Animations are smooth (60fps)
- [ ] Loading states are handled
- [ ] Error states are handled
- [ ] Empty states are handled
- [ ] Accessible with screen reader

## Resources

- [Material Design Guidelines](https://material.io/design)
- [Flutter Widget Catalog](https://docs.flutter.dev/development/ui/widgets)
- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [Accessibility Scanner](https://developer.android.com/guide/topics/ui/accessibility/testing)
