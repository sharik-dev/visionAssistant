import Foundation

struct Instruction: Codable, Identifiable, Equatable {
    var id: UUID
    var x: Double
    var y: Double
    var instruction: String
    var step: Int?
    /// Index 0-based dans NSScreen.screens. nil ou hors-bornes → écran principal.
    var monitor: Int?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(UUID.self, forKey: .id)) ?? UUID()
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        instruction = try c.decode(String.self, forKey: .instruction)
        step = try? c.decode(Int.self, forKey: .step)
        monitor = try? c.decode(Int.self, forKey: .monitor)
    }

    enum CodingKeys: String, CodingKey {
        case id, x, y, instruction, step, monitor
    }
}
