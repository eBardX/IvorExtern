// © 2026 John Gary Pusey (see LICENSE.md)

internal import IvorModel

private import XestiTools

// MARK: Internal Functions

// A credit as one line of free text, for a format whose only home for it
// is a text field with no role of its own (an SMF text event, a Guido
// `\composer` tag, an ABC `C:` field holding a non-composer). The role, if
// any, follows the name in parentheses — `"J. Smith (arranger)"`.
internal func describeCredit(_ credit: Credit) -> String {
    guard let role = credit.role
    else { return credit.name }

    return "\(credit.name) (\(role.stringValue))"
}

// A remark as free text, for a format with no home for its label: the
// label, if any, leads — `"history: Collected in 1904"`.
internal func describeRemark(_ remark: Remark) -> String {
    guard let label = remark.label
    else { return remark.text }

    return "\(label): \(remark.text)"
}

// Whether a line of presentational text — a Guido `\footer`, which is
// where a copyright line goes by convention but which can hold anything —
// reads as a rights notice.
internal func isRightsNoticeText(_ text: String) -> Bool {
    let lowered = text.lowercased()

    return ["©", "℗", "(c)", "copyright", "public domain", "all rights reserved"].contains { lowered.contains($0) }
}

// Collapses multi-line metadata text (a rights notice or remark keeps its
// line breaks in the model) to the single line a format's text field can
// hold.
internal func singleLine(_ text: String) -> String {
    text.normalizingWhitespace()
}
