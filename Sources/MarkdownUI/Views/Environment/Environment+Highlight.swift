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

  /// Creates a highlight, or returns `nil` when the query is empty.
  public init?(query: String, background: Color, foreground: Color) {
    guard !query.isEmpty else { return nil }
    self.query = query
    self.background = background
    self.foreground = foreground
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
    for offset in offsets {
      let lower = result.characters.index(result.startIndex, offsetBy: offset.start)
      let upper = result.characters.index(lower, offsetBy: offset.count)
      result[lower..<upper].backgroundColor = self.background
      result[lower..<upper].foregroundColor = self.foreground
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
  public func markdownHighlight(
    _ query: String?,
    background: Color,
    foreground: Color
  ) -> some View {
    self.environment(
      \.markdownHighlight,
      query.flatMap { MarkdownHighlight(query: $0, background: background, foreground: foreground) }
    )
  }

  /// Identifies the first block that contains the highlighted query.
  ///
  /// The first paragraph, heading, code block, or table — in document order, including those
  /// nested in lists and blockquotes — that contains an occurrence of the query set with
  /// ``SwiftUI/View/markdownHighlight(_:background:foreground:)`` carries `id` on its top
  /// edge, so that a `ScrollViewReader` can scroll to where it starts.
  ///
  /// - Parameter id: The identifier of the block, or `nil` to identify none.
  public func markdownHighlightAnchor<ID: Hashable>(_ id: ID?) -> some View {
    self.environment(\.markdownHighlightAnchor, id.map(AnyHashable.init))
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

  var highlightedBlock: BlockNode? {
    get { self[HighlightedBlockKey.self] }
    set { self[HighlightedBlockKey.self] = newValue }
  }
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
