import SwiftUI

/// Galería de logros e insignias con filtros (Todos / Listos / Pendientes).
/// Equivale a `src/components/analytics/AchievementsGallery.tsx`.
struct AchievementsGalleryView: View {
    let achievements: [AchievementStatus]
    var unlockedAtMap: [String: String] = [:]

    @State private var filter: Filter = .all

    private enum Filter: String, CaseIterable {
        case all = "Todos"
        case unlocked = "Listos"
        case locked = "Pendientes"
    }

    private var unlockedCount: Int {
        achievements.filter(\.unlocked).count
    }

    private var filteredAchievements: [AchievementStatus] {
        achievements.filter { a in
            switch filter {
            case .all: return true
            case .unlocked: return a.unlocked
            case .locked: return !a.unlocked
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.yellow)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("LOGROS E INSIGNIAS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.secondary)

                        Text("\(unlockedCount) de \(achievements.count) desbloqueados")
                            .font(.system(size: 11))
                            .foregroundColor(Color(.tertiaryLabel))
                    }
                }

                Spacer()

                // Filter buttons
                HStack(spacing: 2) {
                    ForEach(Filter.allCases, id: \.self) { item in
                        Button {
                            filter = item
                        } label: {
                            Text(item.rawValue)
                                .font(.system(size: 10, weight: filter == item ? .bold : .medium))
                                .foregroundColor(filter == item ? .white : .secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(filter == item ? Color(.systemGray4) : Color.clear)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(2)
                .background(Color.black.opacity(0.4))
                .cornerRadius(8)
            }

            // List
            VStack(spacing: 8) {
                ForEach(filteredAchievements) { a in
                    let unlockDateFormatted: String? = {
                        guard let iso = unlockedAtMap[a.id],
                              let date = SupabaseDate.parse(iso) else { return nil }
                        let formatter = DateFormatter()
                        formatter.dateStyle = .short
                        return formatter.string(from: date)
                    }()

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .top, spacing: 10) {
                            // Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(a.unlocked ? Color.yellow.opacity(0.15) : Color(.tertiarySystemBackground))
                                    .frame(width: 32, height: 32)

                                Image(systemName: a.unlocked ? "checkmark.seal.fill" : "lock.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(a.unlocked ? .yellow : .secondary)
                            }

                            // Texts
                            VStack(alignment: .leading, spacing: 2) {
                                Text(a.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(a.unlocked ? Color.yellow.opacity(0.95) : .white)

                                Text(a.description)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)

                                if let unlockDateFormatted {
                                    Text("Desbloqueado el \(unlockDateFormatted)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(Color.yellow.opacity(0.7))
                                        .padding(.top, 1)
                                }
                            }

                            Spacer()

                            if !a.unlocked {
                                let curStr = a.target <= 1.0 ? String(format: "%.0f", a.current) : "\(Int(a.current))"
                                let tarStr = a.target <= 1.0 ? String(format: "%.0f", a.target) : "\(Int(a.target))"
                                Text("\(curStr) / \(tarStr)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Progress bar for locked achievements
                        if !a.unlocked && a.target > 1.0 {
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color(.tertiarySystemBackground))
                                        .frame(height: 5)

                                    let pct = min(1.0, max(0.0, a.current / a.target))
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.secondary)
                                        .frame(width: geo.size.width * pct, height: 5)
                                }
                            }
                            .frame(height: 5)
                        }
                    }
                    .padding(10)
                    .background(a.unlocked ? Color.yellow.opacity(0.05) : Color.black.opacity(0.35))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(a.unlocked ? Color.yellow.opacity(0.2) : Color.white.opacity(0.05), lineWidth: 1)
                    )
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}
