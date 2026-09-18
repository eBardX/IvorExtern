# Extras candidates for TempoMap / DynamicMap / InstrumentMap / PanMap / NoteTable

## Background

`TempoMap`, `DynamicMap`, `InstrumentMap`, `PanMap`, and `NoteTable` each let
a per-entry `Extras` value ride along with `insert`/`update` (`extras:
Extras? = nil`), and expose it back through `forEach`. `TempoMap` lives in
`IvorTiming`; `NoteTable` and the other three map types (`DynamicMap`,
`InstrumentMap`, `PanMap`) all live in `IvorModel`. None of IvorExtern's five
importers (ABC, Guido, JohnnySonic, MIDI, MusicXML) currently populate it.

`Extras` (from `XestiTools`) is a name-keyed bag of `Extra(name: String,
values: [AssociatedValue])`, where `AssociatedValue` is `.bool`/`.double`/
`.int`/`.string`. A bare, no-payload `Extra(name: "accent")` is the
established idiom (used throughout `IvorModel`'s and `IvorTiming`'s own entry
tests) for a flag-style tag; a payload-bearing one for anything with an actual
value.

This document proposes a vocabulary of `Extra` names to close the gaps found
by auditing all five importers/exporters. It is organized so the actionable
part — what to name each `Extra` and what payload it carries — comes first,
and the supporting evidence for *why* each one is proposed follows as a
separate reference section.

## Design principles

**Cross-format value over single-format value.** An `Extra` that only helps
one format round-trip its own data is a nice-to-have — it fixes a lossy
conversion within a single importer/exporter pair. An `Extra` that several
*different* formats can produce, using the same name and the same value
convention, is worth more: it lets information survive a **cross-format**
conversion (e.g. MIDI → MusicXML, or ABC → Guido) that would otherwise
silently discard it twice — once on the way in, and again because the target
format's exporter has nothing to write even if the source preserved it
internally. Cross-format candidates are prioritized over single-format ones
throughout this document.

**Tiered vocabulary, not one field per concept.** Several of the richer
`NoteTable` concepts (grace notes, chord symbols, lyrics, articulation/
ornament, slurs) turn out not to reduce to one shared field once the actual
per-format structure is compared. Each of those is instead proposed as a
small family of `Extra` names split into tiers:

- **Tier 1 — universal.** Always populated regardless of source format (or
  populated from every format that has *any* representation of the concept
  at all).
- **Tier 2 — shared-pair.** Populated only when the source is one of exactly
  two formats that happen to share a specific piece of structure; absent for
  the third.
- **Tier 3 — single-format or catch-all.** Either a structure only one
  format has, or a free-text catch-all for whatever doesn't fit a closed
  vocabulary shared by at least two formats.

**Naming avoids collisions and false-sibling names.** Names are unique across
all five `Extra+<Type>.swift` files combined — none is reused in another
file's table. Where a field name would otherwise be ambiguous out of
context, it's given a type-specific prefix instead of the bare concept name:
`lyricText` (not `lyric`), `dynamicMark` (not `mark`), `tempoText` (not
`text`). This also leaves the bare, unprefixed name free for a future
bare-flag/marker `Extra` if one is ever needed.

## Suggested priority

Implement the `dynamicMark` (`DynamicMap`) and `midiBankSelect`/`midiChannel`
(`InstrumentMap`) candidates first — they're the two places where information
is being dropped outright (no MIDI bank-select handling exists at all; a
non-standard dynamic mark produces no `DynamicMap` entry whatsoever) rather
than merely rounded, and both have more than one format ready to produce and
consume them immediately.

`NoteTable`'s `lyricText` and `chordText` candidates are close behind: both
are outright silent loss (not rounding) in three independent importers each,
and both are exactly the kind of information a listener/reader would notice
missing.

## Proposed `Extra` vocabulary

Each table below is the proposed contents of one `Extra+<Type>.swift`
extension file, e.g.:

```swift
extension Extra {
    public static let accent = Self(name: "accent")
    public static let lyricText = Self(name: "lyricText")
}
```

`Extra+TempoMap.swift` belongs in `IvorTiming`; the other four belong in
`IvorModel`. The "Findings" column links each row to its supporting evidence
in the [Findings and rationale](#findings-and-rationale) section below.

### `Extra+TempoMap.swift`

| Name | Payload | Findings |
| --- | --- | --- |
| `tempoText` | `.string` (e.g. `"Allegro"`) | [Human tempo text](#tempomap-tempotext) |
| `exactMicrosecondsPerQuarter` | `.int` | [MIDI tempo rounding](#tempomap-single-format) |
| `rampInitialTempo` | `.double` or `.int` | [JohnnySonic tempo ramp](#tempomap-single-format) |
| `rampFinalTempo` | `.double` or `.int` | [JohnnySonic tempo ramp](#tempomap-single-format) |
| `rampDuration` | `.double` | [JohnnySonic tempo ramp](#tempomap-single-format) |

### `Extra+DynamicMap.swift`

| Name | Payload | Findings |
| --- | --- | --- |
| `dynamicMark` | `.string` (e.g. `"sfz"`, `"rfz"`, free text) | [Off-scale dynamic marks](#dynamicmap-dynamicmark) |
| `velocity` | `.int` (0–127, MIDI-style scale) | [Pre-quantization velocity](#dynamicmap-velocity) |
| `expressionValue` | `.int` (0–127, MIDI-style scale) | [MIDI Expression Controller](#dynamicmap-expressionvalue) |

### `Extra+InstrumentMap.swift`

| Name | Payload | Findings |
| --- | --- | --- |
| `midiProgram` | `.int` (0–127) | [Shared GM program number](#instrumentmap-midiprogram) |
| `midiChannel` | `.int` (1–16) | [Shared channel identity](#instrumentmap-midichannel) |
| `midiBankSelect` | `.int` (0–16,384) | [Bank Select gap](#instrumentmap-midibankselect) |
| `midiVolume` | `.int` or `.double` (0–100, MusicXML's percent scale) | [Channel Volume](#instrumentmap-midivolume) |
| `midiElevation` | `.double` (MusicXML `<elevation>` degrees, -180 to 180) | [MusicXML-only sourcing](#instrumentmap-single-format) |
| `midiUnpitched` | `.int` (MIDI note number, 1–128 as MusicXML declares it) | [MusicXML-only sourcing](#instrumentmap-single-format) |

### `Extra+PanMap.swift`

| Name | Payload | Findings |
| --- | --- | --- |
| `panDegree` | `.double` (unclamped, beyond ±90°) | [MusicXML clamping](#panmap-single-format) |
| `panControllerValue` | `.int` (0–16,383) | [MIDI Pan LSB gap](#panmap-single-format) |

### `Extra+NoteTable.swift`

| Name | Payload | Findings |
| --- | --- | --- |
| `gracePitches` | `.string` (ordered pitch list, e.g. `"D4,E4,F#4"`) | [Grace notes](#notetable-grace) |
| `graceIsSlashed` | bare flag | [Grace notes](#notetable-grace) |
| `graceLengths` | `.string` (ordered, parallel to `gracePitches`) | [Grace notes](#notetable-grace) |
| `graceStealTimePrevious` | `.double` (percent) | [Grace notes](#notetable-grace) |
| `graceStealTimeFollowing` | `.double` (percent) | [Grace notes](#notetable-grace) |
| `graceMakeTime` | `.double` (real-time divisions) | [Grace notes](#notetable-grace) |
| `chordText` | `.string` (e.g. `"Cmaj7"`, `"G/B"`) | [Chord symbols](#notetable-chordsymbol) |
| `chordRootStep` | `.string` (e.g. `"C"`) | [Chord symbols](#notetable-chordsymbol) |
| `chordRootAlter` | `.int` (semitones) | [Chord symbols](#notetable-chordsymbol) |
| `chordBassStep` | `.string` | [Chord symbols](#notetable-chordsymbol) |
| `chordBassAlter` | `.int` (semitones) | [Chord symbols](#notetable-chordsymbol) |
| `lyricText` | `.string` (one syllable/word) | [Lyrics](#notetable-lyric) |
| `lyricHyphenation` | `.string` (`"begin"`/`"middle"`/`"end"`/`"single"`) | [Lyrics](#notetable-lyric) |
| `lyricMelisma` | bare flag | [Lyrics](#notetable-lyric) |
| `lyricVerse` | `.string` | [Lyrics](#notetable-lyric) |
| `accent` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `marcato` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `tenuto` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `staccato` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `fermata` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `harmonic` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `pizzicato` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `trill` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `mordent` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `turn` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `upBow` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `downBow` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `breathMark` | bare flag | [Articulation/ornament](#notetable-articulation) |
| `fingering` | `.string` | [Articulation/ornament](#notetable-articulation) |
| `articulation` | `.string` (mark name, e.g. `"staccatissimo"`, `"spiccato"`) | [Articulation/ornament](#notetable-articulation) |
| `slurStart` | bare flag, or `.string` id | [Slurs](#notetable-slur) |
| `slurEnd` | bare flag, or `.string` id | [Slurs](#notetable-slur) |
| `slurLineStyle` | `.string` (`"solid"`/`"dashed"`/`"dotted"`/`"wavy"`) | [Slurs](#notetable-slur) |
| `polyphonicPressure` | `.int` (0–127) | [MIDI-only NoteTable gaps](#notetable-single-format) |

## Findings and rationale

Evidence and design reasoning behind each row above, grouped by type in the
same order as the tables. Each subsection is self-contained: where a value
space can't be shared across all formats, that's stated explicitly along with
what's deliberately *not* unified and why.

### TempoMap

#### TempoMap: `tempoText` {#tempomap-tempotext}

- **ABC** — `ABCTempo.text` is parsed but never read:
  `convertToTempo(_ tempo: ABCTempo)`,
  `Sources/IvorExtern/ABC/ABCFunctions.swift:189-201`, only consults
  `rate`/`lengths`. Worse, a text-only mark (`Q:"Allegro"`, no numeric rate)
  currently produces **no `TempoMap` entry at all** — the whole marking is
  lost, not just its label.
- **Guido** — `GMNTempo.tempo` is a *required* field (the tag's tempo text,
  e.g. `\tempo<"Allegro">`), read by the AST but never touched by
  `Guido.Importer.Walker` (`Sources/IvorExtern/Guido/Guido.Importer.Walker.swift:163-170`
  only reads `tempo.metronome`, never `tempo.tempo`).

Both formats have a first-class "tempo as text" concept sitting right next to
their numeric BPM field, and both drop it identically. `tempoText` lets
`ABC.Exporter` write a real `ABCTempo(text:)` (its exporter already has the
parameter — `convertToABCTempo(_:)` in `ABCFunctions.swift:95-102` currently
always passes `text: nil`) and lets `Guido.Exporter` write a genuine label
into `GMNTempo`'s non-omissible `tempo` field instead of always stringifying
the BPM value, on both round-trip and cross-format (ABC ↔ Guido) conversions.

#### TempoMap: single-format candidates {#tempomap-single-format}

- **MIDI** — the exact microseconds-per-quarter-note value before
  `convertToTempo(_ tempo:factor:)`
  (`Sources/IvorExtern/MIDI/MIDIFunctions.swift:61-65`) rounds it to an
  integer BPM. No other format carries sub-BPM tempo precision, so
  `exactMicrosecondsPerQuarter` only helps a MIDI round-trip.
- **JohnnySonic** — a `/Tempo` line's original
  `initialTempo`/`finalTempo`/`duration` ramp parameters are resampled away
  by `_beatTempos`/`_makeTempoMap`
  (`Sources/IvorExtern/JohnnySonic/JohnnySonic.Importer.swift:34-55,246-273`)
  into a per-beat step function — already flagged in project memory as a
  known round-trip loss. `rampInitialTempo`/`rampFinalTempo`/`rampDuration`
  only help a JohnnySonic round-trip; no other format has a ramp concept.

### DynamicMap

#### DynamicMap: `dynamicMark` {#dynamicmap-dynamicmark}

Three independent formats hit the exact same wall — a marking that isn't one
of `Dynamic`'s ten named levels — and all three currently just drop it on the
floor rather than losing only its precision:

- **MusicXML** — `convertToDynamic(_ item: MXLDynamics.Item)`,
  `Sources/IvorExtern/MusicXML/MusicXMLFunctions.swift:95-101`: `sf`, `sfz`,
  `fz`, `rf`, `rfz`, and free-text `otherDynamics` all convert to `nil` —
  today that means **no `DynamicMap` entry is created at all** for a note
  or direction carrying only one of these.
- **ABC** — `convertToDynamic(_ name: ABCDecoration.Name)`,
  `Sources/IvorExtern/ABC/ABCFunctions.swift:114-149`: any decoration name
  outside the ten canonical words (an ornament, an articulation, a dialect
  extension) falls through to `nil` the same way.
- **Guido** — `convertToDynamic(_ type: String)`,
  `Sources/IvorExtern/Guido/GuidoFunctions.swift:21-56`: `\intensity`'s
  open `type` string does the same fallback for anything outside the ten.

`dynamicMark` lets each importer still insert a `DynamicMap` entry (at the
previously-held level, tagged with the literal text) instead of silently
omitting the event, and lets an exporter targeting one of the other two
formats try to re-emit the literal string — genuinely recoverable
information across a three-way format boundary that today evaporates
identically in all three places. Named `dynamicMark`, not `mark`, to stay
unambiguous when read outside this file (see Design principles above).

#### DynamicMap: `velocity` {#dynamicmap-velocity}

- **MIDI** — `convertToDynamic(_ keyVelocity:)`,
  `Sources/IvorExtern/MIDI/MIDIFunctions.swift:13-15`, compresses the raw
  0–127 velocity down to one of ten `Dynamic` levels.
- **MusicXML** — `convertToDynamic(_ note:)` /
  `convertToDynamic(_ sound:)`,
  `Sources/IvorExtern/MusicXML/MusicXMLFunctions.swift:105-122`, deliberately
  scales its own `dynamics` percentage-of-90 attribute "the same way
  `convertToDynamic(_ keyVelocity:)` in `MIDIFunctions.swift` does, keeping
  the two importers' scales consistent" (comment at line 105-109) — i.e. this
  shared scale is already a design intention, just not preserved past the
  `Dynamic` quantization step.
- **JohnnySonic** — `convertToDynamic(_ volume:)`,
  `Sources/IvorExtern/JohnnySonic/JohnnySonicFunctions.swift:20-22`, uses a
  0–10 scale that would need a `× 12.7` rescale to join the same key, but
  the underlying continuous-value-compressed-to-ten-levels problem is
  identical.

Because MIDI and MusicXML already agree on the numeric scale by design, this
is close to a free win: storing the pre-quantization integer lets a
MusicXML → MIDI (or reverse) conversion recover exact velocities that
`Dynamic`'s ten levels can't carry, with JohnnySonic joining at the cost of
one linear rescale.

#### DynamicMap: `expressionValue` {#dynamicmap-expressionvalue}

A gap distinct from `velocity` above, and from the general aftertouch/pitch-
bend gap noted under NoteTable's single-format findings below: Expression
Controller (CC 11 `.expressionControllerMSB` / CC 43
`.expressionControllerLSB`,
`IvorMIDI/Sources/IvorMIDI/AST/MIDI/MIDIController.swift:104,107`) is a
*time-indexed* continuous dynamics shaper layered on top of note-on
velocity — the same conceptual role a `DynamicMap` entry already plays — not
a per-note attribute like aftertouch or pitch bend that would need
range-matching against note attack/duration windows to attach anywhere. It
falls into `NotePairer.ingest`'s `default: break`
(`Sources/IvorExtern/MIDI/MIDI.Importer.NotePairer.swift:68-69`), the same
catch-all that drops Bank Select and Pan LSB, so it's dropped outright today,
not rounded. Because it's already time-indexed exactly like a
`.controlChange(_, .panMSB, _)` event, importing it is structurally the same
one-line addition `NotePairer` already does for pan — a direct
`dynamicMap.insert(time: dynamic:)` per event, no note-range-matching design
work required, unlike the rest of the CC gap noted in NoteTable's findings
below. No other format has an equivalent continuous-controller concept, so
this is single-format (MIDI round-trip only), not cross-format.

### InstrumentMap

#### InstrumentMap: `midiProgram` {#instrumentmap-midiprogram}

Every format but JohnnySonic resolves an instrument assignment through a raw
MIDI program number before naming it, and every one of those conversions
throws the number away as soon as it has a name:

- **MIDI** — `convertToInstrument(_ program:)`,
  `Sources/IvorExtern/MIDI/MIDIFunctions.swift:17-19`
- **MusicXML** — `convertToInstrument(_ scorePart:)`,
  `Sources/IvorExtern/MusicXML/MusicXMLFunctions.swift:131-140` (reads
  `<midi-instrument><midi-program>` only when no `<score-instrument>` name
  exists — see `midiElevation`/`midiUnpitched` below for the rest of that
  element)
- **Guido** — `convertToInstrument(_ instrument:)`,
  `Sources/IvorExtern/Guido/GuidoFunctions.swift:156-164`
- **ABC** — `convertToInstrument(_ directive:)`,
  `Sources/IvorExtern/ABC/ABCFunctions.swift:160-173` (`%%MIDI program
  [channel] program-number`)

Because all four read the *same* 0–127 GM program space, one shared `Extra`
name lets any importer populate it and any exporter consume it — a MusicXML
file whose `<score-instrument>` name doesn't map cleanly back through
`generalMIDIProgramNumber(name:)` can still export an exact `%%MIDI program`
directive or `\instrument<..., midi: ...>` tag by reading the original
number back out of `Extras`, instead of re-deriving it (lossily) from the
name.

#### InstrumentMap: `midiChannel` {#instrumentmap-midichannel}

- **MIDI** — the originating channel is known per-voice
  (`Sources/IvorExtern/MIDI/MIDI.Importer.swift:_makeVoices`), but is
  currently only recoverable from the "Channel N" name-string convention
  documented in `MIDI.Exporter._assignChannels`, not from any structured
  field.
- **MusicXML** — `<midi-instrument><midi-channel>`
  (`IvorMusicXML/Sources/IvorMusicXML/AST/Playback/MXLMidiInstrument.swift:62-65`)
  is never read by `convertToInstrument(_ scorePart:)`.
- **ABC** — `%%MIDI program [channel] program-number`'s optional leading
  channel token is parsed only far enough to skip past it
  (`Sources/IvorExtern/ABC/ABCFunctions.swift:158-159`, "the token this
  skips past").

`midiChannel` decouples channel identity from MIDI's own name-string hack and
gives MusicXML/ABC importers a real channel value to hand an exporter —
useful the moment more than one exporter needs to agree on channel
assignment for a cross-format conversion (e.g. MusicXML → MIDI, where
`MIDI.Exporter` currently has to invent channel numbers from scratch).

#### InstrumentMap: `midiBankSelect` {#instrumentmap-midibankselect}

- **MusicXML** — `<midi-instrument><midi-bank>` (1–16,384) is a real,
  parsed AST field (`MXLMidiInstrument.swift:57-60`) that no `convertTo...`
  function in `MusicXMLFunctions.swift` ever reads.
- **MIDI** — Bank Select (CC 0 `.bankSelectMSB` / CC 32 `.bankSelectLSB`,
  `IvorMIDI/Sources/IvorMIDI/AST/MIDI/MIDIController.swift:50,53`) is not
  read *anywhere* in the importer: `MIDI.Importer.NotePairer.ingest`'s
  `.controlChange` match only special-cases `.panMSB`
  (`Sources/IvorExtern/MIDI/MIDI.Importer.NotePairer.swift:62-63`), so a
  Bank Select event falls into the same `default: break` at line 68-69 that
  drops `.panLSB` (see PanMap's MIDI finding below) and is gone before
  `Context` ever sees it. This is outright silent data loss on every
  Standard MIDI File import that uses a non-default bank (GM banks beyond
  0, custom soundfont banks), not a lossy rounding. Export is symmetric:
  `MIDI.Exporter._convert(part:channel:)` only ever emits `.programChange`
  from `part.instrumentMap`
  (`Sources/IvorExtern/MIDI/MIDI.Exporter.swift:144-149`), never a Bank
  Select pair.

This is the most valuable *combination* of "closes a real gap" and "shared
across formats": once the MIDI importer reads Bank Select (CC 0 MSB / CC 32
LSB) and combines the two into one 14-bit value, the exact same key becomes
exportable to MusicXML's `<midi-bank>` directly (1–16,384), and a MusicXML
file that already specifies a bank can propagate it through to a MIDI export
by splitting it back into MSB/LSB on the way out. `midiBankSelect` stores the
combined 14-bit value rather than two separate MSB/LSB `Extra`s, matching the
single field MusicXML already exposes.

#### InstrumentMap: `midiVolume` {#instrumentmap-midivolume}

- **MusicXML** — `<midi-instrument><volume>`
  (`MXLMidiInstrument.swift:91-95`) is read nowhere.
- **MIDI** — Channel Volume (CC 7) is, like Bank Select, never read by the
  importer at all.

Weaker than `midiProgram`/`midiChannel`/`midiBankSelect` (MIDI has no
analogous *importer* support to build on yet), but the same shared-key
argument applies once either side gains it.

**Why this doesn't combine CC 7 (MSB) with CC 39 (LSB):** unlike bank
select, where MusicXML's `<midi-bank>` field is itself the full 14-bit
0–16,384 range, MusicXML's `<volume>` is a coarse 0–100 percent scale — the
cross-format value space the two formats actually share tops out well below
what a combined 14-bit MIDI value could express. Reading CC 39 in on the MIDI
side would only add precision that has nowhere to go on export, and CC 39 is
rarely sent by real MIDI sources in the first place. CC 7 alone, rescaled
toward 0–100, is the shared value both formats can actually round-trip.

#### InstrumentMap: single-format candidates (MusicXML-only sourcing) {#instrumentmap-single-format}

`<midi-instrument>`'s `elevation` and `midiUnpitched` fields
(`MXLMidiInstrument.swift:45-50,77-82`) have no equivalent anywhere else in
the model — `MXLMidiInstrument` is the only AST in the five formats with
fields for either concept, so there's no shared vocabulary to design around
yet, unlike `midiProgram`/`midiChannel`/`midiBankSelect`/`midiVolume` above.

| Name | Source field | Range as declared | Notes |
| --- | --- | --- | --- |
| `midiElevation` | `MXLMidiInstrument.elevation` (nested `<elevation>`) | `MXLRotationDegrees`, -180 to 180 | Placement of sound in 3-D space relative to the listener: 0 is level with the listener, 90 directly above, -90 directly below — shares its type (`MXLRotationDegrees`) and range with `pan`, but pan already has a first-class `PanMap` home in the model *and* a MIDI CC counterpart (Pan MSB/LSB), while elevation has neither: MIDI 1.0 defines no elevation controller, so there's no MIDI-side source to combine this with even for a single-format round-trip — it can only ever be a MusicXML-only, write-then-read-back-unchanged value. |
| `midiUnpitched` | `MXLMidiInstrument.midiUnpitched` (nested `<midi-unpitched>`) | `MXLMidi128`, 1–128 | MIDI note number used with percussion banks to say which unpitched instrument a given note number plays. MusicXML declares it 1–128 (matching its 1-based `midiProgram`/`midiBank` convention) even though it names actual MIDI note numbers, which run 0–127 — store the value as MusicXML declares it (1–128) and let the importer/exporter pair handle the off-by-one against real MIDI note numbers, the same way `midiProgram` already does against GM program numbers. |

### PanMap

#### PanMap: single-format candidates {#panmap-single-format}

- **MusicXML** — pan degrees beyond ±90° (rear placement) are hard-clamped
  to the nearest side by `convertToPan(_ sound:)`
  (`Sources/IvorExtern/MusicXML/MusicXMLFunctions.swift:227-232`); the
  un-clamped original degree has no equivalent in any other format's pan
  representation, so `panDegree` can only help a MusicXML round-trip.
- **MIDI** — Pan LSB (CC 42,
  `IvorMIDI/Sources/IvorMIDI/AST/MIDI/MIDIController.swift:188`) is not read
  *anywhere* in the importer — `MIDI.Importer.NotePairer.ingest`'s
  `.controlChange` match only tests for `.panMSB`
  (`Sources/IvorExtern/MIDI/MIDI.Importer.NotePairer.swift:62-63`), so a
  `.panLSB` event is dropped before it even reaches `Context`, and
  `convertToPan(_:)` only ever takes the 7-bit `PanValue` regardless. Same
  outright-silent-loss shape as the `InstrumentMap` Bank Select gap above,
  just for pan resolution rather than bank number — today's `PanMap`
  round-trip is correct only at 7-bit (CC 10-only) resolution. Export is
  symmetric: `MIDI.Exporter` (`MIDI.Exporter.swift:133-136`) only ever emits
  `.panMSB`, never `.panLSB`. `panControllerValue` combines Pan MSB (CC 10)
  and LSB (CC 42) into one 14-bit value — combined rather than split,
  unlike `midiBankSelect`'s separate-halves-into-one-field reasoning above,
  because no other format has any pan field this could feed at 14-bit
  resolution anyway: this is purely a MIDI round-trip aid, and one combined
  value is simpler to carry than two.

**MIDI Balance (CC 8 `.balanceMSB` / CC 40 `.balanceLSB`) — considered and
rejected.** Falls into the same `default: break` as everything else above.
Considered as a fourth PanMap-adjacent CC gap alongside Bank Select/Pan
LSB/Expression, but rejected: unlike those three, Balance has no home to
read into. It's spatial like Pan, but a distinct axis (stereo-channel
balance, not mono placement), and no MusicXML field corresponds to it —
`MXLMidiInstrument` has `pan`/`elevation` but no `balance`
(`MXLMidiInstrument.swift:84-89`), and no other `IvorModel` type models it
either. Attaching it to `PanMap` would conflate two different concepts under
one map; a real `Extra` here would need a design decision this document
isn't the place to make, unlike the other three, which just read an existing
CC into an existing `insert()` call.

### NoteTable

`NoteTable.insert(attack:duration:pitch:extras:)` takes the same `extras:
Extras? = nil` parameter as the other four maps. Every notation format
(ABC, Guido, MusicXML) turns out to drop a strikingly similar set of
per-note information, in most cases documented in the walker's own code as a
deliberate no-op rather than an oversight. MIDI and JohnnySonic, by
contrast, mostly already thread every field their AST carries through to the
model; their remaining gaps (below) are single-format precision losses, not
cross-format ones.

#### NoteTable: grace notes {#notetable-grace}

All three notation formats parse grace notes into their AST and then throw
them away identically:

- **MusicXML** — `.graceNote`/`.graceNoteCue`
  (`Sources/IvorExtern/MusicXML/MusicXML.Importer.Walker.swift:364-397`):
  "Grace notes ... are dropped from the note table entirely, matching how
  `ABC.Importer.Walker` and `Guido.Importer.Walker` both already treat their
  own formats' ornament/grace constructs."
- **ABC** — `.graceNotes` symbol,
  `Sources/IvorExtern/ABC/ABC.Importer.Walker.swift:398-416` ("Every case
  here that can never reach the note table [...] is a deliberate no-op").
- **Guido** — `.grace(GMNGrace)` tag,
  `Sources/IvorExtern/Guido/Guido.Importer.Walker.swift` type comment:
  "Grace notes, tablature attachments, and the generic tag-passthrough lane
  remain out of scope."

All three formats agree that a grace figure is an ordered group of one or
more pitched notes attached just before a main note — but they split two
ways on *how a performer knows how long to play them*, and Guido lacks an
axis the other two share:

- **ABC** (`ABCGraceNotes`,
  `IvorABC/Sources/IvorABC/AST/Symbol/ABCGraceNotes.swift`) groups the
  whole figure into one symbol: `notes: [ABCNote]`, each of which — like
  any other ABC note — carries a real, non-optional written `length`
  (`ABCNote.swift:17-21`, a multiplier of the unit note length, same as a
  regular note's). It also carries `isSlashed: Bool`, ABC's own name for
  the acciaccatura/slashed-grace-note distinction.
- **Guido** (`GMNGrace`,
  `IvorGuido/Sources/IvorGuido/AST/Tag/Timing/GMNGrace.swift`) groups the
  figure the same way, as a tag's `body: [GMNSymbol]` — and those symbols
  can carry their own written `duration`
  (`IvorGuido/Sources/IvorGuido/AST/Tag/.../GMNNote.swift:26`, though
  *optional* there, unlike ABC's non-optional one, so a Guido grace note
  can be written with no explicit length at all). Guido has **no
  slash/acciaccatura concept anywhere** — confirmed by no occurrence of
  "slash", "acciaccatura", or "appoggiatura" anywhere in `IvorGuido`'s
  source — so the one axis ABC and MusicXML agree on has nothing to read
  from a Guido source at all. `GMNGrace` does carry an `index: Int?`
  ("grace-note index"), but nothing in this codebase or its guidolib
  source comments explains its musical meaning beyond the parameter name,
  and every other opaque rendering-order parameter encountered elsewhere
  in this document (Guido's `curve`, bezier offsets, and the like) has
  been left out of these vocabularies on the same grounds — treated the
  same way here, not proposed.
- **MusicXML** (`MXLGrace`,
  `IvorMusicXML/Sources/IvorMusicXML/AST/Note/MXLGrace.swift`) is the one
  format that goes the *other* way: a grace note's `MXLNote.Content` case
  (`.graceNote`/`.graceNoteCue`,
  `.../MXLNote.Content.swift:12-17`) carries **no duration field at all** —
  the type's own doc comment is explicit: "grace notes carry no duration,
  since they have no defined sounding length." In its place, `MXLGrace`
  has `isSlashed: Bool?` (the same concept as ABC's field, different
  optionality) plus two fields neither other format has any equivalent
  for: `stealTimePrevious`/`stealTimeFollowing` (`MXLPercent`, how much
  playback time to take from the neighboring note) and `makeTime`
  (`MXLDivisions`, add real time rather than stealing any). Also,
  structurally, MusicXML never groups a grace figure into one element the
  way ABC/Guido do — each grace note is its own sibling `<note>`, and a
  "figure" is only ever an unmarked run of consecutive grace-flagged
  `<note>`s in the measure, so an importer has to detect the group
  boundary itself rather than reading one pre-grouped symbol.

**The finding**: this isn't simply "MusicXML has more structure" the way
chord symbols and articulations turn out to be (see below) — it's a genuine
fork. ABC and Guido notate a grace note *with* a real written length and let
a performer infer its performed duration from that; MusicXML notates a
grace note *without* any length at all and instead (optionally) states
exactly how much neighboring time to steal. Neither representation reduces
losslessly to the other; both are proposed as parallel, independently-
populated keys rather than forcing one format's concept to stand in for the
other's.

*Tier 1 — universal, always populated:*

| Name | Payload | Notes |
| --- | --- | --- |
| `gracePitches` | `.string` (ordered, e.g. `"D4,E4,F#4"`) | The grace figure's pitches in order, attached to the main note they lead into. Always derivable: ABC/Guido read it straight from their grouped `notes`/`body`; a MusicXML importer instead has to collect the run of consecutive `.graceNote`/`.graceNoteCue` notes immediately preceding the main note itself. |
| `graceIsSlashed` | bare flag | The shared ABC/MusicXML acciaccatura axis (`ABCGraceNotes.isSlashed`/`MXLGrace.isSlashed`). Never populated from a Guido source — Guido has no such concept at all. |

*Tier 2 — ABC/Guido-only written length (no MusicXML equivalent to read):*

| Name | Payload | Notes |
| --- | --- | --- |
| `graceLengths` | `.string` (ordered, parallel to `gracePitches`, e.g. `"1/8,1/16"`) | Each grace note's own written length, as a unit-note-length multiplier. Populated from ABC (always present per note) or Guido (present when written; Guido's is optional per note, unlike ABC's). Absent for MusicXML-sourced grace notes — they carry no length at all to read, per `MXLNote.Content`'s own doc comment. |

*Tier 3 — MusicXML-only performed-duration structure (the flip side of Tier
2, not a strict extension of it):*

| Name | Payload | Notes |
| --- | --- | --- |
| `graceStealTimePrevious` | `.double` (percent) | Mirrors `MXLGrace.stealTimePrevious`. |
| `graceStealTimeFollowing` | `.double` (percent) | Mirrors `MXLGrace.stealTimeFollowing`; MusicXML's own name for the appoggiatura case. |
| `graceMakeTime` | `.double` (real-time divisions) | Mirrors `MXLGrace.makeTime`. Rarely written in practice, included for completeness. |

**What this deliberately does not unify:** Guido's `index` parameter has no
documented musical meaning beyond a rendering/ordering hint, and is
excluded on the same grounds as every other opaque visual-only parameter
encountered elsewhere in this document. MusicXML's `cue` marker (a
separate, independent axis from grace — a note can be `cue`-sized and
non-grace, grace and non-cue, or both) is a display-size concept, not
performance information, and isn't folded into this vocabulary either.

#### NoteTable: chord symbols {#notetable-chordsymbol}

A harmonic/guitar-chord annotation exists in three formats and is inert in
all three importers:

- **MusicXML** — `<harmony>`,
  `Sources/IvorExtern/MusicXML/MusicXML.Importer.Walker.swift:298-306`
  (`.harmony` sits in the same no-op `break` case as `.barline`/
  `.figuredBass`/`.bookmark`).
- **ABC** — `.chordSymbol` symbol,
  `Sources/IvorExtern/ABC/ABC.Importer.Walker.swift:406-416`.
- **Guido** — `.harmony(GMNHarmony)` tag,
  `Sources/IvorExtern/Guido/Guido.Importer.Walker.swift` (inert, same as
  every tag but `\tie`/`\tempo`/`\intensity`/`\crescendo`/`\diminuendo`).

The three formats sit at three different points on a text-vs-structure
spectrum:

- **Guido** (`\harmony`/`GMNHarmony`) is fully opaque, same as its lyrics
  tag: `GMNHarmony.text` is one unparsed `String`
  (`IvorGuido/Sources/IvorGuido/AST/Tag/Structure/GMNHarmony.swift:62-66`) —
  the type's own doc comment says so explicitly: "The chord-symbol
  vocabulary is open, and the text is left unparsed here."
- **ABC** (`ABCChordSymbol`) is semi-structured: a `root` (`ABCPitchName` —
  a letter plus only flat/sharp, no double-accidentals,
  `IvorABC/Sources/IvorABC/AST/Symbol/ChordSymbol/ABCChordSymbol.Root.swift`)
  and a `kind` that's still a free-form `String?` (e.g. `"m"`, `"7"`,
  `"maj7"`, `"dim"`, `nil` for a plain major triad,
  `.../ABCChordSymbol.Name.swift:24-26`), plus an optional `bass` (same
  `Root` type, for slash chords like `"G/B"`) and an optional
  `parenthesized` secondary `Name` (an alternate/passing chord written in
  parens, e.g. the `Em` in `"G(Em)"`) with no MusicXML or Guido counterpart
  at all.
- **MusicXML** (`MXLHarmony`) is fully structured: `root`/`bass` are each a
  `step` (letter) plus a continuous chromatic `alter`
  (`MXLRoot.swift`/`MXLBass.swift`) — a strict superset of ABC's
  flat/sharp-only root — `kind` is drawn from a **closed ~30-value enum**
  (`.major`, `.minorSeventh`, `.halfDiminished`, `.suspendedFourth`, …,
  `MXLHarmony.Chord.Kind.Value.swift`), there's an explicit `inversion`
  `.int`, a `degree` array of individual added/altered/subtracted chord
  tones with no equivalent in either other format, and `chord: [Chord]`
  can stack more than one chord (intended for classical secondary-function
  analysis, e.g. V of II) — a structural near-miss for ABC's parenthesized
  secondary chord (both are "more than one chord symbol at one point"),
  but the *intent* differs (secondary dominant vs. alternate/passing
  reading), so it isn't proposed as a real mapping below, only noted so
  it isn't overlooked later.

*Tier 1 — universal, always populated:*

| Name | Payload | Notes |
| --- | --- | --- |
| `chordText` | `.string` (e.g. `"Cmaj7"`, `"G/B"`) | The chord symbol as literal display text. For Guido, this **is** `GMNHarmony.text` — no loss, no synthesis. For ABC, it's synthesized losslessly from `root` + `kind` (+ `/bass` if present) — recomposing exactly what ABC's own grammar already spells out. For MusicXML, it's synthesized from `root`/`kind.value`/`bass` into conventional shorthand (e.g. `.majorSeventh` → `"maj7"`) — the one lossy direction, since collapsing the closed `kind` enum to text and reading it back can't guarantee recovering the exact same enum case (see `chordKind`, not proposed, below). |

*Tier 2 — shared root/bass pitch structure (ABC ⟷ MusicXML only; Guido has
no pitch fields to read at all):*

| Name | Payload | Notes |
| --- | --- | --- |
| `chordRootStep` | `.string` (e.g. `"C"`) | Mirrors `MXLRoot.step` directly; trivially derived from ABC's `ABCPitchName` root letter. |
| `chordRootAlter` | `.int` (semitones) | Mirrors `MXLRoot.alter`. Always -1, 0, or 1 when sourced from ABC (flat/sharp only, no double-accidentals) — MusicXML's own range is wider, so an ABC round-trip can't lose anything here, but a MusicXML chord using a double-sharp/flat root can't be represented back in ABC's `ABCPitchName` regardless of this Extra. |
| `chordBassStep` | `.string` | Mirrors `MXLBass.step`; derived from ABC's optional `bass: Root?`. |
| `chordBassAlter` | `.int` (semitones) | Mirrors `MXLBass.alter`; same -1/0/1 constraint from ABC as `chordRootAlter`. |

*Not proposed (single-format precision aids at best, flagged for
completeness):*

- **`chordKind`** (a closed enum name mirroring `MXLHarmony.Chord.Kind.Value`,
  e.g. `"majorSeventh"`) would preserve MusicXML's closed vocabulary
  exactly, but ABC's `kind` is unconstrained free text with no defined
  mapping onto that enum — turning `"m7b5"` into `.halfDiminished` needs a
  real chord-kind-name parser, the same category of vocabulary-matching
  work `generalMIDIProgramNumber(name:)` already does for GM instrument
  names elsewhere in this codebase, just not attempted here.
- **`chordInversion`** (`.int`) has no ABC or Guido concept at all — pop
  chord symbols don't encode inversion the way classical harmony does.
- **MusicXML's `degree` array** (individual add/alter/subtract chord tones)
  has no equivalent in either other format's flat `kind` string — even a
  dedicated Extra for it would need its own repeatable-entry scheme, the
  same "one value per key" limitation `Extras` already has for lyrics'
  multi-verse case (see below), and isn't designed here.

#### NoteTable: lyrics {#notetable-lyric}

Lyrics reach the AST in all three notation formats and go no further:

- **ABC** — `.words`/`.wordsAligned` fields
  (`IvorABC/Sources/IvorABC/AST/Field/ABCField.swift:119-123`, `W:`/`w:`).
  `ABC.Importer.Walker._apply(_ field:)`
  (`Sources/IvorExtern/ABC/ABC.Importer.Walker.swift:201-236`) only switches
  on `.key`/`.macro`/`.meter`/`.tempo`/`.unitNoteLength`; a words field falls
  through the `default: break`.
- **Guido** — `.lyrics(GMNLyrics)` tag (inert, same blanket "every tag but
  five is a no-op" rule as chord symbols above).
- **MusicXML** — `<lyric>` is a child of `<note>`, but
  `MusicXML.Importer.Walker._resolve(_ note:...)`
  (`Sources/IvorExtern/MusicXML/MusicXML.Importer.Walker.swift:377-480`)
  never inspects it.

This is the deepest cross-format gap in this document — actual sung text,
present in three independent formats' grammars, dropped by all three
importers before it ever reaches `NoteTable`. Each format encodes the same
two underlying questions — *is this syllable part of a hyphenated word, and
does it extend across more than one note* — with a different amount of
structure:

- **ABC** (`w:`/`ABCAlignedWords`) is the most structured: a flat token
  stream, one token per note position
  (`IvorABC/Sources/IvorABC/AST/Field/AlignedWords/ABCAlignedWords.Segment.swift`),
  with explicit `.syllable(text)`, `.continuation` (`-`, links this syllable
  to the *next* note within the same word), `.hold` (`_`, extends the
  *previous* syllable over this note with no new text — a melisma), and
  `.skip` (`*`, no lyric for this note) cases, plus `.barAlign` (`|`,
  resync to the next bar) as pure alignment noise with no text of its own.
- **MusicXML** (`<lyric>`) is per-note but shaped differently: `MXLSyllabic`
  (`IvorMusicXML/Sources/IvorMusicXML/AST/Lyric/MXLSyllabic.swift`) is a
  4-way `.begin`/`.end`/`.middle`/`.single` enum carried *on* the syllable
  that has the word-position, rather than ABC's separate
  before/after-continuation tokens; `MXLExtend`
  (`.../MXLExtend.swift`) is a `.start`/`.stop`/`.continue` `kind` for
  melisma lines, functionally the same concept as ABC's `.hold` but spread
  across three explicit marker states instead of one repeatable token;
  MusicXML additionally supports eliding two or more syllables onto a
  single note (`MXLLyric.Content.SyllabicGroup`, French-style, e.g.
  `qu'il` as `qu'` + elision + `il` on one note) and non-text content
  (`.humming`/`.laughing`), neither of which ABC or Guido has any concept
  of at all.
- **Guido** (`\lyrics`/`GMNLyrics`) is the least structured of the three:
  `GMNLyrics.text` is one opaque `String` and `GMNLyrics.body` is the
  `[GMNSymbol]` range of notes it's sung over
  (`IvorGuido/Sources/IvorGuido/AST/Tag/Visual/GMNLyrics.swift:71-81`) —
  guidolib itself only tokenizes that string into syllables/words at render
  time (via `TagParameterStrings.cpp`'s own space/hyphen conventions, not
  captured anywhere in this AST), so `Guido.Importer.Walker` gets *no*
  per-note segmentation for free the way the ABC and MusicXML importers do.

| Name | Payload | Meaning |
| --- | --- | --- |
| `lyricText` | `.string` | This note's syllable text. Omitted when `lyricMelisma` is set — there's no new text, the previous lyric-bearing note's text carries over. |
| `lyricHyphenation` | `.string`: `"begin"`, `"middle"`, `"end"`, or `"single"` | Word position, taken straight from `MXLSyllabic`. Absent implies `"single"`. Derived losslessly from ABC's tokens: a `.syllable` immediately followed by `.continuation` is `"begin"` (or `"middle"` if the *preceding* note's segment was also a continuation-linked one), one immediately preceded by `.continuation` but not followed by one is `"end"`, and one with neither neighbor is `"single"` — reconstructing ABC's `-` markers on export is the reverse of that same rule. |
| `lyricMelisma` | bare flag | This note continues the *same* syllable as the nearest preceding lyric-bearing note — no new text, no new hyphenation state. Maps directly to ABC's `.hold` (`_`). Reconstructs MusicXML's three-state `<extend>` purely from the run of flagged notes: `start` on the syllable note just before the run, `continue` on every flagged note but the last, `stop` on the last — so the exporter never needs to store `kind` explicitly. |
| `lyricVerse` | `.string` | Optional verse/line identifier — MusicXML's `number`/`name`, ABC's Nth `w:` line, Guido's tag `ident`. Absent implies the first/only verse. |

**What this deliberately does not unify** (real information each format can
still lose that this vocabulary doesn't try to fix):

- **MusicXML elision** (`SyllabicGroup`, multiple syllables under one note)
  has no ABC or Guido counterpart at all — round-tripping it would need a
  second, repeatable text field (e.g. an ordered `lyricElidedText` chain),
  which isn't proposed here; a MusicXML file using elision still loses it
  going through this vocabulary, same as today.
- **MusicXML humming/laughing** content has no equivalent in either other
  format — single-format-only information, not attempted here.
- **Guido's opaque `text` string** has no native per-note segmentation to
  read `lyricHyphenation`/`lyricMelisma` from — populating them for Guido
  would mean the importer re-implementing guidolib's own space/hyphen
  tokenization heuristic against `body`'s note sequence, which is a
  best-effort reconstruction, not a lossless parse the way reading ABC's
  tokens or MusicXML's `syllabic`/`extend` elements is. Worth doing (it's
  still much better than dropping the text entirely, which is what happens
  today), but it's the one format where this vocabulary can't be populated
  with full confidence.
- **Multiple simultaneous verses on one note** can't be represented with
  today's name-keyed-only `Extras` bag — one `lyricText` key holds one
  value, not one per verse, so a note with two verses' worth of lyrics
  would need either a verse-indexed key naming convention (`lyricText1`/
  `lyricText2`/…) or multiple `NoteTable` passes, neither of which is
  designed here; flagged as a known gap if multi-verse round-tripping is
  ever wanted, not solved by `lyricVerse` alone (which only *labels* a
  single verse's text, it doesn't let two verses coexist on one entry).

#### NoteTable: articulation/ornament {#notetable-articulation}

Every format has *some* vocabulary for "how to play this note" beyond pitch,
duration, and dynamics, and every importer drops it:

- **ABC** — two distinct, independently-dropped pathways, not one:
  `ABCDecoration.Name` marks written longhand (`!name!`, e.g. `!accent!`,
  `!trill!`, `!tenuto!`) that aren't one of the ten dynamic words fall
  through `convertToDynamic(_ name:)`'s `default: nil`
  (`Sources/IvorExtern/ABC/ABCFunctions.swift:114-149`) and then
  `_handleDecoration`'s own `default: break`
  (`Sources/IvorExtern/ABC/ABC.Importer.Walker.swift:331-360`); separately,
  the single-character shorthand marks (`ABCShorthand` — `.` for staccato,
  plus the redefinable `~`, `H`–`W`, `h`–`w`) are a different AST case
  (`.shorthand`, not `.decoration`) that falls into `_process(_
  symbol:_:)`'s own, separate blanket no-op
  (`ABC.Importer.Walker.swift:406-416`) without ever reaching
  `_handleDecoration` at all. Only `.` has a fixed meaning; every other
  shorthand character is redefined per-tune via the `U:` field to mean
  whatever decoration or annotation the tune's author chose, and that
  resolution table isn't modeled anywhere in the importer at all — see
  `ABC.Importer.MacroTable.swift:21-24`'s own comment: "`U:`
  shorthand-to-decoration/annotation mappings are intentionally not
  modeled at all... both dropped entirely." So this is a deeper gap than a
  missing `Extra`: even with one defined, a shorthand mark can't be
  interpreted without first building the `U:` resolution table the
  importer currently skips outright.
- **Guido** — `.articulation`, `.ornament`, `.tremolo`, `.fingering`,
  `.arpeggio`, `.glissando`, `.pedal`, `.breathMark`, `.mark`, and
  `.stemDirection` tags (`IvorGuido/Sources/IvorGuido/AST/Tag/GMNTag.swift`)
  are all inert in `Guido.Importer.Walker`, same blanket rule as above.
- **MusicXML** — `<note><notations>` (`<articulations>`, `<ornaments>`,
  `<technical>`, `<fermata>`, `<arpeggiate>`, `<glissando>`/`<slide>`) is
  never read at all — `MusicXML.Importer.Walker._resolve(_ note:...)`
  (`Sources/IvorExtern/MusicXML/MusicXML.Importer.Walker.swift:377-480`)
  has no reference to `notations` anywhere in its `MXLNote` handling.

This is the widest gap between formats of any topic in this document — wider
than chord symbols, because MusicXML's vocabulary here isn't just more
*structured* than ABC's or Guido's, it's an order of magnitude *larger*:

- **ABC** is fully open text at the longhand level (`ABCDecoration.Name`
  accepts any string in a broad character set — the ABC 2.1 standard
  *recommends* a vocabulary, like `trill`, `accent`, `tenuto`, `open`,
  `snap`, but the type itself enforces nothing beyond the character set),
  plus the separate shorthand/`U:` mechanism described just above, which
  is a real, currently-unaddressed gap of its own (an unresolved
  redefinition table, not a missing `Extra`).
- **Guido** sits in the middle: a **closed**, modest vocabulary — 8
  articulation kinds (`accent`, `bow`, `fermata`, `harmonic`, `marcato`,
  `pizzicato`, `staccato`, `tenuto`,
  `IvorGuido/Sources/IvorGuido/AST/Tag/Performance/GMNArticulation.Kind.swift`)
  and 3 ornament kinds (`mordent`, `trill`, `turn`,
  `.../GMNOrnament.Kind.swift`), each a real Swift enum case (not free
  text) — but four of the eight articulation kinds *also* carry a `type`
  sub-variant that's still an open string (`up`/`down` for `\bow`,
  `short`/`long` for `\fermata`, `heavy` for `\staccato`,
  `buzz`/`snap`/`bartok`/`fingernail` for `\pizzicato`), so Guido itself
  mixes closed and open vocabulary the same way ABC's decoration/shorthand
  split does, just at a different layer. Separately, `\fingering` carries
  actual finger-number text (`GMNFingering.text`, comma-separated for
  multiple fingerings), and `\tremolo`/`\arpeggio`/`\glissando`/`\pedal`/
  `\breathMark`/`\mark`/`\stemDirection` are independent tags outside the
  articulation/ornament pair entirely — `\pedalOn`/`\pedalOff`
  (`GMNPedal.Kind`) and `\stemsUp`/`\stemsDown`/`\stemsAuto`/`\stemsOff`
  (`GMNStemDirection.Kind`) in particular are engraving/rendering hints,
  not "how to play this note" information, and arguably don't belong in
  this vocabulary at all.
- **MusicXML** is both closed *and* enormous:
  `MXLArticulations.Item`/`MXLOrnaments.Content`/`MXLTechnical.Item`
  together enumerate roughly 60 distinct cases — accents, staccato
  variants, bowing, breath marks, fermata, trills/mordents/turns (each
  with its own shape sub-type), guitar/fretted-instrument techniques
  (bends, hammer-ons, pull-offs, frets, strings, taps), harp techniques,
  brass mutes, handbell techniques, and more — most of which have no
  equivalent concept in either other format at all. Crucially, MusicXML
  already anticipates this exact problem: `otherArticulation`,
  `otherOrnament`, and `otherTechnical`
  (`MXLArticulations.Item.swift:27-31`, `MXLOrnaments.Content.swift:32-36`,
  `MXLTechnical.Item.swift:73-78`) are each a free-text escape hatch (with
  an optional SMuFL glyph name) for exactly the "vocabulary not in my
  enumerated list" situation ABC's open decoration names and this
  document's proposed catch-all both already assume — a real structural
  match, not just a convenient coincidence.

*Tier 1 — closed, shared-name bare flags*, for marks in Guido's closed
`Kind` enums that also have a plain, unqualified case in MusicXML's
enumeration (so no sub-type/shape decision is needed to populate them) and
a natural ABC decoration-name spelling:

`accent`, `marcato`, `tenuto`, `staccato`, `fermata`, `harmonic`,
`pizzicato`, `trill`, `mordent`, `turn`, `upBow`, `downBow`, `breathMark` —
each a bare-flag `Extra`, matching the `Extra(name: "accent")` idiom. `bow`
itself isn't included as a name (Guido's `\bow` *is* `upBow`/`downBow` via
its required `up`/`down` `type`, and MusicXML already has dedicated
`upBow`/`downBow` technical items, so those two names carry the
information Guido's single `\bow` kind would otherwise need a companion
value for).

*Tier 2 — value-bearing marks*, where at least two formats carry an actual
string, not just presence/absence:

| Name | Payload | Notes |
| --- | --- | --- |
| `fingering` | `.string` | Guido's `GMNFingering.text` and MusicXML's `MXLTechnical.fingering` (`MXLFingering`) both carry real finger-number text. ABC has no native fingering decoration at all — if written, it would only ever reach the catch-all below, not this key. |

*Tier 3 — catch-all, mirroring MusicXML's own escape hatch*:

| Name | Payload | Notes |
| --- | --- | --- |
| `articulation` | `.string` (the literal mark name, e.g. `"staccatissimo"`, `"spiccato"`, `"snapPizzicato"`) | For anything outside Tier 1/2. Maps directly onto MusicXML's `otherArticulation`/`otherOrnament`/`otherTechnical` text (already a free-text escape hatch by design, not something this vocabulary is bolting on) and onto ABC's open longhand decoration names, which are exactly as unconstrained. Guido's four `type` sub-variants (`\bow`'s `up`/`down` aside, already folded into Tier 1) — `\fermata`'s `short`/`long`, `\staccato`'s `heavy`, `\pizzicato`'s `buzz`/`snap`/`bartok`/`fingernail` — also land here rather than getting dedicated keys, since none of them has a clean 1:1 match in both other formats' vocabularies (`\staccato<type=heavy>` is a near-miss for MusicXML's `staccatissimo`, but "near-miss" is exactly why it isn't promoted to Tier 1). |

**What this deliberately does not unify:**

- **The ABC shorthand/`U:` redefinition gap** described above is not an
  `Extra` design problem at all — it needs the importer to build the `U:`
  resolution table first (mapping each redefined shorthand character to
  the decoration or annotation it stands for in that tune), which is a
  real, separate piece of work `ABC.Importer.MacroTable` currently
  disclaims outright.
- **MusicXML's large single-format-only tail** — guitar bends/hammer-ons/
  pull-offs/frets/strings/taps, harp fingernails, brass mutes, handbell
  techniques, arrows, and similar — has no equivalent in either other
  format and isn't attempted here; each would only ever help a MusicXML
  round-trip, the same category as `PanMap`'s MusicXML-only `panDegree`
  candidate above.
- **Fermata/trill shape or type sub-variants**
  (`MXLFermata.Shape`'s 9-case enum vs. Guido's free `type` string vs.
  ABC's free decoration text) have no shared closed vocabulary across all
  three the way the Tier 1 names do — same category as `chordKind` above,
  a single-format precision aid at best, not designed here.
- **Guido's non-performance tags** — `\pedalOn`/`\pedalOff` and the four
  `\stems…` stem-direction tags — are engraving hints rather than
  performance information, and are deliberately left out of this
  vocabulary entirely rather than forced into it; `\mark` (a generic
  annotation glyph, distinct from `chordSymbol`/`lyric`) and `\arpeggio`/
  `\glissando`/`\tremolo` remain open candidates of their own (arpeggio
  and glissando already have partial MusicXML/ABC-symbol equivalents —
  `MXLArpeggiate`, `MXLGlissando`/`MXLSlide`, ABC's `.slur` neighbor
  concepts) but are out of scope for this pass.

#### NoteTable: slurs {#notetable-slur}

Lower musical stakes than the above (mostly a display/phrasing hint, not
sounding information), but the same three-way pattern holds: ABC's `.slur`
symbol is a no-op (`ABC.Importer.Walker.swift:406-416`), Guido's
`.slur(GMNSlur)` tag is inert, and MusicXML's `<notations><slur>` is unread
for the same reason `<articulations>` is. All three formats agree on the
basic shape — a slur is a start mark and an end mark, with the notes between
them covered — but differ in how much more than that they can express:

- **ABC** (`ABCSlur`,
  `IvorABC/Sources/IvorABC/AST/Symbol/ABCSlur.swift`) is the simplest: four
  cases, `.startRegular`/`.startDotted`/`.endRegular`/`.endDotted` — a
  bracket symbol placed directly in the note stream, paired with its match
  purely by document order (last opened, next closed — stack-based, per
  §4.11 of the ABC 2.1 standard). There is **no numbering or identifier at
  all**, so ABC's own grammar cannot represent *crossing* slurs (two slurs
  whose spans overlap without one nesting inside the other) — only
  well-nested ones, which need no explicit pairing information beyond
  position. `.dotted` vs. `.regular` is ABC's only style axis: a dotted
  slur bracket, conventionally used for an editorial or secondary phrase
  mark.
- **Guido** (`GMNSlur`,
  `IvorGuido/Sources/IvorGuido/AST/Tag/Performance/GMNSlur.swift`) is
  range-based like its other performance tags: a `body: [GMNSymbol]` for
  the whole-tag form, or a `begin`/`end` pair joined by a numeric `ident`
  for the open-span form (`\slurBegin:1 … \slurEnd:1`) — a real, explicit
  pairing mechanism, unlike ABC's implicit stack order, so Guido *can*
  represent crossing slurs the way ABC cannot. It carries no line-style
  concept at all (no dotted/dashed distinction); its only other fields are
  `curve` (which way the arc bends, up/down) and a set of bezier-style
  control-point offsets, all purely about how the curve is drawn, not
  what it means.
- **MusicXML** (`MXLSlur`,
  `IvorMusicXML/Sources/IvorMusicXML/AST/Notations/MXLSlur.swift`) is the
  most structured: `kind` is a 3-state `start`/`stop`/`continue` (the
  third exists only to carry formatting across a system break, not a
  musical distinction), and — critically — a `number` (`MXLNumberLevel`,
  defaults to `1`, per the MusicXML spec ranges 1–6) that explicitly
  disambiguates multiple simultaneously-active or overlapping slurs, the
  same problem ABC's grammar simply can't pose and Guido's `ident` solves
  in a different, tag-pairing-specific way. `lineKind` (`MXLLineKind`,
  presumably `solid`/`dashed`/`dotted`/`wavy`) is a real superset of ABC's
  binary dotted/regular axis — ABC's `.dotted` maps losslessly onto
  MusicXML's `"dotted"`, `.regular` onto `"solid"`, with `"dashed"`/
  `"wavy"` having no ABC equivalent. `orientation` (over/underhand) is the
  same visual concept as Guido's `curve`, just named and enumerated
  differently. Bezier control points and `continue` exist purely for
  rendering, same as Guido's.

*Tier 1 — span boundaries, universal:*

| Name | Payload | Notes |
| --- | --- | --- |
| `slurStart` | bare flag, or `.string` id | This note begins a slur. Bare flag when the source format needs no disambiguation (always true for ABC — see below); a `.string` id when the source can express overlapping/crossing slurs, mirroring MusicXML's `number` or Guido's `ident` directly. Kept separate from `slurEnd` (not a single combined marker) because one note can end one slur and start another in the same instant (back-to-back phrase marks), which a single flag per note can't express. |
| `slurEnd` | bare flag, or `.string` id | This note ends a slur. Same id-matching rule as `slurStart` — a `slurEnd` with id `"2"` closes the `slurStart` with the same id. Interior notes carry neither key; a renderer/exporter reconstructs "covered by the slur" from every note between a matched start/end pair. |

*Tier 2 — shared style axis (ABC ⟷ MusicXML only; Guido has no line-style
concept to read):*

| Name | Payload | Notes |
| --- | --- | --- |
| `slurLineStyle` | `.string` (`"solid"`, `"dashed"`, `"dotted"`, `"wavy"`) | Attached to the `slurStart` note. Mirrors `MXLSlur.lineKind` directly; ABC's `.dotted`/`.regular` map losslessly onto `"dotted"`/`"solid"`, a true subset. Absent implies `"solid"`. |

**Why `slurStart`/`slurEnd` only need an id for MusicXML/Guido sources, not
ABC ones:** ABC's own grammar can only express well-nested slurs (no
crossing), and nesting order alone is always enough to re-pair a start with
its matching end — an ABC importer never needs to invent an id. A MusicXML
or Guido source, by contrast, can genuinely have two slurs active over the
same or overlapping note ranges (MusicXML's `number` and Guido's `ident`
exist specifically to make that legal), so an importer for either needs to
carry that identifier through as the `.string` form of `slurStart`/
`slurEnd` to keep re-pairing them correctly on export — using the bare-flag
form for such a source would silently collapse two simultaneous slurs into
one indistinguishable span.

**What this deliberately does not unify:** Guido's `curve` and MusicXML's
`orientation` are the same underlying concept (which way the visual arc
bends) but are purely a rendering/engraving choice, not a musical one — the
same reasoning that excluded Guido's `\pedalOn`/`\stems…` tags from the
articulation vocabulary above, and consistent with every other purely
visual field (position, color, font, bezier offsets) encountered across all
three formats' ASTs in this document, none of which has been proposed as an
`Extra` anywhere. MusicXML's `continue` slur kind and both formats' bezier/
control-point offsets are the same category, and are likewise not proposed.

#### NoteTable: single-format candidates {#notetable-single-format}

- **MIDI polyphonic (key) pressure.** `.polyphonicPressure(channel, key,
  pressure)` (`IvorMIDI/Sources/IvorMIDI/AST/MIDI/MIDIChannelMessage.swift:22`)
  is a distinct message type from Control Change, and unlike
  `.channelPressure`/pitch bend below, it carries its own note number —
  the exact same `key` `NotePairer`'s `openNotes: [MIDI.NoteNumber: ...]`
  (`Sources/IvorExtern/MIDI/MIDI.Importer.NotePairer.swift:29`) is already
  keyed by. That makes it directly attachable to the specific open note it
  names, the same way `_closeNote` already matches an incoming note-off to
  its `openNotes[key]` entry — no range-matching design work required,
  unlike channel-wide aftertouch or pitch bend. It still falls into
  `NotePairer.ingest`'s `default: break`
  (`Sources/IvorExtern/MIDI/MIDI.Importer.NotePairer.swift:68-69`) today, so
  it's dropped outright rather than merely rounded. A real Extra would need
  one small design call the other CC gaps above didn't — pressure can be
  sent repeatedly over a held note's duration, so the importer would need to
  pick a single representative value (e.g. the peak, or the value at
  note-on) rather than a MIDI-style continuous envelope, since `Extras`
  holds one value per entry, not a time series. No other format has an
  equivalent per-note pressure concept, so `polyphonicPressure` is
  single-format (MIDI round-trip only), not cross-format.
- **MIDI note-off (release) velocity.** `MIDI.Note.offVelocity` is captured
  by `NotePairer._closeNote`
  (`Sources/IvorExtern/MIDI/MIDI.Importer.NotePairer.swift:101-117`) and
  stored on the paired `MIDI.Note`, but `Context.handleNote`
  (`Sources/IvorExtern/MIDI/MIDI.Importer.Context.swift:41-53`) only ever
  reads `note.onVelocity` — the release velocity is parsed and then
  discarded. No other format has an equivalent concept, so this only helps a
  MIDI round-trip. Not yet promoted to a named candidate above.
- **MIDI channel pressure, pitch bend, and every remaining Control Change**
  (Bank Select, Pan LSB, and Expression Controller are covered above as
  `InstrumentMap`/`PanMap`/`DynamicMap` candidates, and polyphonic pressure
  is covered just above — this bullet is what's left).
  `NotePairer.ingest`'s `switch message { ... default: break }`
  (`Sources/IvorExtern/MIDI/MIDI.Importer.NotePairer.swift:44-71`) drops
  channel pressure, pitch bend, sustain (CC 64), modulation (CC 1), and
  everything else before the event even reaches `Context` — real,
  commonly-authored expressive data (a bent note, a sustained pedal
  passage) lost outright on every MIDI import. Unlike Bank Select/Pan
  LSB/Expression/polyphonic pressure, none of which need any note or time
  window resolved beyond what the event itself already carries, channel
  pressure and pitch bend are channel-wide with no note number attached, so
  attaching either *per note* would need range-matching a continuous
  controller stream against note attack/duration windows, which is real
  design work, not a one-line fix — flagged here as a known gap rather than
  a ready-to-implement candidate.
- **Guido tablature.** `.tablature` symbols
  (`Sources/IvorExtern/Guido/Guido.Importer.Walker.swift`) aren't silently
  dropped — they throw `Guido.Error.unsupportedEvent`. Different category
  from everything else in this document (an explicit rejection, not silent
  loss), so not really an `Extras` candidate; noted here only so it isn't
  mistaken for one.
- **ABC variant endings.** `.variantEnding`
  (`Sources/IvorExtern/ABC/ABC.Importer.Walker.swift:406-416`) — which pass
  through a repeat a given note belongs to — is a no-op. Guido and MusicXML
  have their own repeat/ending constructs with a similar shape, but the
  three formats' models differ enough (Guido's `\repeat`/`GMNRepeat` vs.
  MusicXML's `<ending>` numbers vs. ABC's `|1`/`|2` markers) that unifying
  them under one `Extra` key would take real design work rather than reusing
  one already-shared value space, unlike `chordText`/`lyricText`/
  `articulation` above.
