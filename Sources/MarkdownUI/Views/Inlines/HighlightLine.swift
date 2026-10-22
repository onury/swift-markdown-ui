import SwiftUI

/// The top of the line that holds the current occurrence, reported by the text view that
/// draws it, so that the highlighted block puts its anchor on that line. One per text view
/// holding the current occurrence, which is one at most.
struct HighlightCurrentLineKey: PreferenceKey {
  static let defaultValue: [Anchor<CGPoint>] = []

  static func reduce(value: inout [Anchor<CGPoint>], nextValue: () -> [Anchor<CGPoint>]) {
    value += nextValue()
  }
}

/// The bounds of the marker that carries a highlight anchor's id, one per marker.
struct HighlightAnchorMarkerKey: PreferenceKey {
  static let defaultValue: [Anchor<CGRect>] = []

  static func reduce(value: inout [Anchor<CGRect>], nextValue: () -> [Anchor<CGRect>]) {
    value += nextValue()
  }
}

/// How a text view finds the line of the current occurrence in its layout.
enum HighlightLineLocator: Equatable {
  /// The run marked with ``HighlightCurrentOccurrence``, in text the inline renderer drew.
  case marked
  /// The character at a UTF-16 offset, in text drawn by someone else (a code syntax
  /// highlighter): `offset` within the paragraph numbered `paragraph`, `absolute` within
  /// the whole text.
  case character(paragraph: Int, offset: Int, absolute: Int)

  /// The locator of the current occurrence of `highlight` in plain `text`, or `nil` when
  /// the highlight has none there.
  init?(occurrenceOf highlight: MarkdownHighlight, in text: String) {
    guard let current = highlight.current,
      let range = highlight.range(ofOccurrence: current, in: text)
    else { return nil }
    let before = text[..<range.lowerBound]
    let paragraphStart = before.lastIndex(of: "\n").map { text.index(after: $0) } ?? text.startIndex
    self = .character(
      paragraph: before.unicodeScalars.reduce(0) { $1 == "\n" ? $0 + 1 : $0 },
      offset: text.utf16.distance(from: paragraphStart, to: range.lowerBound),
      absolute: text.utf16.distance(from: text.startIndex, to: range.lowerBound)
    )
  }
}

extension View {
  /// Reports the top of the line that holds the current occurrence, when `locator` names
  /// one and the text layout can be read (iOS 17, macOS 14 and later).
  @ViewBuilder func reportingHighlightLine(_ locator: HighlightLineLocator?) -> some View {
    if let locator {
      if #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) {
        self.modifier(HighlightLineReporter(locator: locator))
      } else {
        self
      }
    } else {
      self
    }
  }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
private struct HighlightLineReporter: ViewModifier {
  let locator: HighlightLineLocator

  func body(content: Content) -> some View {
    content.backgroundPreferenceValue(Text.LayoutKey.self) { layouts in
      GeometryReader { proxy in
        if let top = self.lineTop(in: layouts, proxy: proxy) {
          Color.clear
            .frame(width: 0, height: 0)
            .anchorPreference(key: HighlightCurrentLineKey.self, value: .top) { [$0] }
            .padding(.top, top)
        }
      }
    }
  }

  private func lineTop(in layouts: Text.LayoutKey.Value, proxy: GeometryProxy) -> CGFloat? {
    for anchored in layouts {
      if let top = self.locator.lineTop(in: anchored.layout) {
        return proxy[anchored.origin].y + top
      }
    }
    return nil
  }
}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension HighlightLineLocator {
  /// The top of the line that holds the current occurrence, in the layout's coordinates.
  func lineTop(in layout: Text.Layout) -> CGFloat? {
    switch self {
    case .marked:
      return layout.first { line in
        line.contains { $0[HighlightCurrentOccurrence.self] != nil }
      }?.typographicBounds.rect.minY
    case .character(let paragraph, let offset, let absolute):
      return Self.lineTop(in: layout, paragraph: paragraph, offset: offset, absolute: absolute)
    }
  }

  /// The layout numbers characters from the start of each paragraph (an empty paragraph
  /// is a line of no runs), so the line is found by its paragraph and its offset in it. A
  /// layout that numbers them across the whole text is read by the absolute offset.
  private static func lineTop(
    in layout: Text.Layout,
    paragraph: Int,
    offset: Int,
    absolute: Int
  ) -> CGFloat? {
    let lines = layout.map { line in
      (top: line.typographicBounds.rect.minY, indices: line.flatMap(\.characterIndices))
    }
    guard let zero = lines.lazy.compactMap(\.indices.first).first else { return nil }
    let restartsPerParagraph = lines.dropFirst().contains { $0.indices.first == zero }

    if !restartsPerParagraph {
      let target = zero.advanced(by: absolute)
      return lines.first { $0.indices.contains { $0 >= target } }?.top
    }

    let target = zero.advanced(by: offset)
    var number = -1
    for line in lines {
      if line.indices.first.map({ $0 == zero }) ?? true {
        number += 1
      }
      if number == paragraph, line.indices.contains(where: { $0 >= target }) {
        return line.top
      }
      if number > paragraph { return nil }
    }
    return nil
  }
}
