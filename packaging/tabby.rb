# Homebrew の tap（github.com/yteraoka/homebrew-cask の Casks/tabby.rb）に置く cask の元。
# version と sha256 はリリースのワークフロー（scripts/cask.sh）が書き換える。
cask "tabby" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/yteraoka/tabby/releases/download/v#{version}/Tabby-#{version}-macos-universal.zip"
  name "Tabby"
  desc "Search tabs across browsers and switch to them"
  homepage "https://github.com/yteraoka/tabby"

  livecheck do
    skip "Auto-generated on release."
  end

  depends_on macos: ">= :ventura"

  app "Tabby.app"

  # ad-hoc 署名で公証していないため、quarantine 属性を外して Gatekeeper に止められないようにする
  postflight do
    system_command "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "#{appdir}/Tabby.app"]
  end

  uninstall quit: "com.github.yteraoka.tabby"

  zap trash: "~/Library/Preferences/com.github.yteraoka.tabby.plist"

  caveats <<~EOS
    Tabby runs in the menu bar. Press Shift-Command-Space to search tabs.
    The first time it reads tabs, macOS asks to allow Tabby to control each browser.
  EOS
end
