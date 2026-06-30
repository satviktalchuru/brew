import XCTest
@testable import BrewApp

final class LogicTests: XCTestCase {
    func testEloUpdatesEqualScoresBySixteenPoints() {
        let result = EloCalculator.updatedScores(winner: 1000, loser: 1000)
        XCTAssertEqual(result.winner, 1016, accuracy: 0.001)
        XCTAssertEqual(result.loser, 984, accuracy: 0.001)
    }

    func testPairSelectionExcludesAlreadyComparedPairs() {
        let store = MockData.makeStore()
        let currentLogs = store.drinkLogs.filter { $0.userID == store.currentUserID }
        XCTAssertGreaterThanOrEqual(currentLogs.count, 3)

        let existing = Comparison(
            id: UUID(),
            userID: store.currentUserID,
            winnerLogID: currentLogs[0].id,
            loserLogID: currentLogs[1].id,
            comparedAt: .now
        )

        let pairs = RankingEngine.candidatePairs(
            logs: currentLogs,
            comparisons: [existing],
            userID: store.currentUserID,
            limit: 10
        )

        XCTAssertFalse(pairs.contains { pair in
            Set([pair.0.id, pair.1.id]) == Set([currentLogs[0].id, currentLogs[1].id])
        })
    }

    func testTasteProfileComputesExpectedSeedAveragesFlavorsAndIdentity() {
        let store = MockData.makeStore()
        let profile = TasteProfileEngine.profile(
            for: store.currentUserID,
            logs: store.drinkLogs
        )

        XCTAssertEqual(profile.averageStrength, 3.75, accuracy: 0.001)
        XCTAssertEqual(profile.averageSweetness, 3.75, accuracy: 0.001)
        XCTAssertEqual(profile.topFlavorDescriptors, ["Blueberry", "Caramel", "Cocoa", "Jasmine", "Lemon"])
        XCTAssertEqual(profile.identityLabel, "Sweet & Bright")
        XCTAssertEqual(profile.roastCounts[.light], 2)
        XCTAssertEqual(profile.roastCounts[.medium], 1)
        XCTAssertEqual(profile.roastCounts[.dark], 1)
    }

    func testSeedDataReferencesAreStableAndResolvable() {
        let first = MockData.makeStore()
        let second = MockData.makeStore()

        let firstFlavorIDsByDescriptor = Dictionary(
            uniqueKeysWithValues: first.drinkLogs.flatMap(\.flavorTags).map { ($0.descriptor, $0.id) }
        )
        let secondFlavorIDsByDescriptor = Dictionary(
            uniqueKeysWithValues: second.drinkLogs.flatMap(\.flavorTags).map { ($0.descriptor, $0.id) }
        )
        XCTAssertEqual(firstFlavorIDsByDescriptor, secondFlavorIDsByDescriptor)

        let userIDs = Set(first.users.map(\.id))
        let shopIDs = Set(first.shops.map(\.id))
        let logIDs = Set(first.drinkLogs.map(\.id))

        XCTAssertTrue(first.likedLogIDs.allSatisfy { logIDs.contains($0) })
        XCTAssertTrue(first.comparisons.allSatisfy { comparison in
            userIDs.contains(comparison.userID)
                && logIDs.contains(comparison.winnerLogID)
                && logIDs.contains(comparison.loserLogID)
        })
        XCTAssertTrue(first.chatRequests.allSatisfy { request in
            userIDs.contains(request.requesterID)
                && userIDs.contains(request.addresseeID)
                && shopIDs.contains(request.shopID)
        })
        XCTAssertTrue(first.drinkLogs.allSatisfy { log in
            userIDs.contains(log.userID)
                && log.shopID.map { shopIDs.contains($0) } ?? true
        })
    }

    func testStoreToggleLikeAddsAndRemovesLogID() {
        let store = MockData.makeStore()
        let unlikedLogID = MockData.satvikEspressoID
        XCTAssertFalse(store.likedLogIDs.contains(unlikedLogID))

        store.toggleLike(logID: unlikedLogID)
        XCTAssertTrue(store.likedLogIDs.contains(unlikedLogID))

        store.toggleLike(logID: unlikedLogID)
        XCTAssertFalse(store.likedLogIDs.contains(unlikedLogID))
    }

    func testStoreRecordComparisonUpdatesScoresAndAppendsComparison() {
        let store = MockData.makeStore()
        let winnerID = MockData.satvikEspressoID
        let loserID = MockData.satvikColdBrewID
        let startingComparisonCount = store.comparisons.count
        let startingWinnerScore = store.drinkLogs.first { $0.id == winnerID }?.eloScore
        let startingLoserScore = store.drinkLogs.first { $0.id == loserID }?.eloScore

        store.recordComparison(winnerID: winnerID, loserID: loserID)

        let updatedWinnerScore = store.drinkLogs.first { $0.id == winnerID }?.eloScore
        let updatedLoserScore = store.drinkLogs.first { $0.id == loserID }?.eloScore
        XCTAssertEqual(store.comparisons.count, startingComparisonCount + 1)
        XCTAssertGreaterThan(updatedWinnerScore ?? 0, startingWinnerScore ?? 0)
        XCTAssertLessThan(updatedLoserScore ?? 0, startingLoserScore ?? 0)
        XCTAssertTrue(store.comparisons.contains { comparison in
            comparison.winnerLogID == winnerID && comparison.loserLogID == loserID
        })
    }

    func testStoreChatRequestActionsUpdateStatus() {
        let store = MockData.makeStore()
        let pendingID = store.chatRequests.first { $0.status == .pending }?.id
        XCTAssertNotNil(pendingID)

        store.acceptChatRequest(pendingID!)
        XCTAssertEqual(store.chatRequests.first { $0.id == pendingID }?.status, .accepted)

        store.declineChatRequest(pendingID!)
        XCTAssertEqual(store.chatRequests.first { $0.id == pendingID }?.status, .declined)
    }
}
