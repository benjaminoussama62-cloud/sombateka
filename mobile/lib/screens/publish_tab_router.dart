import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../widgets/finalize_account_sheet.dart';
import '../services/onboarding_service.dart';
import '../widgets/app_tour_overlay.dart';
import 'official_sell_screen.dart';
import 'publish_screen.dart';

/// Onglet central : particulier → annonce simple ; officiel → publication (pas le dashboard).
class PublishTabRouter extends StatefulWidget {
  const PublishTabRouter({
    super.key,
    this.onPublished,
    this.onGoHome,
    this.onOpenMessages,
  });

  final VoidCallback? onPublished;
  final VoidCallback? onGoHome;
  final VoidCallback? onOpenMessages;

  @override
  State<PublishTabRouter> createState() => PublishTabRouterState();
}

class PublishTabRouterState extends State<PublishTabRouter> {
  final _data = DataService();
  final _particularKey = GlobalKey<PublishScreenState>();
  final _sellKey = GlobalKey<OfficialSellScreenState>();
  bool _isOfficial = false;
  bool _loading = true;
  bool _hasSession = false;

  @override
  void initState() {
    super.initState();
    _refreshRole();
  }

  Future<void> refreshRole() => _refreshRole();

  Future<void> _refreshRole() async {
    _hasSession = await _data.hasApiSession();
    if (_hasSession) {
      await _data.refreshUser();
    }
    final official = _hasSession && _data.isOfficialSeller;
    if (mounted) {
      setState(() {
        _isOfficial = official;
        _loading = false;
      });
      if (_hasSession && !_data.needsAccountSetup()) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          AppTourPresenter.maybeShow(context, AppTourPage.publish);
        });
      }
    }
  }

  void resetForm() {
    _particularKey.currentState?.resetForm();
    _sellKey.currentState?.resetForm();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasSession) {
      return _buildLoginRequired(context);
    }
    if (_data.needsAccountSetup()) {
      return _buildFinalizeRequired(context);
    }
    if (_isOfficial) {
      return OfficialSellScreen(
        key: _sellKey,
        onPublished: widget.onPublished,
        onGoHome: widget.onGoHome,
        onOpenMessages: widget.onOpenMessages,
      );
    }
    return PublishScreen(
      key: _particularKey,
      onPublished: widget.onPublished,
      onGoHome: widget.onGoHome,
    );
  }

  Widget _buildLoginRequired(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline_rounded, size: 48, color: PremiumTheme.blue),
              const SizedBox(height: 16),
              Text('Connexion requise', style: PremiumTheme.h1.copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                'Créez un compte ou connectez-vous pour publier une annonce.',
                textAlign: TextAlign.center,
                style: PremiumTheme.body.copyWith(color: PremiumTheme.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.auth, arguments: {'mode': 'login'}),
                child: const Text('Se connecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFinalizeRequired(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.assignment_late_outlined, size: 48, color: AppColors.warning),
              const SizedBox(height: 16),
              Text('Compte à finaliser', style: PremiumTheme.h1.copyWith(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                'Ajoutez votre téléphone et mot de passe dans Paramètres avant de publier.',
                textAlign: TextAlign.center,
                style: PremiumTheme.body.copyWith(color: PremiumTheme.textMuted),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final ok = await showFinalizeAccountSheet(context);
                  if (ok == true) _refreshRole();
                },
                child: const Text('Finaliser mon compte'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
