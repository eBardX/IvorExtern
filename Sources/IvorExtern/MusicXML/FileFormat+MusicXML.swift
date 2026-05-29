// © 2025–2026 John Gary Pusey (see LICENSE.md)

private import IvorTiming
private import IvorTuning

extension FileFormat {
    internal static let musicXML = Self(displayName: "MusicXML Document",
                                        filenameExtensions: ["musicxml",                        // preferred goes 1st
                                                             "xml"],
                                        mimeTypes: ["application/vnd.recordare.musicxml+xml",   // preferred goes 1st
                                                    "application/musicxml+xml"],
                                        pitchNotations: [.standard],
                                        timeBases: [.beat])

    internal static let mxl = Self(displayName: "Compressed MusicXML Document",
                                   filenameExtensions: ["mxl"],
                                   mimeTypes: ["application/vnd.recordare.musicxml",            // preferred goes 1st
                                               "application/musicxml+zip"],
                                   pitchNotations: [.standard],
                                   timeBases: [.beat])
}
