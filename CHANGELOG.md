# Changelog

All notable changes to YourTurn will be documented in this file.

## [0.0.5] - 2026-02-04

### Fixed

- QR code joining now works properly with WiFi-based connectivity
- QR codes now include host IP:PORT for direct connection without discovery
- Extended QR format: `yourturn:CODE:IP:PORT` enables instant joining
- `joinSession` now accepts optional `connectionInfo` parameter for direct connection
- WiFi P2P service properly fetches and caches local IP address when hosting
- All P2P service implementations updated with consistent interface

### Changed

- QR scanner returns structured data (code + connectionInfo) instead of raw string
- Session controller exposes `hostConnectionInfo` getter for QR code generation
- Lobby screen passes connection info when joining via QR code scan

---

## [0.0.4] - 2026-02-03

### Added

- WiFi-based P2P service (`p2p_service_wifi.dart`) for cross-platform connectivity
- TCP/IP socket communication for reliable message delivery between iOS and Android
- UDP broadcast discovery for automatic session detection on same network
- P2P service factory with configurable modes (WiFi, Platform-native, Stub)
- WiFi requirement notification banner on lobby screen
- WiFi reminder on setup screen for all players

### Changed

- Default P2P mode is now WiFi for cross-platform support
- Updated documentation to reflect same WiFi network requirement

### Notes

- All devices must be connected to the same WiFi network for cross-platform sessions
- This is the current solution for iOS + Android interoperability (not the ideal long-term solution, but simplest approach)
- Platform-native mode (MultipeerConnectivity/Nearby Connections) still available for same-OS sessions

---

## [0.0.3] - 2026-02-02

- Added connectivity and joining sessions capability

---

## [0.0.2] - 2026-02-01

- Initial release with newer requirements
- No connectivity features yet

---

## [0.0.1] - 2026-02-01

- Initial release

---

## Version Format

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Version format: `MAJOR.MINOR.PATCH+BUILD`

- MAJOR: Breaking changes
- MINOR: New features (backwards compatible)
- PATCH: Bug fixes (backwards compatible)
- BUILD: Build/release number (auto-incremented by CI/CD)

## How to Update

When adding changes, add them under the current version header at the top.
Use these categories:

- **Added** for new features
- **Changed** for changes in existing functionality
- **Deprecated** for soon-to-be removed features
- **Removed** for now removed features
- **Fixed** for any bug fixes
- **Security** for vulnerability fixes

Example:

```text
## [1.1.0] - 2026-02-15

### Added
- New feature description

### Fixed
- Bug fix description

---
```

Separate versions with `---` delimiter for easy parsing by CI/CD.
