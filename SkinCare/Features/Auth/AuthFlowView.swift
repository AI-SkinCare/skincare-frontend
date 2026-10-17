import SwiftUI

/// 비로그인 화면 흐름: 로그인(SCR-01) → 회원가입(SCR-02)
struct AuthFlowView: View {
    @State private var showsSignup = Self.initialShowsSignup
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

    private static var initialShowsSignup: Bool {
        #if DEBUG
        DebugLaunch.startScreen == .signup
        #else
        false
        #endif
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
        // 화면 가운데 정렬. 키보드가 올라와 공간이 줄면 스크롤된다.
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    Spacer(minLength: 0)
                    header
                    form
                    actions
                    Spacer(minLength: 0)
                    footnote
                }
                .padding(.horizontal, Spacing.screen)
                .padding(.vertical, Spacing.md)
                .frame(maxWidth: .infinity, minHeight: proxy.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(Color.canvas)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        VStack(spacing: Spacing.md) {
            BrandMark(size: 72)
            VStack(spacing: Spacing.xs) {
                Text("피부 사진으로 시작해요.")
                    .appText(.heading3)
                    .foregroundStyle(.ink)
                Text("사진 한 장으로 피부 이미지를 분류하고\n맞는 성분과 관리법을 추천해요.")
                    .appText(.bodyLarge)
                    .foregroundStyle(.textMuted)
            }
            .multilineTextAlignment(.center)
        }
        .padding(.bottom, Spacing.xs)
    }

    private var form: some View {
        VStack(spacing: Spacing.sm) {
            AppTextField(placeholder: "이메일", text: $email, keyboard: .emailAddress, contentType: .username)
            AppTextField(placeholder: "비밀번호", text: $password, isSecure: true, contentType: .password)
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .appText(.bodySmall)
                    .foregroundStyle(.negative)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: errorMessage)
    }

    private var actions: some View {
        VStack(spacing: Spacing.md) {
            Button {
                Task { await submit() }
            } label: {
                HStack(spacing: Spacing.xs) {
                    if isSubmitting { ProgressView().tint(.onPrimary) }
                    Text("로그인")
                }
            }
            .buttonStyle(.primary)
            .disabled(!canSubmit)

            HStack(spacing: Spacing.xxs) {
                Text("처음이신가요?").foregroundStyle(.textMuted)
                Button("회원가입") { showsSignup = true }
                    .foregroundStyle(.ink)
                    .underline()
            }
            .appText(.bodySmall)
            .frame(minHeight: ControlSize.minTouch)
        }
    }

    private var footnote: some View {
        Label(AppCopy.imageConsentShort, systemImage: "lock")
            .appText(.caption)
            .foregroundStyle(.textFaint)
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
