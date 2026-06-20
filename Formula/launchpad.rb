# typed: false
# frozen_string_literal: true

class Launchpad < Formula
  desc "Modern macOS application launcher built with SwiftUI"
  homepage "https://github.com/Poseidoncode/Launchpad"
  url "https://github.com/Poseidoncode/Launchpad.git", branch: "main"
  version "1.0.0"
  head "https://github.com/Poseidoncode/Launchpad.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on macos: :sonoma

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"

    app_name = "Launchpad"
    app_dir = buildpath / "build" / "#{app_name}.app"

    # Create .app bundle structure
    mkdir_p app_dir / "Contents/MacOS"

    # Copy binary
    cp buildpath / ".build/release/#{app_name}", app_dir / "Contents/MacOS/#{app_name}"

    # Create Info.plist
    (app_dir / "Contents/Info.plist").write <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleExecutable</key>
        <string>#{app_name}</string>
        <key>CFBundleIdentifier</key>
        <string>com.launchpad.app</string>
        <key>CFBundleName</key>
        <string>#{app_name}</string>
        <key>CFBundlePackageType</key>
        <string>APPL</string>
        <key>CFBundleShortVersionString</key>
        <string>1.0.0</string>
        <key>CFBundleVersion</key>
        <string>1</string>
        <key>LSMinimumSystemVersion</key>
        <string>14.0</string>
        <key>NSHighResolutionCapable</key>
        <true/>
        <key>NSPrincipalClass</key>
        <string>NSApplication</string>
      </dict>
      </plist>
    PLIST

    # Skip icon generation — use curl installer for full .app with icon
    prefix.install "build/#{app_name}.app"
  end

  def caveats
    <<~EOS
      Launchpad was installed to #{opt_prefix}/Launchpad.app.

      To use it from /Applications:
        cp -r #{opt_prefix}/Launchpad.app /Applications/
        open /Applications/Launchpad.app

      For the full .app with app icon, use the curl installer instead:
        bash <(curl -fsSL https://raw.githubusercontent.com/Poseidoncode/Launchpad/main/install.sh)
    EOS
  end
end
