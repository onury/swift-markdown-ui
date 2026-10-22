import SwiftUI

@available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *)
struct TableView: View {
  @Environment(\.theme.table) private var table
  @Environment(\.tableBorderStyle.strokeStyle.lineWidth) private var borderWidth
  @Environment(\.markdownHighlight) private var highlight
  @Environment(\.softBreakMode) private var softBreakMode

  private let columnAlignments: [RawTableColumnAlignment]
  private let rows: [RawTableRow]

  init(columnAlignments: [RawTableColumnAlignment], rows: [RawTableRow]) {
    self.columnAlignments = columnAlignments
    self.rows = rows
  }

  var body: some View {
    self.table.makeBody(
      configuration: .init(
        label: .init(self.label),
        content: .init(block: .table(columnAlignments: self.columnAlignments, rows: self.rows))
      )
    )
  }

  private var label: some View {
    let occurrencesBefore = self.occurrencesBeforeEachCell
    return Grid(horizontalSpacing: self.borderWidth, verticalSpacing: self.borderWidth) {
      ForEach(0..<self.rowCount, id: \.self) { row in
        GridRow {
          ForEach(0..<self.columnCount, id: \.self) { column in
            TableCell(row: row, column: column, cell: self.rows[row].cells[column])
              .transformEnvironment(\.markdownHighlight) { highlight in
                // Each cell is highlighted apart, so the current occurrence, numbered
                // across the table, is numbered within the cell.
                guard let occurrencesBefore, let current = highlight?.current else { return }
                highlight?.current = current - occurrencesBefore[row][column]
              }
              .gridColumnAlignment(.init(self.columnAlignments[column]))
          }
        }
      }
    }
    .padding(self.borderWidth)
    .tableDecoration(
      rowCount: self.rowCount,
      columnCount: self.columnCount,
      background: TableBackgroundView.init,
      overlay: TableBorderView.init
    )
  }

  /// The number of occurrences of the highlighted query in the cells before each cell, in
  /// row order; worked out only in the table that holds the current occurrence.
  private var occurrencesBeforeEachCell: [[Int]]? {
    guard let highlight = self.highlight, highlight.current != nil else { return nil }
    var total = 0
    return self.rows.map { row in
      row.cells.map { cell in
        let before = total
        total += cell.highlightCount(of: highlight, softBreakMode: self.softBreakMode)
        return before
      }
    }
  }

  private var rowCount: Int {
    self.rows.count
  }

  private var columnCount: Int {
    self.columnAlignments.count
  }
}

extension HorizontalAlignment {
  fileprivate init(_ rawTableColumnAlignment: RawTableColumnAlignment) {
    switch rawTableColumnAlignment {
    case .none, .left:
      self = .leading
    case .center:
      self = .center
    case .right:
      self = .trailing
    }
  }
}
