# typed: false
# frozen_string_literal: true

# Development-only formula: the project has no immutable release tag yet.
# Users should install with --HEAD; publish a tagged source archive and checksum before
# presenting a stable versioned formula.
class Launchpad < Formula
  desc "Modern macOS application launcher built with SwiftUI"
  homepage "https://github.com/Poseidoncode/Launchpad"
  url "https://github.com/Poseidoncode/Launchpad.git", branch: "main"
  version "1.0.0"
  head "https://github.com/Poseidoncode/Launchpad.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on macos: :sonoma

  def install
    odie "No tagged stable release is published yet; install with --HEAD." unless build.head?

    system "./build-app.sh"

    app_name = "Launchpad"
    prefix.install "build/#{app_name}.app"
  end

  def caveats
    <<~EOS
      Launchpad was installed to #{opt_prefix}/Launchpad.app.

      To launch the installed app:
        open #{opt_prefix}/Launchpad.app
    EOS
  end
end
