// © 2026 John Gary Pusey (see LICENSE.md)

public import Foundation

/// The file written from works, with what couldn’t be carried over exactly (see
/// ``ExportFileFormat/write(works:options:)``).
public struct ExportResult {

    // MARK: Public Instance Properties

    /// The file written.
    public let file: FileWrapper

    /// What was dropped or approximated while writing, one warning per kind of loss in each
    /// work.
    public let warnings: [ExternWarning]
}
