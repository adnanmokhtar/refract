import SwiftUI

struct SettingsView: View {
  @AppStorage("receiptPrinter") private var receiptPrinter = "desk"
  @AppStorage("lockAfterMinutes") private var lockAfterMinutes = 15

  var body: some View {
    Form {
      Picker("Receipt printer", selection: $receiptPrinter) {
        Text("Desk").tag("desk")
        Text("Back office").tag("office")
      }
      Stepper("Lock after \(lockAfterMinutes) min", value: $lockAfterMinutes, in: 5...60, step: 5)
    }
    .onAppear { SessionClock.touch() }
  }
}
