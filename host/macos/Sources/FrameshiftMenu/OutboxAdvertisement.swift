import Foundation
import FrameshiftShell
import OSLog

/// Publishes only the active authenticated outbox port, never frame or artwork metadata.
@MainActor
final class OutboxAdvertisement: NSObject, @preconcurrency NetServiceDelegate {
  private static let logger = Logger(subsystem: "io.frameshift.app", category: "outbox")
  private var service: NetService?
  private var port: Int?
  private var task: Task<Void, Never>?
  private var retryAfter = Date.distantPast

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

  func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
    _ = errorDict
    guard sender === service else { return }
    sender.stop()
    service = nil
    port = nil
    retryAfter = Date().addingTimeInterval(30)
    Self.logger.warning("outbox Bonjour publication failed; retry scheduled")
  }

  private func setPort(_ next: Int?) {
    if next == nil {
      service?.stop()
      service = nil
      port = nil
      retryAfter = .distantPast
      return
    }

    guard next != port || service == nil else { return }
    guard Date() >= retryAfter else { return }
    service?.stop()
    service = nil
    port = next
    guard let next else { return }

    let service = NetService(
      domain: "local.", type: "_frameshift-outbox._tcp.", name: "Frameshift", port: Int32(next))
    guard service.setTXTRecord(NetService.data(fromTXTRecord: ["v": Data("0".utf8)])) else {
      port = nil
      retryAfter = Date().addingTimeInterval(30)
      Self.logger.warning("outbox Bonjour TXT record refused; retry scheduled")
      return
    }
    service.delegate = self
    self.service = service
    service.publish()
  }
}
