import SwiftUI

struct BlockSequence<Data, Content>: View
where
  Data: Sequence,
  Data.Element: Hashable,
  Content: View
{
  @Environment(\.multilineTextAlignment) private var textAlignment
  @Environment(\.tightSpacingEnabled) private var tightSpacingEnabled
  @Environment(\.highlightedLeaf) private var highlightedLeaf

  @State private var blockMargins: [Int: BlockMargin] = [:]

  private let data: [Indexed<Data.Element>]
  private let content: (Int, Data.Element) -> Content

  init(
    _ data: Data,
    @ViewBuilder content: @escaping (_ index: Int, _ element: Data.Element) -> Content
  ) {
    self.data = data.indexed()
    self.content = content
  }

  var body: some View {
    let leafOffsets = self.highlightLeafOffsets
    VStack(alignment: self.textAlignment.alignment.horizontal, spacing: 0) {
      ForEach(self.data, id: \.self) { element in
        self.content(element.index, element.value)
          .transformEnvironment(\.highlightLeafOrdinal) { ordinal in
            if let leafOffsets { ordinal += leafOffsets[element.index] }
          }
          .onPreferenceChange(BlockMarginsPreference.self) { value in
            self.blockMargins[element.hashValue] = value
          }
          .padding(.top, self.topPaddingLength(for: element))
      }
    }
  }

  /// The number of leaf blocks before each element, so that a highlighted leaf block can
  /// tell itself from an identical one; worked out only while a highlight anchor names one.
  private var highlightLeafOffsets: [Int]? {
    guard self.highlightedLeaf != nil else { return nil }
    var offsets: [Int] = []
    var total = 0
    for element in self.data {
      offsets.append(total)
      total += (element.value as? HighlightLeaves)?.highlightLeafCount ?? 0
    }
    return offsets
  }

  private func topPaddingLength(for element: Indexed<Data.Element>) -> CGFloat? {
    guard element.index > 0 else {
      return 0
    }

    let topSpacing = self.blockMargins[element.hashValue]?.top
    let predecessor = self.data[element.index - 1]
    let predecessorBottomSpacing =
      self.tightSpacingEnabled ? 0 : self.blockMargins[predecessor.hashValue]?.bottom

    return [topSpacing, predecessorBottomSpacing]
      .compactMap { $0 }
      .max()
  }
}

extension BlockSequence where Data == [BlockNode], Content == BlockNode {
  init(_ blocks: [BlockNode]) {
    self.init(blocks) { $1 }
  }
}

extension TextAlignment {
  fileprivate var alignment: Alignment {
    switch self {
    case .leading:
      return .leading
    case .center:
      return .center
    case .trailing:
      return .trailing
    }
  }
}
