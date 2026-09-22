import Foundation

public protocol CoreClient: Sendable {
  func snapshot() async throws -> CoreSnapshot
  func send(_ command: CoreCommand) async throws -> CoreSnapshot
}

public enum CoreClientError: Error, Equatable, Sendable {
  case coreUnavailable
  case importTooLarge
  case importUnreadable
  case invalidCommand
  case itemNotFound
  case protocolFailure
  case targetNotFound
  case unsupportedMedia
}
