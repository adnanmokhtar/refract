import SwiftUI

/// The receipt sheet. The tinted background runs edge to edge; the content keeps the safe area.
struct ReceiptView: View {
  let receipt: String
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    ZStack {
      Color.green.opacity(0.08)
        .ignoresSafeArea()
      VStack(spacing: 16) {
        Image(systemName: "checkmark.circle.fill")
          .font(.largeTitle)
          .foregroundStyle(.green)
          .accessibilityHidden(true)
        Text("Paid")
          .font(.title.bold())
        Text(receipt)
          .font(.body.monospaced())
        Button("Done") { dismiss() }
          .buttonStyle(.bordered)
      }
      .padding()
    }
  }
}
