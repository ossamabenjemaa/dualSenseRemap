import Foundation
import Combine

/// The rarely-changing facts about the controller: is it there, what is it
/// called, how full is its battery.
struct ControllerStatus: Equatable {
    var isConnected: Bool = false
    var name: String = ""
    var battery: BatteryStatus = BatteryStatus(level: 0, state: .unknown)
}

/// Low-rate status feed for UI that lives in SwiftUI's *scene* graph — the
/// menu bar extra, the shell header, the onboarding sheet.
///
/// Why this exists: observing `DualSenseManager` directly from a scene-level
/// view makes every snapshot publish invalidate the App graph, and SwiftUI
/// answers that by rebuilding the whole main menu
/// (`AppDelegate.makeMainMenu` → `AppKitMainMenuItem.updateMainMenu` →
/// `FocusViewGraph.init`). Each rebuild allocates AttributeGraph nodes, so a
/// controller streaming at its native report rate grew the AttributeGraph zone
/// without bound until `AG::data::table::grow_region()` hit its precondition
/// and called `abort()` — a hard crash after a few hours of uptime.
///
/// This model republishes only when one of the three facts above actually
/// changes, so an idle (or merely jittering) controller costs the scene graph
/// nothing. Views that genuinely need live stick/touchpad values — the
/// controller page and its tuning cards — still observe `DualSenseManager`,
/// but they only exist while that page is on screen.
final class ControllerStatusModel: ObservableObject {

    static let shared = ControllerStatusModel()

    @Published private(set) var status = ControllerStatus()

    private var cancellable: AnyCancellable?

    private init() {
        cancellable = DualSenseManager.shared.$snapshot
            .map { snapshot in
                ControllerStatus(isConnected: snapshot.isConnected,
                                 name: snapshot.controllerName,
                                 battery: snapshot.battery)
            }
            .removeDuplicates()
            // Hop to the next main-queue turn so the assignment never lands
            // inside the view update that produced it.
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.status = status
            }
    }
}
