import NavigatorUI
import Networking
import Onboarding
import PandaModels
import PandaUI
import SFSafeSymbols
import SwiftUI

/// Overview of all saved printers. Tapping a printer makes it the active one
/// for the dashboard, controls, widgets and Live Activity.
struct PrintersView: View {
    @Bindable var dashboardViewModel: DashboardViewModel
    @Binding var selectedTab: RootTab
    @State private var viewModel = PrintersViewModel()
    @State private var showAddPrinter = false
    @State private var renamingPrinter: PrinterProfile?
    @State private var newName = ""
    @State private var removingPrinter: PrinterProfile?

    var body: some View {
        ManagedNavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(viewModel.printers) { printer in
                        printerButton(printer)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Printers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddPrinter = true
                    } label: {
                        Label("Add Printer", systemSymbol: .plus)
                    }
                }
            }
            .refreshable {
                await viewModel.refreshInactivePrinters()
            }
        }
        .task {
            await viewModel.poll()
        }
        .sheet(isPresented: $showAddPrinter) {
            OnboardingRootView(
                connectionTester: { ip, accessCode, serial, printerModel in
                    await ConnectionTestService.testConnection(
                        ip: ip,
                        accessCode: accessCode,
                        serial: serial,
                        printerModel: printerModel
                    )
                },
                onPrinterSaved: {
                    showAddPrinter = false
                    viewModel.reload()
                    selectedTab = .dashboard
                    Task { await dashboardViewModel.reconnectToSelectedPrinter() }
                }
            )
        }
        .alert("Rename Printer", isPresented: isRenaming) {
            TextField("Name", text: $newName)
            Button("Save") {
                if let printer = renamingPrinter {
                    viewModel.rename(printer.id, to: newName)
                    dashboardViewModel.refreshPrinterName()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Leave empty to use the model name.")
        }
        .confirmationDialog(
            "Remove Printer?",
            isPresented: isRemoving,
            presenting: removingPrinter
        ) { printer in
            Button("Remove", role: .destructive) {
                remove(printer)
            }
            Button("Cancel", role: .cancel) {}
        } message: { printer in
            Text("\(printer.displayName) will be removed from the app.")
        }
    }

    private func printerButton(_ printer: PrinterProfile) -> some View {
        let isActive = printer.id == viewModel.selectedID
        return Button {
            select(printer)
        } label: {
            PrinterCard(
                printer: printer,
                isActive: isActive,
                content: cardContent(for: printer, isActive: isActive)
            )
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                newName = printer.name
                renamingPrinter = printer
            } label: {
                Label("Rename", systemSymbol: .pencil)
            }
            Button(role: .destructive) {
                removingPrinter = printer
            } label: {
                Label("Remove", systemSymbol: .trash)
            }
        }
    }

    private func cardContent(for printer: PrinterProfile, isActive: Bool) -> PrinterCard.Content {
        if isActive {
            if dashboardViewModel.hasReceivedInitialData {
                return .state(dashboardViewModel.contentState)
            }
            if case let .error(message) = dashboardViewModel.mqttConnectionState {
                return .offline(message)
            }
            return .loading
        }
        switch viewModel.status(for: printer.id) {
        case .loading: return .loading
        case let .online(snapshot): return .state(snapshot.contentState)
        case let .offline(message): return .offline(message)
        }
    }

    private func select(_ printer: PrinterProfile) {
        selectedTab = .dashboard
        guard printer.id != viewModel.selectedID else { return }
        SharedSettings.selectPrinter(id: printer.id)
        viewModel.reload()
        Task { await dashboardViewModel.reconnectToSelectedPrinter() }
    }

    private func remove(_ printer: PrinterProfile) {
        if printer.id == viewModel.selectedID {
            dashboardViewModel.clearConfigAndDisconnect()
            viewModel.reload()
        } else {
            viewModel.removeInactive(printer.id)
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renamingPrinter != nil }, set: { if !$0 { renamingPrinter = nil } })
    }

    private var isRemoving: Binding<Bool> {
        Binding(get: { removingPrinter != nil }, set: { if !$0 { removingPrinter = nil } })
    }
}

private struct PrinterCard: View {
    enum Content {
        case loading
        case state(PrinterAttributes.ContentState)
        case offline(String)
    }

    let printer: PrinterProfile
    let isActive: Bool
    let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemSymbol: .printerFill)
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(printer.displayName)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isActive {
                    Text("Active")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.tint)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.2))
                        .clipShape(Capsule())
                }
                Image(systemSymbol: .chevronRight)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            Divider()

            switch content {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Connecting…")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            case let .state(state):
                PrintProgressContent(state: state)
            case let .offline(message):
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not reachable")
                            .font(.subheadline)
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                } icon: {
                    Image(systemSymbol: .wifiSlash)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 12, style: .continuous))
        .overlay {
            if isActive {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            }
        }
        .contentShape(.rect)
    }

    private var subtitle: String {
        [printer.model?.displayName, printer.ip]
            .compactMap(\.self)
            .filter { !$0.isEmpty && $0 != printer.displayName }
            .joined(separator: " · ")
    }
}
