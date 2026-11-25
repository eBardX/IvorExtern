# Using IvorExtern

Read works from external music notation files, write them back out, and turn
them into MIDI for playback.

## Overview

IvorExtern connects [IvorModel](https://github.com/eBardX/IvorModel) works to
files in other formats. Each format is handled by a lower-level Ivor package,
which IvorExtern drives on your behalf:

 Format                          | Filename extensions        | Time basis      | Pitch notation        | Built on
:-----                           |:------------------         |:----------      |:--------------        |:--------
 ABC File                        | `abc`                      | Beat            | Standard              | IvorABC
 Guido Score File                | `gmn`                      | Beat            | Standard              | IvorGMN
 JohnnySonic Score File          | `dkm`, `johnnysonic`       | Beat            | Absolute, keyboard    | IvorDKM
 Standard MIDI File              | `mid`, `midi`, `smf`       | Beat, wall      | Keyboard              | IvorSMF
 MusicXML Document               | `musicxml`, `xml`          | Beat            | Standard              | IvorMXL
 Compressed MusicXML Document    | `mxl`                      | Beat            | Standard              | IvorMXL

The core types are ``ImportFileFormat`` and ``ExportFileFormat``, which read
and write files, and ``WorkPerformance``, which turns a work into timed MIDI
channel messages.

## Finding a format

A format is looked up by a filename extension or a MIME type, such as a
document picker or a URL gives you:

```swift
let abc  = ImportFileFormat.importFileFormat(for: "abc")
let midi = ExportFileFormat.exportFileFormat(for: "audio/midi")
```

Each returns `nil` for a tag no format supports. The type properties
`supportedFilenameExtensions`, `supportedMIMETypes`, `supportedTimeBases`, and
`supportedPitchNotations` list what is supported across every format, and their
`preferred…` counterparts give one extension or MIME type per format, for
building a file type list. A format value also has a
``ImportFileFormat/displayName`` and its own extensions, MIME types, time bases,
and pitch notations.

## Importing

``ImportFileFormat/read(from:options:)`` reads every work a `FileWrapper` holds — an ABC
file can hold a whole tunebook — as an ``ImportResult``:

```swift
let result = try ImportFileFormat.importFileFormat(for: "abc")!
    .read(from: FileWrapper(url: url))
let works = result.works
```

Each work comes back in the time basis and pitch notation of its format, as
the table above shows. It holds whatever the file records of its parts, notes,
dynamics, instruments, and pan positions, and of its descriptive information —
titles, credits, rights, and remarks — in the work’s `info`. A work read from a
Standard MIDI File whose times were measured in SMPTE frames reports
`Work.hasMIDITimeCode`, so that writing it back keeps the same division.

``ImportOptions`` adjusts how a format reads: its
``ImportOptions/pedalSimplification`` simplifies each imported pedal table. A
format ignores any option it doesn’t use, and
``ImportFileFormat/supportedOptions`` lists the ones it does.

## Exporting

A format can write a work only in a time basis and pitch notation it supports.
``ExportFileFormat/canWrite(_:)`` checks a work, and IvorModel’s
`convert(timeBasis:pitchNotation:context:dropsUnconvertibleNotes:appliesFermataHolds:)` converts
one that doesn’t fit:

```swift
let midi = ExportFileFormat.exportFileFormat(for: "mid")!
var work = works[0]                        // beat time, standard pitch

if !midi.canWrite(work) {
    work = try work.convert(timeBasis: .beat, pitchNotation: .keyboard)!
}

let file = try midi.write(works: [work]).file   // a FileWrapper
```

``ExportFileFormat/write(works:options:)`` writes one or more works to a `FileWrapper`,
ready to save or share, as an ``ExportResult``.

### Warnings

Reading and writing both report what a format couldn’t carry over exactly, as
``ExternWarning`` values in ``ImportResult/warnings`` and
``ExportResult/warnings``: one per kind of loss in each work, with a count. ABC
has no figure after a note, for example, so writing one moves it before the next
note and reports ``ExternWarning/Kind/movedFigureAfterNote``; and it has no
caesura, so writing one drops it and reports
``ExternWarning/Kind/droppedCaesura``. A warning never stops a read or write.

### Ornaments in ABC

ABC reads and writes grace groups (with chords in braces, the slash, and a tie
into the main note), trills, both mordents, rolled chords, abcm2ps’s tremolo
marks (`!/!` to `!///!`, and `!trem1!` to `!trem4!` between two notes), and
fermatas — on a note, on a rest, or before a bar line, where it becomes a
fermata mark over the last event. A lone grace note is an eighth and each of a
group a sixteenth, whatever `L:` says, as the ABC renderers read them.

### Keys

A beat-time work’s key table comes in from every format that has keys and goes
back out to it. Each entry is a `Key`: atonal, diatonic (with the mode the
source names, or none where it names none), or custom. A key a format records
but Ivor can’t represent (one with a double sharp or flat, or a microtonal
alteration) is left out on import, and so is one that only repeats the key
before it. Mode names are normalized on round trip: ABC’s `K:Aaeo` comes back
as `K:Am`, and MusicXML’s `<mode>ionian</mode>` as `<mode>major</mode>`.

 Format      | Reads                                       | Writes                                      | Loses
:------      |:-----                                       |:------                                      |:-----
 MIDI        | Key signature meta events of the first track that has any, each as major or minor | A meta event at each key, on the first track | A custom key, written as its nearest diatonic signature; modes other than minor, and no mode, which read back as major; an atonal key, written as C major
 MusicXML    | `<key>` of each part’s first staff, traditional or not, along the play order; `<mode>none</mode>` as atonal | `<key>` at each key, at a measure’s start or in the middle | `<key-octave>`
 ABC         | `K:` fields, in the header and inline, along the play order; `K:none` as atonal | `K:` and inline `[K:…]`, with every note’s accidental written against the key and the bar | No mode, written as major; no key at all, written as `K:C`
 Guido       | `\key`: a number of fifths (no mode), a key name (major or minor), or a free key | `\key`: a key name for major or minor, a number of fifths otherwise, or a free key for a custom key | Modes other than major and minor; an atonal key, written as no sharps or flats
 JohnnySonic | —                                           | —                                           | Every key

``ExportOptions`` adjusts how a format writes. The formats that write sound —
a Standard MIDI File and a JohnnySonic score — render the work first (see
IvorModel’s `Work.rendered(options:)`), so its grace notes, trills, mordents,
tremolos and rolls become the notes that sound, and its fermatas and caesuras
become time; ``ExportOptions/fermataMode`` says how, slowing the tempo over
each hold by default. A Standard MIDI File also marks each fermata with a
marker meta event, in every mode. The ``MIDIExportOptions`` of a Standard MIDI
File give the ticks per quarter note for a beat-time work, and the frame rate
and ticks per frame for a wall-time one. A format ignores any option it doesn’t
use, and ``ExportFileFormat/supportedOptions`` lists the ones it does.

## Playing a work

A ``WorkPerformance`` is a work as a MIDI player plays it: every part’s channel
messages, each at its time in the work, in the order they are sent. It is made
from a work in keyboard pitch and wall time — the initializer returns `nil` for
any other — and, optionally, a realization from IvorModel that says what each
instrument sounds as. A performance plays the notes as they stand, so render
the work first, while it’s still in beat time, then convert it:

```swift
let rendered    = try work.rendered().work
let playable    = try rendered.convert(timeBasis: .wall, pitchNotation: .keyboard)!
let performance = WorkPerformance(work: playable)!

performance.duration        // the time of the last event
performance.events          // bank selects, program changes, pan, expression, notes, …
```

Without a realization, each instrument sounds as the General MIDI instrument
its name matches. Event times are exact `WallTime` values, never floating-point
seconds, so events at the same moment stay together; at the same time,
note-offs come first, then bank selects, program changes, pan, expression,
other controllers, and note-ons.

Each part plays on a channel of its own, given in
``WorkPerformance/partChannels``, unless an instrument’s assignment moves it;
``WorkPerformance/partChannelSets`` lists every channel each part plays on.
Given an output for each part,
``WorkPerformance/channelOutputs(forPartOutputs:)`` returns an output for each
channel, in the form a MIDI router such as IvorConnect’s `MIDIRouter` takes.

## General MIDI helpers

IvorExtern also extends a few IvorModel and IvorMIDI types with the General MIDI
knowledge its formats need:

- `Instrument.generalMIDIInstrument` gives the General MIDI Level 1 instrument
  whose name an instrument’s name matches, if any.
- `Patch.generalMIDIName` gives the General MIDI name of a patch’s sound.
- `MIDIPatch(instrument:)` and `MIDIPatch(patch:)` give the bank and program
  that select an instrument or a patch.

## Error handling

Thrown errors conform to `EnhancedError` (from
[XestiTools](https://github.com/eBardX/XestiTools)): each has a `category` of
`"IvorExtern"` and a human-readable `message`. Each also has a `cause`, holding
the error of the lower-level package that failed, if any.

 Type                         | Thrown by
:----                         |:---------
 ``ImportFileFormat/Error``   | ``ImportFileFormat/read(from:options:)``
 ``ExportFileFormat/Error``   | ``ExportFileFormat/write(works:options:)``

Looking up a format returns `nil` for an unsupported tag, and
``WorkPerformance/init(work:realization:partsWithoutExpression:)`` returns
`nil` for a work not in keyboard pitch and wall time.

## Concurrency

IvorExtern is built for Swift 6 strict concurrency. Every public type is a
value type, and every one but ``ExportResult`` — whose `FileWrapper` isn’t
`Sendable` — is `Sendable`, so instances can be freely shared across tasks and
actor boundaries.
