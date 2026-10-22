#if os(macOS)
  import SwiftUI
  import XCTest

  @testable import MarkdownUI

  /// Lays out highlighted Markdown in a hosting view, never shown on screen, and reads where
  /// the highlight anchor's marker lands.
  @MainActor
  final class MarkdownHighlightLayoutTests: XCTestCase {
    private let width: CGFloat = 320

    func testIdenticalBlocksCarryOneAnchor() throws {
      // given
      let markdown = "- Owed: tests\n- Owed: tests"
      let owed = MarkdownHighlight(query: "owed", background: .yellow, foreground: .black)!

      // when
      let first = self.layout(markdown, highlight: owed, occurrence: 0)
      let second = self.layout(markdown, highlight: owed, occurrence: 1)

      // then: one marker each time, on the item named
      XCTAssertEqual(1, first.markers.count)
      XCTAssertEqual(1, second.markers.count)
      let firstTop = try XCTUnwrap(first.markers.first?.minY)
      let secondTop = try XCTUnwrap(second.markers.first?.minY)
      XCTAssertGreaterThan(secondTop, firstTop + 8)
    }

    // MARK: - Layout

    private struct Layout {
      var markers: [CGRect] = []
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
      let hosting = NSHostingView(rootView: AnyView(root))
      hosting.frame = CGRect(x: 0, y: 0, width: self.width, height: 20_000)
      return Host(view: hosting, recorder: recorder)
    }
  }
#endif
