import SwiftUI
import XCTest

@testable import MarkdownUI

final class MarkdownHighlightTests: XCTestCase {
  private let highlight = MarkdownHighlight(query: "cafe", background: .yellow, foreground: .black)!

  func testEmptyQuery() {
    XCTAssertNil(MarkdownHighlight(query: "", background: .yellow, foreground: .black))
  }

  func testMatchesIgnoringCaseAndDiacritics() {
    XCTAssertTrue(self.highlight.matches("Le Café"))
    XCTAssertTrue(self.highlight.matches("CAFE"))
    XCTAssertFalse(self.highlight.matches("caff"))
  }

  func testApplyMarksEveryOccurrence() {
    // given
    let attributedString = AttributedString("Café, then cafe, then CAFÉ.")

    // when
    let result = self.highlight.apply(to: attributedString)

    // then
    let marked = result.runs
      .filter { $0.backgroundColor == .yellow && $0.foregroundColor == .black }
      .map { String(result[$0.range].characters) }
    XCTAssertEqual(["Café", "cafe", "CAFÉ"], marked)
    XCTAssertEqual(String(attributedString.characters), String(result.characters))
  }

  func testApplyWithoutOccurrences() {
    let attributedString = AttributedString("Nothing to see here.")
    XCTAssertEqual(attributedString, self.highlight.apply(to: attributedString))
  }

  func testApplyAcrossRuns() {
    // given
    var attributedString = AttributedString("ca")
    attributedString.inlinePresentationIntent = .stronglyEmphasized
    attributedString += AttributedString("fé au lait")

    // when
    let result = self.highlight.apply(to: attributedString)

    // then
    let marked = result.runs
      .filter { $0.backgroundColor == .yellow }
      .map { String(result[$0.range].characters) }
    XCTAssertEqual(["ca", "fé"], marked)
  }

  func testFirstBlockInDocumentOrder() {
    // given
    let content = MarkdownContent(
      """
      # Menu

      Tea and coffee.

      - Croissant
      - A **café** au lait

      ```
      cafe = 1
      ```
      """
    )

    // when
    let block = content.blocks.firstBlock(matching: self.highlight)

    // then
    XCTAssertEqual(
      block,
      .paragraph(content: [.text("A "), .strong(children: [.text("café")]), .text(" au lait")])
    )
  }

  func testFirstBlockInCodeAndTables() {
    let code = MarkdownContent("Nothing.\n\n```\nlet cafe = 1\n```")
    XCTAssertEqual(code.blocks.firstBlock(matching: self.highlight), code.blocks.last)

    let table = MarkdownContent("| Drink |\n| --- |\n| Café |")
    XCTAssertEqual(table.blocks.firstBlock(matching: self.highlight), table.blocks.first)

    XCTAssertNil(MarkdownContent("Tea.").blocks.firstBlock(matching: self.highlight))
  }
}
