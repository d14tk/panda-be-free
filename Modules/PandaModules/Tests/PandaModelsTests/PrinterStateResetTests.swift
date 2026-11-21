import Foundation
@testable import PandaModels
import Testing

@Suite("Printer State Reset")
struct PrinterStateResetTests {
    @Test("reset restores initial values")
    func resetRestoresDefaults() {
        let state = PrinterState()
        state.gcodeState = "RUNNING"
        state.stgCur = 2
        state.progress = 55
        state.jobName = "Benchy"
        state.nozzleTemp = 220
        state.chamberTemp = 40
        state.airductMode = 1
        state.chamberLightOn = true
        state.amsUnits = [AMSUnit(id: 0)]
        state.activeTrayIndex = 3
        state.isConnected = true
        state.lastUpdated = .now

        state.reset()

        #expect(state.gcodeState == "UNKNOWN")
        #expect(state.stgCur == -1)
        #expect(state.progress == 0)
        #expect(state.jobName.isEmpty)
        #expect(state.nozzleTemp == 0)
        #expect(state.chamberTemp == 0)
        #expect(state.airductMode == -1)
        #expect(state.chamberLightOn == false)
        #expect(state.amsUnits.isEmpty)
        #expect(state.activeTrayIndex == nil)
        #expect(state.isConnected == false)
        #expect(state.lastUpdated == nil)
    }
}
