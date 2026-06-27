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
network access, no telemetry, no analytics**.

### Data Access

- **Reads:** Application bundle metadata (name, icon, bundle ID) from standard system paths.
  No user documents, contacts, browser data, or personal files are accessed.
- **Writes:** Preferences only — stored locally in `UserDefaults` under the key
  `LaunchpadUserPreferences`. A write-ahead staging key is also used for crash recovery.
- **Network:** None. The app never makes network requests.
- **Cloud:** None. No iCloud, no sync, no remote storage.

### Sandbox

Launchpad runs inside the macOS App Sandbox with these entitlements:

- `com.apple.security.app-sandbox` — Sandbox enabled

> **Note:** The Homebrew formula (`brew install`) builds without sandbox or codesigning
> (it uses `--disable-sandbox` for SPM's build sandbox only, and does not apply codesign).
> Sandboxing is only applied when using the curl installer (`build-app.sh`) which codesigns
> with entitlements. Both installation paths produce functionally identical binaries.

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
2. Builds from source using `swift build`
3. Copies the resulting `.app` to `/Applications`
4. Removes the temporary directory on exit

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
