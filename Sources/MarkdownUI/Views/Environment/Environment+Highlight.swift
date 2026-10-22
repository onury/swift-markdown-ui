import SwiftUI

/// A text highlight applied to every occurrence of a query in Markdown content.
///
/// Matching ignores case and diacritics, so `cafe` highlights `Café`. Use the
/// ``SwiftUI/View/markdownHighlight(_:background:foreground:)`` modifier to apply a highlight
/// to the Markdown views in a view hierarchy.
public struct MarkdownHighlight: Hashable {
  /// The text to highlight.
  public var query: String
  /// The background color of a highlighted occurrence.
  public var background: Color
  /// The foreground color of a highlighted occurrence.
  public var foreground: Color
  /// The background color of the current occurrence, the one a find has stepped to, or `nil`
  /// to draw it as the others.
  public var currentBackground: Color?
  /// The foreground color of the current occurrence, or `nil` to draw it as the others.
  public var currentForeground: Color?
  /// The occurrence drawn in the current colors, counted from zero in the text the highlight
  /// is applied to. Set by the block that holds the current occurrence; `nil` elsewhere.
  var current: Int?

  /// Creates a highlight, or returns `nil` when the query is empty.
  public init?(
    query: String,
    background: Color,
    foreground: Color,
    currentBackground: Color? = nil,
    currentForeground: Color? = nil
  ) {
    guard !query.isEmpty else { return nil }
    self.query = query
    self.background = background
    self.foreground = foreground
    self.currentBackground = currentBackground
    self.currentForeground = currentForeground
  }

  /// Returns the number of occurrences of the query in `text`, counted as they are
  /// highlighted: from the start, each one after the end of the one before.
  public func count<S: StringProtocol>(in text: S) -> Int {
    var count = 0
    var start = text.startIndex
    while start < text.endIndex, let range = text[start...].range(of: self.query, options: Self.options) {
      count += 1
      start = range.upperBound
    }
    return count
  }

  /// Returns whether `text` contains an occurrence of the query.
  public func matches<S: StringProtocol>(_ text: S) -> Bool {
    text.range(of: self.query, options: Self.options) != nil
  }

  /// Returns a copy of `attributedString` with every occurrence of the query highlighted.
  ///
  /// Custom code syntax highlighters can use this method to highlight the occurrences in
  /// the code blocks they style.
  public func apply(to attributedString: AttributedString) -> AttributedString {
    var result = attributedString
    var offsets: [(start: Int, count: Int)] = []
    var start = result.startIndex

    while start < result.endIndex,
      let range = result[start...].range(of: self.query, options: Self.options)
    {
      offsets.append(
        (
          result.characters.distance(from: result.startIndex, to: range.lowerBound),
          result.characters.distance(from: range.lowerBound, to: range.upperBound)
        )
      )
      start = range.upperBound
    }

    // Indices are recomputed after each change, as mutating an attributed string can
    // invalidate the indices taken before it.
    for (index, offset) in offsets.enumerated() {
      let lower = result.characters.index(result.startIndex, offsetBy: offset.start)
      let upper = result.characters.index(lower, offsetBy: offset.count)
      let isCurrent = index == self.current
      result[lower..<upper].backgroundColor =
        isCurrent ? (self.currentBackground ?? self.background) : self.background
      result[lower..<upper].foregroundColor =
        isCurrent ? (self.currentForeground ?? self.foreground) : self.foreground
    }

    return result
  }

  private static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
}

extension View {
  /// Highlights every occurrence of a query in the Markdown views in a view hierarchy.
  ///
  /// Occurrences are highlighted in paragraphs, headings, list items, table cells, and code
  /// blocks. Code blocks styled by a custom ``CodeSyntaxHighlighter`` are highlighted when it
  /// implements ``CodeSyntaxHighlighter/highlightCode(_:language:highlight:)``.
  ///
  /// - Parameters:
  ///   - query: The text to highlight, ignoring case and diacritics. Pass `nil` or an empty
  ///     string to remove the highlight.
  ///   - background: The background color of a highlighted occurrence.
  ///   - foreground: The foreground color of a highlighted occurrence.
  ///   - currentBackground: The background color of the occurrence the anchor names (see
  ///     ``SwiftUI/View/markdownHighlightAnchor(_:occurrence:)``), or `nil` to draw it as the
  ///     others.
  ///   - currentForeground: Its foreground color, or `nil` to draw it as the others.
  public func markdownHighlight(
    _ query: String?,
    background: Color,
    foreground: Color,
    currentBackground: Color? = nil,
    currentForeground: Color? = nil
  ) -> some View {
    self.environment(
      \.markdownHighlight,
      query.flatMap {
        MarkdownHighlight(
          query: $0, background: background, foreground: foreground,
          currentBackground: currentBackground, currentForeground: currentForeground)
      }
    )
  }

  /// Identifies the block that contains an occurrence of the highlighted query.
  ///
  /// The paragraph, heading, code block, or table — in document order, including those
  /// nested in lists and blockquotes — that contains the given occurrence of the query set
  /// with ``SwiftUI/View/markdownHighlight(_:background:foreground:currentBackground:currentForeground:)``
  /// carries `id` on its top edge, so that a `ScrollViewReader` can scroll to where it
  /// starts, and that occurrence is drawn in the highlight's current colors (in a table, the
  /// block is identified but no occurrence is drawn apart).
  ///
  /// - Parameters:
  ///   - id: The identifier of the block, or `nil` to identify none.
  ///   - occurrence: The occurrence, counted from zero across the content in document order;
  ///     the first by default.
  public func markdownHighlightAnchor<ID: Hashable>(_ id: ID?, occurrence: Int = 0) -> some View {
    self.environment(\.markdownHighlightAnchor, id.map(AnyHashable.init))
      .environment(\.markdownHighlightOccurrence, occurrence)
  }
}

extension EnvironmentValues {
  var markdownHighlight: MarkdownHighlight? {
    get { self[MarkdownHighlightKey.self] }
    set { self[MarkdownHighlightKey.self] = newValue }
  }

  var markdownHighlightAnchor: AnyHashable? {
    get { self[MarkdownHighlightAnchorKey.self] }
    set { self[MarkdownHighlightAnchorKey.self] = newValue }
  }

  var markdownHighlightOccurrence: Int {
    get { self[MarkdownHighlightOccurrenceKey.self] }
    set { self[MarkdownHighlightOccurrenceKey.self] = newValue }
  }

  var highlightedBlock: BlockNode? {
    get { self[HighlightedBlockKey.self] }
    set { self[HighlightedBlockKey.self] = newValue }
  }

  /// The occurrence within ``highlightedBlock`` that the anchor names.
  var highlightedBlockOccurrence: Int {
    get { self[HighlightedBlockOccurrenceKey.self] }
    set { self[HighlightedBlockOccurrenceKey.self] = newValue }
  }
}

private struct MarkdownHighlightOccurrenceKey: EnvironmentKey {
  static let defaultValue = 0
}

private struct HighlightedBlockOccurrenceKey: EnvironmentKey {
  static let defaultValue = 0
}

private struct MarkdownHighlightKey: EnvironmentKey {
  static let defaultValue: MarkdownHighlight? = nil
}

private struct MarkdownHighlightAnchorKey: EnvironmentKey {
  static let defaultValue: AnyHashable? = nil
}

private struct HighlightedBlockKey: EnvironmentKey {
  static let defaultValue: BlockNode? = nil
}
