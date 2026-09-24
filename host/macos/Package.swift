// swift-tools-version: 6.0

import PackageDescription

let package = Package(
  name: "FrameshiftMac",
  platforms: [.macOS(.v14)],
  products: [
    .library(name: "FrameshiftShell", targets: ["FrameshiftShell"]),
    .executable(name: "frameshift-menu", targets: ["FrameshiftMenu"]),
    .executable(name: "frameshift-shell-checks", targets: ["FrameshiftShellChecks"]),
    .executable(name: "frameshift-ipc-probe", targets: ["FrameshiftIPCProbe"]),
    .executable(name: "frameshift-keychain-probe", targets: ["FrameshiftKeychainProbe"]),
    .executable(name: "frameshiftctl", targets: ["FrameshiftCTL"]),
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
    .executableTarget(
      name: "FrameshiftIPCProbe",
      dependencies: ["FrameshiftShell"]
    ),
    .executableTarget(
      name: "FrameshiftKeychainProbe",
      dependencies: ["FrameshiftShell"]
    ),
    .executableTarget(
      name: "FrameshiftCTL",
      dependencies: ["FrameshiftShell"]
    ),
    .testTarget(
      name: "FrameshiftShellTests",
      dependencies: ["FrameshiftShell"]
    ),
  ],
  swiftLanguageModes: [.v6]
)
