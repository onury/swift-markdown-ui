import Foundation

/// The leaf block a highlight anchor names: its ordinal among the leaf blocks in document
/// order, the block, and the occurrence's number within it, both counted from zero.
struct HighlightTarget: Equatable {
  let leaf: Int
  let block: BlockNode
  let occurrence: Int
}

extension Sequence where Element == BlockNode {
  /// The first leaf block, in document order, whose text contains an occurrence of the
  /// highlighted query.
  func firstBlock(matching highlight: MarkdownHighlight) -> BlockNode? {
    self.block(holding: 0, of: highlight)?.block
  }

  /// The number of occurrences of the highlighted query in the leaf blocks, counted as they
  /// are highlighted.
  func occurrences(of highlight: MarkdownHighlight) -> Int {
    var count = 0
    _ = self.visitLeaves { block in
      count += block.highlightCount(of: highlight)
      return false
    }
    return count
  }

  /// The leaf block, in document order, that holds the given occurrence of the highlighted
  /// query.
  func block(holding occurrence: Int, of highlight: MarkdownHighlight) -> HighlightTarget? {
    guard occurrence >= 0 else { return nil }
    var remaining = occurrence
    var leaf = 0
    var target: HighlightTarget?
    _ = self.visitLeaves { block in
      let count = block.highlightCount(of: highlight)
      if remaining < count {
        target = HighlightTarget(leaf: leaf, block: block, occurrence: remaining)
        return true
      }
      remaining -= count
      leaf += 1
      return false
    }
    return target
  }

  /// Visits the leaf blocks in document order until `visit` returns `true`, and returns
  /// whether it did.
  fileprivate func visitLeaves(_ visit: (BlockNode) -> Bool) -> Bool {
    for block in self {
      if block.isHighlightLeaf {
        if visit(block) { return true }
      } else if block.children.visitLeaves(visit) {
        return true
      }
    }
    return false
  }

  fileprivate var highlightLeafCount: Int {
    self.reduce(0) { $0 + $1.highlightLeafCount }
  }
}

/// A value whose leaf blocks a highlight anchor counts, so that `BlockSequence` can hand
/// each block the ordinal of its first leaf.
protocol HighlightLeaves {
  var highlightLeafCount: Int { get }
}

extension BlockNode: HighlightLeaves {
  /// Whether the block holds text of its own rather than other blocks.
  var isHighlightLeaf: Bool {
    switch self {
    case .blockquote, .bulletedList, .numberedList, .taskList:
      return false
    default:
      return true
    }
  }

  var highlightLeafCount: Int {
    self.isHighlightLeaf ? 1 : self.children.highlightLeafCount
  }

  /// The number of occurrences of the highlighted query in a leaf block.
  fileprivate func highlightCount(of highlight: MarkdownHighlight) -> Int {
    self.highlightTexts.reduce(0) { $0 + highlight.count(in: $1) }
  }

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

extension RawListItem: HighlightLeaves {
  var highlightLeafCount: Int { self.children.highlightLeafCount }
}

extension RawTaskListItem: HighlightLeaves {
  var highlightLeafCount: Int { self.children.highlightLeafCount }
}

extension MarkdownContent {
  /// Returns the number of occurrences of the highlighted query in this content, counted as
  /// a ``Markdown`` view highlights them, so that an occurrence can be named to
  /// ``SwiftUI/View/markdownHighlightAnchor(_:occurrence:)`` by its number.
  public func occurrences(of highlight: MarkdownHighlight) -> Int {
    self.blocks.occurrences(of: highlight)
  }
}
