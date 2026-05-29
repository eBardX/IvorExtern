// © 2025–2026 John Gary Pusey (see LICENSE.md)

private import IvorTiming
private import IvorTuning

extension FileFormat {
    internal static let abc = Self(displayName: "ABC File",
                                   filenameExtensions: ["abc"],
                                   mimeTypes: ["text/vnd.abc"],
                                   pitchNotations: [.standard],
                                   timeBases: [.beat])
}
