import SwiftUI
import Combine

public struct ContentView: View {
    @StateObject private var timerManager = TimerManager()
    @StateObject private var watchConnector = WatchConnector.shared
    
    @State private var currentDate = Date()
    let redrawTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            // Cabecera
            VStack(spacing: 6) {
                Text("CardioFeliz")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(.green)
                
                Text("PROTOTIPO DE VALIDACIÓN — FASE 0")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .tracking(2)
            }
            .padding(.top, 30)
            
            // Estado de Conexión del Apple Watch
            HStack(spacing: 8) {
                Circle()
                    .fill(watchConnector.isWatchReachable ? Color.green : Color.orange)
                    .frame(width: 10, height: 10)
                
                Text(watchStatusText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(20)
            
            Spacer()
            
            // Visualización de Temporizador Activo
            if timerManager.isRunning {
                VStack(spacing: 16) {
                    Text("FASE \(timerManager.currentPhaseIndex + 1) DE \(timerManager.phases.count)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .tracking(3)
                    
                    Text(timerManager.phases[timerManager.currentPhaseIndex].name)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(phaseColor(for: timerManager.currentPhaseIndex))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    ZStack {
                        // Círculo de Fondo
                        Circle()
                            .stroke(Color(.systemGray6), lineWidth: 14)
                            .frame(width: 220, height: 220)
                        
                        // Círculo de Progreso
                        Circle()
                            .trim(from: 0.0, to: CGFloat(timerManager.progressInCurrentPhase(at: currentDate)))
                            .stroke(
                                phaseColor(for: timerManager.currentPhaseIndex),
                                style: StrokeStyle(lineWidth: 14, lineCap: .round)
                            )
                            .frame(width: 220, height: 220)
                            .rotationEffect(Angle(degrees: -90))
                            .animation(.linear(duration: 0.1), value: currentDate)
                        
                        // Cuenta Atrás Numérica
                        VStack(spacing: 4) {
                            Text(timeFormatter(timerManager.timeRemainingInCurrentPhase(at: currentDate)))
                                .font(.system(size: 54, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                            
                            if timerManager.isPaused {
                                Text("PAUSADO")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.orange)
                                    .tracking(2)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            } else {
                // Estado de Bienvenida antes de Iniciar
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.1))
                            .frame(width: 140, height: 140)
                        
                        Image(systemName: "bolt.heart.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                    }
                    
                    Text("Prototipo de 60 Segundos")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        
                    Text("Valida de forma gratuita:\n• Funcionamiento en segundo plano\n• Isla Dinámica / Live Activities\n• Pitidos con pantalla bloqueada\n• HKWorkoutSession en Apple Watch")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                        .padding(.horizontal, 24)
                }
                .padding(.vertical, 10)
            }
            
            Spacer()
            
            // Controles de Acción
            VStack(spacing: 12) {
                if !timerManager.isRunning {
                    Button(action: {
                        timerManager.start()
                    }) {
                        Text("Iniciar Prototipo")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(16)
                            .shadow(color: Color.green.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                } else {
                    HStack(spacing: 16) {
                        if timerManager.isPaused {
                            Button(action: {
                                timerManager.resume()
                            }) {
                                HStack {
                                    Image(systemName: "play.fill")
                                    Text("Reanudar")
                                }
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.green)
                                .cornerRadius(14)
                            }
                        } else {
                            Button(action: {
                                timerManager.pause()
                            }) {
                                HStack {
                                    Image(systemName: "pause.fill")
                                    Text("Pausar")
                                }
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.orange)
                                .cornerRadius(14)
                            }
                        }
                        
                        Button(action: {
                            timerManager.next()
                        }) {
                            HStack {
                                Image(systemName: "forward.fill")
                                Text("Siguiente")
                            }
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.blue)
                            .cornerRadius(14)
                        }
                    }
                    .padding(.horizontal, 24)
                    
                    Button(action: {
                        timerManager.stop()
                    }) {
                        Text("Detener y Reiniciar")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.red)
                            .padding(.vertical, 8)
                    }
                }
            }
            .padding(.bottom, 24)
        }
        .onReceive(redrawTimer) { _ in
            if timerManager.isRunning && !timerManager.isPaused {
                currentDate = Date()
            }
        }
    }
    
    private var watchStatusText: String {
        if watchConnector.isWatchReachable { return "Apple Watch Sincronizado" }
        if !watchConnector.isWatchPaired { return "Sin Apple Watch emparejado" }
        if !watchConnector.isWatchAppInstalled { return "App no instalada en el Apple Watch" }
        return "Apple Watch instalado (abre la app en el reloj)"
    }
    

    private func phaseColor(for index: Int) -> Color {
        switch index {
        case 0: return .yellow // Calentamiento (Amarillo)
        case 1: return .red    // Esfuerzo (Rojo)
        case 2: return .blue   // Descanso (Azul)
        default: return .green
        }
    }
    
    private func timeFormatter(_ interval: TimeInterval) -> String {
        let seconds = Int(ceil(interval))
        return String(format: "%02d s", seconds)
    }
}
