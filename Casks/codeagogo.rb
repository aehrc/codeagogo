cask "codeagogo" do
  version "1.1.0"
  sha256 "59af3764bf8be7342117e28149ddac1a717ae167ba54942c629614f9af706c31"

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
