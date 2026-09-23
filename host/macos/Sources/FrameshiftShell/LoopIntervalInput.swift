import Foundation

public enum LoopIntervalInput {
  public static let maximumMinutes = 525_600

  public static func minimumMinutes(minimumDwellMs: Int?) -> Int {
    let minimum = max(1, minimumDwellMs ?? 1)
    return (minimum - 1) / 60_000 + 1
  }

  public static func dwellMilliseconds(_ input: String, minimumDwellMs: Int?) -> Int? {
    let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let minutes = Int(trimmed),
      (minimumMinutes(minimumDwellMs: minimumDwellMs)...maximumMinutes).contains(minutes)
    else { return nil }

    return minutes * 60_000
  }
}
