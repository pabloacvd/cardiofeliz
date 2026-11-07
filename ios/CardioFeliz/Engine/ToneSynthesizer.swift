import Foundation
import AVFoundation

/// Tipo de forma de onda sintetizada.
public enum ToneWaveform: String, Sendable, CaseIterable {
    case sine
    case triangle
}

/// Parámetros de un tono de audio puro.
public struct ToneSpec: Sendable, Equatable {
    public var startFrequency: Double
    public var endFrequency: Double
    public var durationSeconds: Double
    public var rampDurationSeconds: Double
    public var waveform: ToneWaveform
    public var peakGain: Float
    public var attackSeconds: Double

    public init(
        startFrequency: Double,
        endFrequency: Double? = nil,
        durationSeconds: Double,
        rampDurationSeconds: Double? = nil,
        waveform: ToneWaveform = .sine,
        peakGain: Float = 0.25,
        attackSeconds: Double = 0.02
    ) {
        self.startFrequency = startFrequency
        self.endFrequency = endFrequency ?? startFrequency
        self.durationSeconds = durationSeconds
        self.rampDurationSeconds = rampDurationSeconds ?? durationSeconds
        self.waveform = waveform
        self.peakGain = peakGain
        self.attackSeconds = attackSeconds
    }

    /// Tono de cuenta atrás (3, 2, 1): 520 Hz, 0.12 s, seno, ganancia 0.20
    public static let tick = ToneSpec(
        startFrequency: 520,
        durationSeconds: 0.12,
        waveform: .sine,
        peakGain: 0.20,
        attackSeconds: 0.02
    )

    /// Tono Go / inicio de minuto: 880 Hz -> 1320 Hz en 0.35 s (0.4 s total), triángulo, ganancia 0.35
    public static let go = ToneSpec(
        startFrequency: 880,
        endFrequency: 1320,
        durationSeconds: 0.40,
        rampDurationSeconds: 0.35,
        waveform: .triangle,
        peakGain: 0.35,
        attackSeconds: 0.05
    )

    /// Tono Descanso: 440 Hz -> 330 Hz en 0.35 s (0.4 s total), seno, ganancia 0.25
    public static let rest = ToneSpec(
        startFrequency: 440,
        endFrequency: 330,
        durationSeconds: 0.40,
        rampDurationSeconds: 0.35,
        waveform: .sine,
        peakGain: 0.25,
        attackSeconds: 0.04
    )
}

/// Generador puro de muestras PCM en punto flotante [-1.0, 1.0].
public enum ToneSynthesizer {

    public static let defaultSampleRate: Double = 44100.0

    /// Genera un array de muestras Float32 para una especificación de tono dada.
    public static func generateSamples(
        spec: ToneSpec,
        sampleRate: Double = defaultSampleRate
    ) -> [Float] {
        let totalSamples = max(1, Int(spec.durationSeconds * sampleRate))
        var samples = [Float](repeating: 0, count: totalSamples)

        var phase: Double = 0.0
        let dt = 1.0 / sampleRate
        let rampDuration = max(0.001, spec.rampDurationSeconds)

        for i in 0..<totalSamples {
            let t = Double(i) * dt

            // Frecuencia instantánea (rampa exponencial si varía)
            let freq: Double
            if spec.startFrequency == spec.endFrequency {
                freq = spec.startFrequency
            } else if t <= rampDuration {
                let progress = t / rampDuration
                freq = spec.startFrequency * pow(spec.endFrequency / spec.startFrequency, progress)
            } else {
                freq = spec.endFrequency
            }

            // Envolvente de ganancia para evitar clics (ataque rápido y caída suave)
            let gain: Float
            if t < spec.attackSeconds {
                let attackProgress = Float(t / max(0.0001, spec.attackSeconds))
                gain = 0.001 + (spec.peakGain - 0.001) * attackProgress
            } else {
                let decayDuration = max(0.0001, spec.durationSeconds - spec.attackSeconds)
                let decayProgress = Float((t - spec.attackSeconds) / decayDuration)
                gain = max(0.0, spec.peakGain * (1.0 - decayProgress))
            }

            // Forma de onda
            let rawWave: Float
            switch spec.waveform {
            case .sine:
                rawWave = Float(sin(phase))
            case .triangle:
                // Onda triangular suave normalizada en [-1, 1] usando arcsin(sin(phase)) * (2/pi)
                rawWave = Float(asin(sin(phase)) * (2.0 / .pi))
            }

            samples[i] = rawWave * gain

            // Avanzar fase continua
            phase += 2.0 * .pi * freq * dt
            if phase > 2.0 * .pi * 1000.0 {
                phase = phase.truncatingRemainder(dividingBy: 2.0 * .pi)
            }
        }

        return samples
    }

    /// Genera las muestras de la fanfarria de victoria (arpegio de 4 notas: C5, E5, G5, C6).
    public static func generateVictoryFanfareSamples(
        sampleRate: Double = defaultSampleRate
    ) -> [Float] {
        let notes: [Double] = [523.25, 659.25, 783.99, 1046.50] // C5, E5, G5, C6
        let noteDuration = 0.28
        let noteSpacing = 0.14
        let totalDuration = Double(notes.count - 1) * noteSpacing + noteDuration
        let totalSamples = max(1, Int((totalDuration * sampleRate).rounded()))
        var buffer = [Float](repeating: 0, count: totalSamples)

        for (idx, freq) in notes.enumerated() {
            let spec = ToneSpec(
                startFrequency: freq,
                durationSeconds: noteDuration,
                waveform: .triangle,
                peakGain: 0.30,
                attackSeconds: 0.02
            )
            let noteSamples = generateSamples(spec: spec, sampleRate: sampleRate)
            let offsetSamples = Int(Double(idx) * noteSpacing * sampleRate)

            for i in 0..<noteSamples.count {
                let targetIdx = offsetSamples + i
                if targetIdx < buffer.count {
                    buffer[targetIdx] += noteSamples[i]
                }
            }
        }

        // Limitar / normalizar para evitar clipping
        for i in 0..<buffer.count {
            buffer[i] = max(-1.0, min(1.0, buffer[i]))
        }

        return buffer
    }

    /// Crea un `AVAudioPCMBuffer` a partir de un array de muestras mono Float32.
    public static func makePCMBuffer(
        samples: [Float],
        sampleRate: Double = defaultSampleRate
    ) -> AVAudioPCMBuffer? {
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else { return nil }

        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: AVAudioFrameCount(samples.count)
        ) else { return nil }

        buffer.frameLength = AVAudioFrameCount(samples.count)
        if let channelData = buffer.floatChannelData {
            samples.withUnsafeBufferPointer { ptr in
                if let baseAddress = ptr.baseAddress {
                    channelData[0].initialize(from: baseAddress, count: samples.count)
                }
            }
        }

        return buffer
    }
}
