import Testing
@testable import SkinCare

struct PollingPolicyTests {
    @Test("처음 3분은 3초 간격", arguments: [0.0, 10, 179.9])
    func fastInterval(elapsed: Double) {
        #expect(PollingPolicy.interval(elapsed: elapsed) == 3)
    }

    @Test("3분부터 15분 전까지 10초 간격", arguments: [180.0, 600, 899.9])
    func slowInterval(elapsed: Double) {
        #expect(PollingPolicy.interval(elapsed: elapsed) == 10)
    }

    @Test("15분이 지나면 중단", arguments: [900.0, 3600])
    func timeout(elapsed: Double) {
        #expect(PollingPolicy.interval(elapsed: elapsed) == nil)
    }
}
