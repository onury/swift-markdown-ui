import SwiftUI

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
  /// are drawn.
  func occurrences(of highlight: MarkdownHighlight, softBreakMode: SoftBreak.Mode = .space) -> Int {
    var count = 0
    _ = self.visitLeaves { block in
      count += block.highlightCount(of: highlight, softBreakMode: softBreakMode)
      return false
    }
    return count
  }

  /// The leaf block, in document order, that holds the given occurrence of the highlighted
  /// query.
  func block(
    holding occurrence: Int,
    of highlight: MarkdownHighlight,
    softBreakMode: SoftBreak.Mode = .space
  ) -> HighlightTarget? {
    guard occurrence >= 0 else { return nil }
    var remaining = occurrence
    var leaf = 0
    var target: HighlightTarget?
    _ = self.visitLeaves { block in
      let count = block.highlightCount(of: highlight, softBreakMode: softBreakMode)
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

  /// The number of occurrences of the highlighted query in a leaf block, counted as drawn.
  func highlightCount(of highlight: MarkdownHighlight, softBreakMode: SoftBreak.Mode) -> Int {
    self.highlightTexts(softBreakMode: softBreakMode).reduce(0) { $0 + highlight.count(in: $1) }
  }

  /// The text a highlight is applied to in a leaf block, one string per run it is applied
  /// to separately: a paragraph's or heading's text between its images, a code block's,
  /// each table cell's.
  fileprivate func highlightTexts(softBreakMode: SoftBreak.Mode) -> [String] {
    switch self {
    case .paragraph(let content):
      return content.paragraphHighlightTexts(softBreakMode: softBreakMode)
    case .heading(_, let content):
      return content.highlightTexts(softBreakMode: softBreakMode)
    case .htmlBlock(let content):
      // Drawn as a paragraph of its text, as `ParagraphView` draws it.
      return [InlineNode.text(content.droppingTrailingNewline)]
        .paragraphHighlightTexts(softBreakMode: softBreakMode)
    case .codeBlock(_, let content):
      return [content.droppingTrailingNewline]
    case .table(_, let rows):
      return rows.flatMap(\.cells).flatMap {
        $0.content.cellHighlightTexts(softBreakMode: softBreakMode)
      }
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

extension RawTableCell {
  /// The number of occurrences of the highlighted query in a table cell, counted as drawn.
  func highlightCount(of highlight: MarkdownHighlight, softBreakMode: SoftBreak.Mode) -> Int {
    self.content.cellHighlightTexts(softBreakMode: softBreakMode).reduce(0) {
      $0 + highlight.count(in: $1)
    }
  }
}

extension Array where Element == InlineNode {
  /// A paragraph's text as drawn: none when `ParagraphView` draws it as an image.
  fileprivate func paragraphHighlightTexts(softBreakMode: SoftBreak.Mode) -> [String] {
    if self.count == 1, self.first?.imageData != nil { return [] }
    return self.cellHighlightTexts(softBreakMode: softBreakMode)
  }

  /// A table cell's text as drawn: none when `TableCell` draws it as a flow of images.
  fileprivate func cellHighlightTexts(softBreakMode: SoftBreak.Mode) -> [String] {
    if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *), ImageFlow(self) != nil {
      return []
    }
    return self.highlightTexts(softBreakMode: softBreakMode)
  }
}

extension Sequence where Element == InlineNode {
  /// The text the inline renderer draws for these inlines, split where it draws an image:
  /// the runs it highlights one after another. Mirrors `TextInlineRenderer` and the
  /// attributed string renderer it hands each inline to, so that an occurrence is counted
  /// only where it is drawn: an image's alt text is not drawn, `<br>` is drawn as a line
  /// break, and the whitespace after a line break is dropped.
  func highlightTexts(softBreakMode: SoftBreak.Mode) -> [String] {
    var texts: [String] = []
    var text = ""
    var shouldSkipNextWhitespace = false

    for inline in self {
      switch inline {
      case .text(let content):
        text += shouldSkipNextWhitespace ? content.droppingLeadingWhitespace : content
        shouldSkipNextWhitespace = false
      case .softBreak:
        switch softBreakMode {
        case .space where shouldSkipNextWhitespace:
          shouldSkipNextWhitespace = false
        case .space:
          text += " "
        case .lineBreak:
          shouldSkipNextWhitespace = true
          text += "\n"
        }
      case .html(let content) where content.isLineBreakTag:
        text += "\n"
        shouldSkipNextWhitespace = true
      case .image:
        texts.append(text)
        text = ""
      default:
        var renderer = HighlightTextRenderer(softBreakMode: softBreakMode)
        renderer.render(inline)
        text += renderer.result
      }
    }

    texts.append(text)
    return texts
  }
}

/// The text the attributed string renderer draws for one inline, starting from the state
/// it starts each inline with.
private struct HighlightTextRenderer {
  var result = ""
  private let softBreakMode: SoftBreak.Mode
  private var shouldSkipNextWhitespace = false

  init(softBreakMode: SoftBreak.Mode) {
    self.softBreakMode = softBreakMode
  }

  mutating func render(_ inline: InlineNode) {
    switch inline {
    case .text(let content):
      self.renderText(content)
    case .softBreak:
      switch self.softBreakMode {
      case .space where self.shouldSkipNextWhitespace:
        self.shouldSkipNextWhitespace = false
      case .space:
        self.result += " "
      case .lineBreak:
        self.result += "\n"
      }
    case .lineBreak:
      self.result += "\n"
    case .code(let content):
      self.result += content
    case .html(let content) where content.isLineBreakTag:
      self.result += "\n"
      self.shouldSkipNextWhitespace = true
    case .html(let content):
      self.renderText(content)
    case .emphasis(let children), .strong(let children), .strikethrough(let children),
      .link(_, let children):
      for child in children {
        self.render(child)
      }
    case .image:
      break
    }
  }

  private mutating func renderText(_ text: String) {
    self.result += self.shouldSkipNextWhitespace ? text.droppingLeadingWhitespace : text
    self.shouldSkipNextWhitespace = false
  }
}

extension String {
  fileprivate var droppingTrailingNewline: String {
    self.hasSuffix("\n") ? String(self.dropLast()) : self
  }

  /// The string without its leading whitespace, as the renderers drop it after a break.
  fileprivate var droppingLeadingWhitespace: String {
    self.replacingOccurrences(of: "^\\s+", with: "", options: .regularExpression)
  }

  fileprivate var isLineBreakTag: Bool {
    HTMLTag(self)?.name.lowercased() == "br"
  }
}

extension MarkdownContent {
  /// Returns the number of occurrences of the highlighted query in this content, counted as
  /// a ``Markdown`` view draws them, so that an occurrence can be named to
  /// ``SwiftUI/View/markdownHighlightAnchor(_:occurrence:)`` by its number.
  ///
  /// - Parameters:
  ///   - highlight: The highlight whose query to count.
  ///   - softBreakMode: The soft break mode the view draws with (see
  ///     ``SwiftUI/View/markdownSoftBreakMode(_:)``); `space`, a view's default, when omitted.
  public func occurrences(
    of highlight: MarkdownHighlight,
    softBreakMode: SoftBreak.Mode = .space
  ) -> Int {
    self.blocks.occurrences(of: highlight, softBreakMode: softBreakMode)
  }
}
