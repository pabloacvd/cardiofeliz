import SwiftUI

struct RunFormFields: Equatable {
    var minutes: String
    var km: String
    var location: RunLocation?
    var feeling: Int?
    var date: Date

    init(
        minutes: String = "30",
        km: String = "",
        location: RunLocation? = nil,
        feeling: Int? = nil,
        date: Date = Date()
    ) {
        self.minutes = minutes
        self.km = km
        self.location = location
        self.feeling = feeling
        self.date = date
    }
}

struct RunSheetView: View {
    let title: String
    let submitLabel: String
    let initial: RunFormFields
    let onSubmit: (ActivityDraft) -> Void
    let onClose: () -> Void

    @State private var minutes: String
    @State private var km: String
    @State private var location: RunLocation?
    @State private var feeling: Int?
    @State private var date: Date

    @State private var minutesError: String?
    @State private var kmError: String?
    @State private var dateError: String?

    init(
        title: String = "Registrar corrida",
        submitLabel: String = "Guardar corrida",
        initial: RunFormFields = RunFormFields(),
        onSubmit: @escaping (ActivityDraft) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.submitLabel = submitLabel
        self.initial = initial
        self.onSubmit = onSubmit
        self.onClose = onClose

        _minutes = State(initialValue: initial.minutes)
        _km = State(initialValue: initial.km)
        _location = State(initialValue: initial.location)
        _feeling = State(initialValue: initial.feeling)
        _date = State(initialValue: initial.date)
    }

    private let feelings: [(value: Int, emoji: String, label: String)] = [
        (1, "😣", "Muy pesado"),
        (2, "😕", "Pesado"),
        (3, "😐", "Normal"),
        (4, "🙂", "Bien"),
        (5, "🤩", "Excelente")
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("MINUTOS")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("30", text: $minutes)
                                .keyboardType(.numberPad)
                                .font(.system(size: 17, weight: .semibold))
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: minutes) { _, _ in minutesError = nil }
                            if let minutesError {
                                Text(minutesError)
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text("KM (OPCIONAL)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                            TextField("Ej: 4,5", text: $km)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 17, weight: .semibold))
                                .textFieldStyle(.roundedBorder)
                                .onChange(of: km) { _, _ in kmError = nil }
                            if let kmError {
                                Text(kmError)
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }

                Section("Dónde corriste (opcional)") {
                    HStack(spacing: 12) {
                        locationButton(for: .cinta, label: "Cinta")
                        locationButton(for: .calle, label: "Calle")
                    }
                    .padding(.vertical, 4)
                }

                Section("Cómo te sentiste (opcional)") {
                    HStack(spacing: 8) {
                        ForEach(feelings, id: \.value) { f in
                            Button {
                                if feeling == f.value {
                                    feeling = nil
                                } else {
                                    feeling = f.value
                                }
                            } label: {
                                Text(f.emoji)
                                    .font(.system(size: 24))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 8)
                                    .background(feeling == f.value ? Color.green.opacity(0.2) : Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(feeling == f.value ? Color.green : Color.clear, lineWidth: 2)
                                    )
                                    .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(f.value) de 5: \(f.label)")
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Fecha") {
                    DatePicker(
                        "Fecha de la corrida",
                        selection: $date,
                        in: Calendar.current.date(byAdding: .day, value: -30, to: Date())!...Date(),
                        displayedComponents: .date
                    )
                    if let dateError {
                        Text(dateError)
                            .font(.system(size: 11))
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button(action: submit) {
                        Text(submitLabel)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar", action: onClose)
                }
            }
        }
    }

    private func locationButton(for loc: RunLocation, label: String) -> some View {
        Button {
            if location == loc {
                location = nil
            } else {
                location = loc
            }
        } label: {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(location == loc ? .green : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(location == loc ? Color.green.opacity(0.15) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(location == loc ? Color.green : Color.clear, lineWidth: 1.5)
                )
                .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        let minsClean = minutes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let mins = Int(minsClean), mins >= 1, mins <= 300 else {
            minutesError = "Ingresá minutos enteros entre 1 y 300."
            return
        }

        var parsedKm: Double? = nil
        let kmClean = km.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        if !kmClean.isEmpty {
            guard let val = Double(kmClean), val >= 0.1, val <= 100.0 else {
                kmError = "Ingresá km entre 0.1 y 100 (o dejalo vacío)."
                return
            }
            parsedKm = (val * 100).rounded() / 100
        }

        let occurredOn = ActivityValidation.localDay(date)
        let isToday = occurredOn == ActivityValidation.localDay(Date())
        let startedAt = isToday ? Date() : nil

        let draft = ActivityDraft(
            type: .run,
            occurredOn: occurredOn,
            startedAt: startedAt,
            durationSeconds: mins * 60,
            distanceKm: parsedKm,
            runLocation: location,
            feeling: feeling
        )

        onSubmit(draft)
    }
}
