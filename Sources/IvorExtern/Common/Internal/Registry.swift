// © 2025–2026 John Gary Pusey (see LICENSE.md)

// MARK: Internal Constants

internal let exporters: [any ExporterProtocol] = candidates.compactMap { _validExporter(for: $0) }
internal let importers: [any ImporterProtocol] = candidates.compactMap { _validImporter(for: $0) }

// MARK: Private Type Aliases

private typealias Candidate = Exportable & Importable

// MARK: Private Constants

private let candidates: [any Candidate] = [ABC(), Guido(), JohnnySonic(), MusicXML(), MIDI()]

// MARK: Private Functions

private func _validExporter<C: Candidate>(for candidate: C) -> C.Exporter? {
    let exporter = candidate.exporter

    if !exporter.writableFileFormats.isEmpty {
        return exporter
    }

    return nil
}

private func _validImporter<C: Candidate>(for candidate: C) -> C.Importer? {
    let importer = candidate.importer

    if !importer.readableFileFormats.isEmpty {
        return importer
    }

    return nil
}
