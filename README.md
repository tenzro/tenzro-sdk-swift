# tenzro-sdk-swift

The official Tenzro SDK for Swift: an async/await JSON-RPC client for the [Tenzro Network](https://tenzro.com) (chain id 13380, `0x3444`), for iOS and macOS.

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/tenzro/tenzro-sdk-swift", branch: "main")
```

## Quickstart

```swift
import TenzroSDK

let client = TenzroClient()                       // https://rpc.tenzro.com
let chain = try await client.getChainId()         // 13380
let bal = try await client.getBalance("0x...")
```

## Methods

`TenzroClient`: `getChainId()`, `getBlockNumber()`, `getBalance(_:)`, `getNonce(_:)`, `getStatus()`, `isConnected()`, `resolveDidDocument(_:)`, and a generic `call(_:_:)`. All `async throws`, `Codable` JSON-RPC envelopes, `URLSession` transport. `getStatus()` uses `tenzro_getNodeStatus` and models only the fields seen on a dev node, all optional; balances come back as the node's raw hex plus a decimal string.

`TenzroDID` does syntactic parsing of `did:tenzro:human:...` / `did:tenzro:machine:...` (no resolution or verification — use `resolveDidDocument(_:)` for that). `TenzroClient.get(_:)` throws `TenzroError.paymentRequired(PaymentChallenge)` on an HTTP 402, exposing the `PAYMENT-REQUIRED`/`WWW-Authenticate` headers and body; no payment is built, signed or sent yet.

## Signing

`TenzroSigner` is the signing protocol; `SecureEnclaveSigner` (CryptoKit) and `PasskeySigner` (AuthenticationServices) are real implementations against Apple's documented APIs. Neither has been compiled or tested on an Apple platform yet — see Compatibility.

## Compatibility

| Platform | Status |
|---|---|
| Linux x86_64 (Swift 6.1.3) | `swift build` + 9/9 Swift Testing tests pass (5 offline, 4 live against a dev node) |
| macOS 14+ (arm64) | Verified for real, 7 Nov 2026: Swift 6.3.3 / Xcode 26.6 / macOS 26.6.2, `swift test` — the same 9 tests pass, target `arm64e-apple-macos14.0` |
| iOS 17+ | Compile-verified: `xcodebuild -scheme TenzroSDK -destination generic/platform=iOS build` succeeds. Not yet run on a device or simulator. |
| visionOS, tvOS, watchOS | Not supported yet — those platform SDKs weren't installed on the Mac that ran the verification above, and nothing has been built or tested on them |

`SecureEnclaveSigner` and `PasskeySigner` are written against CryptoKit/AuthenticationServices but not yet compiled or tested (no Apple-platform compiler was available when they were added — see their source comments for exactly what to verify first). `examples/BalanceView.swift` (SwiftUI) is not yet wired into a package target or compiled.

## Tests

```bash
swift test
TENZRO_RPC_URL=http://127.0.0.1:28545 swift test   # live tests
```

## Links

[tenzro-network](https://github.com/tenzro/tenzro-network) (the protocol and node) and the other official SDKs in the [tenzro](https://github.com/tenzro) organization (TypeScript, Rust, Python, Go, C/C++, Kotlin, .NET).

## License

Apache 2.0. See `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`.
