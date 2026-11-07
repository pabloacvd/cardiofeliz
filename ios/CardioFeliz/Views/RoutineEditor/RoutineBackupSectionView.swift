import SwiftUI

struct RoutineBackupSectionView: View {
    let draft: RutinaData
    let username: String
    let isCustom: Bool
    let onLoadDraft: (RutinaData) -> Void
    let onRestoreDefault: () -> Void

    @State private var isShowingPasteArea: Bool = false
    @State private var pastedText: String = ""
    @State private var importErrors: [String] = []
    @State private var pendingImportRoutine: RutinaData? = nil
    @State private var showingImportConfirmAlert: Bool = false
    @State private var showingRestoreConfirmAlert: Bool = false
    @State private var copiedToClipboard: Bool = false

    private var isDefaultAlready: Bool {
        RoutineImportExport.isDefaultRoutine(draft)
    }

    private var serializedJson: String {
        (try? RoutineImportExport.serializeRoutine(draft)) ?? "{}"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("COPIA DE SEGURIDAD Y RESTAURACIÓN")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 16) {
                // Exportar
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exportar Rutina")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Guarda una copia de tu rutina actual en formato JSON.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        Button {
                            UIPasteboard.general.string = serializedJson
                            copiedToClipboard = true
                            Task {
                                try? await Task.sleep(for: .seconds(2))
                                copiedToClipboard = false
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: copiedToClipboard ? "checkmark" : "doc.on.doc")
                                Text(copiedToClipboard ? "¡Copiado!" : "Copiar JSON")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        ShareLink(
                            item: serializedJson,
                            preview: SharePreview("rutina-cardiofeliz.json", image: Image(systemName: "doc.text"))
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Compartir")
                            }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Importar
                VStack(alignment: .leading, spacing: 8) {
                    Text("Importar Rutina")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Pega el JSON de una rutina exportada para cargarla como borrador.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Button {
                        withAnimation {
                            isShowingPasteArea.toggle()
                        }
                    } label: {
                        HStack {
                            Image(systemName: isShowingPasteArea ? "chevron.up" : "square.and.arrow.down")
                            Text(isShowingPasteArea ? "Ocultar área de texto" : "Pegar JSON...")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)

                    if isShowingPasteArea {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $pastedText)
                                .font(.system(size: 11, design: .monospaced))
                                .frame(height: 120)
                                .padding(6)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)

                            if !importErrors.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Errores encontrados:")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.red)

                                    ForEach(importErrors.prefix(5), id: \.self) { err in
                                        Text("• \(err)")
                                            .font(.system(size: 10))
                                            .foregroundColor(.red.opacity(0.9))
                                    }

                                    if importErrors.count > 5 {
                                        Text("…y \(importErrors.count - 5) errores más.")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.red.opacity(0.8))
                                    }
                                }
                                .padding(8)
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(6)
                            }

                            Button {
                                importErrors = []
                                let result = RoutineImportExport.parseImportedRoutine(text: pastedText, usuario: username)
                                switch result {
                                case .success(let routine):
                                    pendingImportRoutine = routine
                                    showingImportConfirmAlert = true
                                case .failure(let errors):
                                    importErrors = errors
                                }
                            } label: {
                                Text("Validar y Cargar Borrador")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(Color.green)
                                    .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                            .disabled(pastedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .padding(.top, 4)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // Restaurar por defecto
                VStack(alignment: .leading, spacing: 8) {
                    Text("Restaurar Original")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Vuelve a la rutina por defecto de CardioFeliz.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Button {
                        showingRestoreConfirmAlert = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Restaurar Rutina por Defecto")
                        }
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isDefaultAlready ? .secondary : .red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(isDefaultAlready ? Color.clear : Color.red.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isDefaultAlready ? Color.secondary.opacity(0.3) : Color.red.opacity(0.4), lineWidth: 1)
                        )
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDefaultAlready)
                }
            }
            .padding(14)
            .background(Color(.systemBackground).opacity(0.6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .alert("¿Reemplazar borrador con la rutina importada?", isPresented: $showingImportConfirmAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Cargar Borrador") {
                if let r = pendingImportRoutine {
                    onLoadDraft(r)
                    pastedText = ""
                    isShowingPasteArea = false
                }
            }
        } message: {
            Text("Se reemplazará el borrador actual con la rutina importada. Para aplicar los cambios deberás presionar 'Guardar'.")
        }
        .alert("¿Restaurar rutina original?", isPresented: $showingRestoreConfirmAlert) {
            Button("Cancelar", role: .cancel) {}
            Button("Restaurar", role: .destructive) {
                onRestoreDefault()
            }
        } message: {
            Text("Se cargará la rutina original en el borrador. Para aplicar los cambios deberás presionar 'Guardar'.")
        }
    }
}
