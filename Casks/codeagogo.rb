cask "codeagogo" do
  version "1.2.0"
  sha256 "cc2c5c1257c586c8cd4dbe18536cbbbd21f0a2c09458c87f493c8875a95e4bee"

  url "https://github.com/aehrc/codeagogo/releases/download/v#{version}/Codeagogo-v#{version}-macOS.zip"
  name "Codeagogo"
  desc "macOS menu bar utility for clinical terminology code lookup"
  homepage "https://aehrc.github.io/codeagogo/"

  depends_on macos: ">= :ventura"

  app "Codeagogo.app"

  zap trash: [
    "~/Library/Preferences/au.csiro.aehrc.Codeagogo.plist",
    "~/Library/Caches/au.csiro.aehrc.Codeagogo",
  ]
end
