import 'dart:ui' show Tristate;

import 'package:flutter/rendering.dart';

/// A kind of text exposed by the live app semantics tree.
enum VisibleTextKind {
  /// Ordinary visible text without a tap action.
  text,

  /// Text on a control with a tap action.
  button,

  /// A text field with its current value and available labels.
  textField;

  /// The wire spelling for this kind.
  String get wireName => switch (this) {
    text => 'text',
    button => 'button',
    textField => 'text_field',
  };
}

/// A visible text item and its app-view bounds.
final class VisibleTextEntry {
  /// Creates an entry from a global logical [rect] and app-view [view].
  factory VisibleTextEntry({
    required String text,
    required VisibleTextKind kind,
    required bool enabled,
    required Rect rect,
    required Rect view,
    String? label,
    String? hint,
    String? value,
  }) {
    final visibleRect = rect.intersect(view);
    return VisibleTextEntry._(
      text: text,
      kind: kind,
      enabled: enabled,
      rect: visibleRect,
      bounds: <double>[
        (visibleRect.left - view.left) / view.width,
        (visibleRect.top - view.top) / view.height,
        (visibleRect.right - view.left) / view.width,
        (visibleRect.bottom - view.top) / view.height,
      ],
      label: label,
      hint: hint,
      value: value,
    );
  }

  const VisibleTextEntry._({
    required this.text,
    required this.kind,
    required this.enabled,
    required this.rect,
    required this.bounds,
    this.label,
    this.hint,
    this.value,
  });

  /// The text shown by this item.
  final String text;

  /// Whether the item is ordinary text or an interactive control.
  final VisibleTextKind kind;

  /// Whether the control is enabled according to semantics.
  final bool enabled;

  /// The visible bounds in global logical coordinates.
  final Rect rect;

  /// The visible bounds as left, top, right and bottom app-view fractions.
  final List<double> bounds;

  /// The text field label, when [kind] is [VisibleTextKind.textField].
  final String? label;

  /// The text field hint, when [kind] is [VisibleTextKind.textField].
  final String? hint;

  /// The text field value, when [kind] is [VisibleTextKind.textField].
  final String? value;

  /// Encodes this entry in the live text reply shape.
  Map<String, Object> toJson() => {
    'text': text,
    'kind': kind.wireName,
    'enabled': enabled,
    'bounds': bounds,
    if (label != null && label!.isNotEmpty) 'label': label!,
    if (hint != null && hint!.isNotEmpty) 'hint': hint!,
    if (value != null && value!.isNotEmpty) 'value': value!,
  };
}

/// Reads visible text from the app view's Flutter semantics tree.
final class VisibleTextReader {
  /// Creates a reader for Flutter's current semantics tree.
  const VisibleTextReader();

  /// Reads entries in top-to-bottom, then left-to-right order.
  List<VisibleTextEntry> read(Rect view, {required double devicePixelRatio}) {
    if (!_hasValidViewport(view, devicePixelRatio)) return const [];

    final root = _findRoot(view, devicePixelRatio);
    if (root == null) return const [];

    final entries = <VisibleTextEntry>[];
    _visitNode(root, Matrix4.identity(), view, devicePixelRatio, entries);
    return _readingOrder(entries);
  }

  void _visitNode(
    SemanticsNode node,
    Matrix4 parentTransform,
    Rect view,
    double devicePixelRatio,
    List<VisibleTextEntry> entries,
  ) {
    if (node.isInvisible) return;

    final transform = Matrix4.copy(parentTransform);
    if (node.transform case final nodeTransform?) {
      transform.multiply(nodeTransform);
    }
    final entry = _entryForNode(node, transform, view, devicePixelRatio);
    if (entry != null) entries.add(entry);

    if (!node.mergeAllDescendantsIntoThisNode) {
      node.visitChildren((child) {
        _visitNode(child, transform, view, devicePixelRatio, entries);
        return true;
      });
    }
  }

  VisibleTextEntry? _entryForNode(
    SemanticsNode node,
    Matrix4 transform,
    Rect view,
    double devicePixelRatio,
  ) {
    final data = node.getSemanticsData();
    if (data.flagsCollection.isHidden) return null;

    final physicalRect = MatrixUtils.transformRect(transform, node.rect);
    final rect = Rect.fromLTRB(
      physicalRect.left / devicePixelRatio,
      physicalRect.top / devicePixelRatio,
      physicalRect.right / devicePixelRatio,
      physicalRect.bottom / devicePixelRatio,
    );
    if (!rect.overlaps(view)) return null;

    return _entryForVisibleData(data, rect, view);
  }

  VisibleTextEntry? _entryForVisibleData(
    SemanticsData data,
    Rect rect,
    Rect view,
  ) {
    final isTextField = data.flagsCollection.isTextField;
    final label = data.label;
    final value = data.value;
    final text = _visibleText(isTextField, label, value);
    if (text.isEmpty && !isTextField) return null;

    return VisibleTextEntry(
      text: text,
      kind: _visibleTextKind(data, isTextField),
      enabled: data.flagsCollection.isEnabled != Tristate.isFalse,
      rect: rect,
      view: view,
      label: isTextField ? label : null,
      hint: isTextField ? data.hint : null,
      value: isTextField ? value : null,
    );
  }

  String _visibleText(bool isTextField, String label, String value) =>
      isTextField && value.isNotEmpty ? value : label;

  VisibleTextKind _visibleTextKind(SemanticsData data, bool isTextField) {
    if (isTextField) return VisibleTextKind.textField;
    if (data.hasAction(SemanticsAction.tap)) return VisibleTextKind.button;
    return VisibleTextKind.text;
  }

  bool _hasValidViewport(Rect view, double devicePixelRatio) =>
      !view.isEmpty &&
      view.isFinite &&
      devicePixelRatio.isFinite &&
      devicePixelRatio > 0;

  SemanticsNode? _findRoot(Rect view, double devicePixelRatio) {
    SemanticsNode? bestRoot;
    var bestIntersection = 0.0;
    for (final renderView in RendererBinding.instance.renderViews) {
      final root = renderView.owner?.semanticsOwner?.rootSemanticsNode;
      if (root == null) continue;

      final transform = root.transform == null
          ? Matrix4.identity()
          : Matrix4.copy(root.transform!);
      final physicalRect = MatrixUtils.transformRect(transform, root.rect);
      final rootRect = Rect.fromLTRB(
        physicalRect.left / devicePixelRatio,
        physicalRect.top / devicePixelRatio,
        physicalRect.right / devicePixelRatio,
        physicalRect.bottom / devicePixelRatio,
      );
      final intersection = rootRect.intersect(view);
      final area = intersection.width * intersection.height;
      if (area > bestIntersection) {
        bestRoot = root;
        bestIntersection = area;
      }
    }
    return bestRoot;
  }

  List<VisibleTextEntry> _readingOrder(List<VisibleTextEntry> entries) {
    entries.sort((left, right) => left.rect.top.compareTo(right.rect.top));
    final rows = <List<VisibleTextEntry>>[];
    for (final entry in entries) {
      List<VisibleTextEntry>? row;
      for (final candidate in rows) {
        if (_sharesRow(candidate.first, entry)) {
          row = candidate;
          break;
        }
      }
      if (row == null) {
        rows.add([entry]);
      } else {
        row.add(entry);
      }
    }

    rows.sort(
      (left, right) => left.first.rect.top.compareTo(right.first.rect.top),
    );
    for (final row in rows) {
      _sortLeftToRight(row);
    }
    return rows.expand((row) => row).toList();
  }

  bool _sharesRow(VisibleTextEntry left, VisibleTextEntry right) {
    final tolerance = left.rect.height < right.rect.height
        ? left.rect.height
        : right.rect.height;
    return (left.rect.center.dy - right.rect.center.dy).abs() <= tolerance / 2;
  }

  void _sortLeftToRight(List<VisibleTextEntry> row) {
    row.sort((left, right) => left.rect.left.compareTo(right.rect.left));
  }
}
