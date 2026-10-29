import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../utils/friendly_error.dart';

/// Formulaire de finalisation : téléphone + mot de passe pour comptes Google/Apple.
Future<bool?> showFinalizeAccountSheet(BuildContext context) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _FinalizeAccountSheet(),
  );
}

class _FinalizeAccountSheet extends StatefulWidget {
  const _FinalizeAccountSheet();

  @override
  State<_FinalizeAccountSheet> createState() => _FinalizeAccountSheetState();
}

class _FinalizeAccountSheetState extends State<_FinalizeAccountSheet> {
  final _data = DataService();
  final _phoneCtrl = TextEditingController(text: '+243');
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  bool get _needsPhone => _data.needsPhone();
  bool get _needsPassword => _data.needsPassword();

  bool get _valid {
    if (_needsPhone && _phoneCtrl.text.trim().length < 12) return false;
    if (_needsPassword) {
      if (_passwordCtrl.text.length < 8) return false;
      if (_passwordCtrl.text != _confirmCtrl.text) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_valid || _busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      if (_needsPhone) {
        final phone = DataService.normalizePhoneE164(_phoneCtrl.text.trim());
        await _data.updateProfilePhone(phone);
      }
      if (_needsPassword) {
        await _data.setAccountPassword(_passwordCtrl.text);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyError(e)),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Finaliser votre compte',
              style: PremiumTheme.h1.copyWith(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Obligatoire pour publier des annonces.',
              style: PremiumTheme.body.copyWith(fontSize: 13, color: PremiumTheme.textMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            if (_needsPhone) ...[
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone',
                  hintText: '+243812345678',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: PremiumTheme.radiusMd),
                ),
              ),
              const SizedBox(height: 14),
            ],
            if (_needsPassword) ...[
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Mot de passe',
                  hintText: '8 caractères minimum',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: PremiumTheme.radiusMd),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  labelText: 'Confirmer le mot de passe',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: PremiumTheme.radiusMd),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirm ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ce mot de passe servira pour vos prochaines connexions par e-mail.',
                style: PremiumTheme.body.copyWith(fontSize: 11, color: PremiumTheme.textMuted),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _valid && !_busy ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusLg),
                ),
                child: _busy
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
