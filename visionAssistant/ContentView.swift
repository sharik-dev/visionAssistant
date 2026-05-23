import SwiftUI

struct ContentView: View {
    @EnvironmentObject var service: InstructionService
    @State private var selectedSection: Section? = .live

    var body: some View {
        NavigationSplitView {
            List(Section.allCases, id: \.self, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180)

            Divider()

            // Status footer in sidebar
            VStack(alignment: .leading, spacing: 6) {
                StatusRow(
                    label: "Serveur :3131",
                    connected: service.isServerRunning
                )
                StatusRow(
                    label: "Screenpipe :3030",
                    connected: service.screenpipeConnected
                )
            }
            .padding(12)
        } detail: {
            switch selectedSection {
            case .live, .none:
                LiveView()
            case .history:
                HistoryView()
            }
        }
        .navigationTitle("visionAssistant")
    }
}

// MARK: - Sections

enum Section: CaseIterable, Hashable {
    case live, history

    var title: String {
        switch self {
        case .live: "En direct"
        case .history: "Historique"
        }
    }

    var icon: String {
        switch self {
        case .live: "dot.radiowaves.left.and.right"
        case .history: "clock"
        }
    }
}

// MARK: - Live view

struct LiveView: View {
    @EnvironmentObject var service: InstructionService

    var body: some View {
        VStack(spacing: 0) {
            if let current = service.current {
                CurrentInstructionCard(instruction: current)
                    .padding()
                    .transition(.move(edge: .top).combined(with: .opacity))

                Divider()
            }

            if service.history.isEmpty && service.current == nil {
                EmptyStateView()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(service.history) { instruction in
                            HistoryRow(instruction: instruction)
                        }
                    }
                    .padding()
                }
            }
        }
        .animation(.spring(response: 0.3), value: service.current?.id)
    }
}

struct CurrentInstructionCard: View {
    @EnvironmentObject var service: InstructionService
    let instruction: Instruction

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let step = instruction.step {
                Text("\(step)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.orange, in: Circle())
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(instruction.instruction)
                    .font(.system(size: 14, weight: .medium))

                Text("x: \(Int(instruction.x))  y: \(Int(instruction.y))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                withAnimation { service.dismiss() }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(.orange.opacity(0.25), lineWidth: 1))
    }
}

// MARK: - History view

struct HistoryView: View {
    @EnvironmentObject var service: InstructionService

    var body: some View {
        if service.history.isEmpty {
            ContentUnavailableView(
                "Aucun historique",
                systemImage: "clock",
                description: Text("Les instructions reçues apparaîtront ici.")
            )
        } else {
            List(service.history) { instruction in
                HistoryRow(instruction: instruction)
                    .listRowSeparator(.visible)
            }
        }
    }
}

struct HistoryRow: View {
    let instruction: Instruction

    var body: some View {
        HStack(spacing: 10) {
            if let step = instruction.step {
                Text("\(step)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(.orange, in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(instruction.instruction)
                    .font(.system(size: 13))
                    .lineLimit(2)

                Text("(\(Int(instruction.x)), \(Int(instruction.y)))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Shared components

struct EmptyStateView: View {
    @EnvironmentObject var service: InstructionService

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("En attente d'instructions")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("POST http://localhost:3131/instruction\n{\"x\": 100, \"y\": 200, \"instruction\": \"…\", \"step\": 1}")
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct StatusRow: View {
    let label: String
    let connected: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(connected ? Color.green : Color.red.opacity(0.7))
                .frame(width: 7, height: 7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SettingsView: View {
    var body: some View {
        Form {
            LabeledContent("Serveur d'écoute", value: "localhost:3131")
            LabeledContent("Screenpipe backend", value: "localhost:3030")
        }
        .padding()
        .frame(width: 380, height: 160)
    }
}

#Preview {
    ContentView()
        .environmentObject(InstructionService.shared)
        .frame(width: 900, height: 600)
}
