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

There are three public types: ``ImportFileFormat`` and ``ExportFileFormat``,
which read and write files, and ``WorkPerformance``, which turns a work into
timed MIDI channel messages.

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

``ImportFileFormat/read(from:)`` reads every work a `FileWrapper` holds — an ABC
file can hold a whole tunebook:

```swift
let works = try ImportFileFormat.importFileFormat(for: "abc")!
    .read(from: FileWrapper(url: url))
```

Each work comes back in the time basis and pitch notation of its format, as
the table above shows. It holds whatever the file records of its parts, notes,
dynamics, instruments, and pan positions, and of its descriptive information —
titles, credits, rights, and remarks — in the work’s `info`. A work read from a
Standard MIDI File whose times were measured in SMPTE frames reports
`Work.hasMIDITimeCode`, so that writing it back keeps the same division.

## Exporting

A format can write a work only in a time basis and pitch notation it supports.
``ExportFileFormat/canWrite(_:)`` checks a work, and IvorModel’s
`convert(timeBasis:pitchNotation:context:dropsUnconvertibleNotes:)` converts
one that doesn’t fit:

```swift
let midi = ExportFileFormat.exportFileFormat(for: "mid")!
var work = works[0]                        // beat time, standard pitch

if !midi.canWrite(work) {
    work = try work.convert(timeBasis: .beat, pitchNotation: .keyboard)!
}

let file = try midi.write(works: [work])   // a FileWrapper
```

``ExportFileFormat/write(works:)`` writes one or more works to a `FileWrapper`,
ready to save or share.

## Playing a work

A ``WorkPerformance`` is a work as a MIDI player plays it: every part’s channel
messages, each at its time in the work, in the order they are sent. It is made
from a work in keyboard pitch and wall time — the initializer returns `nil` for
any other — and, optionally, a realization from IvorModel that says what each
instrument sounds as:

```swift
let playable    = try work.convert(timeBasis: .wall, pitchNotation: .keyboard)!
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
 ``ImportFileFormat/Error``   | ``ImportFileFormat/read(from:)``
 ``ExportFileFormat/Error``   | ``ExportFileFormat/write(works:)``

Looking up a format returns `nil` for an unsupported tag, and
``WorkPerformance/init(work:realization:)`` returns `nil` for a work not in
keyboard pitch and wall time.

## Concurrency

IvorExtern is built for Swift 6 strict concurrency. Every public type is a
`Sendable` value type, so instances can be freely shared across tasks and actor
boundaries.
