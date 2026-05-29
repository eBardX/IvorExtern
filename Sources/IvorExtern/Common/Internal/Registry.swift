// © 2025–2026 John Gary Pusey (see LICENSE.md)

internal let exporters: [any ExporterProtocol] = candidates.compactMap { _validExporter(for: $0) }
internal let importers: [any ImporterProtocol] = candidates.compactMap { _validImporter(for: $0) }

// MARK: - Private Type Aliases

private typealias Candidate       = Exportable & Importable
private typealias ValidFileFormat = (fileFormat: FileFormat, import: Bool, export: Bool)

// MARK: - Private Constants

private let candidates: [any Candidate] = [ABC(), Guido(), JohnnySonic(), MusicXML(), MIDI()]
private let validFileFormats: [ValidFileFormat] = candidates.flatMap {
    _validFileFormats(for: $0)
}.sorted {
    $0.fileFormat.displayName < $1.fileFormat.displayName
}

// MARK: - Private Functions

private func _validExporter<C: Candidate>(for candidate: C) -> C.Exporter? {
    let exporter = candidate.exporter

    if !exporter.writableFileFormats.isEmpty {
        return exporter
    }

    return nil
}

private func _validFileFormats(for candidate: some Candidate) -> [ValidFileFormat] {
    var tmpValidFileFormats: [String: ValidFileFormat] = [:]

    for fileFormat in candidate.exporter.writableFileFormats {
        if let vff = tmpValidFileFormats[fileFormat.uniqueID] {
            tmpValidFileFormats[fileFormat.uniqueID] = (fileFormat: vff.fileFormat, import: vff.import, export: true)
        } else {
            tmpValidFileFormats[fileFormat.uniqueID] = (fileFormat: fileFormat, import: false, export: true)
        }
    }

    for fileFormat in candidate.importer.readableFileFormats {
        if let vff = tmpValidFileFormats[fileFormat.uniqueID] {
            tmpValidFileFormats[fileFormat.uniqueID] = (fileFormat: vff.fileFormat, import: true, export: vff.export)
        } else {
            tmpValidFileFormats[fileFormat.uniqueID] = (fileFormat: fileFormat, import: true, export: false)
        }
    }

    return Array(tmpValidFileFormats.values)
}

private func _validImporter<C: Candidate>(for candidate: C) -> C.Importer? {
    let importer = candidate.importer

    if !importer.readableFileFormats.isEmpty {
        return importer
    }

    return nil
}
