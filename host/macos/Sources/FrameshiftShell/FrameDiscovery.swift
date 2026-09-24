import Foundation
import Network
import Observation

/// A privacy-limited, unauthenticated Bonjour introduction.
public struct FrameIntroduction: Equatable, Sendable {
  public let deviceID: String
  public let thingPath: String
  public let pairMode: Bool

  /// Parses DNS-SD length-prefixed TXT bytes without losing duplicate keys.
  public static func parseTXT(_ data: Data) -> FrameIntroduction? {
    guard !data.isEmpty, data.count <= 512 else { return nil }
    let bytes = Array(data)
    var cursor = 0
    var fields: [String: Data] = [:]

    while cursor < bytes.count {
      let length = Int(bytes[cursor])
      cursor += 1
      guard length > 0, length <= bytes.count - cursor else { return nil }
      let entry = bytes[cursor..<(cursor + length)]
      cursor += length
      guard let separator = entry.firstIndex(of: 0x3D), separator > entry.startIndex,
        let key = String(bytes: entry[..<separator], encoding: .ascii),
        fields[key] == nil
      else { return nil }
      fields[key] = Data(entry[entry.index(after: separator)...])
    }

    return parse(fields)
  }

  public static func parse(_ fields: [String: Data]) -> FrameIntroduction? {
    let allowed: Set<String> = ["v", "id", "td", "scheme", "pair"]
    guard fields.count >= 4, fields.count <= allowed.count,
      Set(fields.keys).isSubset(of: allowed),
      fields.reduce(0, { $0 + $1.key.utf8.count + $1.value.count }) <= 512
    else { return nil }

    var values: [String: String] = [:]
    for (key, value) in fields {
      guard let decoded = String(data: value, encoding: .utf8),
        !decoded.contains("\0")
      else { return nil }
      values[key] = decoded
    }

    guard values["v"] == "0", values["td"] == "/.well-known/wot",
      values["scheme"] == "https", let deviceID = values["id"],
      deviceID.range(of: #"^[A-Za-z0-9._~-]{16,128}$"#, options: .regularExpression) != nil,
      values["pair"] == nil || values["pair"] == "0" || values["pair"] == "1"
    else { return nil }

    return FrameIntroduction(
      deviceID: deviceID,
      thingPath: "/.well-known/wot",
      pairMode: values["pair"] == "1"
    )
  }
}

/// A discovered endpoint is only a candidate; pairing still verifies its QR-pinned TLS identity.
public struct DiscoveredFrame: Identifiable, Sendable {
  public let introduction: FrameIntroduction
  public let endpoint: NWEndpoint

  public var id: String { introduction.deviceID }
}

public enum FrameDiscoveryState: Sendable {
  case idle
  case searching
  case ready
  case unavailable
  case tooManyResults
}

@MainActor
@Observable
public final class FrameDiscovery {
  public private(set) var frames: [DiscoveredFrame] = []
  public private(set) var state: FrameDiscoveryState = .idle

  @ObservationIgnored private var browser: NWBrowser?
  @ObservationIgnored private var generation = 0

  public init() {}

  public func start() {
    guard browser == nil else { return }
    generation += 1
    let currentGeneration = generation
    let next = NWBrowser(
      for: .bonjourWithTXTRecord(type: "_frameshift._tcp", domain: "local."),
      using: .tcp
    )
    browser = next
    state = .searching

    next.browseResultsChangedHandler = { [weak self] results, _ in
      Task { @MainActor [weak self] in
        self?.receive(results, generation: currentGeneration)
      }
    }
    next.stateUpdateHandler = { [weak self] nextState in
      Task { @MainActor [weak self] in
        self?.receive(nextState, generation: currentGeneration)
      }
    }
    next.start(queue: DispatchQueue(label: "io.frameshift.discovery"))
  }

  public func stop() {
    generation += 1
    browser?.cancel()
    browser = nil
    frames = []
    state = .idle
  }

  private func receive(_ nextState: NWBrowser.State, generation callbackGeneration: Int) {
    guard callbackGeneration == generation else { return }
    switch nextState {
    case .ready: state = .ready
    case .waiting: state = .searching
    case .failed, .cancelled: state = .unavailable
    case .setup: state = .searching
    @unknown default: state = .unavailable
    }
  }

  private func receive(_ results: Set<NWBrowser.Result>, generation callbackGeneration: Int) {
    guard callbackGeneration == generation else { return }
    guard results.count <= 64 else {
      frames = []
      state = .tooManyResults
      return
    }

    let candidates = results.compactMap { result -> DiscoveredFrame? in
      guard case .bonjour(let record) = result.metadata,
        let introduction = FrameIntroduction.parseTXT(record.data)
      else { return nil }
      return DiscoveredFrame(introduction: introduction, endpoint: result.endpoint)
    }
    let counts = Dictionary(grouping: candidates, by: \.id)
    frames = candidates.filter { counts[$0.id]?.count == 1 }
      .sorted { $0.id < $1.id }
    state = .ready
  }
}
