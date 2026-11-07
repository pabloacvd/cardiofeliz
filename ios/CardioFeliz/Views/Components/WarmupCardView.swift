import SwiftUI

struct WarmupCardView: View {
    let calentamiento: String
    let calentamientoMinutos: Int?
    let onStart: (() -> Void)?

    init(
        calentamiento: String,
        calentamientoMinutos: Int?,
        onStart: (() -> Void)? = nil
    ) {
        self.calentamiento = calentamiento
        self.calentamientoMinutos = calentamientoMinutos
        self.onStart = onStart
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "flame.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 14))

                Text("CALENTAMIENTO")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.orange)

                Spacer()

                if let mins = calentamientoMinutos, mins > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text("\(mins) min")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(6)
                }
            }

            Text(calentamiento)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(.secondary)
                .lineSpacing(2)

            if let onStart {
                Button(action: onStart) {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("Iniciar Calentamiento")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.orange)
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}
