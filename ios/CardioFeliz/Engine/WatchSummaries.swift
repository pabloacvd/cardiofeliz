import Foundation
import Combine

// Resúmenes de Salud que el Apple Watch envía al terminar cada sesión, y su uso para las calorías del día.
//
// Las calorías medidas por el Watch (energía activa de HealthKit) reemplazan a la estimación por MET.
// La frecuencia cardíaca media solo se conserva en memoria: el esquema de Supabase no tiene columna para
// ella y no se inventa una (ver `supabase/schema.sql`).

/// Resúmenes recibidos del Watch, por `sessionId`. En memoria: la sesión de progreso del día
/// (`WorkoutWorkflowViewModel.blockProgress`) tampoco se persiste, así que no hay a qué aplicarlos tras
/// un reinicio de la app.
@MainActor
final class WatchSummaryStore: ObservableObject {
    static let shared = WatchSummaryStore()

    @Published private(set) var summaries: [String: WatchSummary] = [:]

    private let limit: Int

    init(limit: Int = 50) {
        self.limit = limit
    }

    /// Valores fuera de rango (datos corruptos o manipulados) se descartan en vez de guardarse.
    func record(_ summary: WatchSummary) {
        guard !summary.sessionId.isEmpty else { return }
        var clean = summary
        clean.activeCalories = Self.valid(summary.activeCalories, in: 0...50_000)
        clean.averageHeartRate = Self.valid(summary.averageHeartRate, in: 20...260)
        summaries[clean.sessionId] = clean

        if summaries.count > limit {
            let oldest = summaries.values.sorted { $0.endedAt < $1.endedAt }.prefix(summaries.count - limit)
            for item in oldest { summaries.removeValue(forKey: item.sessionId) }
        }
    }

    private static func valid(_ value: Double?, in range: ClosedRange<Double>) -> Double? {
        guard let value, value.isFinite, range.contains(value) else { return nil }
        return value
    }
}

enum WatchCalories {
    struct Block: Equatable {
        var durationSeconds: Int
        /// Sesión del Watch que cubrió este bloque; nil si el Watch no participó.
        var sessionId: String?
    }

    /// Calorías del día: las medidas por el Watch donde hay resumen, y la estimación por MET (con el peso)
    /// en los bloques que no tienen medición. nil si ningún bloque tiene calorías medidas: en ese caso se
    /// conserva la estimación original de la actividad.
    ///
    /// La energía activa del Watch no incluye el gasto en reposo, mientras que MET × peso × horas sí;
    /// por eso una cifra medida suele ser menor que la estimada. Es esperable, no un error.
    static func dayTotal(blocks: [Block], summaries: [String: WatchSummary], weightKg: Double?) -> Double? {
        var measuredAny = false
        var total = 0.0
        for block in blocks {
            if let id = block.sessionId, let kcal = summaries[id]?.activeCalories {
                measuredAny = true
                total += kcal
            } else if let estimate = CaloriesEstimator.estimateCalories(
                type: .workoutDay, durationSeconds: block.durationSeconds, weightKg: weightKg
            ) {
                total += estimate
            }
        }
        return measuredAny ? total.rounded() : nil
    }
}
