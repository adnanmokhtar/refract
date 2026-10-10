import SwiftUI

@main
struct MerchantApp: App {
  @State private var store = StoreModel()

  var body: some Scene {
    WindowGroup {
      TabView {
        OrdersListView(store: store)
          .tabItem { Label("Pickups", systemImage: "bag") }
        ScanView()
          .tabItem { Label("Scan", systemImage: "barcode.viewfinder") }
        CheckoutPadView(store: store)
          .tabItem { Label("Till", systemImage: "creditcard") }
        SettingsView()
          .tabItem { Label("Settings", systemImage: "gear") }
      }
      .task { Attribution.reportInstall() }
    }
  }
}
