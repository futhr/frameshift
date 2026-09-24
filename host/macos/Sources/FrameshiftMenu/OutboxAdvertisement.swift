import Foundation
import FrameshiftShell

/// Publishes only the active authenticated outbox port, never frame or artwork metadata.
@MainActor
final class OutboxAdvertisement {
  private var service: NetService?
  private var port: Int?
  private var task: Task<Void, Never>?

  func start() {
    guard task == nil else { return }
    task = Task {
      while !Task.isCancelled {
        let status = try? await LocalCoreClient().outboxStatus()
        setPort(status?.available == true ? status?.port : nil)
        try? await Task.sleep(for: .seconds(5))
      }
    }
  }

  func stop() {
    task?.cancel()
    task = nil
    setPort(nil)
  }

  private func setPort(_ next: Int?) {
    guard next != port else { return }
    service?.stop()
    service = nil
    port = next
    guard let next else { return }

    let service = NetService(
      domain: "local.", type: "_frameshift-outbox._tcp.", name: "Frameshift", port: Int32(next))
    service.setTXTRecord(NetService.data(fromTXTRecord: ["v": Data("0".utf8)]))
    service.publish()
    self.service = service
  }
}
