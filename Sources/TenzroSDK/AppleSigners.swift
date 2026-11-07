#if canImport(CryptoKit)
import CryptoKit
import Foundation

/// A `TenzroSigner` backed by the Secure Enclave, via CryptoKit's
/// `SecureEnclave.P256.Signing.PrivateKey`.
///
/// NOT COMPILED OR TESTED by the session that wrote this: no Apple-platform
/// compiler was available (Linux `swift build` can't see this file at all,
/// `canImport(CryptoKit)` is false there). Written against Apple's documented
/// CryptoKit API; needs a real build and a real device or simulator run
/// before it's trusted. `SecureEnclave.isAvailable` is checked at creation
/// and the initializer throws rather than silently falling back to a
/// non-enclave key, since a signer that silently stops using the enclave
/// would be a worse bug than one that fails loudly.
///
/// What curve and encoding the node expects for a given operation is NOT
/// re-derived here — see `sdk/tenzro-ts-sdk/packages/core/src/passkey-rpc.ts`
/// (`CompositeSignature`'s `raw` form expects the classical leg as a P-256
/// signature; this signer produces exactly that, nothing about the ML-DSA-65
/// leg some operations also require).
@available(macOS 14, iOS 17, *)
public final class SecureEnclaveSigner: TenzroSigner {
    private let privateKey: SecureEnclave.P256.Signing.PrivateKey
    public let keyID: String

    /// Creates a new Secure Enclave key. There is no way to recreate the same
    /// key later except from `dataRepresentation`, which the caller must
    /// store (Keychain, not this type's job) if the key needs to persist.
    public init(keyID: String) throws {
        guard SecureEnclave.isAvailable else {
            throw TenzroSignerError.secureEnclaveUnavailable
        }
        self.privateKey = try SecureEnclave.P256.Signing.PrivateKey()
        self.keyID = keyID
    }

    /// Restores a signer from a previously stored `dataRepresentation`.
    public init(keyID: String, dataRepresentation: Data) throws {
        guard SecureEnclave.isAvailable else {
            throw TenzroSignerError.secureEnclaveUnavailable
        }
        self.privateKey = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: dataRepresentation)
        self.keyID = keyID
    }

    /// Opaque bytes to persist if this key must survive past this process;
    /// restore with `init(keyID:dataRepresentation:)`.
    public var dataRepresentation: Data { privateKey.dataRepresentation }

    public func publicKey() async throws -> Data {
        // Uncompressed SEC1 point (0x04 || x || y), 65 bytes: the form the
        // node's `public_key_xy` / `publicKey` hex fields expect elsewhere in
        // this SDK family (see examples/did_resolve.* in the Rust/TS mirrors).
        privateKey.publicKey.x963Representation
    }

    public func sign(_ message: Data) async throws -> Data {
        // P256.Signing produces an ECDSA signature over the SHA-256 of
        // `message`; CryptoKit hashes internally, so callers must pass the
        // actual message bytes, not a pre-hashed digest.
        let signature = try privateKey.signature(for: message)
        // rawRepresentation is r || s, 64 bytes fixed-width -- the form
        // CompositeSignature's `raw` classical leg expects (not DER).
        return signature.rawRepresentation
    }
}

public enum TenzroSignerError: Error, Sendable {
    case secureEnclaveUnavailable
    case passkeyAssertionFailed(underlying: Error)
    case presentationContextMissing
}
#endif

#if canImport(AuthenticationServices)
import AuthenticationServices

/// A `TenzroSigner` backed by a platform passkey, via
/// `ASAuthorizationPlatformPublicKeyCredentialProvider`.
///
/// NOT COMPILED OR TESTED by the session that wrote this, for the same
/// reason as `SecureEnclaveSigner` above -- and this one carries more real
/// risk of a subtle mistake: it bridges `ASAuthorizationControllerDelegate`'s
/// completion-handler API to `async`/`await` by hand, which is exactly the
/// kind of code that looks right and silently hangs or double-resumes a
/// continuation if a detail is wrong. Treat this as a first draft to review
/// against a real build, not a trusted implementation.
///
/// `sign(_:)` here performs a passkey ASSERTION (proving control of an
/// already-registered credential), matching `CompositeSignature`'s
/// `web_authn` form. Registering a NEW passkey (the `create` side) is a
/// separate `ASAuthorizationPlatformPublicKeyCredentialRegistrationRequest`
/// flow, deliberately not implemented here -- see
/// `tenzro-cookbook/recipes/did-tenzro-create.md` for why a create flow
/// needs a real device/simulator ceremony this session could not perform.
@available(macOS 14, iOS 17, *)
public final class PasskeySigner: NSObject, TenzroSigner, ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding
{
    public let keyID: String
    private let relyingPartyIdentifier: String
    private let credentialID: Data
    private weak var presentationAnchorProvider: (() -> ASPresentationAnchor)?

    private var continuation: CheckedContinuation<Data, Error>?
    private var pendingPublicKey: Data?

    /// - Parameters:
    ///   - keyID: the credential id, base64url or hex as the caller tracks it elsewhere.
    ///   - relyingPartyIdentifier: must match the RP id the credential was created under.
    ///   - credentialID: raw credential id bytes, as returned at registration.
    ///   - presentationAnchorProvider: supplies the window/scene to present the
    ///     system passkey UI in; required by `ASAuthorizationControllerPresentationContextProviding`.
    public init(
        keyID: String,
        relyingPartyIdentifier: String,
        credentialID: Data,
        presentationAnchorProvider: @escaping () -> ASPresentationAnchor
    ) {
        self.keyID = keyID
        self.relyingPartyIdentifier = relyingPartyIdentifier
        self.credentialID = credentialID
        self.presentationAnchorProvider = presentationAnchorProvider
    }

    /// There is no public-key-only lookup after the fact for a platform
    /// passkey; the caller must supply it (from where it was recorded at
    /// registration) via `knownPublicKey`, set before the first `sign` call,
    /// or this throws. Kept separate from `init` so a signer can be
    /// constructed before the public key is known.
    public var knownPublicKey: Data?

    public func publicKey() async throws -> Data {
        guard let knownPublicKey else {
            throw TenzroSignerError.passkeyAssertionFailed(
                underlying: CocoaError(.featureUnsupported)
            )
        }
        return knownPublicKey
    }

    public func sign(_ message: Data) async throws -> Data {
        let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
            relyingPartyIdentifier: relyingPartyIdentifier
        )
        let request = provider.createCredentialAssertionRequest(challenge: message)
        request.allowedCredentials = [
            ASAuthorizationPlatformPublicKeyCredentialDescriptor(credentialID: credentialID)
        ]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
            self.continuation = continuation
            controller.performRequests()
        }
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        guard
            let credential = authorization.credential
                as? ASAuthorizationPlatformPublicKeyCredentialAssertion
        else {
            continuation?.resume(
                throwing: TenzroSignerError.passkeyAssertionFailed(
                    underlying: CocoaError(.featureUnsupported)
                )
            )
            continuation = nil
            return
        }
        // The signature over authenticatorData || SHA-256(clientDataJSON);
        // CompositeSignature's `web_authn` form wants these three fields
        // separately, not pre-combined -- callers needing that shape should
        // use `lastAssertion` (set just before resuming) rather than this
        // raw signature alone.
        lastAssertion = (
            authenticatorData: credential.rawAuthenticatorData,
            clientDataJSON: credential.rawClientDataJSON,
            signature: credential.signature
        )
        continuation?.resume(returning: credential.signature)
        continuation = nil
    }

    public func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        continuation?.resume(throwing: TenzroSignerError.passkeyAssertionFailed(underlying: error))
        continuation = nil
    }

    public func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let anchor = presentationAnchorProvider?() else {
            // ASAuthorizationControllerPresentationContextProviding requires a
            // non-optional return; there is no safe anchor to fabricate if
            // the caller's provider is gone. This is a programmer error
            // (the provider was deallocated before the request completed),
            // not a runtime condition to handle gracefully.
            preconditionFailure("presentationAnchorProvider returned nil or was deallocated")
        }
        return anchor
    }

    /// Set by `authorizationController(_:didCompleteWithAuthorization:)` just
    /// before resolving `sign(_:)`'s continuation. Read this after `sign(_:)`
    /// returns to get the full `web_authn` CompositeSignature fields
    /// (`authenticatorData`, `clientDataJSON`, `signature`) rather than the
    /// bare signature `sign(_:)` returns on its own.
    public private(set) var lastAssertion: (
        authenticatorData: Data, clientDataJSON: Data, signature: Data
    )?
}
#endif
