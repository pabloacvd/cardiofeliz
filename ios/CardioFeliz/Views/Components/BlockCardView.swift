import SwiftUI

struct BlockCardView: View {
    let bloque: Bloque
    let index: Int
    let isCompleted: Bool
    let onClick: () -> Void

    init(
        bloque: Bloque,
        index: Int,
        isCompleted: Bool = false,
        onClick: @escaping () -> Void
    ) {
        self.bloque = bloque
        self.index = index
        self.isCompleted = isCompleted
        self.onClick = onClick
    }

    var body: some View {
        Button(action: onClick) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    BlockBadgeView(tipo: bloque.tipo)

                    let meta = BlockMetaHelper.meta(for: bloque)
                    if !meta.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(meta)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color(.systemGray6))
                        .cornerRadius(6)
                    }

                    Spacer()

                    if isCompleted {
                        Text("COMPLETADO")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.15))
                            .cornerRadius(10)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }

                Text(bloque.nombre)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                if !bloque.ejercicios.isEmpty {
                    Text("\(bloque.ejercicios.count) \(bloque.ejercicios.count == 1 ? "ejercicio" : "ejercicios") · \(bloque.ejercicios.prefix(2).map(\.detalle).joined(separator: ", "))\(bloque.ejercicios.count > 2 ? "..." : "")")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isCompleted ? Color.green.opacity(0.3) : Color(.separator), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
