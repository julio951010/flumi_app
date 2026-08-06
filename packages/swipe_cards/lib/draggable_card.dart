import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

enum SlideDirection { left, right, up }

enum SlideRegion { inNopeRegion, inLikeRegion, inSuperLikeRegion }

class DraggableCard extends StatefulWidget {
  final Widget? card;
  final Widget? likeTag;
  final Widget? nopeTag;
  final Widget? superLikeTag;
  final Widget? likeGradient;
  final Widget? nopeGradient;
  final Widget? superLikeGradient;
  final bool isDraggable;
  final SlideDirection? slideTo;
  final Function(double distance)? onSlideUpdate;
  final Function(SlideRegion? slideRegion)? onSlideRegionUpdate;
  final Function(SlideDirection? direction)? onSlideOutComplete;
  final bool upSwipeAllowed;
  final bool leftSwipeAllowed;
  final bool rightSwipeAllowed;
  final EdgeInsets padding;
  final bool isBackCard;

  DraggableCard(
      {this.card,
      this.likeTag,
      this.nopeTag,
      this.superLikeTag,
      this.likeGradient,
      this.nopeGradient,
      this.superLikeGradient,
      this.isDraggable = true,
      this.onSlideUpdate,
      this.onSlideOutComplete,
      this.slideTo,
      this.onSlideRegionUpdate,
      this.upSwipeAllowed = false,
      this.leftSwipeAllowed = true,
      this.rightSwipeAllowed = true,
      this.isBackCard = false,
      this.padding = EdgeInsets.zero});

  @override
  _DraggableCardState createState() => _DraggableCardState();
}

class _DraggableCardState extends State<DraggableCard>
    with TickerProviderStateMixin {
  GlobalKey profileCardKey = GlobalKey(debugLabel: 'profile_card_key');
  Offset? cardOffset = const Offset(0.0, 0.0);
  Offset? dragStart;
  Offset? dragPosition;
  Offset? slideBackStart;
  SlideDirection? slideOutDirection;
  SlideRegion? slideRegion;
  late AnimationController slideBackAnimation;
  Tween<Offset>? slideOutTween;
  late AnimationController slideOutAnimation;

  Rect? anchorBounds;

  @override
  void initState() {
    super.initState();
    slideBackAnimation = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )
      ..addListener(() => setState(() {
            cardOffset = Offset.lerp(
              slideBackStart,
              const Offset(0.0, 0.0),
              Curves.elasticOut.transform(slideBackAnimation.value),
            );

            if (null != widget.onSlideUpdate) {
              widget.onSlideUpdate!(cardOffset!.distance);
            }

            if (null != widget.onSlideRegionUpdate) {
              widget.onSlideRegionUpdate!(slideRegion);
            }
          }))
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            dragStart = null;
            slideBackStart = null;
            dragPosition = null;
          });
        }
      });

    slideOutAnimation = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )
      ..addListener(() {
        setState(() {
          cardOffset = slideOutTween!.evaluate(slideOutAnimation);

          if (null != widget.onSlideUpdate) {
            widget.onSlideUpdate!(cardOffset!.distance);
          }

          if (null != widget.onSlideRegionUpdate) {
            widget.onSlideRegionUpdate!(slideRegion);
          }
        });
      })
      ..addStatusListener((AnimationStatus status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            dragStart = null;
            dragPosition = null;
            slideOutTween = null;
            slideRegion = null;
            if (null != widget.onSlideRegionUpdate) {
              widget.onSlideRegionUpdate!(null);
            }

            if (widget.onSlideOutComplete != null) {
              widget.onSlideOutComplete!(slideOutDirection);
            }
          });
        }
      });
  }

  @override
  void didUpdateWidget(DraggableCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.card!.key != oldWidget.card!.key) {
      cardOffset = const Offset(0.0, 0.0);
      slideRegion = null;
      if (null != widget.onSlideRegionUpdate) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            widget.onSlideRegionUpdate!(null);
          }
        });
      }
    }

    if (oldWidget.slideTo == null && widget.slideTo != null) {
      switch (widget.slideTo!) {
        case SlideDirection.left:
          _slideLeft();
          break;
        case SlideDirection.right:
          _slideRight();
          break;
        case SlideDirection.up:
          _slideUp();
          break;
      }
    }
  }

  @override
  void dispose() {
    slideOutAnimation.dispose();
    slideBackAnimation.dispose();
    super.dispose();
  }

  Offset _chooseRandomDragStart() {
    final cardContext = profileCardKey.currentContext!;
    final dragStartY =
        cardContext.size!.height * (Random().nextDouble() < 0.5 ? 0.25 : 0.75);
    return Offset(cardContext.size!.width / 2, dragStartY);
  }

  void _slideLeft() async {
    await Future.delayed(Duration(milliseconds: 1)).then((_) {
      final screenWidth = context.size!.width;
      dragStart = _chooseRandomDragStart();
      slideOutTween = Tween(
          begin: const Offset(0.0, 0.0), end: Offset(-2 * screenWidth, 0.0));
      slideOutAnimation.forward(from: 0.0);
    });
  }

  void _slideRight() async {
    await Future.delayed(Duration(milliseconds: 1)).then((_) {
      final screenWidth = context.size!.width;
      dragStart = _chooseRandomDragStart();
      slideOutTween = Tween(
          begin: const Offset(0.0, 0.0), end: Offset(2 * screenWidth, 0.0));
      slideOutAnimation.forward(from: 0.0);
    });
  }

  void _slideUp() async {
    await Future.delayed(Duration(milliseconds: 1)).then((_) {
      final screenHeight = context.size!.height;
      dragStart = _chooseRandomDragStart();
      slideOutTween = Tween(
          begin: const Offset(0.0, 0.0), end: Offset(0.0, -2 * screenHeight));
      slideOutAnimation.forward(from: 0.0);
    });
  }

  void _onPanStart(DragStartDetails details) {
    dragStart = details.localPosition;

    if (slideBackAnimation.isAnimating) {
      slideBackAnimation.stop(canceled: true);
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    final isInLeftRegion = (cardOffset!.dx / context.size!.width) < -0.10;
    final isInRightRegion = (cardOffset!.dx / context.size!.width) > 0.10;
    final isInTopRegion = (cardOffset!.dy / context.size!.height) < -0.10;

    setState(() {
      if (isInLeftRegion || isInRightRegion) {
        slideRegion = isInLeftRegion
            ? SlideRegion.inNopeRegion
            : SlideRegion.inLikeRegion;
      } else if (isInTopRegion) {
        slideRegion = SlideRegion.inSuperLikeRegion;
      } else {
        slideRegion = null;
      }

      dragPosition = details.localPosition;
      cardOffset = dragPosition! - dragStart!;

      if (null != widget.onSlideUpdate) {
        widget.onSlideUpdate!(cardOffset!.distance);
      }

      if (null != widget.onSlideRegionUpdate) {
        widget.onSlideRegionUpdate!(slideRegion);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final dragVector = cardOffset! / cardOffset!.distance;

    final isInLeftRegion = (cardOffset!.dx / context.size!.width) < -0.15;
    final isInRightRegion = (cardOffset!.dx / context.size!.width) > 0.15;
    final isInTopRegion = (cardOffset!.dy / context.size!.height) < -0.15;

    setState(() {
      if (isInLeftRegion) {
        if (widget.leftSwipeAllowed) {
          slideOutTween = Tween(
              begin: cardOffset, end: dragVector * (2 * context.size!.width));
          slideOutAnimation.forward(from: 0.0);

          slideOutDirection = SlideDirection.left;
        } else {
          slideBackStart = cardOffset;
          slideBackAnimation.forward(from: 0.0);
        }
      } else if (isInRightRegion) {
        if (widget.rightSwipeAllowed) {
          slideOutTween = Tween(
              begin: cardOffset, end: dragVector * (2 * context.size!.width));
          slideOutAnimation.forward(from: 0.0);

          slideOutDirection = SlideDirection.right;
        } else {
          slideBackStart = cardOffset;
          slideBackAnimation.forward(from: 0.0);
        }
      } else if (isInTopRegion) {
        if (widget.upSwipeAllowed) {
          slideOutTween = Tween(
              begin: cardOffset, end: dragVector * (2 * context.size!.height));
          slideOutAnimation.forward(from: 0.0);

          slideOutDirection = SlideDirection.up;
        } else {
          slideBackStart = cardOffset;
          slideBackAnimation.forward(from: 0.0);
        }
      } else {
        slideBackStart = cardOffset;
        slideBackAnimation.forward(from: 0.0);
        slideRegion = null;
        if (null != widget.onSlideRegionUpdate) {
          widget.onSlideRegionUpdate!(slideRegion);
        }
      }
    });
  }

  double _rotation(Rect? dragBounds) {
    if (dragStart != null) {
      final rotationCornerMultiplier =
          dragStart!.dy >= dragBounds!.top + (dragBounds.height / 2) ? -1 : 1;
      return (pi / 8) *
          (cardOffset!.dx / dragBounds.width) *
          rotationCornerMultiplier;
    } else {
      return 0.0;
    }
  }

  Offset _rotationOrigin(Rect? dragBounds) {
    if (dragStart != null) {
      return dragStart! - dragBounds!.topLeft;
    } else {
      return const Offset(0.0, 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        anchorBounds =
            Rect.fromLTWH(0, 0, constraints.maxWidth, constraints.maxHeight);
        return _buildCard();
      },
    );
  }

  double _progresoLateral() {
    final ancho = anchorBounds?.width ?? context.size!.width;
    if (ancho == 0 || cardOffset == null) return 0;
    return ((cardOffset!.dx.abs() / ancho - 0.10) / 0.10).clamp(0.0, 1.0);
  }

  double _progresoVertical() {
    final alto = anchorBounds?.height ?? context.size!.height;
    if (alto == 0 || cardOffset == null) return 0;
    return ((cardOffset!.dy.abs() / alto - 0.10) / 0.10).clamp(0.0, 1.0);
  }

  Widget _buildCard() {
    //Disables dragging card while slide out animation is in progress. Solves
    // issue that fast swipes cause the back card not loading
    if (widget.isBackCard &&
        anchorBounds != null &&
        cardOffset!.dx < anchorBounds!.height) {
      cardOffset = Offset.zero;
    }

    return Transform(
      transform: Matrix4.translationValues(cardOffset!.dx, cardOffset!.dy, 0.0)
        ..rotateZ(_rotation(anchorBounds)),
      origin: _rotationOrigin(anchorBounds),
      child: Container(
        key: profileCardKey,
        width: anchorBounds?.width,
        height: anchorBounds?.height,
        padding: widget.padding,
        child: GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
              child: widget.card != null
                  ? Stack(
                      clipBehavior: Clip.none,
                      children: [
                        widget.card!,
                        if (widget.nopeGradient != null &&
                            slideRegion == SlideRegion.inNopeRegion)
                          Positioned.fill(
                            child: Opacity(
                              opacity: _progresoLateral(),
                              child: widget.nopeGradient,
                            ),
                          ),
                        if (widget.likeGradient != null &&
                            slideRegion == SlideRegion.inLikeRegion)
                          Positioned.fill(
                            child: Opacity(
                              opacity: _progresoLateral(),
                              child: widget.likeGradient,
                            ),
                          ),
                        if (widget.superLikeGradient != null &&
                            slideRegion == SlideRegion.inSuperLikeRegion)
                          Positioned.fill(
                            child: Opacity(
                              opacity: _progresoVertical(),
                              child: widget.superLikeGradient,
                            ),
                          ),
                        if (widget.likeTag != null &&
                            slideRegion == SlideRegion.inLikeRegion)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            left: -26,
                            child: Center(child: widget.likeTag),
                          ),
                        if (widget.nopeTag != null &&
                            slideRegion == SlideRegion.inNopeRegion)
                          Positioned(
                            top: 0,
                            bottom: 0,
                            right: -26,
                            child: Center(child: widget.nopeTag),
                          ),
                        if (widget.superLikeTag != null &&
                            slideRegion == SlideRegion.inSuperLikeRegion)
                          Positioned(
                            top: -26,
                            left: 0,
                            right: 0,
                            child: Center(child: widget.superLikeTag),
                          ),
                      ],
                    )
                  : Container(),
        ),
      ),
    );
  }
}
