import SwiftUI

/// Every pickup due today. On a busy Saturday the store has several hundred, each row with its bag count.
struct OrdersListView: View {
  let store: StoreModel

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(store.orders) { order in
            OrderRowView(order: order)
          }
        }
        .padding()
      }
      .navigationTitle("Pickups")
      .refreshable { await store.refresh() }
    }
  }
}
