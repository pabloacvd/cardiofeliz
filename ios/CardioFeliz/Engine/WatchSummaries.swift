import Foundation
import Combine

// Resúmenes de Salud que el Apple Watch envía al terminar cada sesión, y su uso para las calorías del día.
//
// Las calorías medidas por el Watch (energía activa de HealthKit) reemplazan a la estimación por MET.
// La frecuencia cardíaca media se guarda en `cf_activities.avg_heart_rate_bpm` (ver
// `supabase/migrations/cf_activities_avg_heart_rate.sql`).

/// Resúmenes recibidos del Watch, por `sessionId`. Se guardan en `UserDefaults` para no perder las
/// calorías y el pulso medidos si la app se reinicia entre el fin de la sesión y la llegada del resumen.
/// Sin `defaults` (los tests) viven solo en memoria.
@MainActor
final class WatchSummaryStore: ObservableObject {
    static let shared = WatchSummaryStore(defaults: .standard)
    static let defaultsKey = "cf.watch.summaries.v1"

    @Published private(set) var summaries: [String: WatchSummary] = [:]

    private let limit: Int
    private let defaults: UserDefaults?

    init(limit: Int = 50, defaults: UserDefaults? = nil) {
        self.limit = limit
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.defaultsKey),
           let stored = try? JSONDecoder().decode([WatchSummary].self, from: data) {
            // Se vuelve a validar al cargar: el valor guardado pudo corromperse.
            for summary in stored { record(summary, persist: false) }
        }
    }

    /// Valores fuera de rango (datos corruptos o manipulados) se descartan en vez de guardarse.
    func record(_ summary: WatchSummary) {
        record(summary, persist: true)
    }

    private func record(_ summary: WatchSummary, persist: Bool) {
        guard !summary.sessionId.isEmpty else { return }
        var clean = summary
        clean.activeCalories = Self.valid(summary.activeCalories, in: 0...50_000)
        clean.averageHeartRate = Self.valid(summary.averageHeartRate, in: 20...260)
        summaries[clean.sessionId] = clean

        if summaries.count > limit {
            let oldest = summaries.values.sorted { $0.endedAt < $1.endedAt }.prefix(summaries.count - limit)
            for item in oldest { summaries.removeValue(forKey: item.sessionId) }
        }
        if persist { save() }
    }

    private func save() {
        guard let defaults else { return }
        if let data = try? JSONEncoder().encode(Array(summaries.values)) {
            defaults.set(data, forKey: Self.defaultsKey)
        }
    }

    private static func valid(_ value: Double?, in range: ClosedRange<Double>) -> Double? {
        guard let value, value.isFinite, range.contains(value) else { return nil }
        return value
    }
}

enum WatchHeartRate {
    /// Pulso medio del día: promedio de los bloques con medición, ponderado por su duración. nil si ningún
    /// bloque tiene pulso. Los bloques sin Watch no cuentan (no se inventa un valor para ellos).
    static func dayAverage(blocks: [WatchCalories.Block], summaries: [String: WatchSummary]) -> Int? {
        var weighted = 0.0
        var seconds = 0.0
        for block in blocks {
            guard let id = block.sessionId, let bpm = summaries[id]?.averageHeartRate else { continue }
            let weight = Double(max(1, block.durationSeconds))
            weighted += bpm * weight
            seconds += weight
        }
        guard seconds > 0 else { return nil }
        let average = Int((weighted / seconds).rounded())
        return ActivityValidation.heartRateRange.contains(average) ? average : nil
    }
}

enum WatchCalories {
    struct Block: Equatable, Codable {
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
