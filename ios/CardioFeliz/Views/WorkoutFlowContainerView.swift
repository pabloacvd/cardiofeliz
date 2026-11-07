import SwiftUI

struct WorkoutFlowContainerView: View {
    @ObservedObject var workflow: WorkoutWorkflowViewModel
    @ObservedObject var activityStore: ActivityStore
    @ObservedObject var weightStore: ProfileWeightStore
    @ObservedObject var routineStore: RoutineStore
    @ObservedObject var vacationsStore: VacationsStore
    @ObservedObject var achievementsStore: AchievementsStore
    @ObservedObject var session: SessionManager
    @ObservedObject private var watchSummaries = WatchSummaryStore.shared

    init(
        workflow: WorkoutWorkflowViewModel,
        activityStore: ActivityStore,
        weightStore: ProfileWeightStore,
        routineStore: RoutineStore,
        vacationsStore: VacationsStore,
        achievementsStore: AchievementsStore,
        session: SessionManager
    ) {
        self.workflow = workflow
        self.activityStore = activityStore
        self.weightStore = weightStore
        self.routineStore = routineStore
        self.vacationsStore = vacationsStore
        self.achievementsStore = achievementsStore
        self.session = session
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            Group {
                switch workflow.destination {
                case .home:
                    HomeView(
                        workflow: workflow,
                        activityStore: activityStore,
                        weightStore: weightStore,
                        vacationsStore: vacationsStore,
                        achievementsStore: achievementsStore,
                        session: session
                    )
                case .dayDetail(let dia):
                    DayDetailView(
                        dia: dia,
                        workflow: workflow
                    )
                case .warmup(let dia):
                    WarmupView(
                        dia: dia,
                        workflow: workflow
                    )
                case .blockDetail(let dia, let bloque):
                    BlockDetailView(
                        dia: dia,
                        bloque: bloque,
                        workflow: workflow
                    )
                case .activeWorkout(let dia, let bloque):
                    ActiveWorkoutView(
                        dia: dia,
                        bloque: bloque,
                        workflow: workflow,
                        activityStore: activityStore,
                        weightStore: weightStore
                    )
                case .routineEditor:
                    let username: String = {
                        if case .signedIn(_, let name) = session.state { return name }
                        return "Usuario"
                    }()
                    RoutineEditorView(
                        routineStore: routineStore,
                        workflow: workflow,
                        username: username,
                        onDismiss: {
                            workflow.goHome()
                        }
                    )
                case .analytics:
                    AnalyticsView(
                        activityStore: activityStore,
                        weightStore: weightStore,
                        vacationsStore: vacationsStore,
                        achievementsStore: achievementsStore,
                        session: session,
                        onBack: {
                            workflow.goHome()
                        }
                    )
                }
            }

            // Completion Modal Overlay
            if let modalData = workflow.completedModalData {
                let currentDia: DiaEntrenamiento = {
                    switch workflow.destination {
                    case .dayDetail(let d), .warmup(let d), .blockDetail(let d, _), .activeWorkout(let d, _):
                        return d
                    case .home, .routineEditor, .analytics:
                        return workflow.rutina.diasEntrenamiento.first ?? DiaEntrenamiento(
                            id: "dia_1",
                            nombre: "Día 1",
                            ubicacion: "Gimnasio",
                            calentamiento: "",
                            calentamientoMinutos: 0,
                            bloques: []
                        )
                    }
                }()

                WorkoutCompleteModalView(
                    data: modalData,
                    watchSummary: modalData.watchSessionId.flatMap { watchSummaries.summaries[$0] },
                    onNextBlock: {
                        workflow.proceedToNextBlock(dia: currentDia)
                    },
                    onBackToDay: {
                        workflow.dismissCompleteModal(dia: currentDia)
                    }
                )
                .transition(.opacity)
            }

            // Celebration Toasts Overlay
            CelebrationToastStackView()
        }
        .preferredColorScheme(.dark)
        .onReceive(routineStore.$rutina) { newRoutine in
            workflow.setRoutine(newRoutine)
        }
        // El resumen del último bloque llega después de guardar el día: ajusta las calorías al recibirlo.
        .onReceive(watchSummaries.$summaries) { summaries in
            workflow.applyWatchSummaries(summaries, activityStore: activityStore, weightKg: weightStore.weightKg)
        }
        #if DEBUG
        .onAppear {
            if let dia = workflow.rutina.diasEntrenamiento.first {
                workflow.destination = .dayDetail(dia)
            }
        }
        #endif
    }
}
