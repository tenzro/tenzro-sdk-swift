import Foundation

/// INTERFACE DEFINITION ONLY. There is no implementation in this package.
///
/// A `TenzroSigner` produces signatures over caller-supplied bytes. The
/// intended implementations, both Apple-only and both requiring real device
/// or simulator testing that has not been done:
///
/// - A passkey signer built on `AuthenticationServices`
///   (`ASAuthorizationPlatformPublicKeyCredentialProvider` assertions).
/// - A key signer backed by `CryptoKit` / the Secure Enclave
///   (`SecureEnclave.P256.Signing.PrivateKey`).
///
/// Neither framework is imported here, so the package stays buildable off
/// Apple platforms. The SDK's read-only client does not use a signer.
///
/// What bytes to sign, which curve the network accepts for which operation,
/// and how a signature is attached to a transaction or DID envelope are
/// NOT defined here. Consult the node's documentation before implementing.
public protocol TenzroSigner: Sendable {
    /// Identifier of the signing key or credential (for example a credential ID).
    var keyID: String { get async }
    /// Public key bytes in the encoding the chosen signature scheme requires.
    func publicKey() async throws -> Data
    /// Sign `message`. May prompt the user (biometrics / passkey UI).
    func sign(_ message: Data) async throws -> Data
}
