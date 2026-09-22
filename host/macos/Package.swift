// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "FrameshiftMac",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "FrameshiftShell", targets: ["FrameshiftShell"]),
    .executable(name: "frameshift-menu", targets: ["FrameshiftMenu"]),
    .executable(name: "frameshift-shell-checks", targets: ["FrameshiftShellChecks"]),
  ],
  targets: [
    .target(name: "FrameshiftShell"),
    .executableTarget(
      name: "FrameshiftMenu",
      dependencies: ["FrameshiftShell"]
    ),
    .executableTarget(
      name: "FrameshiftShellChecks",
      dependencies: ["FrameshiftShell"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
