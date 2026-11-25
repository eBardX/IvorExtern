// © 2026 John Gary Pusey (see LICENSE.md)

/// Something a reader or writer couldn’t carry over exactly, reported alongside its result (see
/// ``ImportResult`` and ``ExportResult``).
///
/// A warning counts every occurrence of one kind of loss or approximation in one work, rather
/// than listing each, since a single file can lose the same thing hundreds of times. A notation
/// format that can’t hold something the model can — a grace figure after a note, a trill’s
/// speed, a caesura — drops or approximates it, and says so here.
public struct ExternWarning {

    // MARK: Public Instance Properties

    /// How many times this happened.
    public let count: Int

    /// What was dropped or approximated.
    public let kind: Kind

    /// The index of the work it happened in, among the works read or written, or `nil` if it
    /// concerns the file as a whole.
    public let workIndex: Int?

    // MARK: Internal Initializers

    internal init(kind: Kind,
                  count: Int,
                  workIndex: Int?) {
        self.count = count
        self.kind = kind
        self.workIndex = workIndex
    }
}

// MARK: - Hashable

extension ExternWarning: Hashable {
}

// MARK: - Sendable

extension ExternWarning: Sendable {
}
