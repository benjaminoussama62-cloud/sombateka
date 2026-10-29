import 'package:flutter/material.dart';

import '../theme/premium_theme.dart';

/// Bulle de chat avec apparition animée (effet « Maya écrit »).
class MayaTypingBubble extends StatefulWidget {
  const MayaTypingBubble({
    super.key,
    required this.text,
    this.highlight = false,
  });

  final String text;
  final bool highlight;

  @override
  State<MayaTypingBubble> createState() => _MayaTypingBubbleState();
}

class _MayaTypingBubbleState extends State<MayaTypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(MayaTypingBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: widget.highlight ? const Color(0xFFEFF6FF) : Colors.white,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            border: Border.all(
              color: widget.highlight ? PremiumTheme.blue.withValues(alpha: 0.25) : const Color(0xFFE2E8F0),
            ),
            boxShadow: PremiumTheme.softShadow,
          ),
          child: Text(widget.text, style: PremiumTheme.body.copyWith(fontSize: 13, height: 1.45)),
        ),
      ),
    );
  }
}
