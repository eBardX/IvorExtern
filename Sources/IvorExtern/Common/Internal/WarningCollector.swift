// © 2026 John Gary Pusey (see LICENSE.md)

//
// Counts the losses an importer or exporter reports while it runs, by kind and work, so each
// can be reported once with its count (see `ExternWarning`). A reference type, so the walkers
// and exporters it is handed to all add to the one count.
//
internal final class WarningCollector {

    // MARK: Internal Initializers

    internal init() {
    }

    // MARK: Private Nested Types

    private struct Key: Hashable {

        // MARK: Fileprivate Instance Properties

        fileprivate let kind: ExternWarning.Kind
        fileprivate let workIndex: Int?
    }

    // MARK: Private Instance Properties

    private var counts: [Key: Int] = [:]
}

// MARK: -

extension WarningCollector {

    // MARK: Internal Instance Properties

    //
    // One warning per kind in each work, ordered by work, then by kind.
    //
    internal var warnings: [ExternWarning] {
        counts.map { ExternWarning(kind: $0.key.kind, count: $0.value, workIndex: $0.key.workIndex) }
            .sorted { ($0.workIndex ?? -1, $0.kind.rawValue) < ($1.workIndex ?? -1, $1.kind.rawValue) }
    }

    // MARK: Internal Instance Methods

    internal func add(_ kind: ExternWarning.Kind,
                      count: Int = 1,
                      workIndex: Int?) {
        guard count >= 1
        else { return }

        counts[Key(kind: kind, workIndex: workIndex), default: 0] += count
    }
}
