import SwiftUI

/// A type that provides syntax highlighting to code blocks in a Markdown view.
///
/// To configure the current code syntax highlighter for a view hierarchy, use the
/// `markdownCodeSyntaxHighlighter(_:)` modifier.
public protocol CodeSyntaxHighlighter {
  /// Returns a text view configured with the syntax highlighted code.
  /// - Parameters:
  ///   - code: The code block.
  ///   - language: The language of the code block.
  func highlightCode(_ code: String, language: String?) -> Text

  /// Returns a text view configured with the syntax highlighted code, with every occurrence
  /// of a highlighted query marked.
  ///
  /// Called instead of ``highlightCode(_:language:)`` for a code block that contains an
  /// occurrence of the query set with the `markdownHighlight(_:background:foreground:)`
  /// modifier. Use ``MarkdownHighlight/apply(to:)`` to mark the occurrences. The default
  /// implementation returns the code unmarked.
  /// - Parameters:
  ///   - code: The code block.
  ///   - language: The language of the code block.
  ///   - highlight: The highlight to apply.
  func highlightCode(_ code: String, language: String?, highlight: MarkdownHighlight) -> Text
}

extension CodeSyntaxHighlighter {
  public func highlightCode(
    _ code: String,
    language: String?,
    highlight: MarkdownHighlight
  ) -> Text {
    self.highlightCode(code, language: language)
  }
}

/// A code syntax highlighter that returns unstyled code blocks.
public struct PlainTextCodeSyntaxHighlighter: CodeSyntaxHighlighter {
  /// Creates a plain text code syntax highlighter.
  public init() {}

  public func highlightCode(_ code: String, language: String?) -> Text {
    Text(code)
  }

  public func highlightCode(
    _ code: String,
    language: String?,
    highlight: MarkdownHighlight
  ) -> Text {
    Text(highlight.apply(to: AttributedString(code)))
  }
}

extension CodeSyntaxHighlighter where Self == PlainTextCodeSyntaxHighlighter {
  /// A code syntax highlighter that returns unstyled code blocks.
  public static var plainText: Self {
    PlainTextCodeSyntaxHighlighter()
  }
}
