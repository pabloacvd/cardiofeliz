import SwiftUI

struct HomeView: View {
    @ObservedObject var workflow: WorkoutWorkflowViewModel
    @ObservedObject var activityStore: ActivityStore
    @ObservedObject var weightStore: ProfileWeightStore
    @ObservedObject var vacationsStore: VacationsStore
    @ObservedObject var achievementsStore: AchievementsStore
    @ObservedObject var session: SessionManager

    @State private var isCoachDismissed: Bool = false
    @State private var isVacationSheetOpen: Bool = false

    private var today: String {
        ActivityValidation.localDay(Date())
    }

    private var userName: String {
        if case .signedIn(_, let name) = session.state { return name }
        return "Usuario"
    }

    private var context: GameContext {
        GameContext(
            activities: activityStore.activities,
            vacations: vacationsStore.vacations,
            today: today,
            weightKg: weightStore.weightKg,
            displayName: userName
        )
    }

    private var game: GameSummary {
        GameEngine.computeGameSummary(input: context)
    }

    private var coachDismissalKey: String {
        let userId = session.state.userId ?? "local"
        return "coach_dismissed_\(userId)_\(today)"
    }

    init(
        workflow: WorkoutWorkflowViewModel,
        activityStore: ActivityStore,
        weightStore: ProfileWeightStore,
        vacationsStore: VacationsStore,
        achievementsStore: AchievementsStore,
        session: SessionManager
    ) {
        self.workflow = workflow
        self.activityStore = activityStore
        self.weightStore = weightStore
        self.vacationsStore = vacationsStore
        self.achievementsStore = achievementsStore
        self.session = session
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                // Header Bar
                HomeHeaderBar(
                    session: session,
                    activityStore: activityStore,
                    onOpenAnalytics: {
                        workflow.openAnalytics()
                    }
                )

                // Coach Card
                if !isCoachDismissed {
                    CoachCardView(
                        coach: game.coach,
                        mascotStage: game.mascot.stage,
                        mascotName: game.mascot.name,
                        onDismiss: {
                            isCoachDismissed = true
                            UserDefaults.standard.set(true, forKey: coachDismissalKey)
                        }
                    )
                }

                // Game Status (Streak, Level/XP, Rings)
                GameStatusView(
                    game: game,
                    onOpenVacations: {
                        isVacationSheetOpen = true
                    }
                )

                // Daily Missions
                DailyMissionsCardView(missions: game.missions)

                // Weekly Challenge
                WeeklyChallengeCardView(challenge: game.challenge)

                // Days List Section
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("SELECCIONA TU ENTRENAMIENTO DE HOY:")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.secondary)

                        Spacer()

                        let count = workflow.rutina.diasEntrenamiento.count
                        Text("\(count) \(count == 1 ? "día disponible" : "días disponibles")")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                    .padding(.horizontal, 4)

                    VStack(spacing: 12) {
                        ForEach(workflow.rutina.diasEntrenamiento.indices, id: \.self) { idx in
                            let dia = workflow.rutina.diasEntrenamiento[idx]
                            let isDone = WorkoutDayProgress.isDayFinished(dia: dia, progress: workflow.blockProgress)

                            DayCardView(
                                dia: dia,
                                index: idx,
                                isCompleted: isDone
                            ) {
                                workflow.selectDay(dia)
                            }
                        }
                    }
                }

                // Quick Log Card
                QuickLogCardView(
                    activityStore: activityStore,
                    weightStore: weightStore,
                    vacations: vacationsStore.vacations,
                    achievementsStore: achievementsStore,
                    displayName: userName
                )

                // Botón "Mi Rutina" (espejo de la PWA al final de Home)
                Button {
                    workflow.openRoutineEditor()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                            .frame(width: 40, height: 40)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(10)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Mi Rutina")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)

                            Text("Personaliza días, bloques, tiempos y ejercicios")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(16)
        }
        .background(Color.black.ignoresSafeArea())
        .onAppear {
            isCoachDismissed = UserDefaults.standard.bool(forKey: coachDismissalKey)
        }
        .sheet(isPresented: $isVacationSheetOpen) {
            VacationSheetView(
                vacationsStore: vacationsStore,
                status: game.vacation,
                today: today,
                onClose: { isVacationSheetOpen = false }
            )
        }
    }
}

private struct HomeHeaderBar: View {
    @ObservedObject var session: SessionManager
    @ObservedObject var activityStore: ActivityStore
    @ObservedObject var soundManager = SoundManager.shared
    let onOpenAnalytics: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Mute Button
            Button {
                soundManager.toggleMute()
            } label: {
                Image(systemName: soundManager.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(soundManager.isMuted ? .red : .green)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(soundManager.isMuted ? "Sonido silenciado" : "Sonido activado")

            // User & Sync info
            VStack(alignment: .leading, spacing: 1) {
                if case .signedIn(_, let username) = session.state {
                    Text(username)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(syncColor)
                        .frame(width: 6, height: 6)
                    Text(syncLabel)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Analytics button
            Button {
                onOpenAnalytics()
            } label: {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Analíticas y Progreso")

            // Manual sync button
            Button {
                activityStore.trySync()
            } label: {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .disabled(activityStore.syncStatus == .syncing)
            .accessibilityLabel("Sincronizar")

            // Sign out button
            Button {
                Task { await session.signOut() }
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 36, height: 36)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(10)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cerrar sesión")
        }
        .padding(.vertical, 4)
    }

    private var syncColor: Color {
        switch activityStore.syncStatus {
        case .synced: return .green
        case .syncing: return .blue
        case .pending: return .orange
        case .offline: return .red
        }
    }

    private var syncLabel: String {
        switch activityStore.syncStatus {
        case .synced: return "Sincronizado"
        case .syncing: return "Sincronizando…"
        case .pending: return "\(activityStore.pendingCount) pendiente(s)"
        case .offline: return "Sin conexión"
        }
    }
}
