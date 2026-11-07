import SwiftUI

/// Tarjeta de mensaje del coach con la mascota animada y botón de descarte.
/// Equivale a `CoachCard` en `src/components/GameStatus.tsx`.
struct CoachCardView: View {
    let coach: CoachMessage
    let mascotStage: Int
    var mascotName: String?
    let onDismiss: () -> Void

    private var moodColor: Color {
        switch coach.mood {
        case .happy, .welcome:
            return Color.green
        case .proud:
            return Color.yellow
        case .worried:
            return Color.orange
        case .recover:
            return Color.cyan
        case .rest:
            return Color.purple
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Mascot container
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )

                MascotView(
                    stage: mascotStage,
                    mood: coach.mood,
                    size: 40,
                    showName: mascotName != nil
                )
                .padding(4)
            }
            .frame(width: 48, height: 48)

            // Coach text
            Text(coach.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color.white.opacity(0.95))
                .lineSpacing(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)

            // Dismiss button
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Descartar mensaje del coach")
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(moodColor.opacity(0.35), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 2)
    }
}
