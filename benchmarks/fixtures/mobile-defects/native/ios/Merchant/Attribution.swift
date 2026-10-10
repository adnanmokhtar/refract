import AdSupport
import Foundation

/// Reports the install to the agency that runs the merchant-recruitment campaign.
enum Attribution {
  static func reportInstall() {
    let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    Task {
      try? await StoreAPI.shared.post("/merchant/installs", body: ["idfa": idfa, "campaign": "spring-onboarding"])
    }
  }
}
