/*
 * Copyright (c) 2021 Simform Solutions
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'actions_container_config.dart';
import 'get_position.dart';

enum TooltipHorizontalAxis { left, right, center }

enum TooltipVerticalPosition { up, down }

class ToolTipWidget extends StatefulWidget {
  final GetPosition? position;
  final Offset? offset;
  final Size screenSize;
  final String? title;
  final String? description;
  final TextStyle? titleTextStyle;
  final TextStyle? descTextStyle;
  final Widget? container;
  final Color? tooltipColor;
  final Color? textColor;
  final bool showArrow;
  final VoidCallback? onTooltipTap;
  final EdgeInsets? contentPadding;
  final Widget? actions;
  final Duration animationDuration;
  final bool disableAnimation;
  final Rect rect;
  final Size arrowSize;
  final ActionsSettings? actionSettings;

  static final _screenTooltipOffset = 14.0;

  /// Defines a common minimum size of all the tooltips.
  static final _minimumTooltipSize = Size.square(40);

  ToolTipWidget({
    Key? key,
    required this.position,
    required this.offset,
    required this.screenSize,
    required this.title,
    required this.description,
    required this.titleTextStyle,
    required this.descTextStyle,
    required this.container,
    required this.tooltipColor,
    required this.textColor,
    required this.showArrow,
    required this.onTooltipTap,
    required this.animationDuration,
    this.contentPadding = const EdgeInsets.symmetric(vertical: 8),
    required this.disableAnimation,
    this.actions,
    required this.rect,
    required this.arrowSize,
    this.actionSettings,
  }) : super(key: key);

  @override
  _ToolTipWidgetState createState() => _ToolTipWidgetState();
}

class _ToolTipWidgetState extends State<ToolTipWidget>
    with SingleTickerProviderStateMixin {
  _TooltipCoordinates? _coords;
  final GlobalKey titleKey = GlobalKey();
  final GlobalKey descriptionKey = GlobalKey();

  late final AnimationController _parentController;
  late final Animation<Offset> _tweenedAnimation;

  Size? _screenSize;

  bool isArrowUp = false;

  void _getPosition() {
    //
    //
    // Get required parameters.
    //
    //

    final screenSize = _screenSize!;

    // Offset that defines how far tooltip will be placed above or
    // below showcase widget.
    final tooltipOffset = Offset(0, 15);

    // Defines position and size of showcase widget.
    final showcaseRect = widget.rect;

    // Calculate maximum bottom position tooltip can have.
    final maximumAllowedBottomPosition =
        screenSize.height - ToolTipWidget._screenTooltipOffset;

    // Calculate minimum top position tooltip can have.
    final minimumAllowedTopPosition = ToolTipWidget._screenTooltipOffset;

    // Calculate minimum left position tooltip can have.
    final minimumAllowedLeftPosition = ToolTipWidget._screenTooltipOffset;

    // Calculate minimum right position tooltip can have.
    final maximumAllowedRightPosition =
        screenSize.width - ToolTipWidget._screenTooltipOffset;

    // Calculate maximum width tooltip can have.
    final maxTooltipWidth =
        screenSize.width - (2 * ToolTipWidget._screenTooltipOffset);

    // Calculate maximum height tooltip can have.
    final maxTooltipHeight =
        screenSize.height - (2 * ToolTipWidget._screenTooltipOffset);

    // gets the center of the showcase widget.
    var showcaseCenter = showcaseRect.center;

    //
    //
    // Calculate tooltip size.
    //
    //

    // Get tooltip size.
    var tooltipSize = (context.findRenderObject() as RenderBox).size;

    // Update size of tooltip based on defined constraints.
    tooltipSize = Size(
      tooltipSize.width.clamp(
        ToolTipWidget._minimumTooltipSize.width,
        maxTooltipWidth,
      ),
      tooltipSize.height.clamp(
        ToolTipWidget._minimumTooltipSize.height,
        maxTooltipHeight,
      ),
    );

    //
    //
    // Calculate top and bottom position of tooltip.
    //
    //
    //

    // Place tooltip at bottom position by default and calculate
    // top & bottom value.
    var verticalAxis = TooltipVerticalPosition.down;

    // Calculate possible top position of tooltip.
    var topPosition = showcaseRect.bottom + tooltipOffset.dy;

    // Calculate possible bottom position of tooltip.
    var bottomPosition =
        topPosition + widget.arrowSize.height + tooltipSize.height;

    // True if bottom position is greater then allowed bottom position.
    var isBottomOverflowing = bottomPosition > maximumAllowedBottomPosition;

    // True if space above showcase widget is more than below.
    //
    // If above has move space then below then we should display tooltip
    // above showcase widget, else we should display it below showcase widget.
    //
    var shouldPlaceAbove = (screenSize.height -
            showcaseRect.bottom -
            ToolTipWidget._screenTooltipOffset) <=
        (showcaseRect.top - ToolTipWidget._screenTooltipOffset);

    // If bottom position is larger than screen height
    // and there is not enough space above showcase widget to place tooltip.
    //
    // Trim bottom position to maximum allowed bottom position.
    if (isBottomOverflowing && !shouldPlaceAbove) {
      bottomPosition = maximumAllowedBottomPosition;

      // If bottom position is larger than screen height
      // and there is enough space above showcase widget to place tooltip.
      //
      // Change tooltip position to above and recalculate top and bottom.
    } else if (isBottomOverflowing && shouldPlaceAbove) {
      verticalAxis = TooltipVerticalPosition.up;

      topPosition = math.max(
          showcaseRect.top - tooltipSize.height - tooltipOffset.dy,
          minimumAllowedTopPosition);

      bottomPosition = showcaseRect.top - tooltipOffset.dy;
    }

    //
    //
    // Calculate left and right position of tooltip.
    //
    //
    //

    // By default place tooltip at the center of the showcase widget.
    // Calculate possible left position of showcase.
    var leftPosition = showcaseCenter.dx - tooltipSize.width / 2;

    // Calculate possible right position of showcase.
    var rightPosition = leftPosition + tooltipSize.width;

    // If left position is less then minimum allowed position,
    // then change left and right position accordingly.
    if (leftPosition < minimumAllowedLeftPosition) {
      // cache old value of left.
      final oldLeft = leftPosition;

      // If left position of showcase widget is less then minimum
      // allowed position, then align tooltip with left position of showcase
      // widget else set left position to minimum allowed position.
      leftPosition = showcaseRect.left < minimumAllowedLeftPosition &&
              showcaseRect.left >= 0
          ? showcaseRect.left
          : minimumAllowedLeftPosition;

      // Change right position to cover offset added by changing left position.
      rightPosition += leftPosition - oldLeft;
    }

    // If right position is greater than maximum allowed position,
    // change left and right accordingly.
    if (rightPosition > maximumAllowedRightPosition) {
      // cache old value of right.
      final oldRight = rightPosition;

      // If right position of showcase widget is greater then maximum
      // allowed position, then align tooltip with right position of showcase
      // widget else set right position to maximum allowed position.
      rightPosition = showcaseRect.right > maximumAllowedRightPosition &&
              showcaseRect.right <= screenSize.width
          ? showcaseRect.right
          : maximumAllowedRightPosition;

      // Recalculate left to cover offset added by changing right position.
      leftPosition = leftPosition - (oldRight - rightPosition);

      // IF left is less then zero,
      if (leftPosition < 0) {
        // If left position of showcase widget is less then minimum
        // allowed position, then align tooltip with left position of showcase
        // widget else set left position to minimum allowed position.
        leftPosition = showcaseRect.left > 0 &&
                showcaseRect.left < minimumAllowedLeftPosition
            ? showcaseRect.left
            : minimumAllowedLeftPosition;
      }
    }

    final tooltipRect =
        Rect.fromLTRB(leftPosition, topPosition, rightPosition, bottomPosition);

    //
    //
    // Calculate position of arrow.
    //
    //

    var horizontalAxis = TooltipHorizontalAxis.center;

    if (showcaseCenter.dx < (tooltipRect.left + tooltipRect.width / 3)) {
      horizontalAxis = TooltipHorizontalAxis.left;
    } else if (showcaseCenter.dx >
        (tooltipRect.left + (tooltipRect.width * 2 / 3))) {
      horizontalAxis = TooltipHorizontalAxis.right;
    }

    // Get the left position arrow can have.
    final scLeft = horizontalAxis == TooltipHorizontalAxis.right
        ? showcaseCenter.dx + (widget.arrowSize.width / 2)
        : showcaseCenter.dx - (widget.arrowSize.width / 2);

    // convert above position to alignment.
    final arrowLeft = 2 * ((scLeft - tooltipRect.left) / tooltipRect.width) - 1;

    final newCoords = _TooltipCoordinates(
      // area: Offset(left, top) & showcaseSize,
      area: tooltipRect,
      horizontalAxis: horizontalAxis,
      verticalAxis: verticalAxis,
      arrowAlignment: Alignment(arrowLeft, 0),
    );

    /// Call set state only if widget is mounted and newly calculated data
    /// differs from older one. This will be useful in web when user resize
    /// window. That will call build method and when window is resized every
    /// time coords will have different values and will trigger rebuild.
    ///
    /// In short it will trigger rebuild only on first build after application
    /// run/resize.
    if (mounted) {
      setState(() {
        /// Assign calculated coordinates to [_coords] that will
        /// be reflected on UI.
        _coords = newCoords;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _parentController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _parentController.reverse();
        }
        if (_parentController.isDismissed) {
          if (!widget.disableAnimation) {
            _parentController.forward();
          }
        }
      });

    // As of now we are giving static offset of 10 pixels for animation.
    _tweenedAnimation =
        Tween<Offset>(begin: Offset(0.0, 0.0), end: Offset(0.0, 10))
            .animate(CurvedAnimation(
      parent: _parentController,
      curve: Curves.easeInOut,
    ));

    if (!widget.disableAnimation) {
      _parentController.forward();
    }
  }

  @override
  void dispose() {
    _parentController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final newScreenSize = MediaQuery.of(context).size;
    final resized = _screenSize != newScreenSize;

    _screenSize = newScreenSize;
    // This will register callback on every build/rebuild.
    WidgetsBinding.instance!.addPostFrameCallback((_) => _getPosition());

    final verticalDirection = _coords?.isArrowUp ?? true
        ? VerticalDirection.down
        : VerticalDirection.up;

    late final BoxConstraints boxConstraints;

    final shouldChangeConstraints = _coords == null || resized;

    boxConstraints = shouldChangeConstraints
        ? BoxConstraints()
        : BoxConstraints(
            maxWidth: _coords!.area.width,
            maxHeight: _coords!.area.height,
          );

    final offset = _tweenedAnimation.value;

    return Positioned(
      top: _coords?.area.top ?? 0,
      left: _coords?.area.left ?? 0,
      child: Opacity(
        opacity: _coords == null ? 0 : 1,
        child: Transform.translate(
          offset: offset,
          child: Material(
            color: Colors.transparent,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              verticalDirection: verticalDirection,
              children: [
                if (widget.showArrow)
                  SizedBox(
                    width: _coords?.area.width ?? 0,
                    child: Transform.translate(
                      offset: Offset(
                          0,
                          _coords?.verticalAxis == TooltipVerticalPosition.up
                              ? -1
                              : 1),
                      child: Align(
                        alignment: _coords?.arrowAlignment ?? Alignment.center,
                        child: CustomPaint(
                          size: widget.arrowSize,
                          painter: _Arrow(
                            strokeColor: widget.tooltipColor!,
                            strokeWidth: 10,
                            paintingStyle: PaintingStyle.fill,
                            isUpArrow: _coords != null && _coords!.isArrowUp,
                          ),
                          child: SizedBox.fromSize(
                            size: widget.arrowSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ConstrainedBox(
                  constraints: boxConstraints,
                  child: widget.container == null
                      ? GestureDetector(
                          onTap: widget.onTooltipTap,
                          child: Container(
                            clipBehavior: Clip.hardEdge,
                            decoration: BoxDecoration(
                              color: widget.tooltipColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment:
                                  _coords?.horizontalAxis.crossAxisAlignment ??
                                      CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Padding(
                                  padding:
                                      widget.contentPadding ?? EdgeInsets.zero,
                                  child: Column(
                                    crossAxisAlignment: _coords?.horizontalAxis
                                            .crossAxisAlignment ??
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      if (widget.title != null)
                                        Text(
                                          widget.title!,
                                          key: titleKey,
                                          textAlign: _coords
                                                  ?.horizontalAxis.textAlign ??
                                              TextAlign.start,
                                          style: widget.titleTextStyle ??
                                              Theme.of(context)
                                                  .textTheme
                                                  .headline6
                                                  ?.merge(
                                                    TextStyle(
                                                      color: widget.textColor,
                                                    ),
                                                  ),
                                        ),
                                      if (widget.description != null)
                                        Text(
                                          widget.description!,
                                          key: descriptionKey,
                                          textAlign: _coords
                                                  ?.horizontalAxis.textAlign ??
                                              TextAlign.start,
                                          style: widget.descTextStyle ??
                                              Theme.of(context)
                                                  .textTheme
                                                  .subtitle2
                                                  ?.merge(
                                                    TextStyle(
                                                      color: widget.textColor,
                                                    ),
                                                  ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (widget.actions != null)
                                  Padding(
                                    padding: widget
                                            .actionSettings?.containerPadding ??
                                        EdgeInsets.zero,
                                    child: Container(
                                      color:
                                          widget.actionSettings?.containerColor,
                                      height: widget
                                          .actionSettings?.containerHeight,
                                      width: _getButtonsContainerWidth(
                                          titleKey,
                                          descriptionKey,
                                          widget.actionSettings?.containerWidth,
                                          widget.contentPadding),
                                      child: widget.actions!,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment:
                              _coords?.horizontalAxis.crossAxisAlignment ??
                                  CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            widget.container!,
                            if (widget.actions != null)
                              Padding(
                                padding:
                                    widget.actionSettings?.containerPadding ??
                                        EdgeInsets.zero,
                                child: widget.actions!,
                              ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double _getButtonsContainerWidth(
    GlobalKey? titleKey,
    GlobalKey? descriptionKey,
    double? buttonWidth,
    EdgeInsets? contentPadding,
  ) {
    final defaultWidth = widget.screenSize.width - 20;

    if (buttonWidth != null) {
      return buttonWidth;
    } else if (titleKey?.currentContext != null ||
        descriptionKey?.currentContext != null) {
      final titleWidth = titleKey?.currentContext != null
          ? (titleKey?.currentContext?.findRenderObject() as RenderBox)
              .size
              .width
          : 0.0;
      final descriptionWidth = descriptionKey?.currentContext != null
          ? (descriptionKey?.currentContext?.findRenderObject() as RenderBox)
              .size
              .width
          : 0.0;
      final addExtraPadding = contentPadding!.left + contentPadding.right;

      if (titleWidth < defaultWidth && descriptionWidth < defaultWidth) {
        return defaultWidth;
      } else if (titleWidth > descriptionWidth) {
        return titleWidth + addExtraPadding;
      } else {
        return descriptionWidth + addExtraPadding;
      }
    }
    return defaultWidth;
  }
}

class _Arrow extends CustomPainter {
  final Color strokeColor;
  final PaintingStyle paintingStyle;
  final double strokeWidth;
  final bool isUpArrow;

  _Arrow(
      {this.strokeColor = Colors.black,
      this.strokeWidth = 3,
      this.paintingStyle = PaintingStyle.stroke,
      this.isUpArrow = true});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..style = paintingStyle;

    canvas.drawPath(getTrianglePath(size.width, size.height), paint);
  }

  Path getTrianglePath(double x, double y) {
    if (isUpArrow) {
      return Path()
        ..moveTo(0, y)
        ..lineTo(x / 2, 0)
        ..lineTo(x, y)
        ..lineTo(0, y);
    } else {
      return Path()
        ..moveTo(0, 0)
        ..lineTo(x, 0)
        ..lineTo(x / 2, y)
        ..lineTo(0, 0);
    }
  }

  @override
  bool shouldRepaint(_Arrow oldDelegate) {
    return oldDelegate.strokeColor != strokeColor ||
        oldDelegate.paintingStyle != paintingStyle ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

// Keep this to avoid 'avoid_equals_and_hash_code_on_mutable_classes' warning.
@immutable
class _TooltipCoordinates {
  final Rect area;
  final TooltipHorizontalAxis horizontalAxis;
  final TooltipVerticalPosition verticalAxis;
  final Alignment arrowAlignment;

  const _TooltipCoordinates({
    required this.area,
    required this.horizontalAxis,
    required this.verticalAxis,
    required this.arrowAlignment,
  });

  bool get isArrowUp => verticalAxis == TooltipVerticalPosition.down;

  bool get isArrowLeft => horizontalAxis == TooltipHorizontalAxis.right;

  bool get isArrowCenter => horizontalAxis == TooltipHorizontalAxis.center;

  @override
  bool operator ==(Object other) =>
      other is _TooltipCoordinates &&
      area == other.area &&
      horizontalAxis == other.horizontalAxis &&
      verticalAxis == other.verticalAxis &&
      arrowAlignment == other.arrowAlignment;

  @override
  int get hashCode => super.hashCode;
}

extension AlignmentExtension on TooltipHorizontalAxis {
  TextAlign get textAlign {
    switch (this) {
      case TooltipHorizontalAxis.left:
        return TextAlign.start;
      case TooltipHorizontalAxis.right:
        return TextAlign.start;
      case TooltipHorizontalAxis.center:
        return TextAlign.center;
      default:
        return TextAlign.justify;
    }
  }

  CrossAxisAlignment get crossAxisAlignment {
    switch (this) {
      case TooltipHorizontalAxis.left:
        return CrossAxisAlignment.start;
      case TooltipHorizontalAxis.right:
        return CrossAxisAlignment.start;
      case TooltipHorizontalAxis.center:
        return CrossAxisAlignment.center;
      default:
        return CrossAxisAlignment.stretch;
    }
  }
}
