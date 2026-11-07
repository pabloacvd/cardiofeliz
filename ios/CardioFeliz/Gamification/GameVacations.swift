import Foundation

/// Períodos de vacaciones y ventana de recuperación.
/// Equivale a `src/gamification/vacations.ts`.

struct VacationStatus: Sendable, Hashable {
    var active: Bool
    var current: VacationPeriod?
    /// Días de vacaciones transcurridos hasta hoy, contando el primero y el de hoy.
    var lengthDays: Int
    /// true cuando las vacaciones activas superan el umbral de aviso.
    var longWarning: Bool
}

struct ComebackStatus: Sendable, Hashable {
    var active: Bool
    /// 1 = primer día de vuelta. 0 cuando no está activo.
    var dayNumber: Int
    /// Días que quedan de ventana, contando hoy.
    var daysLeft: Int
    var endedOn: DateKey?

    static let none = ComebackStatus(active: false, dayNumber: 0, daysLeft: 0, endedOn: nil)
}

enum GameVacations {
    static func isOnVacation(day: DateKey, vacations: [VacationPeriod]) -> Bool {
        vacations.contains { v in
            v.startOn <= day && (v.endOn == nil || day <= v.endOn!)
        }
    }

    /// Cantidad de días de vacaciones entre `from` y `to` (ambos inclusive).
    static func vacationDaysInRange(from: DateKey, to: DateKey, vacations: [VacationPeriod]) -> Int {
        guard from <= to else { return 0 }
        return GameDates.eachDay(from, to).filter { isOnVacation(day: $0, vacations: vacations) }.count
    }

    static func vacationStatus(today: DateKey, vacations: [VacationPeriod]) -> VacationStatus {
        let current = vacations.first { v in
            v.startOn <= today && (v.endOn == nil || today <= v.endOn!)
        }
        guard let current else {
            return VacationStatus(active: false, current: nil, lengthDays: 0, longWarning: false)
        }
        let lengthDays = GameDates.diffDays(today, current.startOn) + 1
        return VacationStatus(
            active: true,
            current: current,
            lengthDays: lengthDays,
            longWarning: lengthDays > GameConfig.Vacation.longWarningDays
        )
    }

    /// Ventana "¡Hay que recuperar!" tras terminar unas vacaciones.
    static func comebackStatus(today: DateKey, vacations: [VacationPeriod]) -> ComebackStatus {
        if isOnVacation(day: today, vacations: vacations) {
            return .none
        }

        let days = GameConfig.Vacation.comebackDays
        var endedOn: DateKey? = nil

        for v in vacations {
            guard let endOn = v.endOn, endOn < today else { continue }
            if today > GameDates.addDays(endOn, days) { continue }
            if endedOn == nil || endOn > endedOn! {
                endedOn = endOn
            }
        }

        guard let endedOn else { return .none }
        let dayNum = GameDates.diffDays(today, endedOn)
        return ComebackStatus(
            active: true,
            dayNumber: dayNum,
            daysLeft: days - dayNum + 1,
            endedOn: endedOn
        )
    }
}
