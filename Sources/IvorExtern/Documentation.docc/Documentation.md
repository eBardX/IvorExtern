# ``IvorExtern``

@Metadata {
    @PageColor(blue)
}

An import and export framework for external music notation formats.

## Overview

The IvorExtern framework provides an import and export framework for external
music notation formats, written in Swift. The following formats are supported:

- [ABC Notation](https://abcnotation.com)
- [Guido Music Notation (GMN)](https://guidodoc.grame.fr)
- [Johnny Sonic score files](https://github.com/JohnnySonic/JohnnySonic/blob/main/JohnnySonicDoc.pdf)
- [Standard MIDI Files](https://midi.org/standard-midi-files)
- [MusicXML](https://www.musicxml.com) (both compressed and uncompressed)

Each format reads files into [IvorModel](https://github.com/eBardX/IvorModel)
works and writes works back out, and a ``WorkPerformance`` turns a work into the
timed MIDI channel messages a player sends.

```swift
import Foundation
import IvorExtern
import IvorModel

// Read every work in an ABC file.
let abc   = ImportFileFormat.importFileFormat(for: "abc")!
let works = try abc.read(from: FileWrapper(url: abcURL))

// A Standard MIDI File holds keyboard pitch, so convert the work first.
let midi = ExportFileFormat.exportFileFormat(for: "mid")!
let work = try works[0].convert(timeBasis: .beat, pitchNotation: .keyboard)!

if midi.canWrite(work) {
    try midi.write(works: [work]).write(to: midiURL, originalContentsURL: nil)
}
```

See <doc:UsingIvorExtern> for a full guide to the formats, importing,
exporting, playing a work, and error handling.

## Topics

### Guides

- <doc:UsingIvorExtern>

### File formats

- ``ImportFileFormat``
- ``ExportFileFormat``

### Playing a work

- ``WorkPerformance``
