import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../content/helpdesk_bot_content.dart';
import '../theme/premium_theme.dart';
import '../widgets/maya_avatar.dart';
import '../widgets/maya_typing_bubble.dart';
import '../widgets/st_safe_area.dart';

/// Panneau bot centre d'aide — options + réponses instantanées.
class HelpdeskBotPanel extends StatefulWidget {
  const HelpdeskBotPanel({
    super.key,
    required this.onEscalate,
    this.onAnswerShown,
  });

  final VoidCallback onEscalate;
  final VoidCallback? onAnswerShown;

  @override
  State<HelpdeskBotPanel> createState() => _HelpdeskBotPanelState();
}

class _HelpdeskBotPanelState extends State<HelpdeskBotPanel> {
  HelpdeskBotOption? _selected;
  String _filter = 'Tous';

  List<String> get _categories {
    final cats = HelpdeskBotContent.options.map((o) => o.category).toSet().toList()..sort();
    return ['Tous', ...cats];
  }

  List<HelpdeskBotOption> get _filtered {
    if (_filter == 'Tous') return HelpdeskBotContent.options;
    return HelpdeskBotContent.options.where((o) => o.category == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            children: [
              _botBubble(HelpdeskBotContent.welcome),
              if (_selected != null) ...[
                const SizedBox(height: 12),
                _userBubble(_selected!.title),
                const SizedBox(height: 8),
                _botBubble(_selected!.answer, highlight: true),
                const SizedBox(height: 12),
                Center(
                  child: TextButton.icon(
                    onPressed: () => setState(() => _selected = null),
                    icon: const Icon(Icons.arrow_back_rounded, size: 18),
                    label: const Text('Autre question'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 16),
                Text('Catégories', style: PremiumTheme.h1.copyWith(fontSize: 14)),
                const SizedBox(height: 10),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final cat = _categories[i];
                      final sel = _filter == cat;
                      return FilterChip(
                        label: Text(cat, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                        selected: sel,
                        onSelected: (_) => setState(() => _filter = cat),
                        selectedColor: PremiumTheme.blue,
                        checkmarkColor: Colors.white,
                        labelStyle: TextStyle(color: sel ? Colors.white : PremiumTheme.textDark),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                ..._filtered.map(_optionTile),
              ],
            ],
          ),
        ),
        _escalationBar(),
      ],
    );
  }

  Widget _botBubble(String text, {bool highlight = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Column(
          children: [
            MayaAvatar(size: 40, showPulse: true),
            SizedBox(height: 4),
            Text('Maya', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: PremiumTheme.textMuted)),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(child: MayaTypingBubble(text: text, highlight: highlight)),
      ],
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [PremiumTheme.blue, PremiumTheme.navy]),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Widget _optionTile(HelpdeskBotOption opt) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: PremiumTheme.radiusMd,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _selected = opt);
            widget.onAnswerShown?.call();
          },
          borderRadius: PremiumTheme.radiusMd,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.help_outline_rounded, color: PremiumTheme.blue.withValues(alpha: 0.85), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(opt.title, style: PremiumTheme.label.copyWith(fontSize: 13)),
                ),
                const Icon(Icons.chevron_right_rounded, color: PremiumTheme.textMuted, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _escalationBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: StSafeBottom(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Toujours bloqué ? Notre équipe humaine peut vous aider.',
                textAlign: TextAlign.center,
                style: PremiumTheme.body.copyWith(fontSize: 12, color: PremiumTheme.textMuted),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: widget.onEscalate,
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: const Text('Autre sujet — écrire au support', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusMd),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
