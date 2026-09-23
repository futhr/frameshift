import Observation

public enum LoginItemStatus: Sendable {
  case notRegistered
  case enabled
  case requiresApproval
  case unavailable
}

@MainActor
public protocol LoginItemService: AnyObject {
  var status: LoginItemStatus { get }
  func register() throws
  func unregister() throws
}

@MainActor
@Observable
public final class LoginSettingsModel {
  public private(set) var status: LoginItemStatus
  public private(set) var errorMessage: String?

  private let service: any LoginItemService

  public init(service: any LoginItemService) {
    self.service = service
    status = service.status
  }

  public var isEnabled: Bool {
    status == .enabled || status == .requiresApproval
  }

  public var requiresApproval: Bool {
    status == .requiresApproval
  }

  public var statusText: String {
    switch status {
    case .enabled: "Frameshift will open when you log in."
    case .requiresApproval: "Allow Frameshift in macOS Login Items to finish enabling it."
    case .notRegistered: "Frameshift opens only when you start it."
    case .unavailable: "Login registration is unavailable for this app installation."
    }
  }

  public func refresh() {
    status = service.status
  }

  public func setEnabled(_ enabled: Bool) {
    do {
      if enabled && !isEnabled {
        try service.register()
      } else if !enabled && isEnabled {
        try service.unregister()
      }
      errorMessage = nil
    } catch {
      errorMessage = "macOS could not update Launch at Login. Check Login Items and try again."
    }
    refresh()
  }
}
