import CoreBluetooth
import Foundation

@objc(ScaleBridge)
final class ScaleBridge: NSObject {
  private let scale = BenchScale()

  @objc static func requiresMainQueueSetup() -> Bool { false }

  @objc func readWeight(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    scale.read { result in
      switch result {
      case .success(let reading): resolve(["grams": reading.grams, "stable": reading.stable])
      case .failure(let error): reject("E_SCALE", error.localizedDescription, error)
      }
    }
  }

  @objc func tare(_ resolve: @escaping RCTPromiseResolveBlock, rejecter reject: @escaping RCTPromiseRejectBlock) {
    scale.tare { error in
      if let error {
        reject("E_SCALE", error.localizedDescription, error)
      } else {
        resolve(nil)
      }
    }
  }
}

struct ScaleReading {
  let grams: Int
  let stable: Bool
}

/** The bench scale over BLE: the vendor's weight service, one characteristic for the reading, one for tare. */
final class BenchScale: NSObject, CBCentralManagerDelegate {
  private lazy var central = CBCentralManager(delegate: self, queue: nil)

  func read(_ completion: @escaping (Result<ScaleReading, Error>) -> Void) {
    VendorScale.shared.readWeight(using: central, completion)
  }

  func tare(_ completion: @escaping (Error?) -> Void) {
    VendorScale.shared.tare(using: central, completion)
  }

  func centralManagerDidUpdateState(_ central: CBCentralManager) {}
}
