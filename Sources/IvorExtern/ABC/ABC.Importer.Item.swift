// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorABC

// One entry in a voice's own flattened, unresolved AST stream — a field or a
// symbol, in source order, after `V:` routing has separated this voice's
// content from every other voice's. `ABC.Importer.Plan` indexes into an
// array of these to compute a replay order; `ABC.Importer.Walker` streams
// that order, resolving each item as it goes.
extension ABC.Importer {

    // MARK: Internal Nested Types

    internal enum Item {
        case field(ABCField)
        case symbol(ABCSymbol)
    }
}

// MARK: - Equatable

extension ABC.Importer.Item: Equatable {
}

// MARK: - Sendable

extension ABC.Importer.Item: Sendable {
}
