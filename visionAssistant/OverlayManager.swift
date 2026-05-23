import AppKit
import SwiftUI

/// Manages a transparent floating NSPanel that displays a visual instruction
/// indicator on top of all other windows.
@MainActor
final class OverlayManager {
    static let shared = OverlayManager()

    private var panel: NSPanel?
    private var hostingView: NSHostingView<AnyView>?

    func update(with instruction: Instruction?) {
        guard let instruction else {
            hide()
            return
        }
        show(instruction)
    }

    private func show(_ instruction: Instruction) {
        let screen = NSScreen.main ?? NSScreen.screens[0]

        if panel == nil {
            let p = NSPanel(
                contentRect: screen.frame,
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            p.level = .floating
            p.isOpaque = false
            p.backgroundColor = .clear
            p.ignoresMouseEvents = true
            p.hasShadow = false
            p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel = p
        }

        let view = AnyView(OverlayContentView(instruction: instruction, screenSize: screen.frame.size))
        if let existing = hostingView {
            existing.rootView = view
        } else {
            let hv = NSHostingView(rootView: view)
            hv.frame = CGRect(origin: .zero, size: screen.frame.size)
            panel?.contentView = hv
            hostingView = hv
        }

        panel?.setFrame(screen.frame, display: true)
        panel?.orderFront(nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

// MARK: - SwiftUI overlay views

private struct OverlayContentView: View {
    let instruction: Instruction
    let screenSize: CGSize

    @State private var pulse = false
    @State private var appeared = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.clear

            // Pulsing target indicator
            ZStack {
                Circle()
                    .stroke(Color.orange.opacity(0.35), lineWidth: 2)
                    .frame(width: pulse ? 52 : 30, height: pulse ? 52 : 30)
                    .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)

                Circle()
                    .fill(Color.orange)
                    .frame(width: 14, height: 14)

                Circle()
                    .fill(Color.white.opacity(0.7))
                    .frame(width: 5, height: 5)
            }
            .position(dotPosition)

            // Instruction bubble
            InstructionBubble(instruction: instruction)
                .position(bubblePosition)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(appeared ? 1 : 0.85, anchor: .bottom)
                .animation(.spring(response: 0.28, dampingFraction: 0.7), value: appeared)
        }
        .frame(width: screenSize.width, height: screenSize.height)
        .onAppear {
            pulse = true
            withAnimation { appeared = true }
        }
        .onChange(of: instruction.id) {
            appeared = false
            withAnimation(.spring(response: 0.28)) { appeared = true }
        }
    }

    // screenpipe gives top-left origin coordinates — SwiftUI also uses top-left, so no flip needed.
    private var dotPosition: CGPoint {
        CGPoint(x: instruction.x, y: instruction.y)
    }

    private var bubblePosition: CGPoint {
        // Keep bubble inside screen bounds
        let bx = min(max(dotPosition.x, 150), screenSize.width - 150)
        // Place bubble above dot when possible, below if too close to top
        let by = dotPosition.y > 90 ? dotPosition.y - 60 : dotPosition.y + 60
        return CGPoint(x: bx, y: by)
    }
}

private struct InstructionBubble: View {
    let instruction: Instruction

    var body: some View {
        HStack(spacing: 10) {
            if let step = instruction.step {
                Text("\(step)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.orange, in: Circle())
            }

            Text(instruction.instruction)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(.labelColor))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
        .frame(maxWidth: 280, alignment: .leading)
    }
}
