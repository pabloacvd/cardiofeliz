import Foundation
import AVFoundation

public final class SoundManager: ObservableObject {
    public static let shared = SoundManager()

    @Published public var isMuted: Bool = false {
        didSet { if oldValue != isMuted { onAudioChanged?() } }
    }

    /// Política de mezcla con el audio de otras apps (música, podcasts).
    /// Decisión: solo `.mixWithOthers`. La música del usuario sigue a su volumen y los tonos y la voz
    /// se mezclan encima. Con `.duckOthers` la música quedaría atenuada todo el entrenamiento
    /// (la sesión de audio está activa todo el tiempo por el bucle de silencio), no solo durante
    /// los avisos. Para atenuar, basta añadir `.duckOthers` aquí.
    static let sessionOptions: AVAudioSession.CategoryOptions = [.mixWithOthers]

    /// Lo asigna `TimerManager` mientras hay un entrenamiento en curso. Se invoca cuando el audio se
    /// recupera de una interrupción o cambia el silencio, para volver a programar los avisos.
    public var onAudioChanged: (() -> Void)?

    private let speechSynthesizer = AVSpeechSynthesizer()
    private var audioEngine: AVAudioEngine?
    /// Reproducción inmediata (botones, avisos disparados por el usuario).
    private var playerNode: AVAudioPlayerNode?
    /// Avisos programados con antelación a una hora exacta.
    private var scheduledPlayer: AVAudioPlayerNode?
    /// Bucle de silencio que mantiene la app viva en segundo plano durante un entrenamiento.
    private var silencePlayer: AVAudioPlayerNode?

    private var tickBuffer: AVAudioPCMBuffer?
    private var goBuffer: AVAudioPCMBuffer?
    private var restBuffer: AVAudioPCMBuffer?
    private var victoryBuffer: AVAudioPCMBuffer?
    private var silenceBuffer: AVAudioPCMBuffer?

    /// Hay un entrenamiento en curso: el bucle de silencio debe estar sonando.
    public private(set) var isWorkoutAudioActive = false

    private init() {
        configureAudioSession()
        setupEngine()
        prepareBuffers()
        observeAudioNotifications()
    }

    public func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: Self.sessionOptions
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            AppLog.audio.error("No se pudo configurar la sesión de audio: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func setupEngine() {
        let engine = AVAudioEngine()
        let immediate = AVAudioPlayerNode()
        let scheduled = AVAudioPlayerNode()
        let silence = AVAudioPlayerNode()
        for node in [immediate, scheduled, silence] { engine.attach(node) }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: ToneSynthesizer.defaultSampleRate,
            channels: 1,
            interleaved: false
        )
        for node in [immediate, scheduled, silence] {
            engine.connect(node, to: engine.mainMixerNode, format: format)
        }

        do {
            try engine.start()
            self.audioEngine = engine
            self.playerNode = immediate
            self.scheduledPlayer = scheduled
            self.silencePlayer = silence
        } catch {
            AppLog.audio.error("No se pudo iniciar el motor de audio: \(String(describing: type(of: error)), privacy: .public)")
        }
    }

    private func prepareBuffers() {
        let sampleRate = ToneSynthesizer.defaultSampleRate
        tickBuffer = ToneSynthesizer.makePCMBuffer(
            samples: ToneSynthesizer.generateSamples(spec: .tick, sampleRate: sampleRate),
            sampleRate: sampleRate
        )
        goBuffer = ToneSynthesizer.makePCMBuffer(
            samples: ToneSynthesizer.generateSamples(spec: .go, sampleRate: sampleRate),
            sampleRate: sampleRate
        )
        restBuffer = ToneSynthesizer.makePCMBuffer(
            samples: ToneSynthesizer.generateSamples(spec: .rest, sampleRate: sampleRate),
            sampleRate: sampleRate
        )
        victoryBuffer = ToneSynthesizer.makePCMBuffer(
            samples: ToneSynthesizer.generateVictoryFanfareSamples(sampleRate: sampleRate),
            sampleRate: sampleRate
        )
        silenceBuffer = ToneSynthesizer.makePCMBuffer(
            samples: [Float](repeating: 0, count: Int(sampleRate)),
            sampleRate: sampleRate
        )
    }

    public func toggleMute() {
        isMuted.toggle()
    }

    // MARK: - Reproducción inmediata

    private func playBuffer(_ buffer: AVAudioPCMBuffer?) {
        guard !isMuted else { return }
        guard let buffer, let player = playerNode, let engine = audioEngine else {
            // Fallback limpio a sonido de sistema si el motor de audio no está disponible
            AudioServicesPlaySystemSound(1052)
            return
        }

        configureAudioSession()
        if !engine.isRunning {
            try? engine.start()
        }

        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    public func playCountdownTick() {
        playBuffer(tickBuffer)
    }

    public func playGo() {
        playBuffer(goBuffer)
    }

    public func playRest() {
        playBuffer(restBuffer)
    }

    public func playVictory() {
        playBuffer(victoryBuffer)
    }

    public func playCue(_ cue: SoundCue) {
        switch cue {
        case .go: playGo()
        case .rest: playRest()
        case .none: break
        }
    }

    public func playBeep() {
        playCountdownTick()
    }

    /// Vibración en cambios de fase y al terminar. Es independiente del silencio: quien silencia
    /// el sonido sigue necesitando el aviso háptico. No hace nada en dispositivos sin motor háptico.
    public func vibrate() {
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    public func speak(_ text: String) {
        guard !isMuted else { return }
        configureAudioSession()

        if speechSynthesizer.isSpeaking {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "es-ES")
        utterance.rate = 0.52
        speechSynthesizer.speak(utterance)
    }

    // MARK: - Audio durante un entrenamiento (segundo plano)

    /// Mantiene la sesión de audio activa con un bucle de silencio para que iOS no suspenda la app
    /// con la pantalla bloqueada y los avisos programados suenen a su hora. Independiente del
    /// silencio: con los sonidos silenciados el contador sigue necesitando la app viva.
    public func beginWorkoutAudio() {
        isWorkoutAudioActive = true
        startSilenceLoop()
    }

    /// Detiene el bucle de silencio. Con `cancelScheduled: false` deja sonar los avisos ya programados
    /// (la fanfarria de victoria programada para el fin del plan).
    public func endWorkoutAudio(cancelScheduled: Bool = true) {
        isWorkoutAudioActive = false
        if cancelScheduled { cancelScheduledCues() }
        silencePlayer?.stop()
    }

    private func startSilenceLoop() {
        configureAudioSession()
        guard let engine = audioEngine, let silence = silencePlayer, let buffer = silenceBuffer else { return }
        if !engine.isRunning { try? engine.start() }
        if !silence.isPlaying {
            silence.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            silence.play()
        }
    }

    /// Programa los tonos futuros a su hora exacta. Reemplaza cualquier programación anterior.
    /// - Returns: `true` si el motor de audio se hace cargo de la reproducción a tiempo; en ese caso el
    ///   llamador no debe reproducir esos mismos tonos de forma inmediata.
    @discardableResult
    public func scheduleCues(_ cues: [ScheduledCue]) -> Bool {
        cancelScheduledCues()
        guard !isMuted else { return false }
        guard let engine = audioEngine, let player = scheduledPlayer else { return false }
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return false }

        let now = Date()
        player.play()
        for cue in cues.sorted(by: { $0.date < $1.date }) {
            let delta = cue.date.timeIntervalSince(now)
            guard delta > 0, let buffer = buffer(for: cue.kind) else { continue }
            let host = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delta)
            player.scheduleBuffer(buffer, at: AVAudioTime(hostTime: host), options: [], completionHandler: nil)
        }
        return true
    }

    public func cancelScheduledCues() {
        guard let player = scheduledPlayer else { return }
        player.stop()
    }

    private func buffer(for kind: AudioCueKind) -> AVAudioPCMBuffer? {
        switch kind {
        case .tick: return tickBuffer
        case .go: return goBuffer
        case .rest: return restBuffer
        case .victory: return victoryBuffer
        }
    }

    // MARK: - Interrupciones

    private func observeAudioNotifications() {
        let center = NotificationCenter.default
        center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            guard let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: raw) == .ended else { return }
            // Con `shouldResume` o sin él, un entrenamiento en curso necesita su audio de vuelta.
            self?.recoverAudio()
        }
        center.addObserver(forName: .AVAudioEngineConfigurationChange, object: nil, queue: .main) { [weak self] _ in
            // Cambio de ruta (auriculares, Bluetooth): el motor se detiene y los nodos pierden su cola.
            self?.recoverAudio()
        }
        center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            self?.recoverAudio()
        }
    }

    /// Reactiva sesión y motor, reanuda el bucle de silencio y pide reprogramar los avisos.
    public func recoverAudio() {
        configureAudioSession()
        if let engine = audioEngine, !engine.isRunning {
            do { try engine.start() } catch {
                AppLog.audio.error("No se pudo reiniciar el motor de audio: \(String(describing: type(of: error)), privacy: .public)")
            }
        }
        guard isWorkoutAudioActive else { return }
        silencePlayer?.stop()
        startSilenceLoop()
        onAudioChanged?()
    }

    /// Al volver a primer plano: si el motor se detuvo mientras estaba en segundo plano, se recupera.
    public func recoverIfNeeded() {
        guard isWorkoutAudioActive else { return }
        if audioEngine?.isRunning != true || silencePlayer?.isPlaying != true {
            recoverAudio()
        }
    }
}
