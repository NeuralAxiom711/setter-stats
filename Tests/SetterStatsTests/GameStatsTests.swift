import XCTest
@testable import SetterStatsCore

final class GameStatsTests: XCTestCase {
    func testIncrementingAndDecrementingAStatNeverGoesBelowZero() {
        var game = GameStats()

        game.increment(.attacks)
        game.increment(.attacks)
        game.decrement(.attacks)
        game.decrement(.attacks)
        game.decrement(.attacks)

        XCTAssertEqual(game.attacks, 0)
    }

    func testRecordingAnAssistIncrementsTheRightLocationAndQuality() {
        var game = GameStats()

        game.recordAssist(location: .front, quality: .perfect)
        game.recordAssist(location: .front, quality: .perfect)
        game.recordAssist(location: .backRow, quality: .offTheMark)

        XCTAssertEqual(game.assistValue(location: .front, quality: .perfect), 2)
        XCTAssertEqual(game.assistValue(location: .backRow, quality: .offTheMark), 1)
        XCTAssertEqual(game.totalAssists, 3)
        XCTAssertEqual(game.assistValue(location: .back, quality: .decent), 0)
    }

    func testAssistSelectionsDoNotChangeTheMatchSetNumber() {
        var game = GameStats()
        game.setSetNumber(2)

        game.recordAssist(location: .middle, quality: .decent)
        game.recordAssist(location: .middle, quality: .decent)

        XCTAssertEqual(game.setNumber, 2)
        XCTAssertEqual(game.assistValue(location: .middle, quality: .decent), 2)
    }

    func testUndoRevertsTheMostRecentAssist() {
        var game = GameStats()

        game.recordAssist(location: .front, quality: .perfect)
        game.recordAssist(location: .back, quality: .decent)
        game.undoLastAction()

        XCTAssertEqual(game.assistValue(location: .front, quality: .perfect), 1)
        XCTAssertEqual(game.assistValue(location: .back, quality: .decent), 0)
        XCTAssertEqual(game.totalAssists, 1)
    }

    func testFinalizeCurrentSetSnapshotsAssistsAndResetsCounters() {
        var game = GameStats()
        game.recordAssist(location: .front, quality: .perfect)
        game.recordAssist(location: .backRow, quality: .offTheMark)
        game.increment(.attacks)

        let finalized = game.finalizeCurrentSet()

        XCTAssertEqual(finalized, 1)
        XCTAssertEqual(game.savedSets.count, 1)
        XCTAssertEqual(game.savedSets[0].assistValue(location: .front, quality: .perfect), 1)
        XCTAssertEqual(game.savedSets[0].assistValue(location: .backRow, quality: .offTheMark), 1)
        XCTAssertEqual(game.savedSets[0].setNumber, 1)
        XCTAssertEqual(game.setNumber, 2)
        XCTAssertEqual(game.totalAssists, 0)
        XCTAssertEqual(game.attacks, 0)
    }

    func testCumulativeAssistsSumSavedSetsAndCurrentSet() {
        var game = GameStats()
        game.recordAssist(location: .front, quality: .perfect)
        game.finalizeCurrentSet()
        game.recordAssist(location: .front, quality: .perfect)
        game.recordAssist(location: .front, quality: .perfect)

        XCTAssertEqual(game.cumulativeAssist(location: .front, quality: .perfect), 3)
        XCTAssertEqual(game.totalAssists, 2)
    }

    func testServiceErrorsAreTrackedSeparatelyFromOtherErrors() {
        var game = GameStats()

        game.increment(.serviceErrors)
        game.increment(.errors)

        XCTAssertEqual(game.serviceErrors, 1)
        XCTAssertEqual(game.errors, 1)
    }

    func testAceAndServiceErrorEachAddToTotalServes() {
        var game = GameStats()

        game.recordAce()
        game.recordServiceError()

        XCTAssertEqual(game.serves, 2)
        XCTAssertEqual(game.aces, 1)
        XCTAssertEqual(game.serviceErrors, 1)
    }

    func testGoBackUndoesTheMostRecentActionOfAnyKind() {
        var game = GameStats()
        game.increment(.attacks)
        game.recordAce()

        game.undoLastAction()
        XCTAssertEqual(game.serves, 0)
        XCTAssertEqual(game.attacks, 1)

        game.undoLastAction()
        XCTAssertEqual(game, GameStats())
    }

    func testSetNumberDefaultsToFirstSetAndIsClampedAtMinimum() {
        var game = GameStats()
        XCTAssertEqual(game.setNumber, 1)

        game.setSetNumber(0)
        XCTAssertEqual(game.setNumber, 1)

        game.setSetNumber(3)
        XCTAssertEqual(game.setNumber, 3)
    }

    func testEditingGameInfoIsUndoable() {
        var game = GameStats()

        game.setOpponent("Liberty")
        game.setSetNumber(2)

        XCTAssertEqual(game.opponent, "Liberty")
        XCTAssertEqual(game.setNumber, 2)

        game.undoLastAction()
        XCTAssertEqual(game.opponent, "Liberty")
        XCTAssertEqual(game.setNumber, 1)

        game.undoLastAction()
        XCTAssertEqual(game, GameStats())
    }

    func testResetClearsAllGameTotalsAndInfo() {
        var game = GameStats()
        game.increment(.serves)
        game.increment(.digs)
        game.setOpponent("Cardinals")
        game.setSetNumber(4)

        game.reset()

        XCTAssertEqual(game, GameStats())
    }

    func testFinalizeCurrentSetSavesSnapshotResetsCountersAndAdvances() {
        var game = GameStats()
        game.increment(.attacks)
        game.increment(.attacks)
        game.recordAce()

        let finalized = game.finalizeCurrentSet()

        XCTAssertEqual(finalized, 1)
        XCTAssertEqual(game.setNumber, 2)
        XCTAssertEqual(game.savedSets.count, 1)
        XCTAssertEqual(game.savedSets[0].setNumber, 1)
        XCTAssertEqual(game.savedSets[0].attacks, 2)
        XCTAssertEqual(game.savedSets[0].aces, 1)
        // current counters reset
        XCTAssertEqual(game.attacks, 0)
        XCTAssertEqual(game.aces, 0)
        XCTAssertEqual(game.serves, 0)
    }

    func testCumulativeValueSumsSavedSetsAndCurrentSet() {
        var game = GameStats()
        game.increment(.attacks)
        game.finalizeCurrentSet()
        game.increment(.attacks)
        game.increment(.attacks)

        XCTAssertEqual(game.cumulativeValue(for: .attacks), 3)
    }

    func testDecrementSetNumberDoesNotDestroySavedDataOrResetCounters() {
        var game = GameStats()
        game.increment(.digs)
        game.finalizeCurrentSet()
        game.increment(.digs)
        game.setSetNumber(3)

        game.decrementSetNumber()

        XCTAssertEqual(game.setNumber, 2)
        XCTAssertEqual(game.savedSets.count, 1)
        XCTAssertEqual(game.digs, 1)
    }

    func testUndoAfterFinalizeRestoresSavedSetsAndCounters() {
        var game = GameStats()
        game.increment(.serves)
        game.finalizeCurrentSet()
        XCTAssertEqual(game.savedSets.count, 1)
        XCTAssertEqual(game.serves, 0)

        game.undoLastAction()

        XCTAssertEqual(game.savedSets.count, 0)
        XCTAssertEqual(game.serves, 1)
        XCTAssertEqual(game.setNumber, 1)
    }

    func testSetNumberIsClampedToMaxSet5() {
        var game = GameStats()
        game.setSetNumber(99)
        XCTAssertEqual(game.setNumber, GameStats.maxSetNumber)

        game.setSetNumber(0)
        XCTAssertEqual(game.setNumber, 1)
    }

    func testCannotAdvanceBeyondSet5() {
        var game = GameStats()
        for i in 1...10 {
            game.increment(.attacks)
            let finalized = game.finalizeCurrentSet()
            if i < GameStats.maxSetNumber {
                XCTAssertEqual(game.setNumber, i + 1, "should advance on set \(i)")
            } else {
                XCTAssertEqual(game.setNumber, GameStats.maxSetNumber, "must stay on set 5 after set \(i)")
            }
            XCTAssertLessThanOrEqual(finalized, GameStats.maxSetNumber)
        }
        XCTAssertEqual(game.setNumber, GameStats.maxSetNumber)
        XCTAssertEqual(game.savedSets.count, GameStats.maxSetNumber)
        XCTAssertEqual(game.savedSets.map { $0.setNumber }, [1, 2, 3, 4, 5])
    }

    func testCanFinalizeIsFalseOnFinalSet() {
        var game = GameStats()
        XCTAssertTrue(game.canFinalizeCurrentSet)
        game.setSetNumber(GameStats.maxSetNumber)
        XCTAssertFalse(game.canFinalizeCurrentSet)
    }

    func testFinalizingFinalSetSavesAndResetsWithoutAdvancing() {
        var game = GameStats()
        game.setSetNumber(GameStats.maxSetNumber)
        game.increment(.attacks)
        game.recordAce()

        let finalized = game.finalizeCurrentSet()

        XCTAssertEqual(finalized, GameStats.maxSetNumber)
        XCTAssertEqual(game.setNumber, GameStats.maxSetNumber)
        XCTAssertEqual(game.savedSets.count, 1)
        XCTAssertEqual(game.savedSets[0].setNumber, GameStats.maxSetNumber)
        XCTAssertEqual(game.savedSets[0].attacks, 1)
        XCTAssertEqual(game.savedSets[0].aces, 1)
        XCTAssertEqual(game.savedSets[0].serves, 1)
        // current counters reset; cumulative still reflects the saved set
        XCTAssertEqual(game.attacks, 0)
        XCTAssertEqual(game.cumulativeValue(for: .attacks), 1)
        XCTAssertEqual(game.cumulativeValue(for: .serves), 1)
    }

    func testSaveCurrentSetDoesNotAdvanceButKeepsCumulativeCorrect() {
        var game = GameStats()
        game.increment(.digs)
        game.saveCurrentSet()

        XCTAssertEqual(game.setNumber, 1)
        XCTAssertEqual(game.savedSets.count, 1)
        XCTAssertEqual(game.digs, 0)
        XCTAssertEqual(game.cumulativeValue(for: .digs), 1)
    }

    func testNormalizeCompletesAssistMapsClampsSetNumberAndSanitizesSavedSets() {
        var game = GameStats()
        game.recordAssist(location: .front, quality: .perfect)
        game.increment(.attacks)
        game.setSetNumber(99)

        let normalized = game.normalized()

        XCTAssertEqual(normalized.setNumber, GameStats.maxSetNumber)
        XCTAssertEqual(normalized.assistValue(location: .front, quality: .perfect), 1)
        XCTAssertEqual(normalized.assistValue(location: .back, quality: .decent), 0)
        XCTAssertEqual(normalized.attacks, 1)

        var dirty = GameStats()
        dirty.increment(.attacks)
        dirty.increment(.digs)
        dirty.saveCurrentSet()
        let cleaned = dirty.normalized()
        XCTAssertEqual(cleaned.savedSets[0].setNumber, 1)
        XCTAssertEqual(cleaned.savedSets[0].attacks, 1)
        XCTAssertEqual(cleaned.savedSets[0].digs, 1)
    }

    func testResetClearsAllTwelveAssistLocationQualityValuesAndSavedSets() {
        var game = GameStats()
        // Populate at least Front Set and Back Row Set across qualities, plus the
        // remaining combinations so we assert every one of the 12 cells.
        game.recordAssist(location: .front, quality: .perfect)
        game.recordAssist(location: .front, quality: .perfect)
        game.recordAssist(location: .front, quality: .decent)
        game.recordAssist(location: .front, quality: .offTheMark)
        game.recordAssist(location: .back, quality: .perfect)
        game.recordAssist(location: .back, quality: .decent)
        game.recordAssist(location: .middle, quality: .perfect)
        game.recordAssist(location: .middle, quality: .decent)
        game.recordAssist(location: .middle, quality: .offTheMark)
        game.recordAssist(location: .backRow, quality: .perfect)
        game.recordAssist(location: .backRow, quality: .decent)
        game.recordAssist(location: .backRow, quality: .offTheMark)

        game.setOpponent("Tigers")
        game.finalizeCurrentSet() // moves those counts into savedSets

        // Record fresh CURRENT-set assists so reset must clear the live table.
        game.recordAssist(location: .front, quality: .decent)
        game.recordAssist(location: .backRow, quality: .offTheMark)

        XCTAssertEqual(game.assistValue(location: .front, quality: .decent), 1)
        XCTAssertEqual(game.savedSets.count, 1)

        game.reset()

        for location in AssistLocation.allCases {
            for quality in AssistQuality.allCases {
                XCTAssertEqual(
                    game.assistValue(location: location, quality: quality),
                    0,
                    "\(location.rawValue) - \(quality.rawValue) must be 0 after reset"
                )
            }
        }
        XCTAssertEqual(game.totalAssists, 0)
        XCTAssertEqual(game.savedSets.count, 0)
        XCTAssertEqual(game.opponent, "")
        XCTAssertEqual(game.setNumber, 1)
    }

    func testPersistThenLoadRestoresSavedSetsOpponentSetNumberAndCounters() {
        let suite = "setter-stats-test-suite"
        UserDefaults.standard.removePersistentDomain(forName: suite)
        let defaults = UserDefaults(suiteName: suite)!

        var game = GameStats()
        game.setOpponent("Riverside")
        game.setSetNumber(2)
        game.increment(.attacks)
        game.increment(.attacks)
        game.recordAssist(location: .backRow, quality: .offTheMark)
        game.finalizeCurrentSet()
        game.increment(.digs)
        game.persist(to: defaults)

        let restored = GameStats.load(from: defaults)
        XCTAssertEqual(restored.opponent, "Riverside")
        XCTAssertEqual(restored.setNumber, 3)
        XCTAssertEqual(restored.savedSets.count, 1)
        XCTAssertEqual(restored.savedSets[0].setNumber, 2)
        XCTAssertEqual(restored.savedSets[0].attacks, 2)
        XCTAssertEqual(restored.savedSets[0].assistValue(location: .backRow, quality: .offTheMark), 1)
        XCTAssertEqual(restored.digs, 1)
        XCTAssertEqual(restored.cumulativeValue(for: .attacks), 2)
    }
}
