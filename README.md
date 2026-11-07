# tenzro-sdk-swift

A minimal Swift client for the Tenzro network (chain id 13380, `0x3444`; production RPC `https://rpc.tenzro.com`). Pre-1.0, read-only.

## Verification status (read this first)

| Item | Status |
|---|---|
| Builds with Swift 6.1.3 on **Linux x86_64** | Verified (`swift build`) |
| 9 Swift Testing tests (5 offline, 4 live against a dev node) | Passed on **Linux** |
| **macOS 14+ (arm64)** | **Verified for real**, 7 Nov: Swift 6.3.3 / Xcode 26.6 / macOS 26.6.2, `swift test` — same 9 tests (5 offline, 4 live against the dev node) PASSED, target `arm64e-apple-macos14.0` |
| **iOS 17+** | **Compile-verified only**: `xcodebuild -scheme TenzroSDK -destination generic/platform=iOS build` → BUILD SUCCEEDED. Not run on a device or simulator yet. |
| **visionOS, tvOS, watchOS** | **Not supported.** Removed from the package's platform list — those platform SDKs were not installed on the Mac that did the verification above and nothing has been built or tested on them. Re-add only once a real build+test exists. |
| `URLSession` behavior on Apple platforms | Verified on macOS (tests passed); not separately exercised on iOS beyond the compile check |
| `examples/BalanceView.swift` (SwiftUI) | **Uncompiled by this session** (no macOS/Xcode access from here). Not wired into a package target. Needs Xcode on the Mac that did the verification above — see "Open follow-ups" |
| Signer (passkeys / Secure Enclave) | Real implementation added, written against Apple's documented `AuthenticationServices`/`CryptoKit` APIs — **not compiled or tested by this session** (no Apple-platform compiler available here). Needs a real build+test on a Mac before it's trusted. |
| Platform minimums (iOS 17, macOS 14) | A judgment call, not checked against a requirement |
| Production endpoint `rpc.tenzro.com` | Not exercised by tests |

## Surface

- `TenzroClient`: `getChainId()`, `getBlockNumber()`, `getBalance(_:)`, `getNonce(_:)`, `getStatus()`, `isConnected()`, `resolveDidDocument(_:)`, generic `call(_:_:)`. All `async throws`, `Codable` JSON-RPC envelopes, `URLSession` transport.
- `TenzroDID`: syntactic parsing of `did:tenzro:human:...` / `did:tenzro:machine:...`. No resolution or verification.
- `TenzroClient.get(_:)`: HTTP GET that throws `TenzroError.paymentRequired(PaymentChallenge)` on 402, exposing the `PAYMENT-REQUIRED` / `WWW-Authenticate` headers and body. Typed surfacing only; **no payment is built, signed or sent**.
- `TenzroSigner`: protocol only.
- Not included: streaming (SSE) inference, transaction building or signing, any write method.

`getStatus()` uses `tenzro_getNodeStatus` and models only fields seen on a dev node; all are optional. Balances are returned as the node's raw hex plus a decimal string (no big-integer type).

## Usage

```swift
import TenzroSDK

let client = TenzroClient()                       // https://rpc.tenzro.com
let chain = try await client.getChainId()         // 13380
let bal = try await client.getBalance("0x...")
```

## Tests

```bash
swift test
TENZRO_RPC_URL=http://127.0.0.1:28545 swift test   # live tests
```

## License

Apache 2.0. See `LICENSE`, `CONTRIBUTING.md`, `SECURITY.md`.
