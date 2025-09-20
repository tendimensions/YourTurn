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
- **Primary Transport**: Bluetooth Low Energy (BLE) for device discovery and small message passing
- **Fallback Options**:
  - iOS: MultipeerConnectivity framework for enhanced reliability
  - Android: Google Play Services Nearby Connections API
- **Range**: 10-foot radius (typical BLE range)
- **Bandwidth**: Low - only small notification messages (< 100 bytes per message)
- **Network Type**: Local peer-to-peer, no internet connectivity required

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

## Functional Requirements

### 1. Session Management
- **FR-1.1**: App leader can create a new game session
- **FR-1.2**: Session generates a short, human-readable code for easy joining
- **FR-1.3**: Other players can discover and join sessions within radio range
- **FR-1.4**: Leader can set and modify turn order by dragging player names
- **FR-1.5**: Sessions persist until manually ended or all players leave

### 2. Player Management
- **FR-2.1**: Players enter their name when joining a session
- **FR-2.2**: Support for 2-8 players per session
- **FR-2.3**: Late joining allowed (players can join mid-game)
- **FR-2.4**: Leader can reorder players at any time
- **FR-2.5**: Players can leave session gracefully

### 3. Turn Notification System
- **FR-3.1**: Current player sees "Your Turn" indicator clearly
- **FR-3.2**: Players can tap "Done" to pass turn to next player
- **FR-3.3**: Next player receives immediate notification (visual and optionally audio)
- **FR-3.4**: All players see current turn status
- **FR-3.5**: Turn order cycles through all players continuously

### 4. Device Discovery & Connection
- **FR-4.1**: Automatic discovery of nearby sessions without manual pairing
- **FR-4.2**: One-tap joining process (minimal user interaction)
- **FR-4.3**: No internet connectivity required
- **FR-4.4**: Connection maintained with screen locked (background support)
- **FR-4.5**: Automatic reconnection if temporarily disconnected

## Non-Functional Requirements

### 1. Usability
- **NFR-1.1**: Minimal setup time (< 30 seconds to start a game)
- **NFR-1.2**: Large, clear turn indicators visible across table
- **NFR-1.3**: Intuitive interface requiring no tutorial
- **NFR-1.4**: Support for various screen sizes and orientations

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

### Initial Setup
1. First player opens app and taps "Create Session"
2. Enters their name, app generates session code
3. Other players open app, see nearby session(s)
4. Players tap to join, enter their names
5. Leader arranges turn order and taps "Start Game"

### During Gameplay
1. Current player sees prominent "Your Turn" indicator
2. Other players see who's currently playing
3. When done, current player taps "Done"
4. Next player immediately receives notification
5. Turn indicator updates across all devices

### Edge Cases
- **Player leaves**: Turn automatically passes to next player
- **Leader leaves**: Leadership transfers to next player
- **Connection issues**: Automatic reconnection attempts
- **Multiple sessions nearby**: Clear session identification

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

### Phase 2 Features
- **Audio notifications**: Customizable turn notification sounds
- **Player avatars**: Simple profile pictures or icons
- **Turn timer**: Optional countdown for turn duration
- **Game history**: Basic statistics and session summaries

### Phase 3 Features
- **Multiple game support**: Manage several concurrent games
- **Advanced turn rules**: Skip players, reverse order, etc.
- **Voice announcements**: Text-to-speech turn notifications
- **Integration hooks**: API for board game companion apps

## Success Criteria

### Primary Goals
- ✅ Zero setup friction - players can join within 30 seconds
- ✅ Reliable turn notifications in tabletop environment
- ✅ Works offline without internet connectivity
- ✅ Battery efficient for multi-hour sessions

### Measurable Outcomes
- Turn notification delivery time < 2 seconds
- Battery drain < 10% per hour during active use
- Successful session completion rate > 95%
- User satisfaction rating > 4.5/5 for ease of use

---

*This requirements document serves as the foundation for YourTurn app development and should be referenced throughout the implementation process. It balances technical feasibility with user experience goals to create a practical solution for tabletop gaming groups.*
