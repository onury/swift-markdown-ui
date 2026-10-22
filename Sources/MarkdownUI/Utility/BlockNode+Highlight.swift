import Foundation

extension Sequence where Element == BlockNode {
  /// The first leaf block, in document order, whose text contains an occurrence of the
  /// highlighted query.
  func firstBlock(matching highlight: MarkdownHighlight) -> BlockNode? {
    self.block(holding: 0, of: highlight)?.block
  }

  /// The number of occurrences of the highlighted query in the leaf blocks, counted as they
  /// are highlighted.
  func occurrences(of highlight: MarkdownHighlight) -> Int {
    self.reduce(0) { count, block in
      switch block {
      case .blockquote, .bulletedList, .numberedList, .taskList:
        return count + block.children.occurrences(of: highlight)
      default:
        return count + block.highlightTexts.reduce(0) { $0 + highlight.count(in: $1) }
      }
    }
  }

  /// The leaf block, in document order, that holds the given occurrence of the highlighted
  /// query, and the occurrence's number within that block, both counted from zero.
  func block(holding occurrence: Int, of highlight: MarkdownHighlight) -> (block: BlockNode, occurrence: Int)? {
    var remaining = occurrence
    return self.block(holding: &remaining, of: highlight)
  }

  private func block(
    holding remaining: inout Int, of highlight: MarkdownHighlight
  ) -> (block: BlockNode, occurrence: Int)? {
    guard remaining >= 0 else { return nil }
    for block in self {
      switch block {
      case .blockquote, .bulletedList, .numberedList, .taskList:
        if let found = block.children.block(holding: &remaining, of: highlight) { return found }
      default:
        let count = block.highlightTexts.reduce(0) { $0 + highlight.count(in: $1) }
        if remaining < count { return (block, remaining) }
        remaining -= count
      }
    }
    return nil
  }
}

extension BlockNode {
  /// The text a highlight is applied to in a leaf block, one string per run it is applied
  /// to separately: a paragraph's or heading's text, a code block's, each table cell's.
  fileprivate var highlightTexts: [String] {
    switch self {
    case .paragraph(let content), .heading(_, let content):
      return [content.renderPlainText()]
    case .htmlBlock(let content), .codeBlock(_, let content):
      return [content]
    case .table(_, let rows):
      return rows.flatMap(\.cells).map { $0.content.renderPlainText() }
    case .thematicBreak, .blockquote, .bulletedList, .numberedList, .taskList:
      return []
    }
  }
}

extension MarkdownContent {
  /// Returns the number of occurrences of the highlighted query in this content, counted as
  /// a ``Markdown`` view highlights them, so that an occurrence can be named to
  /// ``SwiftUI/View/markdownHighlightAnchor(_:occurrence:)`` by its number.
  public func occurrences(of highlight: MarkdownHighlight) -> Int {
    self.blocks.occurrences(of: highlight)
  }
}
