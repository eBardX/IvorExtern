// © 2025–2026 John Gary Pusey (see LICENSE.md)

private import IvorTiming
private import IvorTuning

extension FileFormat {
    internal static let dkm = Self(displayName: "JohnnySonic Score File",
                                   filenameExtensions: ["dkm",          // preferred goes 1st
                                                        "johnnysonic"],
                                   pitchNotations: [.absolute,
                                                    .keyboard],
                                   timeBases: [.beat])
}
