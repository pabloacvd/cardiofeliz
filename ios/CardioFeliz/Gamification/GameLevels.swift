import Foundation

/// Sistema de niveles, rangos y etapas de la mascota.
/// Equivale a `src/gamification/levels.ts`.

struct LevelInfo: Sendable, Hashable {
    var level: Int
    var tierName: String
    var totalXp: Int
    /// XP acumulado dentro del nivel actual.
    var xpIntoLevel: Int
    /// XP total que dura el nivel actual.
    var xpForNextLevel: Int
    /// 0 a 1.
    var progress: Double
}

enum GameLevels {
    /// XP acumulado necesario para llegar al nivel `level` (el nivel 1 arranca en 0).
    static func xpForLevel(_ level: Int) -> Int {
        let l = max(1, level)
        return GameConfig.Levels.stepXp * (l - 1) * l
    }

    static func tierNameForLevel(_ level: Int) -> String {
        let tiers = GameConfig.Levels.tiers
        var name = tiers[0].name
        for t in tiers {
            if level >= t.fromLevel {
                name = t.name
            }
        }
        return name
    }

    static func levelFromXp(_ xp: Int) -> LevelInfo {
        let totalXp = max(0, xp)
        let step = Double(GameConfig.Levels.stepXp)

        var level = max(1, Int(floor((1.0 + sqrt(1.0 + (4.0 * Double(totalXp)) / step)) / 2.0)))
        while xpForLevel(level + 1) <= totalXp {
            level += 1
        }
        while level > 1 && xpForLevel(level) > totalXp {
            level -= 1
        }

        let base = xpForLevel(level)
        let xpForNextLevel = xpForLevel(level + 1) - base
        let xpIntoLevel = totalXp - base
        let progress = xpForNextLevel > 0 ? Double(xpIntoLevel) / Double(xpForNextLevel) : 0.0

        return LevelInfo(
            level: level,
            tierName: tierNameForLevel(level),
            totalXp: totalXp,
            xpIntoLevel: xpIntoLevel,
            xpForNextLevel: xpForNextLevel,
            progress: progress
        )
    }

    /// Etapa de la mascota según el nivel.
    static func mascotStage(_ level: Int) -> MascotStageDef {
        let stages = GameConfig.Mascot.stages
        var current = stages[0]
        for s in stages {
            if level >= s.fromLevel {
                current = s
            }
        }
        return current
    }
}
