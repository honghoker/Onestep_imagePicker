///
/// [Author] Alex (https://github.com/Alex525)
/// [Date] 2020/4/13 18:04
///
import 'package:flutter/material.dart';

/// Build [ImagePickerPageRoute] with the given generic type.
typedef AssetPickerPageRouteBuilder<T> = ImagePickerPageRoute<T> Function(
  Widget picker,
);

/// Built a slide page transition for the picker.
class ImagePickerPageRoute<T> extends PageRoute<T> {
  ImagePickerPageRoute({
    required this.builder,
    this.transitionCurve = Curves.easeIn,
    this.transitionDuration = const Duration(milliseconds: 250),
    this.barrierColor,
    this.barrierDismissible = false,
    this.barrierLabel,
    this.maintainState = true,
    this.opaque = true,
    this.canTransitionFromPredicate,
  });

  final WidgetBuilder builder;

  final Curve transitionCurve;
  @override
  final Duration transitionDuration;

  @override
  final Color? barrierColor;
  @override
  final bool barrierDismissible;
  @override
  final String? barrierLabel;
  @override
  final bool opaque;
  @override
  final bool maintainState;

  final bool Function(TransitionRoute<dynamic>)? canTransitionFromPredicate;

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      canTransitionFromPredicate?.call(previousRoute) ?? false;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(curve: transitionCurve, parent: animation),
      ),
      child: ClipRect(child: child), // Clip the overflowed part.
    );
  }
}
