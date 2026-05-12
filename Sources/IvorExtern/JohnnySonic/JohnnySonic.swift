internal import IvorJohnnySonic

internal struct JohnnySonic {

    // MARK: Internal Nested Types

    internal typealias BaseFormatter = DKMFormatter
    internal typealias Entry         = DKMEntry
    internal typealias Score         = DKMScore

    // MARK: Internal Instance Properties

    internal let exporter = Self.Exporter()
    internal let importer = Self.Importer()
}

// MARK: - External.Exportable

extension JohnnySonic: External.Exportable {
}

// MARK: - External.Importable

extension JohnnySonic: External.Importable {
}

// MARK: - Sendable

extension JohnnySonic: Sendable {
}
