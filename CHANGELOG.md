# Changelog

All notable changes to YourTurn will be documented in this file.

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
