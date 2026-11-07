import Foundation

/// Entrada de progreso de un bloque completado en el día actual (puerto de `src/utils/workoutDay.ts`).
struct BlockProgressEntry: Codable, Equatable, Sendable {
    var date: String
    var completedAt: Date
    var durationSeconds: Int
    var rounds: Int?
    var tipoBloque: TipoBloque
    var bloqueNombre: String
    /// Sesión del Apple Watch que acompañó el bloque, para sumar sus calorías medidas al día.
    var watchSessionId: String?

    init(
        date: String,
        completedAt: Date = Date(),
        durationSeconds: Int,
        rounds: Int? = nil,
        tipoBloque: TipoBloque,
        bloqueNombre: String,
        watchSessionId: String? = nil
    ) {
        self.date = date
        self.completedAt = completedAt
        self.durationSeconds = durationSeconds
        self.rounds = rounds
        self.tipoBloque = tipoBloque
        self.bloqueNombre = bloqueNombre
        self.watchSessionId = watchSessionId
    }
}

enum WorkoutDayProgress {

    /// Genera la clave única de un bloque en el progreso diario: `diaId::blockId`.
    static func blockKey(diaId: String, blockId: String) -> String {
        "\(diaId)::\(blockId)"
    }

    /// Comprueba si todos los bloques del día han sido completados hoy.
    static func isDayFinished(
        dia: DiaEntrenamiento,
        progress: [String: BlockProgressEntry]
    ) -> Bool {
        guard !dia.bloques.isEmpty else { return false }
        return dia.bloques.allSatisfy { bloque in
            guard let blockId = bloque.id else { return false }
            return progress[blockKey(diaId: dia.id, blockId: blockId)] != nil
        }
    }

    /// Construye el `ActivityDraft` final para el día de entrenamiento completado.
    static func buildWorkoutDayActivity(
        dia: DiaEntrenamiento,
        progress: [String: BlockProgressEntry],
        today: String
    ) -> ActivityDraft {
        let entries = dia.bloques.compactMap { bloque -> BlockProgressEntry? in
            guard let blockId = bloque.id else { return nil }
            return progress[blockKey(diaId: dia.id, blockId: blockId)]
        }

        let durationSeconds = entries.reduce(0) { $0 + max(0, $1.durationSeconds) }
        let withRounds = entries.compactMap(\.rounds)
        let roundsTotal = withRounds.isEmpty ? nil : withRounds.reduce(0, +)

        let startTimestamps = entries.map { entry in
            entry.completedAt.addingTimeInterval(-Double(entry.durationSeconds))
        }
        let startedAt = startTimestamps.min()

        return ActivityDraft(
            type: .workoutDay,
            occurredOn: today,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            dayId: dia.id,
            blocksCompleted: entries.count,
            roundsTotal: roundsTotal
        )
    }

    /// Bloques del día, en orden, para sumar las calorías medidas por el Watch.
    static func watchBlocks(
        dia: DiaEntrenamiento,
        progress: [String: BlockProgressEntry]
    ) -> [WatchCalories.Block] {
        dia.bloques.compactMap { bloque in
            guard let blockId = bloque.id, let entry = progress[blockKey(diaId: dia.id, blockId: blockId)] else {
                return nil
            }
            return WatchCalories.Block(durationSeconds: max(0, entry.durationSeconds), sessionId: entry.watchSessionId)
        }
    }

    /// Días de entrenamiento completados en la semana: 'today' si fue hoy, 'week' si fue antes.
    static func weekCompletedDays(
        activities: [ActivityRecord],
        today: String,
        weekStart: String
    ) -> [String: String] {
        var out: [String: String] = [:]
        for a in activities {
            guard a.type == .workoutDay, let dayId = a.dayId else { continue }
            guard a.occurredOn >= weekStart && a.occurredOn <= today else { continue }
            if a.occurredOn == today {
                out[dayId] = "today"
            } else if out[dayId] != "today" {
                out[dayId] = "week"
            }
        }
        return out
    }
}
