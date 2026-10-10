import SwiftUI

struct OrderRowView: View {
  let order: PickupOrder

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(order.customer)
          .font(.headline)
        Text("\(order.bags) bags · due \(order.dueAt.formatted(date: .omitted, time: .shortened))")
          .font(.system(size: 13))
          .foregroundStyle(.secondary)
      }
      Spacer()
      Image(systemName: "chevron.right")
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
    }
    .padding(.vertical, 8)
  }
}
