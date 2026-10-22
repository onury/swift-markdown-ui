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

  func testCountMatchesApply() {
    XCTAssertEqual(3, self.highlight.count(in: "Café, then cafe, then CAFÉ."))
    XCTAssertEqual(0, self.highlight.count(in: "Nothing to see here."))
    XCTAssertEqual(2, self.highlight.count(in: "cafecafe"))
  }

  func testApplyDrawsTheCurrentOccurrenceApart() {
    // given
    var highlight = MarkdownHighlight(
      query: "cafe", background: .yellow, foreground: .black, currentBackground: .orange, currentForeground: .white
    )!
    highlight.current = 1

    // when
    let result = highlight.apply(to: AttributedString("Café, then cafe, then CAFÉ."))

    // then
    let current = result.runs
      .filter { $0.backgroundColor == .orange && $0.foregroundColor == .white }
      .map { String(result[$0.range].characters) }
    let others = result.runs
      .filter { $0.backgroundColor == .yellow }
      .map { String(result[$0.range].characters) }
    XCTAssertEqual(["cafe"], current)
    XCTAssertEqual(["Café", "CAFÉ"], others)
  }

  func testOccurrencesAcrossBlocks() {
    let content = MarkdownContent(
      """
      # Cafe

      A cafe and a **café**.

      - Cafe one
      - Two

      | Cafe | cafe |
      | ---- | ---- |
      | x    | cafe |

      ```
      cafe = 1
      ```
      """
    )
    XCTAssertEqual(8, content.occurrences(of: self.highlight))
  }

  func testBlockHoldingAnOccurrence() {
    // given
    let content = MarkdownContent(
      """
      # Cafe

      A cafe and a **café**.

      - Cafe one
      """
    )

    // then
    XCTAssertEqual(content.blocks.block(holding: 0, of: self.highlight)?.occurrence, 0)
    XCTAssertEqual(content.blocks.block(holding: 0, of: self.highlight)?.block, .heading(level: 1, content: [.text("Cafe")]))
    let second = content.blocks.block(holding: 2, of: self.highlight)
    XCTAssertEqual(second?.occurrence, 1)
    XCTAssertEqual(
      second?.block,
      .paragraph(content: [.text("A cafe and a "), .strong(children: [.text("café")]), .text(".")])
    )
    XCTAssertEqual(content.blocks.block(holding: 3, of: self.highlight)?.block, .paragraph(content: [.text("Cafe one")]))
    XCTAssertNil(content.blocks.block(holding: 4, of: self.highlight))
    XCTAssertNil(content.blocks.block(holding: -1, of: self.highlight))
  }

  func testImageAltTextIsNotCounted() {
    // An inline image draws no text, so its alt text holds no occurrence.
    XCTAssertEqual(1, MarkdownContent("A ![cafe](cup.png) and a cafe.").occurrences(of: self.highlight))
    XCTAssertEqual(0, MarkdownContent("![cafe](cup.png)").occurrences(of: self.highlight))
    XCTAssertEqual(1, MarkdownContent("[![cafe](cup.png)](https://cafe.example) cafe").occurrences(of: self.highlight))

    // The occurrence after the image is the block's first.
    let content = MarkdownContent("A ![cafe](cup.png) and a cafe.")
    XCTAssertEqual(content.blocks.block(holding: 0, of: self.highlight)?.occurrence, 0)
    XCTAssertNil(content.blocks.block(holding: 1, of: self.highlight))
  }

  func testLineBreakTagIsNotCounted() {
    let br = MarkdownHighlight(query: "br", background: .yellow, foreground: .black)!

    // `<br>` is drawn as a line break, so only the drawn "br" counts.
    XCTAssertEqual(1, MarkdownContent("cafe<br>br").occurrences(of: br))
    XCTAssertEqual(1, MarkdownContent("*cafe<br>br*").occurrences(of: br))
    // Another tag is drawn as its text: "<abbr>" and "</abbr>" both hold one.
    XCTAssertEqual(2, MarkdownContent("a <abbr>cafe</abbr>").occurrences(of: br))
  }

  func testWhitespaceDroppedAfterALineBreakIsNotCounted() {
    let spaced = MarkdownHighlight(query: " cafe", background: .yellow, foreground: .black)!

    // The renderer drops the whitespace after `<br>`, so " cafe" is not drawn there.
    XCTAssertEqual(0, MarkdownContent("tea<br> cafe").occurrences(of: spaced))
    XCTAssertEqual(1, MarkdownContent("tea cafe").occurrences(of: spaced))

    // A soft break is a space, or a line break in the line break mode.
    XCTAssertEqual(1, MarkdownContent("tea\ncafe").occurrences(of: spaced))
    XCTAssertEqual(0, MarkdownContent("tea\ncafe").occurrences(of: spaced, softBreakMode: .lineBreak))
  }

  func testImageSplitsTheCount() {
    // The text is highlighted on either side of an image apart, loaded or not, so an
    // occurrence across an image is not one.
    XCTAssertEqual(0, MarkdownContent("ca![](cup.png)fe").occurrences(of: self.highlight))
    XCTAssertEqual(
      ["A cafe ", " then cafe"],
      MarkdownContent("A cafe ![](cup.png) then cafe").blocks.first.flatMap {
        guard case .paragraph(let inlines) = $0 else { return nil }
        return inlines.highlightTexts(softBreakMode: .space)
      }
    )
  }

  func testMarkNumbersAcrossTheParts() {
    // given
    var highlight = MarkdownHighlight(
      query: "cafe", background: .yellow, foreground: .black, currentBackground: .orange
    )!
    highlight.current = 1

    // when: the text an image splits into two runs, highlighted one after the other
    let first = highlight.mark(AttributedString("A cafe "), firstOccurrence: 0)
    let second = highlight.mark(AttributedString(" then cafe and cafe"), firstOccurrence: first.count)

    // then: the current occurrence is the second of the block, the first of the second run
    XCTAssertEqual(1, first.count)
    XCTAssertNil(first.current)
    XCTAssertEqual(2, second.count)
    let current = try? XCTUnwrap(second.current)
    XCTAssertEqual(current.map { String(second.text[$0].characters) }, "cafe")
    XCTAssertEqual(current.map { second.text.characters.distance(from: second.text.startIndex, to: $0.lowerBound) }, 6)
  }

  func testApplyAfterWideCharacters() {
    // The occurrences are found in one walk, so each one's place has to survive the
    // characters before it: emoji, combining marks, and runs of other attributes.
    var attributedString = AttributedString("👍🏽 e\u{301}")
    attributedString.inlinePresentationIntent = .stronglyEmphasized
    attributedString += AttributedString(" Café 🇹🇷 cafe" + String(repeating: " ünïcode cafe", count: 200))

    let result = self.highlight.apply(to: attributedString)

    let marked = result.runs
      .filter { $0.backgroundColor == .yellow }
      .map { String(result[$0.range].characters) }
    XCTAssertEqual(["Café", "cafe"] + Array(repeating: "cafe", count: 200), marked)
    XCTAssertEqual(String(attributedString.characters), String(result.characters))
  }

  func testRangeOfOccurrence() {
    let text = "Cafe, cafe\nand café"
    XCTAssertEqual(self.highlight.range(ofOccurrence: 2, in: text).map { String(text[$0]) }, "café")
    XCTAssertNil(self.highlight.range(ofOccurrence: 3, in: text))
    XCTAssertNil(self.highlight.range(ofOccurrence: -1, in: text))
  }

  func testIdenticalBlocksAreToldApartByTheirPlace() {
    // given
    let owed = MarkdownHighlight(query: "owed", background: .yellow, foreground: .black)!
    let content = MarkdownContent(
      """
      # Debts

      - Owed: tests
      - Owed: tests

      > - Owed: tests
      """
    )

    // then: the same block three times, each its own leaf
    let targets = (0..<3).map { content.blocks.block(holding: $0, of: owed) }
    XCTAssertEqual(targets.map(\.?.leaf), [1, 2, 3])
    XCTAssertEqual(targets.map(\.?.occurrence), [0, 0, 0])
    XCTAssertEqual(targets[0]?.block, targets[1]?.block)
    XCTAssertEqual(4, content.blocks.reduce(0) { $0 + $1.highlightLeafCount })
  }

  func testTableCellsCountInRowOrder() {
    let content = MarkdownContent("| Cafe | x |\n| --- | --- |\n| cafe cafe | ![cafe](cup.png) |")
    guard case .table(_, let rows) = content.blocks.first else { return XCTFail("not a table") }
    XCTAssertEqual(
      rows.flatMap(\.cells).map { $0.highlightCount(of: self.highlight, softBreakMode: .space) },
      [1, 0, 2, 0]
    )
    XCTAssertEqual(3, content.occurrences(of: self.highlight))
  }
}
