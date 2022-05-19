import 'dart:math' as math;

import 'package:xml/xml.dart';

import '../utils/exception.dart';
import '../utils/svg.dart';
import 'element.dart';

/// SVG root element.
class Svg extends SvgElement {
  Svg(
    this.name,
    this.viewBox,
    this.elementList,
    XmlElement xmlElement,
    this.ratioX,
    this.ratioY,
    this.offset,
  ) : super(null, xmlElement);

  /// Parses SVG.
  ///
  /// If [ignoreShapes] is set to false, shapes (circle, rect, etc.) are converted into paths.
  /// Defaults to true.
  /// NOTE: Attributes like "fill" or "stroke" are ignored,
  /// which means only shape's outline will be used.
  ///
  /// Throws [XmlParserException] if XML parsing exception occurs.
  /// Throws [SvgParserException] on any problem related to SVG parsing.
  factory Svg.parse(String name, String xmlString, {bool? ignoreShapes}) {
    ignoreShapes ??= true;

    final xml = XmlDocument.parse(xmlString);
    final root = xml.rootElement;

    if (root.name.local != 'svg') {
      throw SvgParserException('Root element must be SVG');
    }

    final parsedVb = root
        .getAttribute('viewBox')
        ?.split(RegExp(r'[\s|,]'))
        .where((e) => e.isNotEmpty)
        .map(num.parse);
    final vb = [...?parsedVb];

    if (vb.isEmpty || vb.length > 4) {
      throw SvgParserException('viewBox must contain 1..4 parameters');
    }

    final fvb = [
      ...List.filled(4 - vb.length, 0),
      ...vb,
    ];

    final viewBox = math.Rectangle(fvb[0], fvb[1], fvb[2], fvb[3]);

    final parsedRatioX = double.parse(root.getAttribute('ratioX') ?? '1');
    final parsedRatioY = double.parse(root.getAttribute('ratioY') ?? '1');

    final parsedOffset = int.parse(root.getAttribute('offset') ?? '0');

    final svg =
        Svg(name, viewBox, [], root, parsedRatioX, parsedRatioY, parsedOffset);

    final elementList = root.parseSvgElements(svg, ignoreShapes);
    svg.elementList.addAll(elementList);

    return svg;
  }

  final String name;
  final math.Rectangle viewBox;
  final List<SvgElement> elementList;
  final double ratioX;
  final double ratioY;
  final int offset;

  @override
  String toString() => '$name (${elementList.length} elements)';
}
