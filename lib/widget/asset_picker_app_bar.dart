///
/// [Author] Alex (https://github.com/Alex525)
/// [Date] 2019-11-19 10:06
///
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

/// A custom app bar.
class AssetPickerAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AssetPickerAppBar({
    Key? key,
    this.automaticallyImplyLeading = true,
    this.automaticallyImplyActions = true,
    this.brightness,
    this.title,
    this.leading,
    this.bottom,
    this.centerTitle = true,
    this.backgroundColor,
    this.elevation = 0,
    this.actions,
    this.actionsPadding,
    this.height,
    this.blurRadius = 0,
    this.iconTheme,
    this.semanticsBuilder,
  }) : super(key: key);

  /// Title widget. Typically a [Text] widget.
  final Widget? title;

  /// Leading widget.
  final Widget? leading;

  /// Action widgets.
  final List<Widget>? actions;

  /// This widget appears across the bottom of the app bar.
  final PreferredSizeWidget? bottom;

  /// Padding for actions.
  final EdgeInsetsGeometry? actionsPadding;

  /// Whether it should imply leading with [BackButton] automatically.
  final bool automaticallyImplyLeading;

  /// Whether the [title] should be at the center of the [FixedAppBar].
  final bool centerTitle;

  /// Whether it should imply actions size with [effectiveHeight].
  final bool automaticallyImplyActions;

  /// Background color.
  final Color? backgroundColor;

  /// Height of the app bar.
  final double? height;

  /// Elevation to [Material].
  final double elevation;

  /// The blur radius applies on the bar.
  final double blurRadius;

  /// Set the brightness for the status bar's layer.
  final Brightness? brightness;

  final IconThemeData? iconTheme;

  final Semantics Function(Widget appBar)? semanticsBuilder;

  bool canPop(BuildContext context) =>
      Navigator.of(context).canPop() && automaticallyImplyLeading;

  double get _barHeight => height ?? kToolbarHeight;

  double get effectiveHeight =>
      _barHeight + (bottom?.preferredSize.height ?? 0);

  @override
  Size get preferredSize => Size.fromHeight(effectiveHeight);

  @override
  Widget build(BuildContext context) {
    Widget? _title = title;
    if (centerTitle) {
      _title = Center(child: _title);
    }
    Widget child = Container(
      width: double.maxFinite,
      height: _barHeight + MediaQuery.of(context).padding.top,
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
      child: Stack(
        children: <Widget>[
          if (canPop(context))
            PositionedDirectional(
              top: 0.0,
              bottom: 0.0,
              child: leading ?? const BackButton(),
            ),
          if (_title != null)
            PositionedDirectional(
              top: 0.0,
              bottom: 0.0,
              start: canPop(context) ? _barHeight : 0.0,
              end: automaticallyImplyActions ? _barHeight : 0.0,
              child: Align(
                alignment: centerTitle
                    ? Alignment.center
                    : AlignmentDirectional.centerStart,
                child: DefaultTextStyle(
                  child: _title,
                  style: Theme.of(context)
                      .textTheme
                      .headline6!
                      .copyWith(fontSize: 23.0),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          if (canPop(context) && (actions?.isEmpty ?? true))
            SizedBox(width: _barHeight)
          else if (actions?.isNotEmpty ?? false)
            PositionedDirectional(
              top: 0.0,
              end: 0.0,
              height: _barHeight,
              child: Padding(
                padding: actionsPadding ?? EdgeInsets.zero,
                child: Row(mainAxisSize: MainAxisSize.min, children: actions!),
              ),
            ),
        ],
      ),
    );

    // Allow custom blur radius using [ui.ImageFilter.blur].
    if (blurRadius > 0.0) {
      child = ClipRect(
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
          child: child,
        ),
      );
    }

    if (iconTheme != null) {
      child = IconTheme.merge(data: iconTheme!, child: child);
    }

    // Set [SystemUiOverlayStyle] according to the brightness.
    final Brightness _effectiveBrightness = brightness ??
        Theme.of(context).appBarTheme.systemOverlayStyle?.statusBarBrightness ??
        Theme.of(context).brightness;
    child = AnnotatedRegion<SystemUiOverlayStyle>(
      value: _effectiveBrightness == Brightness.dark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          child,
          if (bottom != null) bottom!,
        ],
      ),
    );

    final Widget _result = Material(
      // Wrap to ensure the child rendered correctly
      color: Color.lerp(
        backgroundColor ?? Theme.of(context).colorScheme.surface,
        Colors.transparent,
        blurRadius > 0.0 ? 0.1 : 0.0,
      ),
      elevation: elevation,
      child: child,
    );
    return semanticsBuilder?.call(_result) ??
        Semantics(sortKey: const OrdinalSortKey(0), child: _result);
  }
}

/// Wrapper for [AssetPickerAppBar]. Avoid elevation covered by body.
class AssetPickerAppBarWrapper extends StatelessWidget {
  const AssetPickerAppBarWrapper({
    Key? key,
    required this.appBar,
    required this.body,
  }) : super(key: key);

  final AssetPickerAppBar appBar;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            top: MediaQuery.of(context).padding.top +
                appBar.preferredSize.height,
            child: MediaQuery.removePadding(
              context: context,
              removeTop: true,
              child: body,
            ),
          ),
          Positioned.fill(bottom: null, child: appBar),
        ],
      ),
    );
  }
}
