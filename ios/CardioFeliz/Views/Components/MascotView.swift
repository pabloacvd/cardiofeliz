import SwiftUI

/// Representación vectorial nativa de la mascota de CardioFeliz en sus 5 etapas evolutivas y estados de ánimo.
/// Equivale a `src/components/Mascot.tsx`.
struct MascotView: View {
    var stage: Int = 1 // 1 a 5
    var mood: CoachMood = .happy
    var size: CGFloat = 48
    var showName: Bool = false

    private var clampedStage: Int {
        min(5, max(1, stage))
    }

    private var stageName: String {
        switch clampedStage {
        case 1: return "Brasita"
        case 2: return "Llamita"
        case 3: return "Fueguito"
        case 4: return "Fogata"
        case 5: return "Fénix"
        default: return "Brasita"
        }
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                // Mascot Body
                mascotBody

                // Face / Expression
                mascotFace
            }
            .frame(width: size, height: size)

            if showName {
                Text(stageName)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.yellow.opacity(0.9))
            }
        }
    }

    // MARK: - Bodies

    @ViewBuilder
    private var mascotBody: some View {
        switch clampedStage {
        case 5: // Fénix
            ZStack {
                // Left Wing
                Path { p in
                    p.move(to: CGPoint(x: 12, y: 42))
                    p.addCurve(to: CGPoint(x: 22, y: 24), control1: CGPoint(x: 4, y: 30), control2: CGPoint(x: 8, y: 16))
                    p.addCurve(to: CGPoint(x: 12, y: 42), control1: CGPoint(x: 14, y: 34), control2: CGPoint(x: 18, y: 42))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [.yellow, .red], startPoint: .top, endPoint: .bottom))

                // Right Wing
                Path { p in
                    p.move(to: CGPoint(x: 52, y: 42))
                    p.addCurve(to: CGPoint(x: 42, y: 24), control1: CGPoint(x: 60, y: 30), control2: CGPoint(x: 56, y: 16))
                    p.addCurve(to: CGPoint(x: 52, y: 42), control1: CGPoint(x: 50, y: 34), control2: CGPoint(x: 46, y: 42))
                    p.closeSubpath()
                }
                .fill(LinearGradient(colors: [.yellow, .red], startPoint: .top, endPoint: .bottom))

                // Tail
                Path { p in
                    p.move(to: CGPoint(x: 26, y: 54))
                    p.addQuadCurve(to: CGPoint(x: 38, y: 54), control: CGPoint(x: 32, y: 62))
                    p.addQuadCurve(to: CGPoint(x: 26, y: 54), control: CGPoint(x: 32, y: 58))
                    p.closeSubpath()
                }
                .fill(Color.red)

                // Main body
                flameBodyPath(topY: 10, botY: 42, width: 22)
                    .fill(mainBodyGradient)

                // Inner fire
                flameBodyPath(topY: 18, botY: 42, width: 12)
                    .fill(innerFireGradient)

                // Crown / Crest
                Path { p in
                    p.move(to: CGPoint(x: 32, y: 6))
                    p.addLine(to: CGPoint(x: 28, y: 14))
                    p.addLine(to: CGPoint(x: 32, y: 11))
                    p.addLine(to: CGPoint(x: 36, y: 14))
                    p.closeSubpath()
                }
                .fill(Color.yellow)

                Circle()
                    .fill(Color.orange)
                    .frame(width: 5, height: 5)
                    .position(x: 32, y: 5)
            }
            .scaleEffect(size / 64.0)

        case 4: // Fogata
            ZStack {
                // Logs
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.45, green: 0.22, blue: 0.08))
                    .frame(width: 28, height: 5)
                    .rotationEffect(.degrees(-10))
                    .position(x: 32, y: 55)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(red: 0.55, green: 0.25, blue: 0.08))
                    .frame(width: 28, height: 5)
                    .rotationEffect(.degrees(10))
                    .position(x: 32, y: 55)

                // Sparks
                Circle().fill(Color.yellow).frame(width: 3, height: 3).position(x: 16, y: 20)
                Circle().fill(Color.yellow).frame(width: 3, height: 3).position(x: 48, y: 18)
                Circle().fill(Color.orange).frame(width: 2, height: 2).position(x: 44, y: 10)

                // Main body
                flameBodyPath(topY: 8, botY: 44, width: 32)
                    .fill(mainBodyGradient)

                // Tendrils
                Path { p in
                    p.move(to: CGPoint(x: 18, y: 36))
                    p.addCurve(to: CGPoint(x: 20, y: 28), control1: CGPoint(x: 12, y: 32), control2: CGPoint(x: 14, y: 24))
                    p.addCurve(to: CGPoint(x: 18, y: 36), control1: CGPoint(x: 18, y: 32), control2: CGPoint(x: 18, y: 34))
                }
                .fill(Color.orange)

                Path { p in
                    p.move(to: CGPoint(x: 46, y: 36))
                    p.addCurve(to: CGPoint(x: 44, y: 28), control1: CGPoint(x: 52, y: 32), control2: CGPoint(x: 50, y: 24))
                    p.addCurve(to: CGPoint(x: 46, y: 36), control1: CGPoint(x: 46, y: 32), control2: CGPoint(x: 46, y: 34))
                }
                .fill(Color.orange)

                // Inner fire
                flameBodyPath(topY: 18, botY: 44, width: 16)
                    .fill(innerFireGradient)
            }
            .scaleEffect(size / 64.0)

        case 3: // Fueguito
            ZStack {
                // Sparks
                Circle().fill(Color.yellow).frame(width: 3, height: 3).position(x: 20, y: 16)
                Circle().fill(Color.orange).frame(width: 3, height: 3).position(x: 44, y: 14)

                // Main body
                flameBodyPath(topY: 10, botY: 44, width: 28)
                    .fill(mainBodyGradient)

                // Side flame
                Path { p in
                    p.move(to: CGPoint(x: 44, y: 34))
                    p.addCurve(to: CGPoint(x: 42, y: 27), control1: CGPoint(x: 49, y: 30), control2: CGPoint(x: 47, y: 24))
                    p.addCurve(to: CGPoint(x: 44, y: 34), control1: CGPoint(x: 44, y: 30), control2: CGPoint(x: 44, y: 32))
                }
                .fill(Color.orange)

                // Inner fire
                flameBodyPath(topY: 20, botY: 44, width: 14)
                    .fill(innerFireGradient)
            }
            .scaleEffect(size / 64.0)

        case 2: // Llamita
            ZStack {
                flameBodyPath(topY: 12, botY: 44, width: 24)
                    .fill(mainBodyGradient)

                flameBodyPath(topY: 22, botY: 44, width: 12)
                    .fill(innerFireGradient)
            }
            .scaleEffect(size / 64.0)

        default: // Brasita (stage 1) / fallback
            ZStack {
                Circle()
                    .fill(mainBodyGradient)
                    .frame(width: 32, height: 32)
                    .position(x: 32, y: 38)

                Path { p in
                    p.move(to: CGPoint(x: 32, y: 18))
                    p.addCurve(to: CGPoint(x: 20, y: 38), control1: CGPoint(x: 28, y: 26), control2: CGPoint(x: 20, y: 32))
                    p.addCurve(to: CGPoint(x: 44, y: 38), control1: CGPoint(x: 20, y: 46), control2: CGPoint(x: 44, y: 46))
                    p.addCurve(to: CGPoint(x: 32, y: 18), control1: CGPoint(x: 44, y: 32), control2: CGPoint(x: 36, y: 26))
                    p.closeSubpath()
                }
                .fill(mainBodyGradient)

                Circle()
                    .fill(innerFireGradient)
                    .frame(width: 20, height: 20)
                    .position(x: 32, y: 39)

                Circle()
                    .fill(Color.yellow.opacity(0.8))
                    .frame(width: 3, height: 3)
                    .position(x: 42, y: 24)
            }
            .scaleEffect(size / 64.0)
        }
    }

    // MARK: - Faces

    @ViewBuilder
    private var mascotFace: some View {
        let eyeY: CGFloat = clampedStage == 1 ? 36 : clampedStage == 5 ? 32 : 34
        let mouthY: CGFloat = eyeY + 7

        ZStack {
            switch mood {
            case .proud:
                // Sunglasses
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black)
                    .frame(width: 8, height: 6)
                    .position(x: 27, y: eyeY - 1)

                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.black)
                    .frame(width: 8, height: 6)
                    .position(x: 37, y: eyeY - 1)

                Rectangle()
                    .fill(Color.black)
                    .frame(width: 4, height: 2)
                    .position(x: 32, y: eyeY - 1)

                // Tongue smile
                Path { p in
                    p.move(to: CGPoint(x: 27, y: mouthY))
                    p.addQuadCurve(to: CGPoint(x: 37, y: mouthY), control: CGPoint(x: 32, y: mouthY + 4))
                }
                .stroke(Color(red: 0.45, green: 0.22, blue: 0.08), lineWidth: 2)

                Path { p in
                    p.move(to: CGPoint(x: 29, y: mouthY + 1))
                    p.addQuadCurve(to: CGPoint(x: 35, y: mouthY + 1), control: CGPoint(x: 32, y: mouthY + 5))
                    p.closeSubpath()
                }
                .fill(Color.red)

            case .worried:
                // Worried eyes
                Ellipse().fill(Color.black).frame(width: 5, height: 7).position(x: 26, y: eyeY)
                Ellipse().fill(Color.black).frame(width: 5, height: 7).position(x: 38, y: eyeY)

                // Eyebrows
                Path { p in
                    p.move(to: CGPoint(x: 23, y: eyeY - 5))
                    p.addLine(to: CGPoint(x: 28, y: eyeY - 3))
                }
                .stroke(Color(red: 0.45, green: 0.22, blue: 0.08), lineWidth: 1.5)

                Path { p in
                    p.move(to: CGPoint(x: 41, y: eyeY - 5))
                    p.addLine(to: CGPoint(x: 36, y: eyeY - 3))
                }
                .stroke(Color(red: 0.45, green: 0.22, blue: 0.08), lineWidth: 1.5)

                // Sweat drop
                Path { p in
                    p.move(to: CGPoint(x: 43, y: 28))
                    p.addQuadCurve(to: CGPoint(x: 43, y: 34), control: CGPoint(x: 45, y: 32))
                    p.addQuadCurve(to: CGPoint(x: 43, y: 28), control: CGPoint(x: 41, y: 32))
                    p.closeSubpath()
                }
                .fill(Color.cyan)

                // Wavy mouth
                Path { p in
                    p.move(to: CGPoint(x: 28, y: mouthY))
                    p.addQuadCurve(to: CGPoint(x: 32, y: mouthY), control: CGPoint(x: 30, y: mouthY - 2))
                    p.addQuadCurve(to: CGPoint(x: 36, y: mouthY), control: CGPoint(x: 34, y: mouthY + 2))
                }
                .stroke(Color(red: 0.45, green: 0.22, blue: 0.08), lineWidth: 1.8)

            case .rest:
                // Sleeping eyes
                Path { p in
                    p.move(to: CGPoint(x: 24, y: eyeY))
                    p.addQuadCurve(to: CGPoint(x: 30, y: eyeY), control: CGPoint(x: 27, y: eyeY + 3))
                }
                .stroke(Color.black, lineWidth: 2)

                Path { p in
                    p.move(to: CGPoint(x: 34, y: eyeY))
                    p.addQuadCurve(to: CGPoint(x: 40, y: eyeY), control: CGPoint(x: 37, y: eyeY + 3))
                }
                .stroke(Color.black, lineWidth: 2)

                // z Z text
                Text("z")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.purple)
                    .position(x: 44, y: 24)

                Text("Z")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.purple)
                    .position(x: 49, y: 18)

                // Gentle smile
                Path { p in
                    p.move(to: CGPoint(x: 28, y: mouthY))
                    p.addQuadCurve(to: CGPoint(x: 36, y: mouthY), control: CGPoint(x: 32, y: mouthY + 2))
                }
                .stroke(Color(red: 0.45, green: 0.22, blue: 0.08), lineWidth: 1.8)

            case .recover:
                // Determined eyes
                Ellipse().fill(Color.black).frame(width: 5, height: 7).position(x: 26, y: eyeY)
                Circle().fill(Color.white).frame(width: 2, height: 2).position(x: 27, y: eyeY - 1)

                Ellipse().fill(Color.black).frame(width: 5, height: 7).position(x: 38, y: eyeY)
                Circle().fill(Color.white).frame(width: 2, height: 2).position(x: 39, y: eyeY - 1)

                // Eyebrows
                Path { p in
                    p.move(to: CGPoint(x: 23, y: eyeY - 3))
                    p.addLine(to: CGPoint(x: 28, y: eyeY - 5))
                }
                .stroke(Color(red: 0.45, green: 0.22, blue: 0.08), lineWidth: 1.5)

                Path { p in
                    p.move(to: CGPoint(x: 41, y: eyeY - 3))
                    p.addLine(to: CGPoint(x: 36, y: eyeY - 5))
                }
                .stroke(Color(red: 0.45, green: 0.22, blue: 0.08), lineWidth: 1.5)

                // Headband / bandage
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.cyan.opacity(0.8))
                    .frame(width: 5, height: 4)
                    .rotationEffect(.degrees(-15))
                    .position(x: 21, y: eyeY + 4)

                // Determined smile
                Path { p in
                    p.move(to: CGPoint(x: 26, y: mouthY))
                    p.addQuadCurve(to: CGPoint(x: 38, y: mouthY), control: CGPoint(x: 32, y: mouthY + 4))
                }
                .stroke(Color(red: 0.45, green: 0.22, blue: 0.08), lineWidth: 2)

            case .welcome, .happy:
                // Shiny eyes
                Ellipse().fill(Color.black).frame(width: 6, height: 8).position(x: 26, y: eyeY)
                Circle().fill(Color.white).frame(width: 2.4, height: 2.4).position(x: 27, y: eyeY - 1.5)

                Ellipse().fill(Color.black).frame(width: 6, height: 8).position(x: 38, y: eyeY)
                Circle().fill(Color.white).frame(width: 2.4, height: 2.4).position(x: 39, y: eyeY - 1.5)

                // Rosy cheeks
                Circle().fill(Color.red.opacity(0.4)).frame(width: 4, height: 4).position(x: 21, y: eyeY + 3)
                Circle().fill(Color.red.opacity(0.4)).frame(width: 4, height: 4).position(x: 43, y: eyeY + 3)

                // Happy open mouth
                Path { p in
                    p.move(to: CGPoint(x: 27, y: mouthY - 1))
                    p.addQuadCurve(to: CGPoint(x: 37, y: mouthY - 1), control: CGPoint(x: 32, y: mouthY + 5))
                    p.closeSubpath()
                }
                .fill(Color.red)

                Path { p in
                    p.move(to: CGPoint(x: 27, y: mouthY - 1))
                    p.addQuadCurve(to: CGPoint(x: 37, y: mouthY - 1), control: CGPoint(x: 32, y: mouthY + 5))
                }
                .stroke(Color(red: 0.45, green: 0.22, blue: 0.08), lineWidth: 1.5)
            }
        }
        .scaleEffect(size / 64.0)
    }

    // MARK: - Helpers

    private var mainBodyGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.96, green: 0.62, blue: 0.04), Color(red: 0.92, green: 0.35, blue: 0.05), Color(red: 0.86, green: 0.15, blue: 0.15)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var innerFireGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 1.0, green: 0.94, blue: 0.54), Color(red: 0.98, green: 0.75, blue: 0.14), Color(red: 0.98, green: 0.45, blue: 0.09)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func flameBodyPath(topY: CGFloat, botY: CGFloat, width: CGFloat) -> Path {
        Path { p in
            let halfW = width / 2.0
            p.move(to: CGPoint(x: 32, y: topY))
            p.addCurve(
                to: CGPoint(x: 32 - halfW, y: botY),
                control1: CGPoint(x: 32 - halfW * 0.7, y: topY + (botY - topY) * 0.35),
                control2: CGPoint(x: 32 - halfW * 1.1, y: topY + (botY - topY) * 0.7)
            )
            p.addCurve(
                to: CGPoint(x: 32 + halfW, y: botY),
                control1: CGPoint(x: 32 - halfW * 0.5, y: botY + 8),
                control2: CGPoint(x: 32 + halfW * 0.5, y: botY + 8)
            )
            p.addCurve(
                to: CGPoint(x: 32, y: topY),
                control1: CGPoint(x: 32 + halfW * 1.1, y: topY + (botY - topY) * 0.7),
                control2: CGPoint(x: 32 + halfW * 0.7, y: topY + (botY - topY) * 0.35)
            )
            p.closeSubpath()
        }
    }
}
