import XCTest

final class ToneSynthesizerTests: XCTestCase {

    func testTickSampleGeneration() {
        let sampleRate: Double = 44100
        let samples = ToneSynthesizer.generateSamples(spec: .tick, sampleRate: sampleRate)
        let expectedCount = Int(ToneSpec.tick.durationSeconds * sampleRate)

        XCTAssertEqual(samples.count, expectedCount)
        // Samples must be within [-peakGain, peakGain]
        for s in samples {
            XCTAssertGreaterThanOrEqual(s, -ToneSpec.tick.peakGain - 0.001)
            XCTAssertLessThanOrEqual(s, ToneSpec.tick.peakGain + 0.001)
        }
        // First sample starts close to zero to avoid clicks
        XCTAssertLessThan(abs(samples[0]), 0.05)
        // Final sample ends close to zero
        XCTAssertLessThan(abs(samples[samples.count - 1]), 0.05)
    }

    func testGoChimeSampleGeneration() {
        let sampleRate: Double = 44100
        let samples = ToneSynthesizer.generateSamples(spec: .go, sampleRate: sampleRate)
        let expectedCount = Int(ToneSpec.go.durationSeconds * sampleRate)

        XCTAssertEqual(samples.count, expectedCount)
        for s in samples {
            XCTAssertGreaterThanOrEqual(s, -ToneSpec.go.peakGain - 0.001)
            XCTAssertLessThanOrEqual(s, ToneSpec.go.peakGain + 0.001)
        }
    }

    func testRestChimeSampleGeneration() {
        let sampleRate: Double = 44100
        let samples = ToneSynthesizer.generateSamples(spec: .rest, sampleRate: sampleRate)
        let expectedCount = Int(ToneSpec.rest.durationSeconds * sampleRate)

        XCTAssertEqual(samples.count, expectedCount)
        for s in samples {
            XCTAssertGreaterThanOrEqual(s, -ToneSpec.rest.peakGain - 0.001)
            XCTAssertLessThanOrEqual(s, ToneSpec.rest.peakGain + 0.001)
        }
    }

    func testVictoryFanfareSampleGeneration() {
        let sampleRate: Double = 44100
        let samples = ToneSynthesizer.generateVictoryFanfareSamples(sampleRate: sampleRate)
        // 4 notes: 3 * 0.14 + 0.28 = 0.70 seconds
        let expectedCount = Int((0.70 * sampleRate).rounded())

        XCTAssertEqual(samples.count, expectedCount)
        for s in samples {
            XCTAssertGreaterThanOrEqual(s, -1.0)
            XCTAssertLessThanOrEqual(s, 1.0)
        }
    }

    func testMakePCMBuffer() {
        let samples = ToneSynthesizer.generateSamples(spec: .tick)
        let buffer = ToneSynthesizer.makePCMBuffer(samples: samples)

        XCTAssertNotNil(buffer)
        XCTAssertEqual(Int(buffer?.frameLength ?? 0), samples.count)
    }
}
