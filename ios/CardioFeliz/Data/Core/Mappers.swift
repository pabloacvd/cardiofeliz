import Foundation

/// Equivalentes de `toDomain*` / `toDb*` de `src/types/gamification.ts`.
enum Mappers {
    // MARK: Actividades

    static func activity(_ row: ActivityRow) -> ActivityRecord {
        ActivityRecord(
            id: row.id,
            userId: row.userId,
            type: row.type,
            occurredOn: row.occurredOn,
            startedAt: row.startedAt.flatMap(SupabaseDate.parse),
            durationSeconds: row.durationSeconds,
            dayId: row.dayId,
            blocksCompleted: row.blocksCompleted,
            roundsTotal: row.roundsTotal,
            distanceKm: row.distanceKm?.value,
            runLocation: row.runLocation,
            feeling: row.feeling,
            caloriesKcal: row.caloriesKcal?.value,
            xpEarned: row.xpEarned,
            createdAt: SupabaseDate.parse(row.createdAt)
        )
    }

    /// `user_id` es el de la actividad si lo tiene y, si no, el del usuario actual (`domain.userId ?? userId`).
    static func insert(_ a: ActivityRecord, userId: String) -> ActivityInsert {
        ActivityInsert(
            id: a.id,
            userId: a.userId ?? userId,
            type: a.type,
            occurredOn: a.occurredOn,
            startedAt: a.startedAt.map(SupabaseDate.format),
            durationSeconds: a.durationSeconds,
            dayId: a.dayId,
            blocksCompleted: a.blocksCompleted,
            roundsTotal: a.roundsTotal,
            distanceKm: a.distanceKm,
            runLocation: a.runLocation,
            feeling: a.feeling,
            caloriesKcal: a.caloriesKcal,
            xpEarned: a.xpEarned
        )
    }

    // MARK: Perfil

    static func profile(_ row: ProfileRow) -> UserProfile {
        UserProfile(
            userId: row.userId,
            displayName: row.displayName,
            weightKg: row.weightKg?.value,
            createdAt: SupabaseDate.parse(row.createdAt),
            updatedAt: SupabaseDate.parse(row.updatedAt)
        )
    }

    // MARK: Logros

    /// Un logro con fecha ilegible se descarta (no hay fecha de reemplazo razonable).
    static func achievement(_ row: AchievementRow) -> AchievementUnlock? {
        guard let date = SupabaseDate.parse(row.unlockedAt) else { return nil }
        return AchievementUnlock(userId: row.userId, achievementId: row.achievementId, unlockedAt: date)
    }

    static func insert(_ a: AchievementUnlock, userId: String) -> AchievementInsert {
        AchievementInsert(
            userId: a.userId ?? userId,
            achievementId: a.achievementId,
            unlockedAt: SupabaseDate.format(a.unlockedAt)
        )
    }

    // MARK: Vacaciones

    static func vacation(_ row: VacationRow) -> VacationPeriod {
        VacationPeriod(
            id: row.id,
            userId: row.userId,
            startOn: row.startOn,
            endOn: row.endOn,
            createdAt: SupabaseDate.parse(row.createdAt)
        )
    }

    static func insert(_ v: VacationPeriod, userId: String) -> VacationInsert {
        VacationInsert(id: v.id, userId: v.userId ?? userId, startOn: v.startOn, endOn: v.endOn)
    }

    // MARK: Rutina

    static func routine(data: RutinaData, updatedAt: String) -> RemoteRoutine {
        RemoteRoutine(data: data, updatedAt: SupabaseDate.parse(updatedAt))
    }
}
