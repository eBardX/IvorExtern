// © 2026 John Gary Pusey (see LICENSE.md)

@testable import IvorExtern
import Testing

struct RemarkLabelTests {
}

// MARK: -

extension RemarkLabelTests {
    @Test
    func labels_areDistinct() {
        let labels = [RemarkLabel.area,
                      RemarkLabel.book,
                      RemarkLabel.discography,
                      RemarkLabel.encodingDescription,
                      RemarkLabel.fileURL,
                      RemarkLabel.footer,
                      RemarkLabel.group,
                      RemarkLabel.history,
                      RemarkLabel.label,
                      RemarkLabel.movementNumber,
                      RemarkLabel.notes,
                      RemarkLabel.origin,
                      RemarkLabel.relation,
                      RemarkLabel.rhythm,
                      RemarkLabel.source,
                      RemarkLabel.workNumber]

        #expect(Set(labels).count == labels.count)
    }

    @Test
    func labels_values() {
        #expect(RemarkLabel.area == "area")
        #expect(RemarkLabel.book == "book")
        #expect(RemarkLabel.discography == "discography")
        #expect(RemarkLabel.encodingDescription == "encoding description")
        #expect(RemarkLabel.fileURL == "file URL")
        #expect(RemarkLabel.footer == "footer")
        #expect(RemarkLabel.group == "group")
        #expect(RemarkLabel.history == "history")
        #expect(RemarkLabel.label == "label")
        #expect(RemarkLabel.movementNumber == "movement number")
        #expect(RemarkLabel.notes == "notes")
        #expect(RemarkLabel.origin == "origin")
        #expect(RemarkLabel.relation == "relation")
        #expect(RemarkLabel.rhythm == "rhythm")
        #expect(RemarkLabel.source == "source")
        #expect(RemarkLabel.workNumber == "work number")
    }
}
