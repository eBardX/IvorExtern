// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal protocol Exportable<Exporter>: Sendable {

    // MARK: Internal Associated Types

    associatedtype Exporter: ExporterProtocol

    // MARK: Internal Instance Properties

    var exporter: Exporter { get }
}
