import SwiftUI

/// SCR-12 마이페이지 (FR-AUTH-03, 04)
struct MyPageView: View {
    @Environment(\.api) private var api
    @Environment(SessionStore.self) private var session
    @State private var me: Me?
    @State private var showsPolicy = false
    @State private var confirmsLogout = false
    @State private var confirmsDelete = false
    @State private var isDeleting = false
    @State private var alert: AlertItem?

    private var nickname: String { me?.nickname ?? session.user?.nickname ?? "" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                TabHeader(title: "마이")
                profile
                stats
                menu
                Text("스킨케어 \(appVersion)")
                    .appText(.caption)
                    .foregroundStyle(.textFaint)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.bottom, Spacing.md)
        }
        .background(Color.canvas)
        .navigationTitle("마이")
        .toolbar(.hidden, for: .navigationBar)
        .task { me = try? await api.send(UsersAPI.me()) }
        .sheet(isPresented: $showsPolicy) {
            if let url = AppConfig.privacyPolicyURL { SafariView(url: url).ignoresSafeArea() }
        }
        .confirmationDialog("로그아웃할까요?", isPresented: $confirmsLogout, titleVisibility: .visible) {
            Button("로그아웃", role: .destructive) { Task { await session.signOut() } }
            Button("취소", role: .cancel) {}
        }
        .confirmationDialog("회원 탈퇴", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("탈퇴하기", role: .destructive) { Task { await deleteAccount() } }
            Button("취소", role: .cancel) {}
        } message: {
            Text("모든 측정 기록이 바로 삭제되고 되돌릴 수 없어요.")
        }
        .alert($alert)
    }

    private var profile: some View {
        HStack(spacing: Spacing.md) {
            Text(String(nickname.prefix(1)))
                .appText(.title)
                .foregroundStyle(.onPrimary)
                .frame(width: 56, height: 56)
                .background(Color.ink, in: Circle())
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(nickname)님").appText(.title).foregroundStyle(.ink)
                Text(me?.email ?? session.user?.email ?? "").appText(.bodySmall).foregroundStyle(.textMuted)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private var stats: some View {
        HStack(spacing: 0) {
            statItem(title: "누적 측정", value: me.map { "\($0.analysisCount)회" } ?? "-")
            Rectangle().fill(Color.hairline).frame(width: 1, height: 32)
            statItem(title: "함께한 날", value: me.map { Formatting.date($0.createdAt) } ?? "-")
        }
        .card(.soft, padding: Spacing.md, radius: Radius.sm)
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).appText(.link).foregroundStyle(.ink)
            Text(title).appText(.caption).foregroundStyle(.textMuted)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var menu: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            SectionTitle(title: "설정")
            VStack(spacing: 0) {
                MenuRow(title: "개인정보 처리방침", systemImage: "lock.shield") { showsPolicy = true } trailing: {
                    if AppConfig.privacyPolicyURL == nil {
                        Text("준비 중").appText(.bodySmall).foregroundStyle(.textFaint)
                    } else {
                        Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(.textFaint)
                    }
                }
                .disabled(AppConfig.privacyPolicyURL == nil)
                Hairline()
                MenuRow(title: "로그아웃", systemImage: "rectangle.portrait.and.arrow.right") { confirmsLogout = true }
                Hairline()
                MenuRow(title: isDeleting ? "탈퇴 처리 중…" : "회원 탈퇴", systemImage: "person.crop.circle.badge.xmark",
                        role: .destructive) { confirmsDelete = true }
                    .disabled(isDeleting)
            }
            .padding(.horizontal, Spacing.md)
            .card(.outlined, padding: 0, radius: Radius.sm)
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
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
