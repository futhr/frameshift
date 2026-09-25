import FrameshiftShell
import Testing

@Suite("Launch at Login settings")
@MainActor
struct LoginSettingsTests {
  @Test("The main app registers only after the user enables it")
  func optInAndDisable() {
    let service = RecordingLoginItemService()
    let model = LoginSettingsModel(service: service)

    #expect(!model.isEnabled)
    #expect(service.registerCount == 0)

    model.setEnabled(true)
    #expect(model.isEnabled)
    #expect(service.registerCount == 1)

    model.setEnabled(false)
    #expect(!model.isEnabled)
    #expect(service.unregisterCount == 1)
  }

  @Test("Approval-required state remains enabled and can be unregistered")
  func approvalAndFailure() {
    let service = RecordingLoginItemService(status: .requiresApproval)
    let model = LoginSettingsModel(service: service)

    #expect(model.isEnabled)
    #expect(model.requiresApproval)
    #expect(model.statusText.contains("Login Items"))

    service.shouldFail = true
    model.setEnabled(false)
    #expect(model.requiresApproval)
    #expect(model.errorMessage?.contains("could not update") == true)
    #expect(service.unregisterCount == 1)
  }
}

@MainActor
private final class RecordingLoginItemService: LoginItemService {
  var status: LoginItemStatus
  var registerCount = 0
  var unregisterCount = 0
  var shouldFail = false

  init(status: LoginItemStatus = .notRegistered) {
    self.status = status
  }

  func register() throws {
    registerCount += 1
    if shouldFail { throw TestError.registration }
    status = .enabled
  }

  func unregister() throws {
    unregisterCount += 1
    if shouldFail { throw TestError.registration }
    status = .notRegistered
  }
}

private enum TestError: Error {
  case registration
}
