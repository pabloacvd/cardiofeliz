import Foundation

/// Estimación pura de calorías metabólicas basada en las reglas de CardioFeliz (`src/gamification/calories.ts` y `config.ts`).
public enum CaloriesEstimator {

    public static let weightMinKg: Double = 20.0
    public static let weightMaxKg: Double = 300.0

    public static let metWorkout: Double = 8.0
    public static let metActiveRest: Double = 3.0
    public static let metRunDefault: Double = 8.3
    public static let maxPlausibleRunSpeedKmh: Double = 25.0

    public struct RunMetPoint: Equatable, Sendable {
        public let speedKmh: Double
        public let met: Double

        public init(speedKmh: Double, met: Double) {
            self.speedKmh = speedKmh
            self.met = met
        }
    }

    public static let runTable: [RunMetPoint] = [
        RunMetPoint(speedKmh: 4.0, met: 3.5),
        RunMetPoint(speedKmh: 6.4, met: 6.0),
        RunMetPoint(speedKmh: 8.0, met: 8.3),
        RunMetPoint(speedKmh: 9.7, met: 9.8),
        RunMetPoint(speedKmh: 11.3, met: 11.0),
        RunMetPoint(speedKmh: 12.9, met: 11.8),
        RunMetPoint(speedKmh: 14.5, met: 12.8),
        RunMetPoint(speedKmh: 16.1, met: 14.5)
    ]

    /// Devuelve el peso si es válido (entre 20 y 300 kg); si no, nil.
    public static func sanitizeWeight(_ weightKg: Double?) -> Double? {
        guard let weight = weightKg, weight.isFinite else { return nil }
        guard weight >= weightMinKg && weight <= weightMaxKg else { return nil }
        return weight
    }

    /// MET de una corrida. Con distancia y duración se interpola linealmente por velocidad;
    /// si falta alguna o la velocidad es inverosímil, se usa el valor por defecto.
    public static func metForRun(distanceKm: Double?, minutes: Double) -> Double {
        guard let distance = distanceKm, distance.isFinite, distance > 0, minutes.isFinite, minutes > 0 else {
            return metRunDefault
        }

        let speed = distance / (minutes / 60.0)
        if speed < 2.0 || speed > maxPlausibleRunSpeedKmh {
            return metRunDefault
        }
        if speed <= runTable[0].speedKmh {
            return runTable[0].met
        }
        let last = runTable[runTable.count - 1]
        if speed >= last.speedKmh {
            return last.met
        }

        for i in 1..<runTable.count {
            let lo = runTable[i - 1]
            let hi = runTable[i]
            if speed <= hi.speedKmh {
                let t = (speed - lo.speedKmh) / (hi.speedKmh - lo.speedKmh)
                return lo.met + t * (hi.met - lo.met)
            }
        }

        return metRunDefault
    }

    /// Estimación de calorías = MET × peso (kg) × horas. Devuelve nil si falta un peso válido.
    public static func estimateCalories(
        type: ActivityType,
        durationSeconds: Int,
        distanceKm: Double? = nil,
        weightKg: Double?
    ) -> Double? {
        guard let weight = sanitizeWeight(weightKg) else { return nil }

        let seconds = max(0, durationSeconds)
        guard seconds > 0 else { return 0 }

        let hours = Double(seconds) / 3600.0
        let minutes = Double(seconds) / 60.0

        let met: Double
        switch type {
        case .run:
            met = metForRun(distanceKm: distanceKm, minutes: minutes)
        case .activeRest:
            met = metActiveRest
        case .workoutDay:
            met = metWorkout
        }

        return (met * weight * hours).rounded()
    }
}
