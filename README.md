# IvorExtern

An import and export framework for external music notation formats.

[![Swift 6.3](https://img.shields.io/badge/Swift-6.3-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20macOS-lightgrey.svg)](https://developer.apple.com)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-brightgreen.svg)](https://swift.org/package-manager/)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](https://github.com/eBardX/IvorExtern/blob/main/LICENSE.md)

* [Overview](#overview)
* [Requirements](#requirements)
* [Installation](#installation)
    * [Swift Package Manager](#spm_installation)
* [Quick Start](#quick_start)
* [Documentation](#documentation)
* [Reference Documentation](#reference_documentation)
* [Credits](#credits)
* [License](#license)

## <a name="overview">Overview</a>

The IvorExtern framework provides an import and export framework for external
music notation formats, written in Swift. The following formats are supported:

- [ABC Notation](https://abcnotation.com)
- [Guido Music Notation (GMN)](https://guidodoc.grame.fr)
- [JohnnySonic score files](https://github.com/JohnnySonic/JohnnySonic/blob/main/JohnnySonicDoc.pdf)
- [Standard MIDI Files](https://midi.org/standard-midi-files)
- [MusicXML](https://www.musicxml.com) (both compressed and uncompressed)

Each format reads files into [IvorModel][ivormodel] works and writes works back
out, and a `WorkPerformance` turns a work into the timed MIDI channel messages
a player sends.

## <a name="requirements">Requirements</a>

* iOS 18.0+ / macOS 15.0+
* Swift 6.3 toolchain
* Swift 6 language mode

## <a name="installation">Installation</a>

### <a name="spm_installation">Swift Package Manager</a>

IvorExtern is distributed exclusively through the [Swift Package Manager][spm].

To add IvorExtern to a Swift package, add it to the `dependencies` in your
`Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/eBardX/IvorExtern.git",
             .upToNextMinor(from: "0.22.0"))
]
```

Then add `IvorExtern` to the dependencies of any target that uses it:

```swift
.target(name: "MyTarget",
        dependencies: [.product(name: "IvorExtern",
                                package: "IvorExtern")])
```

To add IvorExtern to an Xcode project, choose **File ▸ Add Package
Dependencies…** and enter the repository URL:

```
https://github.com/eBardX/IvorExtern.git
```

IvorExtern depends on [IvorABC][ivorabc], [IvorDKM][ivordkm],
[IvorGeneralMIDI][ivorgeneralmidi], [IvorGMN][ivorgmn], [IvorMIDI][ivormidi],
[IvorModel][ivormodel], [IvorMXL][ivormxl], [IvorSMF][ivorsmf],
[IvorSMPTE][ivorsmpte], [IvorTiming][ivortiming], [IvorTuning][ivortuning],
[XestiNumbers][xestinumbers], [XestiText][xestitext], and
[XestiTools][xestitools]; the Swift Package Manager resolves them
automatically.

## <a name="quick_start">Quick Start</a>

Read the works in an ABC file, and write one out as a Standard MIDI File:

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

For the complete story — the formats and what each holds, exporting, playing a
work, and error handling — see the [usage guide][guide].

## <a name="documentation">Documentation</a>

* [Using IvorExtern][guide] — a guide to using the public API, published as
  part of the DocC documentation.
* Every public declaration carries a DocC comment.

## <a name="reference_documentation">Reference Documentation</a>

Full [reference documentation][refdoc] is available courtesy of [DocC][docc].

## <a name="credits">Credits</a>

John Gary Pusey (ebardx@gmail.com)

## <a name="license">License</a>

IvorExtern is available under [the MIT license][license].

[docc]:             https://www.swift.org/documentation/docc/
[guide]:            https://eBardX.github.io/ivor-packages-docs/documentation/ivorextern/usingivorextern
[ivorabc]:          https://github.com/eBardX/IvorABC
[ivordkm]:          https://github.com/eBardX/IvorDKM
[ivorgeneralmidi]:  https://github.com/eBardX/IvorGeneralMIDI
[ivorgmn]:          https://github.com/eBardX/IvorGMN
[ivormidi]:         https://github.com/eBardX/IvorMIDI
[ivormodel]:        https://github.com/eBardX/IvorModel
[ivormxl]:          https://github.com/eBardX/IvorMXL
[ivorsmf]:          https://github.com/eBardX/IvorSMF
[ivorsmpte]:        https://github.com/eBardX/IvorSMPTE
[ivortiming]:       https://github.com/eBardX/IvorTiming
[ivortuning]:       https://github.com/eBardX/IvorTuning
[license]:          https://github.com/eBardX/IvorExtern/blob/main/LICENSE.md
[refdoc]:           https://eBardX.github.io/ivor-packages-docs/documentation/ivorextern
[spm]:              https://swift.org/package-manager/
[xestinumbers]:     https://github.com/eBardX/XestiNumbers
[xestitext]:        https://github.com/eBardX/XestiText
[xestitools]:       https://github.com/eBardX/XestiTools
