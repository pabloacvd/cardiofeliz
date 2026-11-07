import SwiftUI

struct WeightSheetView: View {
    let initialKg: Double?
    let skipLabel: String?
    let onSave: (Double) -> Void
    let onSkip: (() -> Void)?
    let onClose: () -> Void

    @State private var text: String
    @State private var errorMessage: String?

    init(
        initialKg: Double?,
        skipLabel: String? = nil,
        onSave: @escaping (Double) -> Void,
        onSkip: (() -> Void)? = nil,
        onClose: @escaping () -> Void
    ) {
        self.initialKg = initialKg
        self.skipLabel = skipLabel
        self.onSave = onSave
        self.onSkip = onSkip
        self.onClose = onClose
        _text = State(initialValue: initialKg != nil ? String(format: "%.1f", initialKg!).replacingOccurrences(of: ".", with: ",") : "")
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Lo usamos solo para estimar las calorías de tus entrenamientos y corridas. Es una estimación y la pedimos una sola vez; podés cambiarla cuando quieras.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .lineSpacing(2)

                VStack(alignment: .leading, spacing: 8) {
                    Text("PESO (KG)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.secondary)

                    TextField("Ej: 62,5", text: $text)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 18, weight: .bold))
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(errorMessage != nil ? Color.red : Color(.separator), lineWidth: 1)
                        )
                        .onChange(of: text) { _, _ in
                            errorMessage = nil
                        }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red)
                    }
                }

                Spacer()

                VStack(spacing: 10) {
                    Button(action: save) {
                        Text("Guardar peso")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.green)
                            .cornerRadius(14)
                    }

                    if let skipLabel, let onSkip {
                        Button(action: onSkip) {
                            Text(skipLabel)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(20)
            .navigationTitle("Tu peso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", action: onClose)
                }
            }
        }
    }

    private func save() {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard let value = Double(clean), let sanitized = CaloriesEstimator.sanitizeWeight(value) else {
            errorMessage = "Ingresá un peso entre 20 y 300 kg."
            return
        }
        onSave(sanitized)
    }
}
