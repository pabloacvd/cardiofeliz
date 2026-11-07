import SwiftUI

struct QuickLogCardView: View {
    @ObservedObject var activityStore: ActivityStore
    @ObservedObject var weightStore: ProfileWeightStore
    var vacations: [VacationPeriod] = []
    var achievementsStore: AchievementsStore? = nil
    var displayName: String? = nil

    let today: String
    let weeklyRunsGoal: Int

    @State private var showingRunSheet: Bool = false
    @State private var showingAdjustSheet: Bool = false
    @State private var showingWeightSheet: Bool = false
    @State private var pendingAction: QuickAction?
    @State private var confirmDuplicate: QuickAction?
    @State private var lastResult: (activity: ActivityRecord, kind: QuickAction)?

    enum QuickAction: Equatable {
        case quickRun
        case activeRest
    }

    init(
        activityStore: ActivityStore,
        weightStore: ProfileWeightStore,
        vacations: [VacationPeriod] = [],
        achievementsStore: AchievementsStore? = nil,
        displayName: String? = nil,
        today: String = ActivityValidation.localDay(Date()),
        weeklyRunsGoal: Int = 2
    ) {
        self.activityStore = activityStore
        self.weightStore = weightStore
        self.vacations = vacations
        self.achievementsStore = achievementsStore
        self.displayName = displayName
        self.today = today
        self.weeklyRunsGoal = weeklyRunsGoal
    }

    private var currentWeekRunsCount: Int {
        let calendar = Calendar.current
        let todayDate = Date()
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: todayDate) else { return 0 }
        let startString = ActivityValidation.localDay(weekInterval.start)
        let endString = ActivityValidation.localDay(weekInterval.end)

        return activityStore.activities.filter {
            $0.type == .run && $0.occurredOn >= startString && $0.occurredOn <= endString
        }.count
    }

    private var runsToday: Int {
        activityStore.activities.filter { $0.type == .run && $0.occurredOn == today }.count
    }

    private var restToday: Bool {
        activityStore.activities.contains { $0.type == .activeRest && $0.occurredOn == today }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "figure.run")
                        .foregroundColor(.cyan)
                    Text("CORRIDAS DE LA SEMANA")
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundColor(.cyan)
                }

                Spacer()

                Text("\(currentWeekRunsCount)/\(weeklyRunsGoal)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }

            Text(currentWeekRunsCount >= weeklyRunsGoal
                 ? "¡Meta de corridas cumplida esta semana!"
                 : "Tu meta son \(weeklyRunsGoal) corridas por semana. Te \(weeklyRunsGoal - currentWeekRunsCount == 1 ? "falta 1" : "faltan \(weeklyRunsGoal - currentWeekRunsCount)").")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineSpacing(2)

            // Main CTA
            Button {
                triggerAction(.quickRun)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "figure.run")
                    Text("Hoy corrí (30 min)")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.cyan, Color.green],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(14)
                .shadow(color: Color.cyan.opacity(0.2), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)

            // Secondary Buttons
            HStack(spacing: 10) {
                Button {
                    lastResult = nil
                    showingRunSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Con detalles")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)

                Button {
                    triggerAction(.activeRest)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(.green)
                        Text("Descanso activo")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
                }
                .buttonStyle(.plain)
            }

            // Weight access
            Button {
                pendingAction = nil
                showingWeightSheet = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 10))
                    if let weight = weightStore.weightKg {
                        Text("Peso: \(String(format: "%.1f", weight).replacingOccurrences(of: ".", with: ",")) kg · editar")
                    } else {
                        Text("Cargar mi peso para estimar calorías")
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)

            // Duplicate confirmation dialog
            if let confirm = confirmDuplicate {
                VStack(alignment: .leading, spacing: 10) {
                    Text(confirm == .quickRun
                         ? "Ya registraste una corrida hoy. ¿Registrar otra?"
                         : "Ya registraste un descanso activo hoy. ¿Registrar otro igual?")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.orange)

                    HStack(spacing: 10) {
                        Button("No, gracias") {
                            confirmDuplicate = nil
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)

                        Button("Sí, registrar") {
                            executeAction(confirm)
                            confirmDuplicate = nil
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 14)
                        .background(Color.orange)
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.3), lineWidth: 1))
            }

            // Result banner with Undo & Adjust
            if let result = lastResult {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.green)
                        Text(result.kind == .quickRun ? "¡Corrida registrada!" : "¡Descanso activo registrado!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    }

                    if let kcal = result.activity.caloriesKcal {
                        Text("~\(Int(kcal)) kcal (estimado)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 10) {
                        if result.kind == .quickRun {
                            Button("Ajustar") {
                                showingAdjustSheet = true
                            }
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }

                        Button("Deshacer") {
                            activityStore.removeActivity(id: result.activity.id)
                            lastResult = nil
                        }
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.red)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 12)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.green.opacity(0.3), lineWidth: 1))
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.cyan.opacity(0.3), lineWidth: 1))
        .sheet(isPresented: $showingWeightSheet) {
            WeightSheetView(
                initialKg: weightStore.weightKg,
                skipLabel: pendingAction != nil ? "Ahora no, guardar sin calorías" : nil,
                onSave: { kg in
                    weightStore.setWeightKg(kg)
                    activityStore.fillMissingCalories(weightKg: kg)
                    showingWeightSheet = false
                    if let pending = pendingAction {
                        executeAction(pending)
                        pendingAction = nil
                    }
                },
                onSkip: {
                    weightStore.dismissPrompt()
                    showingWeightSheet = false
                    if let pending = pendingAction {
                        executeAction(pending)
                        pendingAction = nil
                    }
                },
                onClose: {
                    showingWeightSheet = false
                    pendingAction = nil
                }
            )
        }
        .sheet(isPresented: $showingRunSheet) {
            RunSheetView(
                title: "Registrar corrida",
                submitLabel: "Guardar corrida",
                onSubmit: { draft in
                    showingRunSheet = false
                    let beforeCtx = GameContext(
                        activities: activityStore.activities,
                        vacations: vacations,
                        today: today,
                        weightKg: weightStore.weightKg,
                        displayName: displayName
                    )
                    if let saved = try? activityStore.addActivity(draft, options: AddActivityOptions(weightKg: weightStore.weightKg, vacations: vacations)) {
                        SoundManager.shared.playVictory()
                        lastResult = (saved, .quickRun)
                        celebrateOutcome(beforeCtx: beforeCtx, saved: saved)
                    }
                },
                onClose: {
                    showingRunSheet = false
                }
            )
        }
        .sheet(isPresented: $showingAdjustSheet) {
            if let result = lastResult {
                let initial = RunFormFields(
                    minutes: String(max(1, result.activity.durationSeconds / 60)),
                    km: result.activity.distanceKm != nil ? String(format: "%.2f", result.activity.distanceKm!) : "",
                    location: result.activity.runLocation,
                    feeling: result.activity.feeling,
                    date: SupabaseDate.parse(result.activity.occurredOn) ?? Date()
                )
                RunSheetView(
                    title: "Ajustar corrida",
                    submitLabel: "Guardar cambios",
                    initial: initial,
                    onSubmit: { patchDraft in
                        showingAdjustSheet = false
                        if let updated = try? activityStore.updateActivity(
                            id: result.activity.id,
                            patch: { current in
                                current.durationSeconds = patchDraft.durationSeconds
                                current.distanceKm = patchDraft.distanceKm
                                current.runLocation = patchDraft.runLocation
                                current.feeling = patchDraft.feeling
                                current.occurredOn = patchDraft.occurredOn
                            },
                            options: AddActivityOptions(weightKg: weightStore.weightKg)
                        ) {
                            lastResult = (updated, .quickRun)
                        }
                    },
                    onClose: {
                        showingAdjustSheet = false
                    }
                )
            }
        }
    }

    private func triggerAction(_ action: QuickAction) {
        let isDuplicate = (action == .quickRun) ? (runsToday > 0) : restToday
        if isDuplicate {
            confirmDuplicate = action
            return
        }

        if weightStore.weightKg == nil && weightStore.isLoaded && !weightStore.promptDismissed {
            pendingAction = action
            showingWeightSheet = true
            return
        }

        executeAction(action)
    }

    private func executeAction(_ action: QuickAction) {
        let draft: ActivityDraft
        if action == .quickRun {
            draft = ActivityDraft(
                type: .run,
                occurredOn: today,
                startedAt: Date(),
                durationSeconds: 30 * 60
            )
        } else {
            draft = ActivityDraft(
                type: .activeRest,
                occurredOn: today,
                startedAt: Date(),
                durationSeconds: 10 * 60
            )
        }

        let beforeCtx = GameContext(
            activities: activityStore.activities,
            vacations: vacations,
            today: today,
            weightKg: weightStore.weightKg,
            displayName: displayName
        )
        if let saved = try? activityStore.addActivity(draft, options: AddActivityOptions(weightKg: weightStore.weightKg, vacations: vacations)) {
            SoundManager.shared.playVictory()
            lastResult = (saved, action)
            celebrateOutcome(beforeCtx: beforeCtx, saved: saved)
        }
    }

    private func celebrateOutcome(beforeCtx: GameContext, saved: ActivityRecord) {
        let afterCtx = GameOutcome.withActivity(ctx: beforeCtx, activity: saved)
        let outcome = GameOutcome.logOutcome(before: beforeCtx, after: afterCtx)
        let rawIds = outcome.newAchievements.map { $0.id }
        let claimed = achievementsStore?.claimNew(ids: rawIds) ?? rawIds
        ToastManager.shared.push(outcome: outcome, claimedIds: claimed)
    }
}
