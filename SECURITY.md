# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| HEAD    | ✅ Active development, no release yet |

## Security Posture

### What This App Does

Launchpad is a native macOS app that scans system application directories (`/Applications`,
`/System/Applications`, `/System/Applications/Utilities`, `~/Applications`) and displays them in a grid UI. It stores
user preferences (folder layout, custom app names) in `UserDefaults` only — **no
network access, no telemetry, no analytics**. The app is not App Sandbox-enabled because its
core workflows need to enumerate and manage app bundles outside its own container.

### Data Access

- **Reads:** The implemented scanner reads application bundle metadata (name, icon, bundle ID)
  from standard application directories. It does not read user documents, contacts, browser data,
  or personal files.
- **Writes:** Preferences are stored locally in `UserDefaults` under the key
  `LaunchpadUserPreferences`; a write-ahead staging key is used for crash recovery. The explicit
  Move to Trash action moves only the app bundle the user selected, subject to normal macOS file
  permissions and System Integrity Protection.
- **Filesystem access:** The app runs with the current user's normal filesystem permissions rather
  than an App Sandbox. This is required for app discovery and moving user-owned apps to Trash. A
  compromised or malicious build could access other files the user can access; only install builds
  you trust. The app's implemented workflows do not access those other files.
- **Network:** None. The app never makes network requests.
- **Cloud:** None. No iCloud, no sync, no remote storage.

### App Sandbox and Code Signing

The packaged app is intentionally **not** signed with the App Sandbox entitlement. Sandbox access
would prevent reliable discovery of apps in `~/Applications` and block moving user-owned app bundles
outside the app container to Trash. The app does not request administrator privileges or bypass POSIX
permissions or System Integrity Protection, so some apps (especially those in `/Applications`) may
still be impossible to move to Trash.

Both the curl installer and Homebrew formula call `build-app.sh`. The resulting app is ad-hoc signed,
not Developer ID signed or notarized; macOS may show its normal warning for software distributed
outside the App Store. The SwiftPM build sandbox is a build-time restriction and does not sandbox the
resulting app at runtime.

### Dependencies

- [swift-composable-architecture](https://github.com/pointfreeco/swift-composable-architecture)
  (MIT) — state management library. No network, file, or system access beyond what the
  host app provides.

## Reporting a Vulnerability

This project is in early development with no stable release. If you find a security
issue, please open a [GitHub Issue](https://github.com/Poseidoncode/Launchpad/issues)
or email the repository owner directly.

Please **do not** open a public issue for critical vulnerabilities affecting users of
the installed application.

## Security Considerations for Users

### curl | bash Installer

The recommended install method pipes a script from GitHub over HTTPS:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Poseidoncode/Launchpad/main/install.sh)
```

This is standard practice for developer tools (Homebrew, Rust, Deno all do the same).
The script:

1. Clones the repository to a temporary directory via `git clone --depth 1` over HTTPS
2. Builds from source using `swift build` with SwiftPM's default build-time sandbox
3. Stages the resulting `.app` in `~/Applications` by default (or `LAUNCHPAD_INSTALL_DIR`) and preserves the old copy if replacement fails
4. Removes the temporary build directory on exit

**You are trusting:**
- The HTTPS/TLS certificate chain (GitHub uses strong TLS)
- The GitHub repository content (protected by GitHub's access controls)
- The Swift compiler and Xcode toolchain on your machine

To verify integrity before running, you can inspect the script first:

```bash
curl -fsSL https://raw.githubusercontent.com/Poseidoncode/Launchpad/main/install.sh | less
```

### Homebrew Install

The Homebrew formula builds from source in a sandboxed environment. No pre-built
binaries are distributed.

### Build Verification

All builds are from source code in this repository. There are no pre-compiled
binaries — what you build is what you run.
