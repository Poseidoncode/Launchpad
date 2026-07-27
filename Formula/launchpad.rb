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
    system "./build-app.sh"

    app_name = "Launchpad"
    prefix.install "build/#{app_name}.app"
  end

  def caveats
    <<~EOS
      Launchpad was installed to #{opt_prefix}/Launchpad.app.

      To use it from /Applications:
        cp -r #{opt_prefix}/Launchpad.app /Applications/
        open /Applications/Launchpad.app
    EOS
  end
end
