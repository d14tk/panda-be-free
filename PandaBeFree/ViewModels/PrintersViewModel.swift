import Foundation
import Networking
import PandaLogger
import PandaModels

private let logCategory = "Printers"

/// Saved printers and their live status for the printer overview.
@MainActor
@Observable
final class PrintersViewModel {
    enum Status {
        case loading
        case online(PrinterStateSnapshot)
        case offline(String)
    }

    typealias SnapshotFetcher = @Sendable (PrinterProfile) async throws -> PrinterStateSnapshot

    private(set) var printers: [PrinterProfile] = []
    private(set) var selectedID: UUID?
    private(set) var statuses: [UUID: Status] = [:]

    private let fetchSnapshot: SnapshotFetcher
    private let pollInterval: Duration

    init(
        pollInterval: Duration = .seconds(20),
        fetchSnapshot: @escaping SnapshotFetcher = { printer in
            try await WidgetMQTTService.fetchSnapshot(
                ip: printer.ip,
                accessCode: printer.accessCode,
                serial: printer.serial
            )
        }
    ) {
        self.pollInterval = pollInterval
        self.fetchSnapshot = fetchSnapshot
        reload()
    }

    func reload() {
        printers = SharedSettings.printers
        selectedID = SharedSettings.selectedPrinter?.id
        let ids = Set(printers.map(\.id))
        statuses = statuses.filter { ids.contains($0.key) }
    }

    func status(for id: UUID) -> Status {
        statuses[id] ?? .loading
    }

    /// Refreshes the inactive printers until the surrounding task is cancelled.
    func poll() async {
        while !Task.isCancelled {
            await refreshInactivePrinters()
            try? await Task.sleep(for: pollInterval)
        }
    }

    /// Fetches a one-shot snapshot from every printer except the active one;
    /// the dashboard already holds a live connection to that printer.
    /// Runs one printer at a time because the snapshot service handles one session at a time.
    func refreshInactivePrinters() async {
        reload()
        for printer in printers where printer.id != selectedID {
            guard !Task.isCancelled else { return }
            do {
                let snapshot = try await fetchSnapshot(printer)
                statuses[printer.id] = .online(snapshot)
            } catch {
                appLog(.warning, category: logCategory, "Status fetch failed for \(printer.displayName): \(error.localizedDescription)")
                statuses[printer.id] = .offline(error.localizedDescription)
            }
        }
    }

    func rename(_ id: UUID, to name: String) {
        guard var printer = printers.first(where: { $0.id == id }) else { return }
        printer.name = name.trimmingCharacters(in: .whitespaces)
        SharedSettings.updatePrinter(printer)
        reload()
    }

    /// Removes an inactive printer. The active printer is removed through the dashboard,
    /// which also has to disconnect and connect to the next one.
    func removeInactive(_ id: UUID) {
        guard id != selectedID else { return }
        SharedSettings.removePrinter(id: id)
        reload()
    }
}
