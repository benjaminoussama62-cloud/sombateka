import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Saisie OTP fiable (iPhone Safari : collage, 0 en tête, auto-remplissage SMS).
class OtpPinInput extends StatefulWidget {
  const OtpPinInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.hasError = false,
    this.length = 6,
    this.controller,
  });

  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool hasError;
  final int length;
  final TextEditingController? controller;

  @override
  State<OtpPinInput> createState() => OtpPinInputState();
}

class OtpPinInputState extends State<OtpPinInput> {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController();
    _focus = FocusNode();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focus.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    var t = _controller.text.replaceAll(RegExp(r'\D'), '');
    if (t.length > widget.length) t = t.substring(0, widget.length);
    if (t != _controller.text) {
      _controller.value = TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: t.length),
      );
      return;
    }
    widget.onChanged?.call(t);
    if (t.length == widget.length) widget.onCompleted(t);
    setState(() {});
  }

  void setCode(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    final t = digits.length >= widget.length
        ? digits.substring(0, widget.length)
        : digits.padLeft(widget.length, '0');
    _controller.text = t;
    _onTextChanged();
  }

  void clear() {
    _controller.clear();
    setState(() {});
  }

  void focus() => _focus.requestFocus();

  String get value => _controller.text;

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    final borderColor = widget.hasError
        ? const Color(0xFFE74C3C)
        : const Color(0xFFE5E7EB);
    final filledColor = widget.hasError
        ? const Color(0xFFFEF2F2)
        : const Color(0xFFF9FAFB);

    return LayoutBuilder(
      builder: (context, constraints) {
        final gap = 8.0;
        final boxW = ((constraints.maxWidth - gap * (widget.length - 1)) / widget.length)
            .clamp(40.0, 52.0);

        return SizedBox(
          width: constraints.maxWidth,
          height: 58,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.length, (i) {
                  final char = i < code.length ? code[i] : '';
                  final active = i == code.length && _focus.hasFocus;
                  return Padding(
                    padding: EdgeInsets.only(right: i < widget.length - 1 ? gap : 0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: boxW,
                      height: 58,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: char.isNotEmpty
                            ? const Color(0xFFEFF6FF)
                            : filledColor,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: active
                              ? const Color(0xFF2563EB)
                              : char.isNotEmpty
                                  ? const Color(0xFF2563EB)
                                  : borderColor,
                          width: active || char.isNotEmpty ? 2 : 1.5,
                        ),
                        boxShadow: active
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF2563EB).withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Text(
                        char,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                  );
                }),
              ),
              Positioned.fill(
                child: Theme(
                  data: Theme.of(context).copyWith(
                    inputDecorationTheme: const InputDecorationTheme(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    enableSuggestions: false,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(widget.length),
                    ],
                    style: const TextStyle(
                      color: Colors.transparent,
                      fontSize: 1,
                      height: 1,
                    ),
                    strutStyle: const StrutStyle(fontSize: 1, height: 1),
                    cursorColor: Colors.transparent,
                    showCursor: false,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                      isDense: true,
                      counterText: '',
                      filled: false,
                    ),
                    onTap: () => _focus.requestFocus(),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
