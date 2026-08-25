import Testing
import Foundation
@testable import Cycle

struct LocalHealthContextTests {
    @Test func buildsPromptWithoutContactData() {
        var prefs = UserPreferences.default
        prefs.experiencesPMS = true
        prefs.typicalCycleLength = 28
        prefs.typicalPeriodSymptoms = [.cramps]
        prefs.iMessageContacts = [
            MessageContact(id: UUID(), label: "Friend", phoneNumber: "+15551234567")
        ]

        let cycles = [
            CycleRecord(
                id: UUID(),
                startDate: Date().addingDays(-60),
                endDate: Date().addingDays(-55),
                source: .user,
                createdAt: .now,
                updatedAt: .now
            )
        ]
        let completed = [
            CompletedCycle(
                startDate: Date().addingDays(-60),
                lengthDays: 28,
                periodLengthDays: 5
            )
        ]

        let context = LocalHealthContextBuilder.build(
            preferences: prefs,
            cycles: cycles,
            completedCycles: completed,
            checkIns: [],
            flows: [],
            prediction: nil,
            insights: [],
            currentCycleDay: 12
        )

        #expect(context.promptBlock.contains("Current cycle day: 12"))
        #expect(context.promptBlock.contains("28"))
        #expect(!context.promptBlock.contains("555"))
        #expect(!context.promptBlock.contains("Friend"))
        #expect(context.cycleCount == 1)
    }
}
