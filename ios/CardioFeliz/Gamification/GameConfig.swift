import Foundation

/// Reglas numéricas del juego (metas, XP, niveles, calorías, umbrales).
/// Equivale a `src/gamification/config.ts`.
struct RunMetPoint: Sendable, Hashable {
    let speedKmh: Double
    let met: Double
}

struct LevelTier: Sendable, Hashable {
    let fromLevel: Int
    let name: String
}

struct MascotStageDef: Sendable, Hashable {
    let stage: Int
    let fromLevel: Int
    let name: String
    let catchphrase: String
}

enum GameConfig {
    /// Meta semanal base (lunes a domingo).
    enum WeeklyGoal {
        static let workouts = 3
        static let runs = 2
    }

    /// Duración por defecto de "Hoy corrí" en minutos.
    static let defaultRunMinutes = 30

    enum Streak {
        /// Se gana 1 congelador cada N días de racha.
        static let freezeEvery = 5
        static let maxFreezes = 2
        /// XP único por alcanzar cada hito de racha.
        static let milestoneBonusXp: [Int: Int] = [
            3: 20,
            7: 50,
            14: 100,
            30: 200,
            60: 400,
            100: 800
        ]
    }

    enum Week {
        /// Una semana con al menos esta cantidad de días de vacaciones queda "pausada".
        static let vacationPauseMinDays = 4
    }

    enum Vacation {
        /// Se avisa cuando las vacaciones superan esta cantidad de días.
        static let longWarningDays = 30
        /// Días de "¡Hay que recuperar!" después de volver.
        static let comebackDays = 3
        static let comebackXpMultiplier = 1.5
    }

    enum Xp {
        static let workoutDay = 100
        static let baseBlocks = 3
        static let extraBlock = 10
        static let run = 60
        static let runBaseMinutes = 30
        static let runStepMinutes = 5
        static let runMaxTimeBonus = 20
        static let runKmBonus = 10
        static let activeRest = 20
        static let perfectWeek = 150
        static let challenge = 80
        static let allMissionsBonus = 20
    }

    enum Levels {
        /// XP acumulado para llegar al nivel L = stepXp * (L - 1) * L.
        static let stepXp = 50
        static let tiers: [LevelTier] = [
            LevelTier(fromLevel: 1, name: "Calentando motores"),
            LevelTier(fromLevel: 3, name: "En ritmo"),
            LevelTier(fromLevel: 6, name: "Constante"),
            LevelTier(fromLevel: 10, name: "Imparable"),
            LevelTier(fromLevel: 15, name: "Atleta"),
            LevelTier(fromLevel: 20, name: "Élite"),
            LevelTier(fromLevel: 30, name: "Leyenda")
        ]
    }

    enum Mascot {
        static let stages: [MascotStageDef] = [
            MascotStageDef(stage: 1, fromLevel: 1, name: "Brasita", catchphrase: "¡Chispa!"),
            MascotStageDef(stage: 2, fromLevel: 4, name: "Llamita", catchphrase: "¡A prender!"),
            MascotStageDef(stage: 3, fromLevel: 8, name: "Fueguito", catchphrase: "¡Arde!"),
            MascotStageDef(stage: 4, fromLevel: 14, name: "Fogata", catchphrase: "¡Imparable!"),
            MascotStageDef(stage: 5, fromLevel: 22, name: "Fénix", catchphrase: "¡Renazco más fuerte!")
        ]
    }

    enum Calories {
        static let weightMinKg: Double = 20
        static let weightMaxKg: Double = 300
        enum Met {
            static let workout: Double = 8.0
            static let activeRest: Double = 3.0
            static let runDefault: Double = 8.3
            static let maxPlausibleRunSpeedKmh: Double = 25.0
        }
        static let runTable: [RunMetPoint] = [
            RunMetPoint(speedKmh: 4.0, met: 3.5),
            RunMetPoint(speedKmh: 6.4, met: 6.0),
            RunMetPoint(speedKmh: 8.0, met: 8.3),
            RunMetPoint(speedKmh: 9.7, met: 9.8),
            RunMetPoint(speedKmh: 11.3, met: 11.0),
            RunMetPoint(speedKmh: 12.9, met: 11.8),
            RunMetPoint(speedKmh: 14.5, met: 12.8),
            RunMetPoint(speedKmh: 16.1, met: 14.5)
        ]
    }

    enum Coach {
        /// Días completos sin actividad para el mensaje "te extrañamos".
        static let lapseDays = 4
    }

    enum Achievements {
        /// "Madrugadora": actividad iniciada antes de esta hora local.
        static let earlyBirdBeforeHour = 8
        /// "Volví": días sin actividad antes de retomar.
        static let comebackGapDays = 7
    }

    enum Challenges {
        /// "Antes del mediodía".
        static let morningBeforeHour = 12
    }
}
