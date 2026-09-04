// © 2026 John Gary Pusey (see LICENSE.md)

internal import Foundation
internal import IvorABC

private import XestiTools

// `m:` macro matching and expansion, ported from upstream's own macro
// matcher/expander. `ABCMacro`'s own pre-parsed `kind` /
// `targetSymbols` / `replacementSymbols` / `replacementTemplate` /
// `targetNoteLength` properties are `internal` to IvorABC and invisible
// here, so this type re-derives the same information from `ABCMacro`'s two
// public raw strings (`target`/`replacement`) instead: the static/transposing
// split and the trailing note-slot length come from the same text-level scan
// `parseMacroTarget` uses, and every symbol fragment (a target's literal
// prefix, a static replacement, a transposing replacement with its
// placeholder letters substituted for real note text) is recovered by
// re-lexing through the public `ABC.BaseParser`, the same re-lex-through-the-
// public-parser trick Guido's `$variable` expansion uses.
//
// `U:` shorthand-to-decoration/annotation mappings are intentionally not
// modeled at all: a shorthand can only ever resolve to a decoration or
// annotation (`ABCUserSymbol.Definition`), both dropped entirely, so they
// can never affect a note table or tempo map.
extension ABC.Importer {

    // MARK: Internal Nested Types

    internal struct MacroTable {
    }
}

// MARK: -

extension ABC.Importer.MacroTable {

    // MARK: Internal Instance Methods

    // Expands a macro match into its literal replacement symbols.
    internal func expand(_ match: Match) throws(ABC.Error) -> [ABCSymbol] {
        switch Self._parsedTarget(match.macro.target).kind {
        case .static:
            return _symbols(from: match.macro.replacement)

        case .transposing:
            guard let matchedNote = match.matchedNote
            else { return [] }

            return try _symbols(from: _substituted(match.macro.replacement,
                                                   matchedPitch: matchedNote.pitch))
        }
    }

    // Returns the first active macro (most-recently-defined first, i.e.
    // `macros.reversed()`) whose target pattern matches starting at
    // `index`, or `nil` if none match.
    internal func findMatch(_ symbols: [ABCSymbol],
                            _ index: Int,
                            _ macros: [ABCMacro]) -> Match? {
        for macro in macros.reversed() {
            let parsedTarget = Self._parsedTarget(macro.target)
            let prefixSymbols = _symbols(from: parsedTarget.prefixText)
            let prefixCount = prefixSymbols.count

            guard index + prefixCount <= symbols.count,
                  Array(symbols[index..<(index + prefixCount)]) == prefixSymbols
            else { continue }

            switch parsedTarget.kind {
            case .static:
                guard prefixCount > 0
                else { continue }

                return Match(consumedCount: prefixCount,
                             macro: macro,
                             matchedNote: nil)

            case .transposing:
                let noteIndex = index + prefixCount

                guard noteIndex < symbols.count,
                      case let .note(note) = symbols[noteIndex],
                      note.length == parsedTarget.noteLength
                else { continue }

                return Match(consumedCount: prefixCount + 1,
                             macro: macro,
                             matchedNote: note)
            }
        }

        return nil
    }

    // MARK: Private Nested Types

    // Which flavor of macro a target pattern describes, re-derived from
    // `ABCMacro.target`'s raw text (see the type-level comment).
    private enum Kind {
        case `static`
        case transposing
    }

    // MARK: Private Type Properties

    // The letters of the diatonic (natural, 7-note) scale in ascending pitch
    // order, anchored at C.
    private static let diatonicOrder: [ABCPitch.Letter] = [.c, .d, .e, .f, .g, .a, .b]

    // `n` is offset 0 (the matched note itself); `h`–`m` step diatonically
    // downward, `o`–`w` upward.
    private static let placeholderDiatonicOffsets: [Character: Int] = ["h": -6,
                                                                       "i": -5,
                                                                       "j": -4,
                                                                       "k": -3,
                                                                       "l": -2,
                                                                       "m": -1,
                                                                       "n": 0,
                                                                       "o": 1,
                                                                       "p": 2,
                                                                       "q": 3,
                                                                       "r": 4,
                                                                       "s": 5,
                                                                       "t": 6,
                                                                       "u": 7,
                                                                       "v": 8,
                                                                       "w": 9]

    // MARK: Private Type Methods

    // Renders `pitch` as ABC note-source text (letter case plus `'`/`,`
    // octave marks, no accidental — a macro placeholder note always carries
    // `.omitted`), the inverse of `pitchLetterOctaves`.
    private static func _noteText(for pitch: ABCPitch) -> String {
        let octave = Int(pitch.octave.uintValue)
        let upper = String(describing: pitch.letter).uppercased()

        return octave <= 4
            ? upper + String(repeating: ",", count: 4 - octave)
            : upper.lowercased() + String(repeating: "'", count: octave - 5)
    }

    // A minimal length-multiplier parser, ported from the internal
    // `parseLength(_:)`: `<decUInteger>? "/" ( <decUInteger>? | "/"{2,6} )`.
    private static func _parsedLength(_ text: Substring) -> ABCLength? {
        guard !text.isEmpty
        else { return nil }

        guard let slashIndex = text.firstIndex(of: "/")
        else {
            guard let numerator = UInt(text)
            else { return nil }

            return ABCLength(numerator: numerator)
        }

        let head = text[text.startIndex..<slashIndex]
        var tail = text[slashIndex...]
        var numerator: UInt = 1
        var denominator: UInt = 1

        if !head.isEmpty {
            guard let numer = UInt(head)
            else { return nil }

            numerator = numer
        }

        while tail.hasPrefix("/") {
            denominator *= 2
            tail = tail.dropFirst()
        }

        if !tail.isEmpty {
            guard denominator == 2,
                  let denom = UInt(tail)
            else { return nil }

            denominator = denom
        }

        return ABCLength(numerator: numerator,
                         denominator: denominator)
    }

    // Determines whether `target` is static or transposing, and splits it
    // into its literal prefix text (the whole string, for a static target)
    // and, for a transposing target, the required written length of the
    // trailing `n` note-slot. Ported from the internal `parseMacroTarget(_:)`.
    private static func _parsedTarget(_ target: String) -> (kind: Kind, prefixText: String, noteLength: ABCLength?) {
        let chars = Substring(target)
        var lengthStart = chars.endIndex

        while lengthStart > chars.startIndex,
              "0123456789/".contains(chars[chars.index(before: lengthStart)]) {
            lengthStart = chars.index(before: lengthStart)
        }

        guard lengthStart > chars.startIndex,
              chars[chars.index(before: lengthStart)] == "n"
        else { return (.static, target, nil) }

        let lengthText = chars[lengthStart...]
        let noteLength = lengthText.isEmpty ? ABCLength(numerator: 1).require() : _parsedLength(lengthText)

        guard let noteLength
        else { return (.static, target, nil) }

        return (.transposing, String(chars[..<chars.index(before: lengthStart)]), noteLength)
    }

    // Shifts `pitch` by `diatonicOffset` steps of the natural (7-note) scale,
    // wrapping the octave at the B/C boundary. Returns `nil` if the result
    // falls outside octave 0...9.
    private static func _transposedPitch(_ pitch: ABCPitch,
                                         by diatonicOffset: Int) -> ABCPitch? {
        guard let letterIndex = diatonicOrder.firstIndex(of: pitch.letter)
        else { return nil }

        let totalSteps = letterIndex + diatonicOffset
        let newLetterIndex = ((totalSteps % 7) + 7) % 7
        let octaveShift = totalSteps >= 0 ? totalSteps / 7 : (totalSteps - 6) / 7
        let newOctaveValue = Int(pitch.octave.uintValue) + octaveShift

        guard newOctaveValue >= 0,
              let newOctave = ABCPitch.Octave(uintValue: UInt(newOctaveValue))
        else { return nil }

        return ABCPitch(letter: diatonicOrder[newLetterIndex],
                        accidental: .omitted,
                        octave: newOctave)
    }

    // MARK: Private Instance Methods

    // Substitutes each depth-0 placeholder letter in `replacement` with the
    // matched note's pitch, diatonically transposed and rendered back as ABC
    // note-source text, so the result can be handed to the public parser.
    // Depth tracks `{`/`}` and `[`/`]` nesting — placeholders are recognized
    // only at depth 0, since grace-note/chord contents are always literal.
    // `!...!` and `"..."` delimited spans are copied through verbatim.
    private func _substituted(_ replacement: String,
                              matchedPitch: ABCPitch) throws(ABC.Error) -> String {
        var result = ""
        var protectedDelimiter: Character?
        var nestingDepth = 0

        for character in replacement {
            if let delimiter = protectedDelimiter {
                result.append(character)

                if character == delimiter {
                    protectedDelimiter = nil
                }

                continue
            }

            if character == "!" || character == "\"" {
                protectedDelimiter = character
                result.append(character)
                continue
            }

            if character == "{" || character == "[" {
                nestingDepth += 1
                result.append(character)
                continue
            }

            if character == "}" || character == "]" {
                nestingDepth = max(0, nestingDepth - 1)
                result.append(character)
                continue
            }

            if nestingDepth == 0,
               let diatonicOffset = Self.placeholderDiatonicOffsets[character] {
                guard let transposed = Self._transposedPitch(matchedPitch, by: diatonicOffset)
                else { throw ABC.Error.unresolvableMacro("diatonic offset \(diatonicOffset) from \(matchedPitch) is out of range") }

                result += Self._noteText(for: transposed)
                continue
            }

            result.append(character)
        }

        return result
    }

    // Parses `text` as a literal symbol sequence via the public parser,
    // wrapped in a minimal synthetic tune — best-effort, matching the
    // leniency the internal tokenizer/matcher route has always had for
    // macro content: an unparseable fragment yields no symbols.
    private func _symbols(from text: String) -> [ABCSymbol] {
        guard !text.isEmpty,
              let (tunebook, _) = try? ABC.BaseParser().parse(Data("X:1\nK:C\n\(text)\n".utf8)),
              let tune = tunebook.tunes.first
        else { return [] }

        return tune.body.flatMap { entry -> [ABCSymbol] in
            guard case let .symbols(symbols) = entry
            else { return [] }

            return symbols
        }
    }
}
