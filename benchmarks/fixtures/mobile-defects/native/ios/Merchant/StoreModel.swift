import Foundation
import Observation

struct PickupOrder: Identifiable, Hashable {
  let id: Int
  let customer: String
  let bags: Int
  let dueAt: Date
}

@Observable
final class StoreModel {
  var orders: [PickupOrder] = []
  var basketTotal: Decimal = 0
  var lastReceipt: String?

  func refresh() async {
    orders = (try? await StoreAPI.shared.pickups()) ?? orders
  }

  func charge() async {
    lastReceipt = try? await StoreAPI.shared.charge(amount: basketTotal)
  }
}
