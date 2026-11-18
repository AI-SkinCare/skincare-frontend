import SafariServices
import SwiftUI

// MARK: - 토스트

private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let message {
                Text(message)
                    .appText(.bodySmall)
                    .foregroundStyle(.onPrimary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
                    .background(Color.ink, in: Capsule())
                    .padding(.bottom, Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(for: .seconds(2.5))
                        withAnimation { self.message = nil }
                    }
            }
        }
        .animation(.default, value: message)
    }
}

extension View {
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

// MARK: - 알림 다이얼로그

struct AlertItem: Identifiable, Equatable {
    let id = UUID()
    var title: String = ""
    let message: String
}

extension View {
    func alert(_ item: Binding<AlertItem?>) -> some View {
        alert(
            item.wrappedValue?.title ?? "",
            isPresented: Binding(get: { item.wrappedValue != nil }, set: { if !$0 { item.wrappedValue = nil } }),
            presenting: item.wrappedValue
        ) { _ in
            Button("확인", role: .cancel) {}
        } message: { alert in
            Text(alert.message)
        }
    }
}

// MARK: - 사파리 (개인정보 처리방침)

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
