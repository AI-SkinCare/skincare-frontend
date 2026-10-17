import Testing
@testable import SkinCare

struct SignupValidationTests {
    @Test(arguments: ["user@example.com", "a.b+c@sub.domain.kr"])
    func validEmails(email: String) {
        #expect(SignupValidation.isValidEmail(email))
    }

    @Test(arguments: ["", "user", "user@", "user@domain", "a b@c.d"])
    func invalidEmails(email: String) {
        #expect(!SignupValidation.isValidEmail(email))
    }

    @Test("비밀번호: 8–64자, 영문·숫자·특수문자 중 2종 이상 (API §3.1)")
    func password() {
        #expect(SignupValidation.passwordError("Skin!2026") == nil)
        #expect(SignupValidation.passwordError("skincare1") == nil)
        #expect(SignupValidation.passwordError("abcdefgh") != nil) // 1종
        #expect(SignupValidation.passwordError("a1!") != nil) // 짧음
    }

    @Test func nickname() {
        #expect(SignupValidation.nicknameError("우주") == nil)
        #expect(SignupValidation.nicknameError("우") != nil)
        #expect(SignupValidation.nicknameError(String(repeating: "가", count: 21)) != nil)
    }
}

struct FormattingTests {
    @Test func waitTime() {
        #expect(Formatting.waitTime(seconds: 30) == "1분 이내")
        #expect(Formatting.waitTime(seconds: 60) == "1분 이내")
        #expect(Formatting.waitTime(seconds: 110) == "약 2분")
        #expect(Formatting.waitTime(seconds: 165) == "약 3분")
    }

    @Test("요약은 앞 2문장")
    func leadingSentences() {
        let text = "첫 문장이에요. 둘째 문장이에요. 셋째 문장이에요."
        #expect(Formatting.leadingSentences(text) == "첫 문장이에요. 둘째 문장이에요.")
    }

    @Test func apiDate() {
        #expect(Formatting.apiDate("2026-10-15") == "2026.10.15")
    }
}
