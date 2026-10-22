import SwiftUI

extension BlockNode: View {
  var body: some View {
    self.content.modifier(HighlightAnchorModifier(block: self))
  }

  @ViewBuilder private var content: some View {
    switch self {
    case .blockquote(let children):
      BlockquoteView(children: children)
    case .bulletedList(let isTight, let items):
      BulletedListView(isTight: isTight, items: items)
    case .numberedList(let isTight, let start, let items):
      NumberedListView(isTight: isTight, start: start, items: items)
    case .taskList(let isTight, let items):
      TaskListView(isTight: isTight, items: items)
    case .codeBlock(let fenceInfo, let content):
      CodeBlockView(fenceInfo: fenceInfo, content: content)
    case .htmlBlock(let content):
      ParagraphView(content: content)
    case .paragraph(let content):
      ParagraphView(content: content)
    case .heading(let level, let content):
      HeadingView(level: level, content: content)
    case .table(let columnAlignments, let rows):
      if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
        TableView(columnAlignments: columnAlignments, rows: rows)
      }
    case .thematicBreak:
      ThematicBreakView()
    }
  }
}

private struct HighlightAnchorModifier: ViewModifier {
  @Environment(\.highlightedLeaf) private var highlightedLeaf
  @Environment(\.highlightLeafOrdinal) private var leafOrdinal
  @Environment(\.highlightedBlockOccurrence) private var highlightedOccurrence
  @Environment(\.markdownHighlightAnchor) private var highlightAnchor
  @Environment(\.markdownHighlight) private var highlight

  let block: BlockNode

  /// Whether this is the leaf block that holds the anchored occurrence: told by its place
  /// among the leaf blocks, so that an identical block elsewhere is not taken for it.
  private var isHighlighted: Bool {
    self.highlightAnchor != nil && self.block.isHighlightLeaf
      && self.highlightedLeaf == self.leafOrdinal
  }

  /// The highlight with the anchored occurrence drawn apart, in the block that holds it. A
  /// table applies the highlight once per cell, where the number would name an occurrence
  /// in every cell, so a table keeps the plain highlight.
  private var blockHighlight: MarkdownHighlight? {
    guard self.isHighlighted, var highlight = self.highlight else { return self.highlight }
    if case .table = self.block { return highlight }
    highlight.current = self.highlightedOccurrence
    return highlight
  }

  func body(content: Content) -> some View {
    // A marker of no height on the top edge of the line that holds the occurrence, as the
    // text view drawing it reports it, so that a scroll anchor names that line however
    // tall the block; on the block's top edge when no line is reported.
    content
      .environment(\.markdownHighlight, self.blockHighlight)
      .backgroundPreferenceValue(HighlightCurrentLineKey.self) { lines in
        if let highlightAnchor, self.isHighlighted {
          GeometryReader { proxy in
            Color.clear
              .frame(height: 0)
              .id(highlightAnchor)
              .anchorPreference(key: HighlightAnchorMarkerKey.self, value: .bounds) { [$0] }
              .padding(.top, lines.first.map { max(0, proxy[$0].y) } ?? 0)
          }
        }
      }
  }
}
