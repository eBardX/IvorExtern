// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel
internal import IvorMXL

private import XestiTools

// MARK: Internal Functions

// The text printed on the first page: every subtitle and the
// dedication, the things only a credit can hold. MusicXML has no standard
// credit type for a dedication (the schema mentions one but names no
// value), so it's typed `dedication`, which the free-text type allows.
// The title is printed too, so that a renderer laying out the page from
// its credits shows it above the rest.
internal func convertToMusicXMLCredits(title: String?,
                                       subtitles: [String],
                                       dedication: String?) -> [MXLCredit] {
    var credits: [MXLCredit] = []

    func add(_ kind: String, _ text: String) {
        credits.append(MXLCredit(kind: [kind],
                                 content: .alternative(content: .creditWords(MXLFormattedTextID(value: text)),
                                                       group: []),
                                 page: 1))
    }

    if let title, !subtitles.isEmpty || dedication != nil {
        add("title", title)
    }

    for subtitle in subtitles {
        add("subtitle", subtitle)
    }

    if let dedication {
        add("dedication", dedication)
    }

    return credits
}

// The work's `<identification>` (see `determineWorkInfo(_:)` for the
// reverse mapping): a `<creator>` for each credit, typed with its role,
// except that a transcriber is the `<encoder>`; a `<rights>` for each
// notice, typed with its scope; and its remarks (see
// `convertToMusicXMLIdentification(remarks:alternateTitles:encoders:)`),
// plus a miscellaneous field for each alternate title, which MusicXML has
// no element for. The work and movement numbers aren't remarks here: they
// have elements of their own, outside `<identification>`.
internal func convertToMusicXMLIdentification(_ info: Work.Info) -> MXLIdentification? {
    let creators = info.credits.filter { $0.role != .transcriber }.map {
        MXLTypedText(value: $0.name, kind: $0.role?.stringValue)
    }
    let encoders = info.credits.filter { $0.role == .transcriber }.map {
        MXLTypedText(value: $0.name)
    }
    let rights = info.rights.map {
        MXLTypedText(value: $0.text, kind: $0.scope?.stringValue)
    }
    let remarks = info.remarks.filter {
        $0.label != RemarkLabel.workNumber && $0.label != RemarkLabel.movementNumber
    }
    let base = convertToMusicXMLIdentification(remarks: remarks,
                                               alternateTitles: info.alternateTitles,
                                               encoders: encoders)

    guard !creators.isEmpty || !rights.isEmpty || base != nil
    else { return nil }

    return MXLIdentification(creator: creators,
                             rights: rights,
                             encoding: base?.encoding,
                             source: base?.source,
                             relation: base?.relation ?? [],
                             miscellaneous: base?.miscellaneous)
}

// An `<identification>` holding remarks, alternate titles and encoders,
// or `nil` with none to hold. The first `source` remark is the `<source>`
// (there can be only one), each `relation` remark a `<relation>`, and each
// `encoding description` remark an `<encoding-description>`; every other
// remark is a miscellaneous field named for its label, or for
// `MusicXML.remarkFieldName` without one.
internal func convertToMusicXMLIdentification(remarks: [Remark],
                                              alternateTitles: [String] = [],
                                              encoders: [MXLTypedText] = []) -> MXLIdentification? {
    var source: String?
    var relations: [MXLTypedText] = []
    var encodingItems = encoders.map { MXLEncoding.Item.encoder($0) }
    var fields = alternateTitles.map { MXLMiscellaneous.Field(value: $0, name: MusicXML.alternateTitleFieldName) }

    for remark in remarks {
        switch remark.label {
        case RemarkLabel.source where source == nil:
            source = remark.text

        case RemarkLabel.relation:
            relations.append(MXLTypedText(value: remark.text))

        case RemarkLabel.encodingDescription:
            encodingItems.append(.encodingDescription(remark.text))

        default:
            fields.append(MXLMiscellaneous.Field(value: remark.text,
                                                 name: remark.label ?? MusicXML.remarkFieldName))
        }
    }

    guard source != nil || !relations.isEmpty || !encodingItems.isEmpty || !fields.isEmpty
    else { return nil }

    return MXLIdentification(encoding: encodingItems.isEmpty ? nil : MXLEncoding(items: encodingItems),
                             source: source,
                             relation: relations,
                             miscellaneous: fields.isEmpty ? nil : MXLMiscellaneous(field: fields))
}

// MusicXML describes a work twice over: semantically, in `<work>`,
// `<movement-*>` and `<identification>`, and presentationally, in the
// `<credit>`s printed on the page. The semantic layer is preferred, and a
// credit is read only for what that layer lacks: the title when the score
// has neither a work nor a movement title, every subtitle and the
// dedication (which only a credit can hold), and creators or rights when `<identification>` has
// none. A credit's purpose is its `<credit-type>`, so one from a file
// older than MusicXML 3.0, which has none, isn't read at all.
//
// A movement's title is the title of the work, and the work it belongs to
// is its parent; a score with no movement title is titled by its work
// title. An `<encoder>` is credited as a transcriber, the role ABC's `Z:`
// gives the same person. Work and movement numbers, the source,
// relations, and encoding descriptions have no dedicated home, so they're
// kept as labeled remarks, as is each miscellaneous field, labeled with
// its name.
internal func determineWorkInfo(_ score: MusicXML.Score) -> Work.Info {
    var info = Work.Info()
    let workTitle = score.work?.title?.nilIfEmpty
    let identification = score.identification

    if let movementTitle = score.movementTitle?.nilIfEmpty {
        info.title = movementTitle
        info.parentWorkTitle = workTitle
    } else {
        info.title = workTitle
    }

    _addIdentification(identification, to: &info)

    _addCredits(score.credit,
                to: &info,
                hasCreators: !(identification?.creator.isEmpty ?? true),
                hasRights: !(identification?.rights.isEmpty ?? true))

    for (label, value) in [(RemarkLabel.workNumber, score.work?.number), (RemarkLabel.movementNumber, score.movementNumber)] {
        if let value, let remark = Remark(text: value, label: label) {
            info.remarks.append(remark)
        }
    }

    for item in _remarks(identification) {
        if let alternateTitle = item.alternateTitle {
            info.alternateTitles.append(alternateTitle)
        } else if let remark = item.remark {
            info.remarks.append(remark)
        }
    }

    return info
}

// MARK: Private Functions

private func _addCredits(_ credits: [MXLCredit],
                         to info: inout Work.Info,
                         hasCreators: Bool,
                         hasRights: Bool) {
    let hadTitle = info.title != nil

    for credit in credits {
        guard let text = _creditText(credit)
        else { continue }

        for kind in credit.kind.map({ $0.normalizingWhitespace().lowercased() }) {
            switch kind {
            case "title" where !hadTitle && info.title == nil:
                info.title = text

            case "dedication" where info.dedication == nil:
                info.dedication = text

            case "subtitle":
                info.subtitles.append(text)

            case "arranger" where !hasCreators,
                 "composer" where !hasCreators,
                 "lyricist" where !hasCreators:
                if let credit = Credit(name: text, role: Credit.Role(stringValue: kind)) {
                    info.credits.append(credit)
                }

            case "rights" where !hasRights:
                if let notice = RightsNotice(text: text) {
                    info.rights.append(notice)
                }

            default:
                break
            }
        }
    }
}

private func _addIdentification(_ identification: MXLIdentification?,
                                to info: inout Work.Info) {
    for creator in identification?.creator ?? [] {
        if let credit = Credit(name: creator.value,
                               role: creator.kind.flatMap { Credit.Role(stringValue: $0.normalizingWhitespace()) }) {
            info.credits.append(credit)
        }
    }

    for item in identification?.encoding?.items ?? [] {
        if case let .encoder(encoder) = item,
           let credit = Credit(name: encoder.value, role: .transcriber) {
            info.credits.append(credit)
        }
    }

    for rights in identification?.rights ?? [] {
        if let notice = RightsNotice(text: rights.value,
                                     scope: rights.kind.flatMap { RightsNotice.Scope(stringValue: $0.normalizingWhitespace()) }) {
            info.rights.append(notice)
        }
    }
}

// The words of a credit, joined from every `<credit-words>` it holds; `nil`
// for a credit that is an image or symbol alone.
private func _creditText(_ credit: MXLCredit) -> String? {
    guard case let .alternative(content, group) = credit.content
    else { return nil }

    var words: [String] = []

    if case let .creditWords(text) = content {
        words.append(text.value)
    }

    for item in group {
        if case let .creditWords(text) = item.content {
            words.append(text.value)
        }
    }

    return words.joined().nilIfEmpty
}

// The remarks an `<identification>` holds, plus any alternate title kept in
// a miscellaneous field (see `MusicXML.alternateTitleFieldName`).
private func _remarks(_ identification: MXLIdentification?) -> [(remark: Remark?, alternateTitle: String?)] {
    guard let identification
    else { return [] }

    var results: [(remark: Remark?, alternateTitle: String?)] = []

    func add(_ text: String, _ label: String?) {
        results.append((Remark(text: text, label: label), nil))
    }

    if let source = identification.source {
        add(source, RemarkLabel.source)
    }

    for relation in identification.relation {
        add(relation.value, RemarkLabel.relation)
    }

    for item in identification.encoding?.items ?? [] {
        if case let .encodingDescription(text) = item {
            add(text, RemarkLabel.encodingDescription)
        }
    }

    for field in identification.miscellaneous?.field ?? [] {
        switch field.name {
        case MusicXML.alternateTitleFieldName:
            results.append((nil, field.value))

        case MusicXML.remarkFieldName:
            add(field.value, nil)

        default:
            add(field.value, field.name)
        }
    }

    return results
}
