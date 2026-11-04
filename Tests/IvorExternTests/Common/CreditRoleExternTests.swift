// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import IvorModel
import Testing
import XestiTools

struct CreditRoleExternTests {
}

// MARK: -

extension CreditRoleExternTests {
    @Test
    func roles_areDistinctFromStandardRoles() {
        let roles: [Credit.Role] = [.artist, .composer, .editor, .lyricist, .transcriber]

        #expect(Set(roles.map(\.stringValue)).count == roles.count)
    }

    @Test
    func roles_values() {
        #expect(Credit.Role.artist.stringValue == "artist")
        #expect(Credit.Role.editor.stringValue == "editor")
        #expect(Credit.Role.transcriber.stringValue == "transcriber")
    }
}
