import Foundation
import Observation

@MainActor
@Observable
public final class PairingSettingsModel {
  public private(set) var isBusy = false
  public private(set) var statusMessage: String?
  public private(set) var errorMessage: String?

  private let core: LocalCoreClient
  private let identityStore: KeychainIdentityStore

  public init(
    core: LocalCoreClient = LocalCoreClient(), identityStore: KeychainIdentityStore = .init()
  ) {
    self.core = core
    self.identityStore = identityStore
  }

  @discardableResult
  public func pair(
    frame: DiscoveredFrame, bootstrap: String, discovery: FrameDiscovery
  ) async -> Bool {
    guard !isBusy,
      frame.introduction.pairMode,
      discovery.frames.contains(where: { $0.id == frame.id && $0.endpoint == frame.endpoint })
    else {
      errorMessage = "This frame is no longer available in physical pair mode."
      return false
    }

    isBusy = true
    errorMessage = nil
    statusMessage = nil
    defer { isBusy = false }

    do {
      let origin = try await FrameServiceResolver().resolve(frame.endpoint)
      let reference = try identityStore.ensureHostIdentity()
      let paired = try await core.pair(
        bootstrap: bootstrap,
        discoveredID: frame.id,
        origin: origin,
        credentialReference: reference
      )
      statusMessage = "Paired \(paired.frameID)."
      return true
    } catch CoreClientError.pairingOutcomeUnknown {
      errorMessage = "The frame may have accepted pairing. Check its status before trying again."
    } catch CoreClientError.pairingIncomplete {
      errorMessage =
        "The frame accepted pairing, but its authenticated description was not admitted."
    } catch CoreClientError.pairingRejected {
      errorMessage =
        "The frame rejected pairing. Reopen physical pair mode and use its current QR label."
    } catch CoreClientError.pairingPreflightFailed {
      errorMessage =
        "The selected frame and QR label do not match, or the pairing record is invalid."
    } catch is FrameServiceResolutionError {
      errorMessage = "The selected frame could not be resolved on this local network."
    } catch is KeychainIdentityError {
      errorMessage = "The Mac could not access its pairing identity in Keychain."
    } catch {
      errorMessage = "Pairing could not be completed. Check the frame before trying again."
    }
    return false
  }

  public func reportInvalidQR() {
    errorMessage = "Choose one clear image of the frame’s pairing QR label."
  }
}
