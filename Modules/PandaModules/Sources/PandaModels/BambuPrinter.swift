import Foundation

// MARK: - Printer Family

public enum PrinterFamily: String, CaseIterable, Identifiable, Sendable {
    case x1
    case p1
    case p2
    case a1
    case h2
    case h3

    public var id: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .x1: "X1 Series"
        case .p1: "P1 Series"
        case .p2: "P2 Series"
        case .a1: "A1 Series"
        case .h2: "H2 Series"
        case .h3: "H3 Series"
        }
    }

    public var models: [BambuPrinter] {
        BambuPrinter.allCases.filter { $0.family == self }
    }
}

// MARK: - Printer Model

public enum BambuPrinter: String, CaseIterable, Identifiable, Codable, Sendable {
    case x1
    case x1c
    case x1e
    case p1p
    case p1s
    case p2s
    case a1
    case a1Mini
    case h2c
    case h2d
    case h2dPro
    case h2s
    case h3c

    public var id: String {
        rawValue
    }

    public var family: PrinterFamily {
        switch self {
        case .x1, .x1c, .x1e: .x1
        case .p1p, .p1s: .p1
        case .p2s: .p2
        case .a1, .a1Mini: .a1
        case .h2c, .h2d, .h2dPro, .h2s: .h2
        case .h3c: .h3
        }
    }

    public var displayName: String {
        switch self {
        case .x1: "X1"
        case .x1c: "X1 Carbon"
        case .x1e: "X1E"
        case .p1p: "P1P"
        case .p1s: "P1S"
        case .p2s: "P2S"
        case .a1: "A1"
        case .a1Mini: "A1 Mini"
        case .h2c: "H2C"
        case .h2d: "H2D"
        case .h2dPro: "H2D Pro"
        case .h2s: "H2S"
        case .h3c: "H3C"
        }
    }

    public var cameraProtocol: PrinterType {
        switch self {
        case .x1, .x1c, .x1e, .p2s, .h2c, .h2d, .h2dPro, .h2s, .h3c:
            .rtsp
        case .p1p, .p1s, .a1, .a1Mini:
            .tcp
        }
    }

    public var serialRequired: Bool {
        switch self {
        case .a1, .a1Mini: true
        default: false
        }
    }

    public var hasChamberTemp: Bool {
        switch self {
        case .x1, .x1c, .x1e, .p2s, .h2c, .h2d, .h2dPro, .h2s, .h3c:
            true
        case .p1p, .p1s, .a1, .a1Mini:
            false
        }
    }

    public var hasAuxFan: Bool {
        switch self {
        case .a1, .a1Mini: false
        default: true
        }
    }

    public var hasAirduct: Bool {
        switch self {
        case .p2s: true
        default: false
        }
    }

    public var hasDualNozzle: Bool {
        switch self {
        case .h2c, .h2d, .h2dPro: true
        default: false
        }
    }
}
