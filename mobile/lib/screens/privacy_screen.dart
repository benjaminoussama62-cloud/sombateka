import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/app_feedback.dart';

class PrivacyScreen extends StatefulWidget {
  const PrivacyScreen({super.key});

  @override
  State<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends State<PrivacyScreen> {
  final _data = DataService();
  bool _loading = true;
  bool _profilePublic = true;
  bool _showPhone = false;
  bool _allowMessages = true;
  bool _analytics = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      await _data.refreshUser();
      final u = _data.currentUser;
      final p = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _profilePublic = u?['privacy_profile_public'] as bool? ?? p.getBool('privacy_profile_public') ?? true;
          _showPhone = u?['privacy_show_phone'] as bool? ?? p.getBool('privacy_show_phone') ?? false;
          _allowMessages = u?['privacy_allow_messages'] as bool? ?? true;
          _analytics = p.getBool('privacy_analytics') ?? true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveLocal(String key, bool v) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  }

  Future<void> _syncPrivacy({
    bool? profilePublic,
    bool? showPhone,
    bool? allowMessages,
  }) async {
    await _data.updatePrivacySettings(
      profilePublic: profilePublic,
      showPhone: showPhone,
      allowMessages: allowMessages,
    );
    if (profilePublic != null) await _saveLocal('privacy_profile_public', profilePublic);
    if (showPhone != null) await _saveLocal('privacy_show_phone', showPhone);
    if (mounted) showAppSuccess(context, 'Paramètres enregistrés');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      appBar: AppBar(
        title: const Text('Confidentialité'),
        backgroundColor: Colors.white,
        foregroundColor: PremiumTheme.textDark,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: PremiumTheme.blue))
          : ListView(
              children: [
                SwitchListTile(
                  title: const Text('Profil public'),
                  subtitle: const Text('Les acheteurs voient votre nom et vos avis'),
                  value: _profilePublic,
                  onChanged: (v) {
                    setState(() => _profilePublic = v);
                    _syncPrivacy(profilePublic: v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Afficher le téléphone'),
                  subtitle: const Text('Visible sur vos annonces si activé'),
                  value: _showPhone,
                  onChanged: (v) {
                    setState(() => _showPhone = v);
                    _syncPrivacy(showPhone: v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Autoriser les messages'),
                  subtitle: const Text('Les acheteurs peuvent vous contacter'),
                  value: _allowMessages,
                  onChanged: (v) {
                    setState(() => _allowMessages = v);
                    _syncPrivacy(allowMessages: v);
                  },
                ),
                SwitchListTile(
                  title: const Text('Statistiques anonymes'),
                  subtitle: const Text('Stocké uniquement sur cet appareil'),
                  value: _analytics,
                  onChanged: (v) {
                    setState(() => _analytics = v);
                    _saveLocal('privacy_analytics', v);
                  },
                ),
              ],
            ),
    );
  }
}
