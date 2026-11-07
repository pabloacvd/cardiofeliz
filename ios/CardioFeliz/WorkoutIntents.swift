import AppIntents
import Foundation

// Botones de la Live Activity. Este archivo se compila en la app y en la widget extension:
// el botón (en la extensión) referencia el tipo, pero `perform()` lo ejecuta el sistema en el
// proceso de la app (`LiveActivityIntent`), donde `TimerManager` registra el manejador.
// En la extensión el manejador es siempre nil.

public enum WorkoutCommand: Equatable {
    case pause
    case resume
    case next
}

public final class WorkoutCommandBus {
    public static let shared = WorkoutCommandBus()
    private init() {}

    /// Lo registra el `TimerManager` con un entrenamiento en curso. Siempre en el hilo principal.
    public var handler: ((WorkoutCommand) -> Void)?

    @MainActor
    func send(_ command: WorkoutCommand) {
        handler?(command)
    }
}

public struct PauseWorkoutIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Pausar entrenamiento"
    public init() {}
    public func perform() async throws -> some IntentResult {
        await WorkoutCommandBus.shared.send(.pause)
        return .result()
    }
}

public struct ResumeWorkoutIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Reanudar entrenamiento"
    public init() {}
    public func perform() async throws -> some IntentResult {
        await WorkoutCommandBus.shared.send(.resume)
        return .result()
    }
}

public struct NextPhaseIntent: LiveActivityIntent {
    public static let title: LocalizedStringResource = "Siguiente fase"
    public init() {}
    public func perform() async throws -> some IntentResult {
        await WorkoutCommandBus.shared.send(.next)
        return .result()
    }
}
