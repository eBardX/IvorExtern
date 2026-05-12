extension External.FileFormat {
    internal static let musicXML = Self(displayName: "MusicXML Document",
                                        filenameExtensions: ["musicxml",                        // preferred goes 1st
                                                             "xml"],
                                        mimeTypes: ["application/vnd.recordare.musicxml+xml",   // preferred goes 1st
                                                    "application/musicxml+xml"])

    internal static let mxl = Self(displayName: "Compressed MusicXML Document",
                                   filenameExtensions: ["mxl"],
                                   mimeTypes: ["application/vnd.recordare.musicxml",            // preferred goes 1st
                                               "application/musicxml+zip"])
}
