import Foundation

/// Locks the till after 15 minutes of no use. Measured on the monotonic clock so a changed wall clock cannot extend it.
enum SessionClock {
  private static var lastActivity = ProcessInfo.processInfo.systemUptime

  static func touch() {
    lastActivity = ProcessInfo.processInfo.systemUptime
  }

  static var shouldLock: Bool {
    ProcessInfo.processInfo.systemUptime - lastActivity > 15 * 60
  }
}
