import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const _teal = Color(0xFF0F766E);
const _bg = Color(0xFFF7F8FA);

/// A row of boxes reflecting [controller]'s digits, backed by a real
/// (invisible but full-size) TextField stacked on top so it reliably
/// receives taps/keyboard focus on every device - a zero-size or Offstage
/// TextField doesn't always open the system keyboard. Matches the app's
/// flat, teal-accented visual language instead of a default-styled
/// TextFormField. [onCompleted] fires once all digits are entered.
///
/// The box at the current cursor position gets a teal focus ring + a
/// blinking caret (only while the field actually has focus), and a filled
/// box pops its dot in with a small scale animation - so the row reads as
/// an active input waiting for digits, not a static grid of squares.
class PinBoxField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final int length;
  final bool autofocus;
  final bool hasError;
  final ValueChanged<String>? onCompleted;

  const PinBoxField({
    super.key,
    required this.controller,
    this.focusNode,
    this.length = 6,
    this.autofocus = false,
    this.hasError = false,
    this.onCompleted,
  });

  @override
  State<PinBoxField> createState() => _PinBoxFieldState();
}

class _PinBoxFieldState extends State<PinBoxField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();

  // _onChanged runs off two listeners (controller text AND focus - the
  // latter so the cursor/box highlight updates the instant the field is
  // tapped, not just as digits are typed). The system keyboard often drops
  // focus the moment the max length is reached, which fires the focus
  // listener at almost the same instant the controller listener already
  // fired for that same 6th digit - without this guard, onCompleted (which
  // callers use to pop a bottom sheet) would fire twice for one entry,
  // popping one route too many. Reset once the text is no longer complete
  // (cleared/edited) so a genuinely new entry can complete again.
  bool _completedFired = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
    _focusNode.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    _focusNode.removeListener(_onChanged);
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (!mounted) return;
    setState(() {});

    if (widget.controller.text.length != widget.length) {
      _completedFired = false;
      return;
    }

    if (_completedFired) return;
    _completedFired = true;
    widget.onCompleted?.call(widget.controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;
    final cursorIndex = value.length;

    return SizedBox(
      height: 62,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.length, (i) {
              final filled = i < value.length;
              final isCursor =
                  !widget.hasError && _focusNode.hasFocus && i == cursorIndex;

              final Color borderColor;
              if (widget.hasError) {
                borderColor = Colors.red[300]!;
              } else if (isCursor) {
                borderColor = _teal;
              } else if (filled) {
                borderColor = _teal.withValues(alpha: 0.55);
              } else {
                borderColor = const Color(0xFFD8DBE2);
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                width: 44,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: filled ? _teal.withValues(alpha: 0.08) : _bg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                    width: filled || isCursor || widget.hasError ? 2 : 1.3,
                  ),
                  boxShadow: isCursor
                      ? [
                          BoxShadow(
                            color: _teal.withValues(alpha: 0.18),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: filled
                    ? TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: 1),
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        builder: (context, scale, child) =>
                            Transform.scale(scale: scale, child: child),
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: _teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : (isCursor
                          ? const _BlinkingCursor(key: ValueKey('cursor'))
                          : null),
              );
            }),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: 0,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                autofocus: widget.autofocus,
                keyboardType: TextInputType.number,
                obscureText: true,
                textAlign: TextAlign.center,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(widget.length),
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A thin blinking vertical bar marking the box that will receive the next
/// digit - the small extra cue that makes the row read as "actively
/// waiting for input" rather than a static grid of empty squares.
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor({super.key});

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller.drive(CurveTween(curve: Curves.easeInOut)),
      child: Container(
        width: 2,
        height: 22,
        decoration: BoxDecoration(
          color: _teal,
          borderRadius: BorderRadius.circular(1),
        ),
      ),
    );
  }
}
