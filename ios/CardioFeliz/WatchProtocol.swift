import Foundation

// Protocolo iPhone <-> Watch. Solo Foundation: se compila en la app iOS, en el Watch y en los tests.
//
// Reglas:
// - El iPhone es el dueño del reloj de entrenamiento. Envía un estado COMPLETO con fechas absolutas
//   (`WatchWorkoutState`); el Watch deriva fase y tiempo restante de esas fechas, no cuenta por su cuenta.
// - Ese estado viaja por `updateApplicationContext` (el último gana, sirve para arranques tardíos) y,
//   si el Watch está al alcance, también por `sendMessage` (inmediato).
// - Los comandos del Watch (`WatchCommand`) viajan SOLO por `sendMessage` con respuesta. Nunca por
//   contexto ni por cola: un "stop" o "next" reentregado más tarde sería un comando fantasma.
// - Al terminar la sesión de Salud el Watch envía un `WatchSummary` por `transferUserInfo` (cola con
//   entrega garantizada, aunque el iPhone no esté cerca en ese momento).

/// Comandos que el Watch puede pedir al iPhone sobre el entrenamiento EN CURSO. No existe "start": el plan
/// (qué bloque, qué fases) lo elige el usuario en el iPhone, así que el Watch no puede arrancar uno.
public enum WatchCommand: String, Codable, CaseIterable {
    case pause
    case resume
    case next
    case stop
}

public enum WatchMessageKey {
    public static let state = "state"
    public static let command = "command"
    public static let summary = "summary"
    /// Clave de la respuesta a un comando: Bool.
    public static let accepted = "accepted"
}

// MARK: - Estado

public struct WatchWorkoutState: Codable, Equatable {
    /// Un entrenamiento (un bloque) = una sesión. El Watch abre una `HKWorkoutSession` por sesión.
    public var sessionId: String
    public var title: String
    public var phases: [WorkoutPhase]
    public var startDates: [Date]
    public var endDates: [Date]
    public var currentPhaseIndex: Int
    /// true mientras el reloj está en marcha o en pausa. false = terminó (o no hay nada en curso).
    public var isRunning: Bool
    public var isPaused: Bool
    public var pausedAt: Date?
    /// Instante de envío (reloj del iPhone). Sirve para descartar estados más viejos que el ya recibido.
    public var sentAt: Date

    public init(
        sessionId: String,
        title: String,
        phases: [WorkoutPhase],
        startDates: [Date],
        endDates: [Date],
        currentPhaseIndex: Int,
        isRunning: Bool,
        isPaused: Bool,
        pausedAt: Date?,
        sentAt: Date
    ) {
        self.sessionId = sessionId
        self.title = title
        self.phases = phases
        self.startDates = startDates
        self.endDates = endDates
        self.currentPhaseIndex = currentPhaseIndex
        self.isRunning = isRunning
        self.isPaused = isPaused
        self.pausedAt = pausedAt
        self.sentAt = sentAt
    }

    /// Sin entrenamiento. `sentAt` en el pasado remoto para que cualquier estado real lo reemplace.
    public static func idle(sentAt: Date = .distantPast) -> WatchWorkoutState {
        WatchWorkoutState(
            sessionId: "", title: "", phases: [], startDates: [], endDates: [],
            currentPhaseIndex: 0, isRunning: false, isPaused: false, pausedAt: nil, sentAt: sentAt
        )
    }

    /// La sesión `sessionId` terminó. Conserva el id para que el Watch cierre justo esa sesión de Salud
    /// y no otra.
    public static func finished(sessionId: String, title: String, sentAt: Date) -> WatchWorkoutState {
        WatchWorkoutState(
            sessionId: sessionId, title: title, phases: [], startDates: [], endDates: [],
            currentPhaseIndex: 0, isRunning: false, isPaused: false, pausedAt: nil, sentAt: sentAt
        )
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(WatchWorkoutState.self, from: data)
    }

    /// Coherencia mínima de las fechas con las fases. Un estado incoherente se descarta.
    public var isWellFormed: Bool {
        phases.count == startDates.count && phases.count == endDates.count
            && (phases.isEmpty || phases.indices.contains(currentPhaseIndex))
    }

    // MARK: Fin planificado y vigencia

    /// Fin conocido del entrenamiento si no queda ninguna fase manual por delante; nil si no se sabe.
    public var plannedEnd: Date? {
        guard isRunning, isWellFormed, !phases.isEmpty else { return nil }
        for i in currentPhaseIndex..<phases.count where phases[i].isManual { return nil }
        return endDates.last
    }

    /// Margen tras el fin planificado antes de dar el estado por abandonado (el iPhone confirma el fin
    /// en milisegundos; esto solo actúa si el iPhone dejó de responder).
    public static let endGrace: TimeInterval = 10
    /// Antigüedad máxima de un estado en pausa o con fases manuales por delante.
    public static let maxAge: TimeInterval = 3 * 3600

    /// ¿El Watch debe dar por muerto este "en curso"? Cubre un iPhone cerrado o sin alcance durante el
    /// entrenamiento: sin esto, el Watch conservaría un contexto viejo y abriría una sesión de Salud fantasma.
    public func isStale(at now: Date) -> Bool {
        guard isRunning else { return false }
        if !isPaused, let end = plannedEnd {
            return now > end.addingTimeInterval(Self.endGrace)
        }
        return now.timeIntervalSince(sentAt) > Self.maxAge
    }
}

// MARK: - Lo que muestra el Watch

public struct WatchDisplay: Equatable {
    public enum Mode: Equatable {
        case idle
        case running
        case paused
        /// El tiempo planificado se agotó (a la espera de que el iPhone lo confirme).
        case finished
    }

    public var mode: Mode
    public var phaseIndex: Int
    public var phase: WorkoutPhase?
    /// Segundos a mostrar: restantes, o transcurridos si `showsElapsed`.
    public var seconds: Int
    public var showsElapsed: Bool
    public var isManual: Bool
    /// 3, 2 o 1 cuando la cuenta regresiva está en sus últimos segundos.
    public var countdownSecond: Int?
    /// 0...1 de la fase actual.
    public var progress: Double

    public static let idle = WatchDisplay(
        mode: .idle, phaseIndex: 0, phase: nil, seconds: 0, showsElapsed: false,
        isManual: false, countdownSecond: nil, progress: 0
    )
}

public extension WatchWorkoutState {
    /// Segundos de cuenta regresiva con tic, como `WorkoutPlan.countdownTickSeconds` del iPhone.
    static let countdownSeconds = [3, 2, 1]

    /// Fase y tiempo a mostrar en `now`, derivados de las fechas absolutas. Si pasó el fin de la fase
    /// actual sin que llegara el estado siguiente (iPhone ocupado o lejos), avanza solo hasta una fase
    /// manual (cuyo fin no se conoce) o hasta agotar el plan, igual que `WorkoutClock.tick`.
    func display(at now: Date) -> WatchDisplay {
        guard isRunning, isWellFormed, !phases.isEmpty else { return .idle }

        let reference = isPaused ? (pausedAt ?? sentAt) : now
        var index = currentPhaseIndex
        var finished = false

        if !isPaused {
            while !phases[index].isManual && reference >= endDates[index] {
                if index == phases.count - 1 { finished = true; break }
                index += 1
            }
        }

        let phase = phases[index]
        let elapsed = max(0, reference.timeIntervalSince(startDates[index]))
        let remaining = phase.isManual ? 0 : max(0, endDates[index].timeIntervalSince(reference))
        let showsElapsed = phase.isManual || phase.countsUp

        let seconds: Int
        if finished { seconds = 0 }
        else if showsElapsed { seconds = Int(elapsed) }
        else { seconds = Int(ceil(remaining)) }

        var countdown: Int?
        if !isPaused, !finished, !showsElapsed {
            let s = Int(ceil(remaining))
            if Self.countdownSeconds.contains(s), Double(s) < phase.duration { countdown = s }
        }

        var progress = 0.0
        if !phase.isManual, phase.duration > 0 {
            progress = showsElapsed ? elapsed / phase.duration : 1 - remaining / phase.duration
            progress = min(1, max(0, progress))
        }

        return WatchDisplay(
            mode: finished ? .finished : (isPaused ? .paused : .running),
            phaseIndex: index,
            phase: phase,
            seconds: seconds,
            showsElapsed: showsElapsed,
            isManual: phase.isManual,
            countdownSecond: countdown,
            progress: progress
        )
    }
}

// MARK: - Resumen de Salud

public struct WatchSummary: Codable, Equatable {
    public var sessionId: String
    public var startedAt: Date
    public var endedAt: Date
    /// nil si no se midió (sin permiso o sin muestras).
    public var averageHeartRate: Double?
    public var activeCalories: Double?
    public var savedToHealth: Bool

    public init(
        sessionId: String,
        startedAt: Date,
        endedAt: Date,
        averageHeartRate: Double?,
        activeCalories: Double?,
        savedToHealth: Bool
    ) {
        self.sessionId = sessionId
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.averageHeartRate = averageHeartRate
        self.activeCalories = activeCalories
        self.savedToHealth = savedToHealth
    }

    public func encoded() throws -> Data { try JSONEncoder().encode(self) }

    public init(data: Data) throws {
        self = try JSONDecoder().decode(WatchSummary.self, from: data)
    }
}

// MARK: - Vibraciones

public enum WatchHapticEvent: Equatable {
    case phaseStart(PhaseKind)
    case countdown(Int)
    case finished
}

/// Decide cuándo vibrar a partir de lo que muestra el Watch. Puro: el Watch mapea cada evento a un
/// `WKHapticType`. No vibra al abrir una sesión nueva (la línea base se toma sin evento) ni mientras
/// está en pausa.
public struct WatchHapticTracker {
    private var sessionId: String?
    private var lastPhaseIndex: Int?
    private var lastTick: (phase: Int, second: Int)?
    private var finishedFired = false

    public init() {}

    public mutating func update(state: WatchWorkoutState, display: WatchDisplay) -> [WatchHapticEvent] {
        if state.sessionId != sessionId {
            sessionId = state.sessionId
            lastPhaseIndex = state.isRunning ? display.phaseIndex : nil
            lastTick = nil
            finishedFired = false
            return []
        }

        var events: [WatchHapticEvent] = []

        // Fin: o el iPhone confirmó que terminó, o el tiempo planificado se agotó.
        if !state.isRunning || display.mode == .finished {
            if lastPhaseIndex != nil, !finishedFired {
                finishedFired = true
                events.append(.finished)
            }
            lastPhaseIndex = nil
            return events
        }

        if let previous = lastPhaseIndex, display.phaseIndex != previous, let phase = display.phase {
            events.append(.phaseStart(phase.kind))
            lastTick = nil
        }
        lastPhaseIndex = display.phaseIndex

        if display.mode == .running, let second = display.countdownSecond {
            if lastTick?.phase != display.phaseIndex || lastTick?.second != second {
                lastTick = (display.phaseIndex, second)
                events.append(.countdown(second))
            }
        }
        return events
    }
}
