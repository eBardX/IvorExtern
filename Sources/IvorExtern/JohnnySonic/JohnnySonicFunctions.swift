// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorTiming
internal import IvorTuning

private import Foundation
private import IvorDKM
private import XestiNumbers
private import XestiTools

// MARK: Internal Functions

internal func convertToBeatDuration(_ duration: Double) -> BeatDuration {
    BeatDuration(Number(duration))
}

internal func convertToBeatTime(_ beat: Double) -> BeatTime {
    BeatTime(Number(beat))
}

internal func convertToDynamic(_ volume: Double) -> Dynamic? {
    Dynamic(numberValue: Number(volume / 10.0))
}

// Takes a frequency already in Hz — `JohnnySonic.Importer.Tuning`, not this
// function, is what turns a raw JohnnySonic pitch (positive = pitch number,
// negative = frequency in Hz) into Hz.
internal func convertToFrequency(_ hertz: Double) -> Frequency? {
    Frequency(numberValue: Number(hertz))
}

internal func convertToInstrument(_ name: String) -> Instrument? {
    Instrument(stringValue: name)
}

internal func convertToJohnnySonicBeat(_ beatTime: BeatTime) -> JohnnySonic.Beat {
    beatTime.doubleValue
}

// DKM defines no metadata at all — only comments — so the work's metadata
// is written as comment lines in a `Key: value` form of this module's own
// (see `determineWorkMetadata(_:)` for the reverse), right after the
// `| Work: … |` banner that already carries the work's name. A credit's
// role, a rights notice's scope, or a remark's label follows the key in
// parentheses — `Credit (composer): J. S. Bach`. Every line but the first
// of a multi-line rights notice or remark is a continuation line, indented
// two spaces. Part metadata isn't written: DKM has no parts, only the
// per-note instrument names that `JohnnySonic.Importer` groups notes by.
internal func convertToJohnnySonicComments(_ metadata: Work.Metadata) -> [String] {
    var comments: [String] = []

    func add(_ key: String, _ qualifier: String?, _ text: String) {
        let lines = text.components(separatedBy: "\n")
        let prefix = qualifier.map { "\(key) (\($0)): " } ?? "\(key): "

        comments.append(prefix + (lines.first ?? ""))
        comments += lines.dropFirst().map { continuationPrefix + $0 }
    }

    if let title = metadata.title {
        add(titleKey, nil, title)
    }

    for subtitle in metadata.subtitles {
        add(subtitleKey, nil, subtitle)
    }

    for alternateTitle in metadata.alternateTitles {
        add(alternateTitleKey, nil, alternateTitle)
    }

    if let parentWorkTitle = metadata.parentWorkTitle {
        add(parentWorkTitleKey, nil, parentWorkTitle)
    }

    for credit in metadata.credits {
        add(creditKey, credit.role?.stringValue, credit.name)
    }

    for notice in metadata.rights {
        add(rightsKey, notice.scope?.stringValue, notice.text)
    }

    for remark in metadata.remarks {
        add(remarkKey, remark.label, remark.text)
    }

    return comments
}

internal func convertToJohnnySonicDuration(_ beatDuration: BeatDuration) -> JohnnySonic.Duration {
    beatDuration.doubleValue
}

internal func convertToJohnnySonicLocation(_ pan: Pan) -> JohnnySonic.Location {
    pan.stereo.doubleValue
}

internal func convertToJohnnySonicPitch(_ frequency: Frequency) -> JohnnySonic.Pitch {
    -frequency.doubleValue
}

internal func convertToJohnnySonicPitch(_ noteNumber: NoteNumber) -> JohnnySonic.Pitch {
    noteNumber.doubleValue
}

internal func convertToJohnnySonicTempo(_ tempo: Tempo) -> JohnnySonic.Tempo {
    tempo.doubleValue
}

internal func convertToJohnnySonicVolume(_ dynamic: Dynamic) -> JohnnySonic.Volume {
    dynamic.doubleValue * 10
}

internal func convertToNoteNumber(_ pitch: Double) -> NoteNumber? {
    guard pitch >= 0
    else { return nil }

    return NoteNumber(uintValue: UInt(pitch.rounded()))
}

internal func convertToPan(_ location: JohnnySonic.Location) -> Pan? {
    Pan(stereo: Number(location))
}

internal func convertToTempo(_ bpm: Double) -> Tempo {
    guard bpm.isFinite, bpm > 0
    else { return .default }

    return Tempo(uintValue: UInt(bpm.rounded())) ?? .default
}

// Reads the metadata comment lines `convertToJohnnySonicComments(_:)`
// writes. Every other comment is a remark with no label, the only reading
// DKM gives one — except the boxed banners `JohnnySonic.Exporter` frames
// its sections with — and a run of consecutive comment lines, unbroken by
// any other command, is one remark.
internal func determineWorkMetadata(_ score: JohnnySonic.Score) -> Work.Metadata {
    var metadata = Work.Metadata()
    var entry: (key: String, qualifier: String?, lines: [String])?
    var plainLines: [String] = []

    func flush() {
        if let entry {
            _addMetadata(entry.key, entry.qualifier, entry.lines.joined(separator: "\n"), to: &metadata)
        }

        if let remark = Remark(text: plainLines.joined(separator: "\n")) {
            metadata.remarks.append(remark)
        }

        entry = nil
        plainLines = []
    }

    for command in score.commands {
        guard case let .comment(text) = command,
              !_isBanner(text)
        else {
            flush()
            continue
        }

        if entry != nil, text.hasPrefix(continuationPrefix) {
            entry?.lines.append(String(text.dropFirst(continuationPrefix.count)))
        } else if let parsed = _parseMetadataComment(text) {
            flush()
            entry = (parsed.key, parsed.qualifier, [parsed.value])
        } else {
            if entry != nil {
                flush()
            }

            plainLines.append(text)
        }
    }

    flush()

    return metadata
}

internal func determineWorkName(_ score: JohnnySonic.Score) -> String {
    let prefix = "| Work: "
    let suffix = " |"

    for command in score.commands {
        guard case let .comment(text) = command
        else { continue }

        if text.hasPrefix(prefix), text.hasSuffix(suffix) {
            return String(text.dropFirst(prefix.count).dropLast(suffix.count))
        }
    }

    return ""
}

// MARK: Private Constants

private let alternateTitleKey  = "Alternate Title"
private let continuationPrefix = "  "
private let creditKey          = "Credit"
private let parentWorkTitleKey = "Parent Work Title"
private let remarkKey          = "Remark"
private let rightsKey          = "Rights"
private let subtitleKey        = "Subtitle"
private let titleKey           = "Title"

private let metadataKeys = [alternateTitleKey, creditKey, parentWorkTitleKey, remarkKey, rightsKey, subtitleKey, titleKey]

// MARK: Private Functions

private func _addMetadata(_ key: String,
                          _ qualifier: String?,
                          _ value: String,
                          to metadata: inout Work.Metadata) {
    switch key {
    case alternateTitleKey:
        metadata.alternateTitles.append(value)

    case creditKey:
        if let credit = Credit(name: value, role: qualifier.flatMap { Credit.Role(stringValue: $0) }) {
            metadata.credits.append(credit)
        }

    case parentWorkTitleKey:
        metadata.parentWorkTitle = value

    case remarkKey:
        if let remark = Remark(text: value, label: qualifier) {
            metadata.remarks.append(remark)
        }

    case rightsKey:
        if let notice = RightsNotice(text: value, scope: qualifier.flatMap { RightsNotice.Scope(stringValue: $0) }) {
            metadata.rights.append(notice)
        }

    case subtitleKey:
        metadata.subtitles.append(value)

    case titleKey:
        metadata.title = value

    default:
        break
    }
}

// The `+---+` and `| … |` lines `JohnnySonic.Exporter._makeBoxed` frames a
// section's banner with.
private func _isBanner(_ text: String) -> Bool {
    if text.count >= 4, text.hasPrefix("+-"), text.hasSuffix("-+") {
        return text.allSatisfy { $0 == "+" || $0 == "-" }
    }

    return text.hasPrefix("| ") && text.hasSuffix(" |")
}

// Splits `Key: value` or `Key (qualifier): value` into its parts, or `nil`
// for a comment whose key isn't one of `metadataKeys`.
private func _parseMetadataComment(_ text: String) -> (key: String, qualifier: String?, value: String)? {
    for key in metadataKeys where text.hasPrefix(key) {
        var rest = text.dropFirst(key.count)
        var qualifier: String?

        if rest.hasPrefix(" ("), let close = rest.firstIndex(of: ")") {
            qualifier = String(rest[rest.index(rest.startIndex, offsetBy: 2)..<close])
            rest = rest[rest.index(after: close)...]
        }

        guard rest.hasPrefix(": ")
        else { continue }

        return (key, qualifier, String(rest.dropFirst(2)))
    }

    return nil
}
