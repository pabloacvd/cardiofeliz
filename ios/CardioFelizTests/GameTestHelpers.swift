import Foundation
import XCTest

enum GameTestHelpers {
    private static var counter = 0

    static func reset() {
        counter = 0
    }

    static func workout(
        _ day: String,
        durationSeconds: Int = 45 * 60,
        blocksCompleted: Int = 3,
        xpEarned: Int = 100,
        startedAt: Date? = nil,
        distanceKm: Double? = nil,
        feeling: Int? = nil,
        roundsTotal: Int? = nil
    ) -> ActivityRecord {
        counter += 1
        return ActivityRecord(
            id: "w-\(counter)",
            userId: "u-test",
            type: .workoutDay,
            occurredOn: day,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            dayId: "d1",
            blocksCompleted: blocksCompleted,
            roundsTotal: roundsTotal,
            distanceKm: distanceKm,
            runLocation: nil,
            feeling: feeling,
            caloriesKcal: nil,
            xpEarned: xpEarned,
            createdAt: nil
        )
    }

    static func run(
        _ day: String,
        durationSeconds: Int = 30 * 60,
        distanceKm: Double? = nil,
        runLocation: RunLocation? = nil,
        xpEarned: Int = 60,
        startedAt: Date? = nil,
        feeling: Int? = nil
    ) -> ActivityRecord {
        counter += 1
        return ActivityRecord(
            id: "r-\(counter)",
            userId: "u-test",
            type: .run,
            occurredOn: day,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            dayId: nil,
            blocksCompleted: nil,
            roundsTotal: nil,
            distanceKm: distanceKm,
            runLocation: runLocation,
            feeling: feeling,
            caloriesKcal: nil,
            xpEarned: xpEarned,
            createdAt: nil
        )
    }

    static func rest(
        _ day: String,
        durationSeconds: Int = 10 * 60,
        xpEarned: Int = 20,
        startedAt: Date? = nil,
        feeling: Int? = nil
    ) -> ActivityRecord {
        counter += 1
        return ActivityRecord(
            id: "a-\(counter)",
            userId: "u-test",
            type: .activeRest,
            occurredOn: day,
            startedAt: startedAt,
            durationSeconds: durationSeconds,
            dayId: nil,
            blocksCompleted: nil,
            roundsTotal: nil,
            distanceKm: nil,
            runLocation: nil,
            feeling: feeling,
            caloriesKcal: nil,
            xpEarned: xpEarned,
            createdAt: nil
        )
    }

    static func vacation(_ startOn: String, _ endOn: String?) -> VacationPeriod {
        counter += 1
        return VacationPeriod(id: "v-\(counter)", userId: "u-test", startOn: startOn, endOn: endOn, createdAt: nil)
    }

    static func ctx(
        today: String,
        activities: [ActivityRecord] = [],
        vacations: [VacationPeriod] = [],
        weightKg: Double? = nil,
        displayName: String? = nil
    ) -> GameContext {
        GameContext(
            activities: activities,
            vacations: vacations,
            today: today,
            weightKg: weightKg,
            displayName: displayName
        )
    }

    static func activeDays(_ days: [String]) -> [ActivityRecord] {
        days.map { rest($0) }
    }
}
