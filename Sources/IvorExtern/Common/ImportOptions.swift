// © 2026 John Gary Pusey (see LICENSE.md)

public import IvorModel

/// Options that adjust how an ``ImportFileFormat`` reads works.
///
/// The defaults (``default``) read a file just as an import without options does. A format
/// ignores any option it doesn’t use; ``ImportFileFormat/supportedOptions`` lists the ones it
/// does.
public struct ImportOptions {

    // MARK: Public Initializers

    /// Creates import options.
    ///
    /// - Parameter pedalSimplification:    How to simplify each imported pedal table, or `nil`
    ///                                     to keep the tables as read.
    public init(pedalSimplification: Pedal.SimplifyMode? = nil) {
        self.pedalSimplification = pedalSimplification
    }

    // MARK: Public Instance Properties

    /// How to simplify each imported pedal table, with `PedalTable.simplify(_:)`, or `nil` to
    /// keep the tables as read.
    ///
    /// The default is `nil`.
    public var pedalSimplification: Pedal.SimplifyMode?
}

// MARK: -

extension ImportOptions {

    // MARK: Public Type Properties

    /// The default import options, which change nothing.
    public static let `default` = Self()
}

// MARK: - Equatable

extension ImportOptions: Equatable {
}

// MARK: - Sendable

extension ImportOptions: Sendable {
}
