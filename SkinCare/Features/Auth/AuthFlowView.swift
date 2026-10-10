import SwiftUI

/// 비로그인 화면 흐름: 로그인(SCR-01) → 회원가입(SCR-02)
struct AuthFlowView: View {
    @State private var showsSignup = false
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            LoginView(showsSignup: $showsSignup)
                .navigationDestination(isPresented: $showsSignup) {
                    SignupView { message in
                        showsSignup = false
                        toast = message
                    }
                }
        }
        .toast($toast)
    }
}

// MARK: - SCR-01 로그인

struct LoginView: View {
    @Binding var showsSignup: Bool
    @Environment(SessionStore.self) private var session

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?
    @State private var isSubmitting = false

    private var canSubmit: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("피부 상태를 숫자로 확인해요.")
                        .appText(.heading3)
                        .foregroundStyle(.ink)
                    Text("사진 한 장으로 수분·탄력·색소침착·모공을 측정해요.")
                        .appText(.bodyLarge)
                        .foregroundStyle(.textMuted)
                }
                .padding(.top, Spacing.xxl)

                VStack(spacing: Spacing.sm) {
                    AppTextField(placeholder: "이메일", text: $email, keyboard: .emailAddress, contentType: .username)
                    AppTextField(placeholder: "비밀번호", text: $password, isSecure: true, contentType: .password)
                    if let errorMessage {
                        Text(errorMessage)
                            .appText(.bodySmall)
                            .foregroundStyle(.gradeCare)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                VStack(spacing: Spacing.sm) {
                    Button(isSubmitting ? "로그인 중…" : "로그인") { Task { await submit() } }
                        .buttonStyle(.primary)
                        .disabled(!canSubmit)
                    Button("회원가입") { showsSignup = true }
                        .buttonStyle(.outline)
                }
            }
            .padding(.horizontal, Spacing.screen)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.canvas)
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil
        defer { isSubmitting = false }
        do {
            try await session.signIn(email: email.trimmingCharacters(in: .whitespaces).lowercased(), password: password)
        } catch let error as APIError where error.code == "E1003" {
            // 어느 쪽이 틀렸는지 알려주지 않는다 (SCR-01)
            errorMessage = "이메일 또는 비밀번호가 맞지 않아요."
        } catch {
            errorMessage = error.userMessage
        }
    }
}
