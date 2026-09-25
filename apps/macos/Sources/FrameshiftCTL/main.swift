import Foundation
import FrameshiftShell

@main
struct FrameshiftCTL {
  static func main() {
    do {
      let arguments = Array(CommandLine.arguments.dropFirst())
      guard arguments.count >= 2, arguments[0] == "diagnostics" else {
        throw UsageError.invalid
      }

      let operation = arguments[1]
      var cursor: Int?
      var limit = 50
      var index = 2

      while index < arguments.count {
        guard index + 1 < arguments.count, let value = Int(arguments[index + 1]) else {
          throw UsageError.invalid
        }

        switch arguments[index] {
        case "--cursor": cursor = value
        case "--limit": limit = value
        default: throw UsageError.invalid
        }

        index += 2
      }

      let response = try DiagnosticsClient.query(operation, cursor: cursor, limit: limit)
      let document = try JSONSerialization.jsonObject(with: response)
      let output = try JSONSerialization.data(
        withJSONObject: document,
        options: [.prettyPrinted, .sortedKeys]
      )
      FileHandle.standardOutput.write(output)
      FileHandle.standardOutput.write(Data([10]))
    } catch UsageError.invalid {
      fputs(
        "usage: frameshiftctl diagnostics health|metrics|audit [--limit 1..100] [--cursor ID]\n",
        stderr
      )
      exit(64)
    } catch {
      fputs("frameshiftctl: diagnostics unavailable or response invalid\n", stderr)
      exit(1)
    }
  }

  private enum UsageError: Error {
    case invalid
  }
}
