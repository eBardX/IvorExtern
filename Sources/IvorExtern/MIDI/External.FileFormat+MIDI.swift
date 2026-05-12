extension External.FileFormat {
    internal static let midi = Self(displayName: "Standard MIDI File",
                                    filenameExtensions: ["midi",        // preferred goes 1st
                                                         "mid",
                                                         "smf"],
                                    mimeTypes: ["audio/midi",           // preferred goes 1st
                                                "audio/x-midi"])
}
