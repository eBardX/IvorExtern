// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal import IvorJohnnySonic

internal struct JohnnySonic {

    // MARK: Internal Nested Types

    internal typealias BaseFormatter = DKMFormatter
    internal typealias BaseParser    = DKMParser
    internal typealias Command       = DKMCommand
    internal typealias Score         = DKMScore

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - Exportable

extension JohnnySonic: Exportable {
}

// MARK: - Importable

extension JohnnySonic: Importable {
}

// MARK: - Sendable

extension JohnnySonic: Sendable {
}
