import Foundation
import SelfProtectKit

@MainActor
class CategoryProvider: ObservableObject {
    @Published var enabledPresets: Set<UUID> = []

    var allSelectedWebsites: [String] {
        PresetData.allPresets
            .filter { enabledPresets.contains($0.id) }
            .flatMap { $0.websites }
    }

    var allSelectedApps: [String: String] {
        PresetData.allPresets
            .filter { enabledPresets.contains($0.id) }
            .reduce(into: [String: String]()) { result, preset in
                for (bundleID, name) in preset.apps {
                    result[bundleID] = name
                }
            }
    }

    func togglePreset(_ preset: BlockPreset) {
        if enabledPresets.contains(preset.id) {
            enabledPresets.remove(preset.id)
        } else {
            enabledPresets.insert(preset.id)
        }
    }

    func isEnabled(_ preset: BlockPreset) -> Bool {
        enabledPresets.contains(preset.id)
    }
}
