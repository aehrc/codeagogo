cask "codeagogo" do
  version "1.0.0"
  sha256 "c7618b149a06cec589209485e80b308d0cdf15c47a7ac282ba5a05522562332f"

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
