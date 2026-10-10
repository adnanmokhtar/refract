import SwiftUI

/// The till on the iPad at the collection desk: add-on items bought at pickup, then charge the card on file.
struct CheckoutPadView: View {
  let store: StoreModel
  @State private var showReceipt = false

  var body: some View {
    VStack(spacing: 24) {
      Text(store.basketTotal, format: .currency(code: "GBP"))
        .font(.largeTitle.bold())
      Spacer()
      Button {
        Task {
          await store.charge()
          showReceipt = true
        }
      } label: {
        Text("Charge card on file")
          .frame(maxWidth: .infinity, minHeight: 56)
      }
      .buttonStyle(.borderedProminent)
    }
    .padding(.horizontal)
    .edgesIgnoringSafeArea(.all)
    .sheet(isPresented: $showReceipt) { ReceiptView(receipt: store.lastReceipt ?? "") }
  }
}
