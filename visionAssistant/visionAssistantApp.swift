import SwiftUI
import Combine

@main
struct visionAssistantApp: App {
    @StateObject private var service = InstructionService.shared
    private let overlay = OverlayManager.shared
    private var cancellable: AnyCancellable?

    init() {
        // Start the instruction server and screenpipe health polling
        Task { @MainActor in
            InstructionService.shared.start()
        }

        // Pipe every instruction change into the overlay
        cancellable = InstructionService.shared.$current
            .receive(on: RunLoop.main)
            .sink { instruction in
                OverlayManager.shared.update(with: instruction)
            }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(service)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 900, height: 600)

        Settings {
            SettingsView()
        }
    }
}
