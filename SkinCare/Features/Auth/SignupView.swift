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
            VStack(alignment: .leading, spacing: Spacing.xl) {
                ScreenHeader(title: "계정을 만들어요.", subtitle: "분석 결과와 추천을 기록으로 모아 볼 수 있어요.")

                VStack(alignment: .leading, spacing: Spacing.md) {
                    LabeledField(title: "이메일",
                                 message: emailError ?? (email.isEmpty || SignupValidation.isValidEmail(email) ? nil : "이메일 형식을 확인해 주세요.")) {
                        AppTextField(placeholder: "name@example.com", text: $email, keyboard: .emailAddress, contentType: .username)
                    }
                    LabeledField(title: "비밀번호",
                                 hint: "8–64자, 영문·숫자·특수문자 중 2종 이상",
                                 message: password.isEmpty ? nil : SignupValidation.passwordError(password)) {
                        AppTextField(placeholder: "비밀번호", text: $password, isSecure: true, contentType: .newPassword)
                    }
                    LabeledField(title: "닉네임", hint: "2–20자",
                                 message: nickname.isEmpty ? nil : SignupValidation.nicknameError(nickname)) {
                        AppTextField(placeholder: "닉네임", text: $nickname, contentType: .nickname)
                    }
                }

                agreements

                if let formError {
                    Label(formError, systemImage: "exclamationmark.circle")
                        .appText(.bodySmall)
                        .foregroundStyle(.negative)
                }
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.top, Spacing.xs)
            .padding(.bottom, Spacing.lg)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button {
                    Task { await submit() }
                } label: {
                    HStack(spacing: Spacing.xs) {
                        if isSubmitting { ProgressView().tint(.onPrimary) }
                        Text("가입하기")
                    }
                }
                .buttonStyle(.primary)
                .disabled(!canSubmit)
            }
        }
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: email) { emailError = nil }
        .sheet(isPresented: $showsPolicy) {
            if let url = AppConfig.privacyPolicyURL { SafariView(url: url).ignoresSafeArea() }
        }
    }

    private var agreements: some View {
        VStack(alignment: .leading, spacing: 0) {
            AgreementRow(title: "약관 전체 동의", isOn: Binding(
                get: { allAgreed },
                set: { value in
                    agreesTerms = value; agreesPrivacy = value; agreesImage = value; confirmsOver14 = value
                }
            ), isEmphasized: true)
            .padding(.horizontal, Spacing.md)
            .background(Color.canvasSoft, in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
            .padding(.bottom, Spacing.xs)

            VStack(alignment: .leading, spacing: 0) {
                AgreementRow(title: "이용약관 동의", isOn: $agreesTerms)
                AgreementRow(title: "개인정보 수집·이용 동의", isOn: $agreesPrivacy)
                AgreementRow(title: "얼굴 이미지 처리 동의", isOn: $agreesImage)
                HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
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
                .padding(.leading, 34)
                .padding(.bottom, Spacing.xs)
                AgreementRow(title: "만 14세 이상입니다", isOn: $confirmsOver14)
            }
            .padding(.horizontal, Spacing.md)
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

private struct LabeledField<Field: View>: View {
    let title: String
    var hint: String?
    var message: String?
    @ViewBuilder let field: Field

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).appText(.label).foregroundStyle(.ink)
                if let hint { Text(hint).appText(.caption).foregroundStyle(.textFaint) }
            }
            field
            if let message {
                Text(message)
                    .appText(.caption)
                    .foregroundStyle(.negative)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.2), value: message)
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
            HStack(spacing: Spacing.sm) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(isOn ? .ink : .hairline)
                    .contentTransition(.symbolEffect(.replace))
                Text(title)
                    .appText(isEmphasized ? .link : .body)
                    .foregroundStyle(.ink)
                if !isEmphasized {
                    Text("필수").appText(.caption).foregroundStyle(.textFaint)
                }
                Spacer()
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isEmphasized ? title : "필수, \(title)")
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
