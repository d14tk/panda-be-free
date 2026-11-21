import Foundation

/// A saved printer connection.
public struct PrinterProfile: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var ip: String
    public var accessCode: String
    public var serial: String
    public var model: BambuPrinter?

    public init(
        id: UUID = UUID(),
        name: String = "",
        ip: String,
        accessCode: String,
        serial: String = "",
        model: BambuPrinter? = nil
    ) {
        self.id = id
        self.name = name
        self.ip = ip
        self.accessCode = accessCode
        self.serial = serial
        self.model = model
    }

    /// Custom name if set, otherwise the model name, otherwise the IP address.
    public var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty { return trimmed }
        return model?.displayName ?? ip
    }
}

/// Stores the list of saved printers and mirrors the selected one into the
/// single-printer keys (`printerIP`, `printerAccessCode`, `printerSerial`,
/// `printerModel`) that the dashboard, widgets, intents and background refresh read.
public struct PrinterStore {
    private enum Key {
        static let printers = "printers"
        static let selectedID = "selectedPrinterID"
        static let ip = "printerIP"
        static let accessCode = "printerAccessCode"
        static let serial = "printerSerial"
        static let model = "printerModel"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    public var printers: [PrinterProfile] {
        get {
            guard let data = defaults.data(forKey: Key.printers),
                  let list = try? JSONDecoder().decode([PrinterProfile].self, from: data) else { return [] }
            return list
        }
        nonmutating set {
            defaults.set(try? JSONEncoder().encode(newValue), forKey: Key.printers)
        }
    }

    public var selectedID: UUID? {
        defaults.string(forKey: Key.selectedID).flatMap(UUID.init(uuidString:))
    }

    public var selected: PrinterProfile? {
        guard let id = selectedID else { return nil }
        return printers.first { $0.id == id }
    }

    /// Creates a profile from the single-printer keys of installs that predate the printer list.
    public func migrateLegacyConfiguration() {
        guard printers.isEmpty else { return }
        let ip = defaults.string(forKey: Key.ip) ?? ""
        let accessCode = defaults.string(forKey: Key.accessCode) ?? ""
        guard !ip.isEmpty, !accessCode.isEmpty else { return }
        let profile = PrinterProfile(
            ip: ip,
            accessCode: accessCode,
            serial: defaults.string(forKey: Key.serial) ?? "",
            model: defaults.string(forKey: Key.model).flatMap(BambuPrinter.init(rawValue:))
        )
        printers = [profile]
        defaults.set(profile.id.uuidString, forKey: Key.selectedID)
    }

    /// Adds the printer and selects it. Returns `true` if the selection changed.
    @discardableResult
    public func add(_ profile: PrinterProfile) -> Bool {
        printers = printers.filter { $0.id != profile.id } + [profile]
        return select(id: profile.id)
    }

    /// Selects the printer and writes its connection data into the single-printer keys.
    /// Returns `true` if the selection changed.
    @discardableResult
    public func select(id: UUID) -> Bool {
        guard let profile = printers.first(where: { $0.id == id }) else { return false }
        let changed = selectedID != id
        defaults.set(id.uuidString, forKey: Key.selectedID)
        writeActive(profile)
        return changed
    }

    /// Replaces a saved printer. Refreshes the single-printer keys if it is the selected one.
    public func update(_ profile: PrinterProfile) {
        var list = printers
        guard let index = list.firstIndex(where: { $0.id == profile.id }) else { return }
        list[index] = profile
        printers = list
        if selectedID == profile.id { writeActive(profile) }
    }

    /// Removes a printer. If it was selected, the first remaining printer becomes selected,
    /// or all single-printer keys are cleared when none is left.
    /// Returns `true` if the selection changed.
    @discardableResult
    public func remove(id: UUID) -> Bool {
        printers = printers.filter { $0.id != id }
        guard selectedID == id || selectedID == nil else { return false }
        if let next = printers.first {
            return select(id: next.id)
        }
        defaults.removeObject(forKey: Key.selectedID)
        writeActive(nil)
        return true
    }

    /// Removes all saved printers and clears the single-printer keys.
    public func removeAll() {
        printers = []
        defaults.removeObject(forKey: Key.selectedID)
        writeActive(nil)
    }

    private func writeActive(_ profile: PrinterProfile?) {
        defaults.set(profile?.ip ?? "", forKey: Key.ip)
        defaults.set(profile?.accessCode ?? "", forKey: Key.accessCode)
        defaults.set(profile?.serial ?? "", forKey: Key.serial)
        defaults.set(profile?.model?.rawValue, forKey: Key.model)
    }
}
