import SwiftUI

struct DayCardView: View {
    let dia: DiaEntrenamiento
    let index: Int
    let isCompleted: Bool
    let onClick: () -> Void

    init(
        dia: DiaEntrenamiento,
        index: Int,
        isCompleted: Bool = false,
        onClick: @escaping () -> Void
    ) {
        self.dia = dia
        self.index = index
        self.isCompleted = isCompleted
        self.onClick = onClick
    }

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text(dia.id.replacingOccurrences(of: "_", with: " ").uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(6)

                    HStack(spacing: 4) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 10))
                        Text(dia.ubicacion)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray6))
                    .cornerRadius(6)

                    Spacer()

                    if isCompleted {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("LISTO")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .cornerRadius(12)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }

                Text(dia.nombre)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label("\(dia.bloques.count) bloques", systemImage: "square.stack.3d.up.fill")
                    if let cal = dia.calentamientoMinutos, cal > 0 {
                        Label("\(cal) min de calentamiento", systemImage: "flame.fill")
                    }
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isCompleted ? Color.green.opacity(0.3) : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(dia.nombre), \(dia.bloques.count) bloques\(isCompleted ? ", completado hoy" : "")")
    }
}
