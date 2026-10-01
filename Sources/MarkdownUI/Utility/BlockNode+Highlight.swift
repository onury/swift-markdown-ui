import Foundation

extension Sequence where Element == BlockNode {
  /// The first leaf block, in document order, whose text contains an occurrence of the
  /// highlighted query.
  func firstBlock(matching highlight: MarkdownHighlight) -> BlockNode? {
    for block in self {
      switch block {
      case .paragraph(let content), .heading(_, let content):
        if highlight.matches(content.renderPlainText()) { return block }
      case .htmlBlock(let content), .codeBlock(_, let content):
        if highlight.matches(content) { return block }
      case .table(_, let rows):
        let cells = rows.lazy.flatMap(\.cells).map { $0.content.renderPlainText() }
        if cells.contains(where: highlight.matches) { return block }
      case .thematicBreak:
        continue
      case .blockquote, .bulletedList, .numberedList, .taskList:
        if let child = block.children.firstBlock(matching: highlight) { return child }
      }
    }
    return nil
  }
}
