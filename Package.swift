// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "TenzroSDK",
    // macOS 14+ verified for real (swift test, 9/9 pass) on a real Mac, 7 Nov.
    // iOS 17+ is compile-verified only (xcodebuild build succeeded; not run on
    // a device or simulator). visionOS/tvOS/watchOS are deliberately absent:
    // those platform SDKs were not installed on the verifying Mac and nothing
    // has been built or tested on them -- add back only with real evidence.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "TenzroSDK", targets: ["TenzroSDK"]),
    ],
    targets: [
        .target(name: "TenzroSDK"),
        .testTarget(name: "TenzroSDKTests", dependencies: ["TenzroSDK"]),
    ],
    swiftLanguageModes: [.v6]
)
