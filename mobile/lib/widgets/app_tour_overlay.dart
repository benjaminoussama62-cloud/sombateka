import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/onboarding_service.dart';
import '../theme/premium_theme.dart';

/// Présentation guidée avec avatar guide — bouton Passer.
class AppTourPresenter {
  AppTourPresenter._();

  static Future<void> maybeShow(BuildContext context, AppTourPage page) async {
    if (!context.mounted) return;
    final steps = OnboardingService.steps[page];
    if (steps == null || steps.isEmpty) return;
    if (!await OnboardingService.instance.shouldShow(page)) return;
    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (ctx) => _AppTourSheet(page: page, steps: steps),
    );
  }
}

class _AppTourSheet extends StatefulWidget {
  const _AppTourSheet({required this.page, required this.steps});

  final AppTourPage page;
  final List<AppTourStep> steps;

  @override
  State<_AppTourSheet> createState() => _AppTourSheetState();
}

class _AppTourSheetState extends State<_AppTourSheet> {
  int _index = 0;

  Future<void> _finish({required bool skipAll}) async {
    if (skipAll) {
      await OnboardingService.instance.skipAll();
    } else {
      await OnboardingService.instance.markDone(widget.page);
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_index];
    final last = _index >= widget.steps.length - 1;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.of(context).padding.bottom),
      child: Material(
        borderRadius: PremiumTheme.radiusLg,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: PremiumTheme.radiusLg,
            boxShadow: PremiumTheme.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: PremiumTheme.heroGradient,
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      alignment: Alignment.center,
                      child: const Text('🧭', style: TextStyle(fontSize: 26)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Guide SombaTeka', style: PremiumTheme.display.copyWith(fontSize: 18)),
                          Text(
                            'Maya · votre accompagnatrice',
                            style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        _finish(skipAll: true);
                      },
                      child: Text('Passer', style: PremiumTheme.label.copyWith(color: Colors.white)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 24, 8),
                child: Column(
                  children: [
                    Text(step.emoji, style: const TextStyle(fontSize: 44)),
                    const SizedBox(height: 14),
                    Text(step.title, style: PremiumTheme.h1.copyWith(fontSize: 20), textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    Text(
                      step.body,
                      style: PremiumTheme.body.copyWith(height: 1.55, fontSize: 15),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.steps.length > 1) ...[
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.steps.length, (i) {
                          return Container(
                            width: i == _index ? 22 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: i == _index ? PremiumTheme.blue : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      HapticFeedback.mediumImpact();
                      if (last) {
                        _finish(skipAll: false);
                      } else {
                        setState(() => _index++);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: PremiumTheme.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusMd),
                      elevation: 0,
                    ),
                    child: Text(last ? 'Compris !' : 'Suivant', style: const TextStyle(fontWeight: FontWeight.w800)),
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
