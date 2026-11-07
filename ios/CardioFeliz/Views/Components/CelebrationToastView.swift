import SwiftUI

/// Pila de toasts flotantes de celebración.
public struct CelebrationToastStackView: View {
    @ObservedObject var toastManager = ToastManager.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 8) {
            ForEach(toastManager.toasts) { toast in
                HStack(spacing: 12) {
                    // Icon
                    ZStack {
                        Circle()
                            .fill(toastColor(toast.kind).opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: toastIcon(toast.kind))
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(toastColor(toast.kind))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(toast.title)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)

                        Text(toast.detail)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button {
                        toastManager.dismiss(id: toast.id)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.black.opacity(0.9))
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(toastColor(toast.kind).opacity(0.4), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.spring(), value: toastManager.toasts)
    }

    private func toastIcon(_ kind: ToastKind) -> String {
        switch kind {
        case .achievement: return "medal.fill"
        case .level: return "sparkles"
        case .freeze: return "snowflake"
        }
    }

    private func toastColor(_ kind: ToastKind) -> Color {
        switch kind {
        case .achievement: return .yellow
        case .level: return .green
        case .freeze: return .cyan
        }
    }
}
