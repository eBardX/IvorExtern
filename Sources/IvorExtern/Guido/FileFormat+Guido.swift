// © 2025–2026 John Gary Pusey (see LICENSE.md)

private import IvorTiming
private import IvorTuning

extension FileFormat {
    internal static let gmn = Self(displayName: "Guido Score File",
                                   filenameExtensions: ["gmn"],
                                   pitchNotations: [.standard],
                                   timeBases: [.beat])
}
