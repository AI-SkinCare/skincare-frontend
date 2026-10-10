import SwiftUI

/// SCR-12 마이페이지 (FR-AUTH-03, 04)
struct MyPageView: View {
    @Environment(\.api) private var api
    @Environment(SessionStore.self) private var session
    @State private var me: Me?
    @State private var showsPolicy = false
    @State private var confirmsDelete = false
    @State private var isDeleting = false
    @State private var alert: AlertItem?

    var body: some View {
        List {
            Section {
                row("닉네임", value: me?.nickname ?? session.user?.nickname ?? "")
                row("이메일", value: me?.email ?? session.user?.email ?? "")
                row("누적 측정", value: me.map { "\($0.analysisCount)회" } ?? "-")
            }

            Section {
                Button {
                    showsPolicy = true
                } label: {
                    HStack {
                        Text("개인정보 처리방침").appText(.body).foregroundStyle(.ink)
                        Spacer()
                        if AppConfig.privacyPolicyURL == nil {
                            Text("준비 중").appText(.bodySmall).foregroundStyle(.textFaint)
                        } else {
                            Image(systemName: "chevron.right").foregroundStyle(.textFaint)
                        }
                    }
                }
                .disabled(AppConfig.privacyPolicyURL == nil)
            }

            Section {
                Button("로그아웃") { Task { await session.signOut() } }
                    .appText(.body)
                    .foregroundStyle(.ink)
                Button(isDeleting ? "탈퇴 처리 중…" : "회원 탈퇴") { confirmsDelete = true }
                    .appText(.body)
                    .foregroundStyle(.gradeCare)
                    .disabled(isDeleting)
            }
        }
        .navigationTitle("마이")
        .task { me = try? await api.send(UsersAPI.me()) }
        .sheet(isPresented: $showsPolicy) {
            if let url = AppConfig.privacyPolicyURL { SafariView(url: url).ignoresSafeArea() }
        }
        .confirmationDialog("회원 탈퇴", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("탈퇴하기", role: .destructive) { Task { await deleteAccount() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("모든 측정 기록이 바로 삭제되고 되돌릴 수 없어요.")
        }
        .alert($alert)
    }

    private func row(_ title: String, value: String) -> some View {
        HStack {
            Text(title).appText(.body).foregroundStyle(.textMuted)
            Spacer()
            Text(value).appText(.body).foregroundStyle(.ink)
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await session.deleteAccount()
        } catch {
            alert = AlertItem(message: error.userMessage)
        }
    }
}
