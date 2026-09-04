// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorMusicXML

private import XestiNumbers

// The pure duration arithmetic behind the cursor walk: resolving an integer
// `<divisions>` count into a whole-note fraction (ported from upstream's own
// duration-resolution pass), and the whole-measure length implied by an
// active `<time>` (ported from upstream's own measure-style expansion
// helper, needed for a `<multiple-rest>`-covered empty measure).
extension MusicXML.Importer {

    internal struct Rhythm {
    }
}

// MARK: -

extension MusicXML.Importer.Rhythm {

    // MARK: Internal Instance Methods

    // Resolves an integer division `count` against the active `<divisions>`
    // into a whole-note fraction. `context` labels the offending element for
    // errors.
    internal func resolve(count: Int,
                          activeDivisions: Int?,
                          context: @autoclosure () -> String) throws(MusicXML.Error) -> MusicXML.Duration {
        guard let activeDivisions
        else { throw MusicXML.Error.durationBeforeDivisions(context()) }

        guard activeDivisions > 0
        else { throw MusicXML.Error.unresolvableDuration(context()) }

        return MusicXML.Duration(numberValue: Number(numerator: count,
                                                     denominator: activeDivisions * 4))
    }

    // The whole-note fraction of one measure in the active `<time>`: the sum
    // of the beats over the beat type. Throws `Error.unexpandableMeasure`
    // when no measured time is in force or its signature cannot be parsed.
    // `context` labels the offending element.
    internal func wholeMeasureDuration(from time: MXLTime?,
                                       context: @autoclosure () -> String) throws(MusicXML.Error) -> MusicXML.Duration {
        guard let time,
              case let .timeSignature(signatures, _) = time.content,
              let signature = signatures.first
        else { throw MusicXML.Error.unexpandableMeasure(context()) }

        let beatFields = signature.beats.split(separator: "+")
        let beats = beatFields.compactMap { Int($0) }

        guard beats.count == beatFields.count,
              let beatType = Int(signature.beatType),
              beatType > 0
        else { throw MusicXML.Error.unexpandableMeasure(context()) }

        let total = beats.reduce(0, +)

        guard total > 0
        else { throw MusicXML.Error.unexpandableMeasure(context()) }

        return MusicXML.Duration(numberValue: Number(numerator: total,
                                                     denominator: beatType))
    }
}
