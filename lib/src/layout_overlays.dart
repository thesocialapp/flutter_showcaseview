import 'package:flutter/material.dart';

import 'showcase_widget.dart';

class AnchoredOverlay extends StatelessWidget {
  final bool showOverlay;
  final Widget Function(BuildContext, Rect anchorBounds, Offset anchor)?
      overlayBuilder;
  final Widget? child;

  AnchoredOverlay({
    Key? key,
    this.showOverlay = false,
    this.overlayBuilder,
    this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return OverlayBuilder(
          showOverlay: showOverlay,
          overlayBuilder: (overlayContext) {
            final box = context.findRenderObject() as RenderBox;
            final topLeft =
                box.size.topLeft(box.localToGlobal(const Offset(0.0, 0.0)));
            final bottomRight =
                box.size.bottomRight(box.localToGlobal(const Offset(0.0, 0.0)));
            Rect anchorBounds;
            anchorBounds = (topLeft.dx.isNaN ||
                    topLeft.dy.isNaN ||
                    bottomRight.dx.isNaN ||
                    bottomRight.dy.isNaN)
                ? Rect.fromLTRB(0.0, 0.0, 0.0, 0.0)
                : Rect.fromLTRB(
                    topLeft.dx,
                    topLeft.dy,
                    bottomRight.dx,
                    bottomRight.dy,
                  );
            final anchorCenter = box.size.center(topLeft);
            return overlayBuilder!(overlayContext, anchorBounds, anchorCenter);
          },
          child: child,
        );
      },
    );
  }
}

class OverlayBuilder extends StatefulWidget {
  final bool showOverlay;
  final Widget Function(BuildContext)? overlayBuilder;
  final Widget? child;

  OverlayBuilder({
    Key? key,
    this.showOverlay = false,
    this.overlayBuilder,
    this.child,
  }) : super(key: key);

  @override
  _OverlayBuilderState createState() => _OverlayBuilderState();
}

class _OverlayBuilderState extends State<OverlayBuilder> {
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();

    if (widget.showOverlay) {
      WidgetsBinding.instance!.addPostFrameCallback((_) => showOverlay());
    }
  }

  @override
  void didUpdateWidget(OverlayBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance!
        .addPostFrameCallback((_) => syncWidgetAndOverlay());
  }

  @override
  void reassemble() {
    super.reassemble();
    WidgetsBinding.instance!
        .addPostFrameCallback((_) => syncWidgetAndOverlay());
  }

  @override
  void dispose() {
    if (isShowingOverlay()) {
      hideOverlay();
    }

    super.dispose();
  }

  bool isShowingOverlay() => _overlayEntry != null;

  void showOverlay() {
    if (_overlayEntry == null) {
      _overlayEntry = OverlayEntry(
        builder: widget.overlayBuilder!,
      );
      addToOverlay(_overlayEntry!);
    } else {
      buildOverlay();
    }
  }

  void addToOverlay(OverlayEntry overlayEntry) async {
    final showCaseContext = ShowCaseWidget.of(context).context;
    if (mounted) {
      if (Overlay.of(showCaseContext) != null) {
        Overlay.of(showCaseContext)!.insert(overlayEntry);
      } else {
        if (Overlay.of(context) != null) {
          Overlay.of(context)!.insert(overlayEntry);
        }
      }
    }
  }

  void hideOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
  }

  void syncWidgetAndOverlay() {
    if (isShowingOverlay() && !widget.showOverlay) {
      hideOverlay();
    } else if (!isShowingOverlay() && widget.showOverlay) {
      showOverlay();
    }
  }

  void buildOverlay() async {
    WidgetsBinding.instance!
        .addPostFrameCallback((_) => _overlayEntry?.markNeedsBuild());
  }

  @override
  Widget build(BuildContext context) {
    buildOverlay();

    return widget.child!;
  }
}
