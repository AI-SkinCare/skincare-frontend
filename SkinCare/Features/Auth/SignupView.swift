import SwiftUI

/// SCR-02 회원가입 (FR-AUTH-01). 입력 규칙은 API §3.1.
struct SignupView: View {
    let onCompleted: (String) -> Void

    @Environment(\.api) private var api

    @State private var email = ""
    @State private var password = ""
    @State private var nickname = ""
    @State private var agreesTerms = false
    @State private var agreesPrivacy = false
    @State private var agreesImage = false
    @State private var confirmsOver14 = false
    @State private var emailError: String?
    @State private var formError: String?
    @State private var isSubmitting = false
    @State private var showsPolicy = false

    private var allAgreed: Bool { agreesTerms && agreesPrivacy && agreesImage && confirmsOver14 }

    private var canSubmit: Bool {
        allAgreed && SignupValidation.isValidEmail(email) && SignupValidation.passwordError(password) == nil
            && SignupValidation.nicknameError(nickname) == nil && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("계정을 만들어요.")
                    .appText(.heading3)
                    .foregroundStyle(.ink)

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    AppTextField(placeholder: "이메일", text: $email, keyboard: .emailAddress, contentType: .username)
                    fieldMessage(emailError ?? (email.isEmpty || SignupValidation.isValidEmail(email) ? nil : "이메일 형식을 확인해 주세요."))
                    AppTextField(placeholder: "비밀번호 (8–64자, 영문·숫자·특수문자 중 2종 이상)", text: $password,
                                 isSecure: true, contentType: .newPassword)
                    fieldMessage(password.isEmpty ? nil : SignupValidation.passwordError(password))
                    AppTextField(placeholder: "닉네임 (2–20자)", text: $nickname, contentType: .nickname)
                    fieldMessage(nickname.isEmpty ? nil : SignupValidation.nicknameError(nickname))
                }

                agreements

                if let formError {
                    fieldMessage(formError)
                }

                Button(isSubmitting ? "가입 중…" : "가입하기") { Task { await submit() } }
                    .buttonStyle(.primary)
                    .disabled(!canSubmit)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: email) { emailError = nil }
        .sheet(isPresented: $showsPolicy) {
            if let url = AppConfig.privacyPolicyURL { SafariView(url: url).ignoresSafeArea() }
        }
    }

    private var agreements: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            AgreementRow(title: "전체 동의", isOn: Binding(
                get: { allAgreed },
                set: { value in
                    agreesTerms = value; agreesPrivacy = value; agreesImage = value; confirmsOver14 = value
                }
            ), isEmphasized: true)
            Divider().overlay(Color.hairlineSoft)
            AgreementRow(title: "(필수) 이용약관 동의", isOn: $agreesTerms)
            AgreementRow(title: "(필수) 개인정보 수집·이용 동의", isOn: $agreesPrivacy)
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                AgreementRow(title: "(필수) 얼굴 이미지 처리 동의", isOn: $agreesImage)
                HStack(spacing: Spacing.xs) {
                    Text(AppCopy.imageConsentShort)
                        .appText(.caption)
                        .foregroundStyle(.textMuted)
                    if AppConfig.privacyPolicyURL != nil {
                        Button("내용 보기") { showsPolicy = true }
                            .appText(.caption)
                            .foregroundStyle(.ink)
                            .underline()
                    }
                }
                .padding(.leading, 32)
            }
            AgreementRow(title: "(필수) 만 14세 이상입니다", isOn: $confirmsOver14)
        }
        .card(.outlined, padding: Spacing.md, radius: Radius.sm)
    }

    @ViewBuilder
    private func fieldMessage(_ message: String?) -> some View {
        if let message {
            Text(message)
                .appText(.caption)
                .foregroundStyle(.gradeCare)
        }
    }

    private func submit() async {
        isSubmitting = true
        formError = nil
        defer { isSubmitting = false }
        let request = SignupRequest(
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            password: password,
            nickname: nickname.trimmingCharacters(in: .whitespaces),
            agreements: .init(terms: agreesTerms, privacy: agreesPrivacy, imageProcessing: agreesImage, over14: confirmsOver14)
        )
        do {
            _ = try await api.send(AuthAPI.signup(request))
            onCompleted("가입이 완료됐어요")
        } catch let error as APIError where error.code == "E1004" {
            emailError = error.userMessage
        } catch {
            formError = error.userMessage
        }
    }
}

private struct AgreementRow: View {
    let title: String
    @Binding var isOn: Bool
    var isEmphasized = false

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: Spacing.xs) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? .ink : .textFaint)
                Text(title)
                    .appText(isEmphasized ? .link : .body)
                    .foregroundStyle(.ink)
                Spacer()
            }
            .frame(minHeight: ControlSize.minTouch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// 가입 입력 규칙 (API §3.1)
enum SignupValidation {
    static func isValidEmail(_ email: String) -> Bool {
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard trimmed.count <= 255 else { return false }
        return trimmed.wholeMatch(of: /[^@\s]+@[^@\s]+\.[^@\s]+/) != nil
    }

    static func passwordError(_ password: String) -> String? {
        guard (8...64).contains(password.count) else { return "비밀번호는 8–64자로 입력해 주세요." }
        let kinds = [
            password.contains(where: \.isLetter),
            password.contains(where: \.isNumber),
            password.contains { !$0.isLetter && !$0.isNumber && !$0.isWhitespace },
        ].filter { $0 }.count
        return kinds >= 2 ? nil : "영문·숫자·특수문자 중 2종 이상을 섞어 주세요."
    }

    static func nicknameError(_ nickname: String) -> String? {
        (2...20).contains(nickname.trimmingCharacters(in: .whitespaces).count) ? nil : "닉네임은 2–20자로 입력해 주세요."
    }
}
