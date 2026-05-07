import 'package:flutter/material.dart';
import 'package:flutter_highlight/flutter_highlight.dart';

typedef HighlightViewBuilder = Widget Function(double minWidth);

class AppHighlightView extends StatelessWidget {
  final String source;
  final String? language;
  final Map<String, TextStyle> theme;
  final EdgeInsetsGeometry? padding;
  final TextStyle? textStyle;
  final double minWidth;

  const AppHighlightView(
    this.source, {
    super.key,
    this.language,
    this.theme = const {},
    this.padding,
    this.textStyle,
    this.minWidth = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minWidth: minWidth),
      child: HighlightView(
        source,
        language: language,
        theme: theme,
        padding: padding,
        textStyle: textStyle,
      ),
    );
  }
}
