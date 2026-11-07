import Foundation

// Motor de temporizador basado en fechas absolutas. Reemplaza a los seis timers de React
// (que usan `setInterval` de 1 s y contadores) por un modelo donde cada fase tiene un inicio y
// un fin como `Date`. La fase actual, el tiempo restante y el progreso se derivan de la hora
// que se le pasa; nada depende de que un timer siga vivo (segundo plano, Live Activity, Watch).
//
// Es un `struct` puro: sin sonido, notificaciones, ActivityKit ni WatchConnectivity.
// Los efectos secundarios los aplica `TimerManager` a partir de los `ClockEvent` devueltos.
// Solo Foundation, por lo que también puede compilarse en watchOS.
//
// Fechas de fases manuales: no tienen fin conocido. Para mantener `startDates`/`endDates`
// del mismo largo que `plan.phases` (el Watch y la Live Activity del prototipo los reciben como
// `[Date]`), su `endDate` vale lo mismo que su `startDate`. Los consumidores deben mirar
// `phase.isManual`. Al pasar de una fase manual a la siguiente, las fechas posteriores se
// reanclan a ese instante.

public enum ClockState: String, Codable, Hashable {
    case idle
    case running
    case paused
    case finished
}

public enum PhaseChangeCause: String, Codable, Hashable {
    /// El tiempo de la fase se agotó.
    case elapsed
    /// El usuario saltó la fase o confirmó un paso manual ("Siguiente", "Listo", "Saltar descanso").
    case user
}

public enum FinishReason: String, Codable, Hashable {
    /// Se agotó la última fase, o el usuario avanzó más allá de ella.
    case completed
    /// El usuario terminó antes ("Terminar Bloque", "¡TERMINÉ!", detener).
    case finishedEarly
}

public enum ClockEvent: Equatable {
    case started
    case paused
    case resumed
    case phaseChanged(from: Int, to: Int, cause: PhaseChangeCause)
    /// Tic de cuenta regresiva: quedan 3, 2 o 1 segundos de la fase `phase`.
    case countdownTick(phase: Int, secondsLeft: Int)
    case finished(FinishReason)
}

public struct WorkoutResult: Codable, Equatable {
    /// Tiempo activo en segundos (sin pausas). Es lo que la PWA llama `totalSeconds`.
    public let elapsedSeconds: Int
    public let reason: FinishReason
    /// Fases que llegaron a terminar (la que estaba en curso al finalizar no cuenta salvo `.completed`).
    public let phasesCompleted: Int
}

/// Estado serializable del reloj, para el Watch, la Live Activity o para restaurar tras un cierre.
public struct ClockSnapshot: Codable, Equatable {
    public var title: String
    public var phases: [WorkoutPhase]
    public var startDates: [Date]
    public var endDates: [Date]
    public var currentPhaseIndex: Int
    public var state: ClockState
    public var startedAt: Date?
    public var pausedAt: Date?
    public var pausedTotal: TimeInterval
}

public struct WorkoutClock: Equatable {
    public let plan: WorkoutPlan
    public private(set) var state: ClockState = .idle
    public private(set) var currentIndex: Int = 0
    public private(set) var startDates: [Date] = []
    public private(set) var endDates: [Date] = []
    public private(set) var startedAt: Date?
    public private(set) var pausedAt: Date?
    /// Suma de las pausas ya reanudadas.
    public private(set) var pausedTotal: TimeInterval = 0
    public private(set) var finishedAt: Date?
    public private(set) var finishReason: FinishReason?

    private var firedTicks: Set<Int> = []

    public init(plan: WorkoutPlan) {
        self.plan = plan
    }

    // MARK: Consulta

    public var currentPhase: WorkoutPhase? {
        guard state != .idle, plan.phases.indices.contains(currentIndex) else { return nil }
        return plan.phases[currentIndex]
    }

    public var isActive: Bool { state == .running || state == .paused }

    /// Segundos restantes de la fase actual. nil si no hay fase en curso o es manual.
    /// En pausa queda congelado en el instante de la pausa.
    public func timeRemainingInCurrentPhase(at now: Date = Date()) -> TimeInterval? {
        guard isActive, let phase = currentPhase, !phase.isManual else { return nil }
        let reference = (state == .paused ? pausedAt : nil) ?? now
        return max(0, endDates[currentIndex].timeIntervalSince(reference))
    }

    /// Segundos transcurridos en la fase actual (para el cronómetro de FOR_TIME y los pasos manuales).
    public func elapsedInCurrentPhase(at now: Date = Date()) -> TimeInterval {
        guard isActive, startDates.indices.contains(currentIndex) else { return 0 }
        let reference = (state == .paused ? pausedAt : nil) ?? now
        return max(0, reference.timeIntervalSince(startDates[currentIndex]))
    }

    /// Progreso 0...1 de la fase actual. 0 en fases manuales.
    public func progressInCurrentPhase(at now: Date = Date()) -> Double {
        guard let phase = currentPhase, !phase.isManual, phase.duration > 0,
              let remaining = timeRemainingInCurrentPhase(at: now) else { return 0 }
        return min(1, max(0, (phase.duration - remaining) / phase.duration))
    }

    /// AMRAP: quedan `lowTimeWarning` segundos o menos (y todavía no terminó).
    public func isLowTime(at now: Date = Date()) -> Bool {
        guard let warning = currentPhase?.lowTimeWarning,
              let remaining = timeRemainingInCurrentPhase(at: now) else { return false }
        return remaining > 0 && remaining <= warning
    }

    /// Tiempo activo (sin pausas) desde el inicio, en segundos.
    public func activeElapsed(at now: Date = Date()) -> TimeInterval {
        guard let startedAt else { return 0 }
        let reference = finishedAt ?? now
        var total = reference.timeIntervalSince(startedAt) - pausedTotal
        if state == .paused, let pausedAt { total -= reference.timeIntervalSince(pausedAt) }
        return max(0, total)
    }

    public var result: WorkoutResult? {
        guard state == .finished, let reason = finishReason else { return nil }
        return WorkoutResult(
            elapsedSeconds: Int(activeElapsed().rounded()),
            reason: reason,
            phasesCompleted: reason == .completed ? plan.phases.count : currentIndex
        )
    }

    // MARK: Control

    /// Arranca el plan. Las fases se encadenan: cada una empieza cuando termina la anterior.
    @discardableResult
    public mutating func start(at now: Date = Date()) -> [ClockEvent] {
        guard state == .idle || state == .finished, !plan.isEmpty else { return [] }

        var cursor = now
        startDates = []
        endDates = []
        for phase in plan.phases {
            startDates.append(cursor)
            let end = phase.isManual ? cursor : cursor.addingTimeInterval(phase.duration)
            endDates.append(end)
            cursor = end
        }
        state = .running
        currentIndex = 0
        startedAt = now
        pausedAt = nil
        pausedTotal = 0
        finishedAt = nil
        finishReason = nil
        firedTicks = []
        return [.started]
    }

    /// Avanza lo que el tiempo ya agotó y emite los tics de cuenta regresiva. Llamar a ~10 Hz
    /// o al volver a primer plano: si pasaron varias fases, las recorre todas.
    @discardableResult
    public mutating func tick(at now: Date = Date()) -> [ClockEvent] {
        guard state == .running else { return [] }
        var events: [ClockEvent] = []

        while let phase = currentPhase, !phase.isManual, now >= endDates[currentIndex] {
            if currentIndex == plan.phases.count - 1 {
                // Natural: se fecha en el fin planificado, no en la hora (tardía) del tick.
                events += finishInternal(at: endDates[currentIndex], reason: .completed)
                return events
            }
            events += advance(anchor: nil, cause: .elapsed)
        }

        if let phase = currentPhase, !phase.isManual {
            let secondsLeft = Int(ceil(endDates[currentIndex].timeIntervalSince(now)))
            if WorkoutPlan.countdownTickSeconds.contains(secondsLeft),
               Double(secondsLeft) < phase.duration,
               firedTicks.insert(secondsLeft).inserted {
                events.append(.countdownTick(phase: currentIndex, secondsLeft: secondsLeft))
            }
        }
        return events
    }

    @discardableResult
    public mutating func pause(at now: Date = Date()) -> [ClockEvent] {
        guard state == .running else { return [] }
        var events = tick(at: now)
        guard state == .running else { return events }
        state = .paused
        pausedAt = now
        events.append(.paused)
        return events
    }

    /// Reanuda desplazando la fase actual y las siguientes por la duración de la pausa.
    @discardableResult
    public mutating func resume(at now: Date = Date()) -> [ClockEvent] {
        guard state == .paused, let pausedAt else { return [] }
        let delta = max(0, now.timeIntervalSince(pausedAt))
        shift(from: currentIndex, by: delta)
        pausedTotal += delta
        self.pausedAt = nil
        state = .running
        return [.resumed]
    }

    /// Salta a la fase siguiente (o confirma un paso manual). En la última fase termina el bloque.
    /// En pausa, la nueva fase queda con su duración completa y se mantiene la pausa.
    @discardableResult
    public mutating func next(at now: Date = Date()) -> [ClockEvent] {
        guard isActive else { return [] }
        var events: [ClockEvent] = []
        if state == .running {
            events += tick(at: now)
            guard state == .running else { return events }
        }
        if currentIndex >= plan.phases.count - 1 {
            events += finishInternal(at: now, reason: .completed)
        } else {
            events += advance(anchor: state == .paused ? (pausedAt ?? now) : now, cause: .user)
        }
        return events
    }

    /// Termina de inmediato (detener o "Terminar Bloque").
    @discardableResult
    public mutating func finish(at now: Date = Date()) -> [ClockEvent] {
        guard isActive else { return [] }
        return finishInternal(at: now, reason: .finishedEarly)
    }

    // MARK: Internos

    /// Pasa a la fase siguiente. Con `anchor`, la siguiente empieza en ese instante y las
    /// posteriores se desplazan en bloque (salto o paso manual). Sin `anchor`, la siguiente
    /// empieza donde terminó la anterior.
    private mutating func advance(anchor: Date?, cause: PhaseChangeCause) -> [ClockEvent] {
        let from = currentIndex
        let to = from + 1
        if let anchor {
            endDates[from] = anchor
            shift(from: to, by: anchor.timeIntervalSince(startDates[to]))
        }
        currentIndex = to
        firedTicks = []
        return [.phaseChanged(from: from, to: to, cause: cause)]
    }

    private mutating func shift(from index: Int, by delta: TimeInterval) {
        guard delta != 0, index < startDates.count else { return }
        for i in index..<startDates.count {
            startDates[i] = startDates[i].addingTimeInterval(delta)
            endDates[i] = endDates[i].addingTimeInterval(delta)
        }
    }

    private mutating func finishInternal(at date: Date, reason: FinishReason) -> [ClockEvent] {
        if state == .paused, let pausedAt {
            pausedTotal += max(0, date.timeIntervalSince(pausedAt))
            self.pausedAt = nil
        }
        finishedAt = date
        finishReason = reason
        state = .finished
        return [.finished(reason)]
    }

    // MARK: Serialización

    public var snapshot: ClockSnapshot {
        ClockSnapshot(
            title: plan.title,
            phases: plan.phases,
            startDates: startDates,
            endDates: endDates,
            currentPhaseIndex: currentIndex,
            state: state,
            startedAt: startedAt,
            pausedAt: pausedAt,
            pausedTotal: pausedTotal
        )
    }

    /// Reconstruye un reloj desde un snapshot (Watch, o iPhone tras un cierre). Un snapshot con
    /// fechas incoherentes con las fases se descarta con nil.
    public init?(snapshot: ClockSnapshot) {
        let count = snapshot.phases.count
        switch snapshot.state {
        case .idle:
            break
        case .running, .paused, .finished:
            guard snapshot.startDates.count == count, snapshot.endDates.count == count,
                  snapshot.currentPhaseIndex >= 0, snapshot.currentPhaseIndex < max(count, 1) else { return nil }
        }
        self.plan = WorkoutPlan(title: snapshot.title, phases: snapshot.phases)
        self.state = snapshot.state
        self.currentIndex = snapshot.currentPhaseIndex
        self.startDates = snapshot.startDates
        self.endDates = snapshot.endDates
        self.startedAt = snapshot.startedAt
        self.pausedAt = snapshot.pausedAt
        self.pausedTotal = snapshot.pausedTotal
    }
}
