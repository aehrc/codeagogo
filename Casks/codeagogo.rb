cask "codeagogo" do
  version "1.1.1"
  sha256 "e54d70483c4d6cd5fe644b3489e4e70c5ea7ead8599a9f95758e89122356f5fd"

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
