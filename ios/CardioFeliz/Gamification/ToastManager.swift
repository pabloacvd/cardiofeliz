import Foundation
import SwiftUI

enum ToastKind: String, Sendable {
    case achievement
    case level
    case freeze
}

struct ToastItem: Identifiable, Equatable, Sendable {
    var id: String
    var kind: ToastKind
    var title: String
    var detail: String

    init(id: String, kind: ToastKind, title: String, detail: String) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
    }
}

@MainActor
final class ToastManager: ObservableObject {
    static let shared = ToastManager()
    @Published var toasts: [ToastItem] = []

    init() {}

    func push(_ item: ToastItem) {
        toasts.append(item)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            self?.dismiss(id: item.id)
        }
    }

    func push(outcome: LogOutcome, claimedIds: [String]) {
        let claimedSet = Set(claimedIds)
        if outcome.leveledUp {
            push(ToastItem(
                id: "level-\(outcome.levelAfter)",
                kind: .level,
                title: "¡Nivel \(outcome.levelAfter)!",
                detail: outcome.tierName
            ))
        }
        for a in outcome.newAchievements where claimedSet.contains(a.id) {
            push(ToastItem(
                id: "achievement-\(a.id)",
                kind: .achievement,
                title: "Logro: \(a.title)",
                detail: a.description
            ))
        }
        if outcome.earnedFreeze {
            push(ToastItem(
                id: "freeze-\(outcome.streakAfter)",
                kind: .freeze,
                title: "Ganaste un congelador",
                detail: "Protege tu racha si algún día no podés entrenar."
            ))
        }
    }

    func dismiss(id: String) {
        withAnimation {
            toasts.removeAll { $0.id == id }
        }
    }
}
