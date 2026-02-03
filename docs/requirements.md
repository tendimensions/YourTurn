# YourTurn - Turn Notification App Requirements

## Project Overview

**YourTurn** is a mobile application designed to facilitate turn-based board games played by groups of friends sitting around a table. The app creates a local peer-to-peer network between devices to manage turn order and notify players when it's their turn, eliminating the need for constant attention to the game state.

## Core Use Case

- **Primary Scenario**: A group of 3-8 friends playing a complex board game where individual turns take several minutes
- **Environment**: Players within a 10-foot radius (typical table setting)
- **Goal**: Minimize interruptions by automatically notifying the next player when a turn is complete

## Technical Architecture Requirements

### Platform Support

- **Target Platforms**: iOS and Android
- **Framework**: Flutter for cross-platform development
- **Minimum Requirements**:
  - iOS 12.0+ (for MultipeerConnectivity support)
  - Android 6.0+ (API level 23) for BLE support
  - Android 10+ for optimal Nearby Connections support

### Networking & Communication

> **IMPORTANT: Same WiFi Network Requirement**
>
> All devices must be connected to the same WiFi network to use YourTurn. This is the current implementation for cross-platform (iOS + Android) support. While not the preferred long-term solution, it provides the simplest and most reliable connectivity for mixed platform groups. Future versions may support direct peer-to-peer connectivity without this requirement.

- **Network Requirement**: All players must be on the same local WiFi network
- **Primary Transport**: Combination of WiFi (TCP/IP) and platform-specific technologies for optimal reliability
  - WiFi TCP/IP sockets for cross-platform connectivity (iOS + Android)
  - iOS: MultipeerConnectivity framework for iOS-only sessions
  - Android: Google Play Services Nearby Connections API for Android-only sessions
- **Discovery Method**: Automatic session discovery
  - Players launching the app see a list of all nearby sessions waiting to start
  - One-tap selection to join a specific session
  - QR code scanning available for manual joining
- **Range**: 10-foot radius (typical table distance)
- **Bandwidth**: Low - only small notification messages (< 100 bytes per message)
- **Network Type**: Local WiFi network, no internet connectivity required (WiFi required but internet access is not)
- **Session Visibility**: Active games show as "In Progress" but cannot be joined

### Data Requirements

- **Session Data**:
  - Session ID (UUID)
  - Short human-readable session code (e.g., "J7X-3")
  - Player list with names and unique IDs
  - Current turn holder
  - Turn sequence number for state synchronization
- **Message Types**:
  - Turn completion notifications
  - Player join/leave events
  - Session state updates
  - Heartbeat/presence messages

### UI Design Specifications

- **Color Palette**:
  - Active Player Background: #129c26 (Green)
  - Waiting Player Background: #c03317 (Red)
- **AppTheme Requirements**:
  - All UI colors, fonts, and sizes must be defined in a centralized AppTheme Dart file
  - Ensures consistency across the app and easy modification
  - Font sizes and styles for timer display, player names, and time summaries must be configurable through AppTheme
- **Layout Specifications**:
  - "DONE" button: Bottom third of screen (percentage-based for responsive design)
  - Timer display: Top center, MM:SS format, large font size
  - Player list: Above button area with green dot indicator for current player
  - End-game time summary: List format with player names left-aligned, times right-aligned

## Functional Requirements

### 1. Session Management

#### 1.1 Team Leader Session Creation

- **FR-1.1**: Team leader can create a new game session
- **FR-1.2**: Session creates a local network that nearby devices can discover and join
- **FR-1.3**: Session generates a unique identifier for connection
- **FR-1.4**: Session persists until team leader explicitly ends the game
- **FR-1.5**: Only one team leader per session (cannot transfer leadership)

#### 1.2 Player Join Process

- **FR-1.6**: Players can discover active sessions within local network range (up to 10 feet)
- **FR-1.7**: Players enter their name and automatically join the session (no approval required)
- **FR-1.8**: Team leader sees all joined players in real-time
- **FR-1.9**: All players who join are visible to the team leader
- **FR-1.10**: Players can ONLY join during setup phase (before game starts)
- **FR-1.11**: Active games appear as "In Progress" and cannot be joined
- **FR-1.12**: Maximum of 8 players per session (including team leader)
- **FR-1.13**: Minimum of 2 players required to start game (team leader + at least one other player)
- **FR-1.14**: Only one session per device at a time

#### 1.3 Turn Order Configuration

- **FR-1.11**: Team leader can drag and drop player names to reorder turn sequence
- **FR-1.12**: Team leader designates one player as the "start player"
- **FR-1.13**: Turn order is established before game begins
- **FR-1.14**: Start player is the first to receive the green screen and "DONE" button

### 2. Turn Tracking System

#### 2.1 Visual Turn Indicators

- **FR-2.1**: Active player's screen displays GREEN background (#129c26)
- **FR-2.2**: Active player's screen displays a "DONE" button in bottom third of screen
- **FR-2.3**: All non-active players' screens display RED background (#c03317)
- **FR-2.4**: Non-active players do NOT have a "DONE" button visible
- **FR-2.5**: All players see complete player list with turn order above button area
- **FR-2.6**: Green dot indicator appears next to current active player's name in the list
- **FR-2.7**: Player list visible to all players shows turn rotation and current player
- **FR-2.8**: When "DONE" button is pressed, turn immediately passes to next player in rotation
- **FR-2.9**: Next player's screen changes from RED to GREEN with "DONE" button appearing
- **FR-2.10**: Previous player's screen changes from GREEN to RED with "DONE" button disappearing
- **FR-2.11**: Green dot indicator moves to next player in the list

#### 2.2 Turn Progression

- **FR-2.8**: Turn order cycles continuously through all players
- **FR-2.9**: After last player in turn order, rotation returns to first player
- **FR-2.10**: Turn tracking is synchronized across all connected devices
- **FR-2.11**: Turn state persists during temporary connection interruptions

### 3. Network Connectivity

#### 3.1 Short-Range Network Requirements

- **FR-3.0**: All devices must be connected to the same WiFi network (current requirement for cross-platform support)
- **FR-3.1**: All devices must maintain connectivity within short range (table distance)
- **FR-3.2**: Network must support both Android and iOS devices simultaneously
- **FR-3.3**: Connection method must work without internet connectivity (WiFi network required, but not internet access)
- **FR-3.4**: Devices remain connected while sitting around a table (approximately 2-10 feet)
- **FR-3.5**: Network must support real-time turn state updates across all devices

#### 3.2 Connection Maintenance

- **FR-3.6**: Connections must persist with device screens locked (app continues to function)
- **FR-3.7**: Connections must persist when app is in background
- **FR-3.8**: Connection status displayed as dot symbol next to each player name in player list
- **FR-3.9**: Connection status visible to all players (if technically feasible)
- **FR-3.10**: Automatic reconnection attempts for temporarily disconnected players (future feature)
- **FR-3.11**: Screen stays awake during active game (prevents auto-lock)

### 4. Timer Feature (Optional Setting 1)

#### 4.1 Timer Configuration

- **FR-4.1**: Team leader can set a timer in minutes during game setup
- **FR-4.2**: Timer setting is optional (can be disabled/set to "no timer")
- **FR-4.3**: Timer range: 1-15 minutes in 1-minute increments
- **FR-4.4**: Timer applies to all players equally when enabled
- **FR-4.5**: Team leader can change timer value mid-game via menu (applies to next turn)
- **FR-4.6**: Team leader can disable timer mid-game (set to "no timer")

#### 4.2 Timer Display and Behavior

- **FR-4.7**: Countdown timer starts when player's screen turns GREEN
- **FR-4.8**: Timer displays at top center of screen in MM:SS format with large font
- **FR-4.9**: Timer font size and style defined in AppTheme for consistency
- **FR-4.10**: Timer visible ONLY to active player (not shown to waiting players)
- **FR-4.11**: Timer counts down in real-time showing minutes and seconds remaining
- **FR-4.12**: Timer stops/resets when "DONE" button is pressed
- **FR-4.13**: Timer starts fresh for next player when turn passes

#### 4.3 Timer Warning and Expiration

- **FR-4.14**: Screen begins flashing when timer reaches 10 seconds remaining
- **FR-4.15**: When timer reaches zero (00:00), device triggers haptic feedback (vibration)
- **FR-4.16**: Haptic feedback delivered in pulses until "DONE" button is pressed
- **FR-4.17**: Player can still complete their turn after timer expires
- **FR-4.18**: Expiration does not automatically pass turn to next player

### 5. Turn Focus Feature (Optional Setting 2 - FUTURE FEATURE)

#### 5.1 Turn Focus Configuration

- **FR-5.1**: Team leader sees "Turn Focus On" option as a checkbox during setup
- **FR-5.2**: Checkbox is VISIBLE but DISABLED (grayed out)
- **FR-5.3**: Tapping checkbox displays "Coming Soon" tooltip
- **FR-5.4**: Feature will be developed in a later phase
- **FR-5.5**: Intended purpose: Prevent players from using phones for other activities during game
- **FR-5.6**: Technical feasibility requires further design discussion (app locking capability)

### 6. Team Leader Menu System

#### 6.1 Menu Access

- **FR-6.1**: Team leader screen ALWAYS displays a menu icon in the top right corner
- **FR-6.2**: Menu icon is visible at all times during active game session
- **FR-6.3**: Menu is accessible regardless of game state (during turns, between turns, etc.)
- **FR-6.4**: Confirmation dialogs required for destructive actions (End Game, etc.)

#### 6.2 End Game Function

- **FR-6.5**: Menu includes "End Game" option
- **FR-6.6**: Confirmation popup required before ending game
- **FR-6.7**: Selecting "End Game" disengages all connected players
- **FR-6.8**: Upon ending game, each player's screen displays total time summary
- **FR-6.9**: Time summary shows total time spent per player while their screen was green
- **FR-6.10**: Time tracking begins when player's screen turns green
- **FR-6.11**: Time tracking stops when player presses "DONE" button
- **FR-6.12**: Cumulative time is calculated across all turns for each player

#### 6.3 Change Timer Function

- **FR-6.13**: Menu includes option to "Change Timer" or "Adjust Countdown"
- **FR-6.14**: Team leader can modify countdown timer value while game is in progress
- **FR-6.15**: Timer can be set to any value 1-15 minutes or "no timer"
- **FR-6.16**: New timer value applies to next turn (not current active turn)
- **FR-6.17**: All players receive updated timer value for their future turns

#### 6.4 Reorder Turn Order Function

- **FR-6.18**: Menu includes "Reorder Players" option
- **FR-6.19**: Team leader can drag/drop to change turn order during active game
- **FR-6.20**: Turn order changes take effect immediately
- **FR-6.21**: Current active player remains active until they press "DONE"
- **FR-6.22**: New turn order applies starting with next turn

#### 6.5 Change Start Player Function

- **FR-6.23**: Menu includes "Change Start Player" option
- **FR-6.24**: Team leader can designate a different player as start player mid-game
- **FR-6.25**: Start player designation relevant for game restart or next round

#### 6.6 Pause Game Function (FUTURE FEATURE)

- **FR-6.26**: Menu will include "Pause Game" option in future version
- **FR-6.27**: Pausing will freeze game state without disconnecting players
- **FR-6.28**: Team leader can resume game when ready

#### 6.7 Remove Player Function (ON HOLD - FUTURE FEATURE)

- **FR-6.29**: "Remove Player" feature deferred due to complexity
- **FR-6.30**: Players cannot leave rotation mid-game in current version
- **FR-6.31**: Future implementation will allow tapping player name to remove
- **FR-6.32**: Removed players will be disconnected and cannot rejoin same session

### 7. Player Role Requirements

#### 7.1 Team Leader Exclusive Capabilities

- **FR-7.1**: Only team leader can create sessions
- **FR-7.2**: Only team leader can configure initial turn order
- **FR-7.3**: Only team leader can set optional timer
- **FR-7.4**: Only team leader can access the menu system
- **FR-7.5**: Only team leader can end the game
- **FR-7.6**: Only team leader can change timer mid-game
- **FR-7.7**: Only team leader can reorder turn order mid-game
- **FR-7.8**: Only team leader can change start player designation

#### 7.2 Regular Player Capabilities

- **FR-7.9**: Players can join sessions created by team leader (during setup only)
- **FR-7.10**: Players can view their turn status (green/red screen)
- **FR-7.11**: Players can view complete player list with turn order
- **FR-7.12**: Players can see who is currently active (green dot indicator)
- **FR-7.13**: Players can press "DONE" button when it's their turn
- **FR-7.14**: Players can view timer countdown on their screen when active
- **FR-7.15**: Players can view end-game time summary

### 8. Time Tracking Requirements

#### 8.1 Time Measurement

- **FR-8.1**: App tracks elapsed time for each player while screen is green
- **FR-8.2**: Time tracking starts when green screen appears for player
- **FR-8.3**: Time tracking stops when player presses "DONE" button
- **FR-8.4**: Time accumulates across multiple turns for same player
- **FR-8.5**: Time is tracked per player, not per turn
- **FR-8.6**: Time is NOT visible during gameplay (only at end)

#### 8.2 Time Display

- **FR-8.7**: End-game summary displays cumulative total time per player only
- **FR-8.8**: Time is displayed in human-readable format (e.g., "15 minutes 32 seconds")
- **FR-8.9**: All players see the complete time summary when game ends
- **FR-8.10**: Time summary displayed in list format: player names left, times right
- **FR-8.11**: Font and spacing defined in AppTheme for consistency
- **FR-8.12**: No individual turn times, longest/shortest turn, or average statistics
- **FR-8.13**: Time summary displayed on screen only (no save/export functionality)

## Non-Functional Requirements

### 1. Usability

- **NFR-1.1**: Minimal setup time (< 30 seconds to start a game)
- **NFR-1.2**: Large, clear turn indicators visible across table
- **NFR-1.3**: Intuitive interface requiring no tutorial
- **NFR-1.4**: Support for various screen sizes (portrait orientation only)
- **NFR-1.5**: App locked to portrait orientation (landscape provides no added value)
- **NFR-1.6**: Screen stays awake during active game (no auto-lock)

### 2. Performance

- **NFR-2.1**: Turn notifications delivered within 2 seconds
- **NFR-2.2**: App remains responsive during background scanning
- **NFR-2.3**: Battery efficient - support 4+ hour gaming sessions
- **NFR-2.4**: Reliable operation in presence of other BLE devices

### 3. Reliability

- **NFR-3.1**: 99%+ successful turn notification delivery
- **NFR-3.2**: Graceful handling of player disconnections
- **NFR-3.3**: State synchronization across all devices
- **NFR-3.4**: Recovery from temporary radio interference

### 4. Security & Privacy

- **NFR-4.1**: No personal data transmitted or stored
- **NFR-4.2**: Session codes prevent accidental cross-table joining
- **NFR-4.3**: Ephemeral sessions - no persistent data after game ends
- **NFR-4.4**: Local-only operation - no cloud/server dependencies

## User Experience Flow

### Session Setup Flow

1. **Team Leader Setup**:
   - Team leader opens app and selects "Create Session"
   - Team leader enters their name
   - App creates local network session
   - Team leader waits for players to join

2. **Player Join Flow**:
   - Other players open app
   - Players discover available session within range
   - Players select session to join
   - Players enter their name
   - Players send join request
   - Players appear in team leader's lobby

3. **Pre-Game Configuration**:
   - Team leader sees list of all joined players
   - Team leader drags/drops to arrange turn order
   - Team leader selects start player
   - Team leader optionally sets timer (in minutes)
   - Team leader optionally enables "Turn Focus On" (future feature)
   - Team leader starts the game

### Active Gameplay Flow

1. **Game Start**:
   - Start player's screen turns GREEN with "DONE" button
   - All other players' screens turn RED with no button
   - Timer starts counting down if enabled

2. **Turn Progression**:
   - Active player plays their board game turn
   - Active player presses "DONE" button when finished
   - Next player in rotation receives GREEN screen with "DONE" button
   - Previous player's screen turns RED and "DONE" button disappears
   - Cycle continues through all players in order

3. **Timer Behavior (if enabled)**:
   - Countdown displays on active player's green screen
   - Timer counts down while player is active
   - If timer reaches 00:00, phone vibrates with haptic feedback
   - Vibration continues until player presses "DONE"
   - Timer resets for next player

### Team Leader Menu Operations

1. **End Game**:
   - Team leader taps menu icon (top right)
   - Selects "End Game"
   - All players disconnected
   - Each player sees time summary showing total green-screen time per player

2. **Change Timer Mid-Game**:
   - Team leader taps menu icon
   - Selects "Change Timer" or "Adjust Countdown"
   - Enters new timer value in minutes
   - New timer applies to next player's turn

3. **Remove Player**:
   - Team leader taps menu icon
   - Selects "Remove Player"
   - Chooses player to remove from list
   - If removed player is active, turn passes to next player
   - Player removed from rotation and disconnected

### Edge Cases & Error Handling

- **Player disconnects during their turn**: Turn passes to next player automatically
- **Player force-closes app**: Treated as disconnect, turn skips to next player
- **Player disconnects while waiting**: Removed from turn rotation, game continues (future: reconnection logic)
- **Team leader battery dies or app crashes**: Game terminates for all players, connections closed
- **Team leader disconnects**: Game ends for all players (no leadership transfer)
- **Incoming phone call**: Team leader call pauses game for everyone automatically
- **Connection lost and restored**: Future feature - reconnection logic to be designed
- **Multiple sessions nearby**: Automatic discovery shows all available sessions in list
- **Timer change during active turn**: Current turn completes with old timer, next turn uses new timer
- **Turn interrupted by app crash/connection loss**: Time does NOT count toward player total (future: reconnection handling)
- **Device enters low-power mode**: If connectivity lost, treat as disconnection
- **App in background or screen locked**: App continues to function normally
- **No audible alerts**: Visual (screen color) and haptic feedback only

## Technical Implementation Details

### App Architecture

- **Models**: Session, Player, TurnEvent data classes
- **Controllers**: SessionController for state management
- **Services**: P2PService interface with platform-specific implementations
- **UI**: Reusable player tiles, session lobby, game state screens

### Platform-Specific Implementations

- **iOS**: MultipeerConnectivity bridge via MethodChannel
- **Android**: Nearby Connections or BLE implementation via MethodChannel
- **Cross-Platform**: Flutter UI with native platform channels for P2P communication

### Data Synchronization

- **Sequence Numbers**: Monotonic counters for state ordering
- **Conflict Resolution**: Leader device acts as authoritative source
- **Heartbeat System**: Regular status broadcasts for connection health
- **State Recovery**: Automatic resync for temporarily disconnected devices

## Future Enhancement Opportunities

### Implemented Features (Current Version)

- **Turn timer**: 1-15 minute countdown with haptic feedback and screen flashing ✅
- **Time tracking**: Cumulative green-screen time per player displayed at game end ✅
- **Dynamic timer adjustment**: Change timer value or disable mid-game ✅
- **Reorder turn order**: Mid-game turn order adjustment ✅
- **Change start player**: Modify start player designation during game ✅
- **Connection status display**: Dot indicators for player connection state ✅
- **Player list visibility**: All players see turn rotation with current player highlighted ✅

### Phase 2 Features (Deferred/On Hold)

- **Remove player mid-game**: ON HOLD due to complexity of handling removed start player and turn transitions
- **Pause game**: Temporarily freeze game state without disconnecting players
- **Turn Focus On**: Prevent players from leaving app during game (visible disabled checkbox with "Coming Soon" tooltip)
- **Player reconnection**: Handle temporary disconnections with automatic rejoin and time tracking preservation
- **Audible alerts**: Customizable turn notification sounds (currently visual and haptic only)
- **Help/Tutorial screen**: Explain app functionality to new users

### Phase 3 Features (Future Consideration)

- **Player avatars**: Simple profile pictures or icons
- **Game history**: Basic statistics and session summaries
- **Individual turn statistics**: Longest turn, shortest turn, average turn time per player
- **Save/export time summary**: Allow players to save or share end-game results
- **Multiple game support**: Manage several concurrent games
- **Advanced turn rules**: Skip players, reverse order, etc.
- **Voice announcements**: Text-to-speech turn notifications
- **Integration hooks**: API for board game companion apps
- **Leadership transfer**: Allow leader role to pass to another player
- **Timer visible to all**: Show active player's countdown to waiting players
- **Player statistics**: Track performance metrics across multiple games

## Success Criteria

### Primary Goals

- ✅ Zero setup friction - players can join within 30 seconds
- ✅ Reliable turn notifications in tabletop environment
- ✅ Works offline without internet connectivity
- ✅ Battery efficient for multi-hour sessions

### Measurable Outcomes

- Battery drain < 10% per hour during active use
- Successful session completion rate > 95%
- User satisfaction rating > 4.5/5 for ease of use

## Implementation Notes

### Critical Technical Decisions (Based on Requirements Review)

1. **Color Specifications**: Active=#129c26, Waiting=#c03317 (defined in AppTheme)
2. **Network Technology**: Same WiFi network required for cross-platform support; platform-specific P2P for same-OS sessions
3. **Session Discovery**: Automatic list-based discovery with QR code fallback
4. **Timer Range**: 1-15 minutes in 1-minute increments, with "no timer" option
5. **Orientation**: Portrait only (locked)
6. **Screen Behavior**: Wake lock enabled during active game
7. **Player Visibility**: All players see complete turn order with current player highlighted
8. **Connection Status**: Displayed as dot indicators next to player names
9. **Mid-Game Features**: Reorder turn order and change start player available via menu
10. **Deferred Features**: Remove player mid-game, pause game, reconnection logic, Turn Focus
11. **WiFi Requirement**: Temporary solution for cross-platform - not preferred long-term but easiest current approach

---

*This requirements document serves as the foundation for YourTurn app development and should be referenced throughout the implementation process. It balances technical feasibility with user experience goals to create a practical solution for tabletop gaming groups. All clarification questions have been answered and incorporated into the functional requirements above.*
