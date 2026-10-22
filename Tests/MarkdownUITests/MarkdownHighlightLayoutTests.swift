#if os(macOS)
  import SwiftUI
  import XCTest

  @testable import MarkdownUI

  /// Lays out highlighted Markdown in a hosting view, never shown on screen, and reads where
  /// the highlight anchor's marker lands and which lines report the current occurrence.
  @MainActor
  final class MarkdownHighlightLayoutTests: XCTestCase {
    private let width: CGFloat = 320

    /// A paragraph of many lines with "cafe" at its start and its end.
    private let tallParagraph =
      "A cafe opens. " + String(repeating: "Tea is poured and the room fills slowly. ", count: 60)
      + "The last cafe closes."

    func testAnchorMarksTheLineOfALaterOccurrence() throws {
      // given
      let markdown = "# Menu\n\n" + self.tallParagraph

      // when
      let first = try XCTUnwrap(self.layout(markdown, occurrence: 0).markers.first)
      let last = try XCTUnwrap(self.layout(markdown, occurrence: 1).markers.first)
      let height = self.layout(markdown, occurrence: 1).height

      // then: the first sits on the paragraph's first line, the last on its last line, far
      // below the block's top
      XCTAssertGreaterThan(height, 500)
      XCTAssertGreaterThan(last.minY - first.minY, height - 100)
      XCTAssertLessThan(last.minY, height)
    }

    func testAnchorMarksTheLineInATallListItem() throws {
      // given
      let markdown = "- Short\n- " + self.tallParagraph

      // when
      let first = try XCTUnwrap(self.layout(markdown, occurrence: 0).markers.first)
      let result = self.layout(markdown, occurrence: 1)
      let last = try XCTUnwrap(result.markers.first)

      // then
      XCTAssertEqual(1, result.markers.count)
      XCTAssertEqual(1, result.currentLines)
      XCTAssertGreaterThan(last.minY - first.minY, result.height - 100)
    }

    func testAnchorMarksTheLineInATallCodeBlock() throws {
      // given
      let lines = (0..<80).map { $0 == 3 || $0 == 70 ? "let cafe = \($0)" : "let tea = \($0)" }
      let markdown = "Code:\n\n```\n" + lines.joined(separator: "\n") + "\n\n\nlet cafe = 99\n```"

      // when
      let third = try XCTUnwrap(self.layout(markdown, occurrence: 0).markers.first)
      let seventieth = try XCTUnwrap(self.layout(markdown, occurrence: 1).markers.first)
      let result = self.layout(markdown, occurrence: 2)
      let last = try XCTUnwrap(result.markers.first)

      // then: the lines are evenly spaced, so the marks are as far apart as the lines
      let lineHeight = (seventieth.minY - third.minY) / 67
      XCTAssertGreaterThan(lineHeight, 8)
      XCTAssertEqual(last.minY - seventieth.minY, lineHeight * 12, accuracy: 2)
      XCTAssertEqual(1, result.currentLines)
    }

    func testIdenticalBlocksCarryOneAnchor() throws {
      // given
      let markdown = "- Owed: tests\n- Owed: tests"
      let owed = MarkdownHighlight(query: "owed", background: .yellow, foreground: .black)!

      // when
      let first = self.layout(markdown, highlight: owed, occurrence: 0)
      let second = self.layout(markdown, highlight: owed, occurrence: 1)

      // then: one marker and one current occurrence each time, on the item named
      XCTAssertEqual(1, first.markers.count)
      XCTAssertEqual(1, second.markers.count)
      XCTAssertEqual(1, first.currentLines)
      XCTAssertEqual(1, second.currentLines)
      let firstTop = try XCTUnwrap(first.markers.first?.minY)
      let secondTop = try XCTUnwrap(second.markers.first?.minY)
      XCTAssertGreaterThan(secondTop, firstTop + 8)
    }

    // MARK: - Layout

    private struct Layout {
      var markers: [CGRect] = []
      var currentLines = 0
      var height: CGFloat = 0
    }

    private final class Recorder {
      var layout = Layout()
    }

    private func layout(
      _ markdown: String,
      highlight: MarkdownHighlight? = nil,
      occurrence: Int
    ) -> Layout {
      let host = self.host(markdown, highlight: highlight, occurrence: occurrence)
      host.layout()
      return host.recorder.layout
    }

    private struct Host {
      let view: NSHostingView<AnyView>
      let recorder: Recorder

      func layout() {
        self.view.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        self.view.layoutSubtreeIfNeeded()
      }
    }

    private func host(
      _ markdown: String,
      highlight: MarkdownHighlight?,
      occurrence: Int
    ) -> Host {
      let highlight =
        highlight
        ?? MarkdownHighlight(query: "cafe", background: .yellow, foreground: .black)!
      let recorder = Recorder()
      let view = AnyView(
        Markdown(markdown)
          .markdownHighlight(
            highlight.query, background: .yellow, foreground: .black, currentBackground: .orange)
          .markdownHighlightAnchor("match", occurrence: occurrence)
      )
      let root = view
        .frame(width: self.width)
        .fixedSize(horizontal: false, vertical: true)
        .overlayPreferenceValue(HighlightAnchorMarkerKey.self) { markers in
          GeometryReader { proxy in
            let _ = recorder.layout.markers = markers.map { proxy[$0] }
            let _ = recorder.layout.height = proxy.size.height
            Color.clear
          }
        }
        .overlayPreferenceValue(HighlightCurrentLineKey.self) { lines in
          let _ = recorder.layout.currentLines = lines.count
          Color.clear
        }
      let hosting = NSHostingView(rootView: AnyView(root))
      hosting.frame = CGRect(x: 0, y: 0, width: self.width, height: 20_000)
      return Host(view: hosting, recorder: recorder)
    }
  }
#endif
