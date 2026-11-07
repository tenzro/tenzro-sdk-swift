// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TenzroSDK",
    // Minimums are a judgment call (modern async/await + Observation), not
    // verified against any compatibility requirement.
    platforms: [.iOS(.v17), .macOS(.v14), .visionOS(.v1)],
    products: [
        .library(name: "TenzroSDK", targets: ["TenzroSDK"]),
    ],
    targets: [
        .target(name: "TenzroSDK"),
        .testTarget(name: "TenzroSDKTests", dependencies: ["TenzroSDK"]),
    ],
    swiftLanguageModes: [.v6]
)
