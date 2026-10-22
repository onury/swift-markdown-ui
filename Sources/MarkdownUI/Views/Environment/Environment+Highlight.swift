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
    while start < text.endIndex,
      let range = text.range(of: self.query, options: Self.options, range: start..<text.endIndex),
      !range.isEmpty
    {
      count += 1
      start = range.upperBound
    }
    return count
  }

  /// The range of the given occurrence of the query in `text`, counted from zero.
  func range(ofOccurrence occurrence: Int, in text: String) -> Range<String.Index>? {
    guard occurrence >= 0 else { return nil }
    var remaining = occurrence
    var start = text.startIndex
    while start < text.endIndex,
      let range = text.range(of: self.query, options: Self.options, range: start..<text.endIndex),
      !range.isEmpty
    {
      if remaining == 0 { return range }
      remaining -= 1
      start = range.upperBound
    }
    return nil
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
    self.mark(attributedString).text
  }

  /// Highlights every occurrence of the query in `attributedString`, numbering them from
  /// `firstOccurrence`, so that a run highlighted in parts numbers its occurrences across
  /// the parts.
  func mark(_ attributedString: AttributedString, firstOccurrence: Int = 0) -> Marked {
    // One walk from the start: the string is searched from the end of the previous
    // occurrence, and the attributed string's index is moved on by the same distance.
    let string = String(attributedString.characters)
    var ranges: [Range<AttributedString.Index>] = []
    var start = string.startIndex
    var lower = attributedString.startIndex

    while start < string.endIndex,
      let range = string.range(of: self.query, options: Self.options, range: start..<string.endIndex),
      !range.isEmpty
    {
      let matchLower = attributedString.characters.index(
        lower, offsetBy: string.distance(from: start, to: range.lowerBound))
      let matchUpper = attributedString.characters.index(
        matchLower, offsetBy: string.distance(from: range.lowerBound, to: range.upperBound))
      ranges.append(matchLower..<matchUpper)
      start = range.upperBound
      lower = matchUpper
    }

    var result = attributedString
    var current: Range<AttributedString.Index>?
    var plain = AttributeContainer()
    plain.backgroundColor = self.background
    plain.foregroundColor = self.foreground
    var drawnApart = AttributeContainer()
    drawnApart.backgroundColor = self.currentBackground ?? self.background
    drawnApart.foregroundColor = self.currentForeground ?? self.foreground

    // Setting attributes leaves the characters, and so the indices taken above, as they are.
    for (index, range) in ranges.enumerated() {
      if firstOccurrence + index == self.current {
        result[range].mergeAttributes(drawnApart)
        current = range
      } else {
        result[range].mergeAttributes(plain)
      }
    }

    return Marked(text: result, current: current, count: ranges.count)
  }

  /// A highlighted run: its text, the range of the current occurrence when it holds it, and
  /// the number of occurrences in it.
  struct Marked {
    var text: AttributedString
    var current: Range<AttributedString.Index>?
    var count: Int

    /// The run as a text view, with the current occurrence marked by
    /// ``HighlightCurrentOccurrence``, so that its line can be found in the text's layout.
    var textView: Text {
      guard let current else { return Text(self.text) }
      guard #available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *) else { return Text(self.text) }
      return Text(AttributedString(self.text[..<current.lowerBound]))
        + Text(AttributedString(self.text[current])).customAttribute(HighlightCurrentOccurrence())
        + Text(AttributedString(self.text[current.upperBound...]))
    }
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
  /// carries `id` on the top edge of the line that holds the occurrence, so that a
  /// `ScrollViewReader` can scroll to it however tall the block, and that occurrence is drawn
  /// in the highlight's current colors. Before iOS 17 and macOS 14, `id` sits on the block's
  /// top edge.
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

  /// The ordinal, among the leaf blocks of a ``Markdown`` view in document order, of the leaf
  /// block that holds the occurrence the anchor names.
  var highlightedLeaf: Int? {
    get { self[HighlightedLeafKey.self] }
    set { self[HighlightedLeafKey.self] = newValue }
  }

  /// The ordinal of the first leaf block in the blocks below, which `BlockSequence` moves on
  /// for each block it lays out, so that a leaf block finds its own.
  var highlightLeafOrdinal: Int {
    get { self[HighlightLeafOrdinalKey.self] }
    set { self[HighlightLeafOrdinalKey.self] = newValue }
  }

  /// The occurrence within the highlighted leaf block that the anchor names.
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

private struct HighlightedLeafKey: EnvironmentKey {
  static let defaultValue: Int? = nil
}

private struct HighlightLeafOrdinalKey: EnvironmentKey {
  static let defaultValue = 0
}

/// Marks the current occurrence in a text view, so that its line can be found in the text's
/// layout.
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
struct HighlightCurrentOccurrence: TextAttribute {}
