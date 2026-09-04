// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal protocol Importable<Importer>: Sendable {

    // MARK: Internal Associated Types

    associatedtype Importer: ImporterProtocol

    // MARK: Internal Instance Properties

    var importer: Importer { get }
}
