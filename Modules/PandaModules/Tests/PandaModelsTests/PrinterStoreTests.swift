import Foundation
@testable import PandaModels
import Testing

@Suite("Printer Store")
struct PrinterStoreTests {
    private func makeStore() -> (PrinterStore, UserDefaults) {
        let suite = "PrinterStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (PrinterStore(defaults: defaults), defaults)
    }

    private let printerA = PrinterProfile(name: "Werkstatt", ip: "10.0.0.1", accessCode: "aaaa", serial: "SA", model: .h2c)
    private let printerB = PrinterProfile(ip: "10.0.0.2", accessCode: "bbbb", model: .h3c)

    @Test("Adding a printer selects it and mirrors its connection data")
    func addSelects() {
        let (store, defaults) = makeStore()

        #expect(store.add(printerA))
        #expect(store.printers == [printerA])
        #expect(store.selected == printerA)
        #expect(defaults.string(forKey: "printerIP") == "10.0.0.1")
        #expect(defaults.string(forKey: "printerAccessCode") == "aaaa")
        #expect(defaults.string(forKey: "printerSerial") == "SA")
        #expect(defaults.string(forKey: "printerModel") == "h2c")
    }

    @Test("Selecting switches the mirrored connection data")
    func selectSwitches() {
        let (store, defaults) = makeStore()
        store.add(printerA)
        store.add(printerB)
        #expect(store.selected == printerB)

        #expect(store.select(id: printerA.id))
        #expect(store.selected == printerA)
        #expect(defaults.string(forKey: "printerIP") == "10.0.0.1")
        #expect(store.select(id: printerA.id) == false) // unchanged
    }

    @Test("Selecting an unknown printer does nothing")
    func selectUnknown() {
        let (store, _) = makeStore()
        store.add(printerA)
        #expect(store.select(id: UUID()) == false)
        #expect(store.selected == printerA)
    }

    @Test("Removing the selected printer selects the next one")
    func removeSelected() {
        let (store, defaults) = makeStore()
        store.add(printerA)
        store.add(printerB)

        #expect(store.remove(id: printerB.id))
        #expect(store.printers == [printerA])
        #expect(store.selected == printerA)
        #expect(defaults.string(forKey: "printerIP") == "10.0.0.1")
    }

    @Test("Removing another printer keeps the selection")
    func removeOther() {
        let (store, _) = makeStore()
        store.add(printerA)
        store.add(printerB)

        #expect(store.remove(id: printerA.id) == false)
        #expect(store.selected == printerB)
    }

    @Test("Removing the last printer clears the connection data")
    func removeLast() {
        let (store, defaults) = makeStore()
        store.add(printerA)

        #expect(store.remove(id: printerA.id))
        #expect(store.printers.isEmpty)
        #expect(store.selected == nil)
        #expect(defaults.string(forKey: "printerIP") == "")
        #expect(defaults.string(forKey: "printerAccessCode") == "")
        #expect(defaults.string(forKey: "printerModel") == nil)
    }

    @Test("Updating the selected printer refreshes the mirrored data")
    func updateSelected() {
        let (store, defaults) = makeStore()
        store.add(printerA)

        var changed = printerA
        changed.ip = "10.0.0.9"
        changed.name = "Neu"
        store.update(changed)

        #expect(store.selected?.name == "Neu")
        #expect(defaults.string(forKey: "printerIP") == "10.0.0.9")
    }

    @Test("Legacy single-printer configuration is migrated once")
    func migrateLegacy() {
        let (store, defaults) = makeStore()
        defaults.set("192.168.1.50", forKey: "printerIP")
        defaults.set("code", forKey: "printerAccessCode")
        defaults.set("SER", forKey: "printerSerial")
        defaults.set("p2s", forKey: "printerModel")

        store.migrateLegacyConfiguration()
        #expect(store.printers.count == 1)
        #expect(store.selected?.ip == "192.168.1.50")
        #expect(store.selected?.serial == "SER")
        #expect(store.selected?.model == .p2s)

        store.migrateLegacyConfiguration()
        #expect(store.printers.count == 1)
    }

    @Test("Migration without configuration creates nothing")
    func migrateEmpty() {
        let (store, _) = makeStore()
        store.migrateLegacyConfiguration()
        #expect(store.printers.isEmpty)
    }

    @Test("Display name falls back to model, then IP")
    func displayName() {
        #expect(printerA.displayName == "Werkstatt")
        #expect(printerB.displayName == "H3C")
        #expect(PrinterProfile(name: "  ", ip: "10.0.0.3", accessCode: "c").displayName == "10.0.0.3")
    }
}
