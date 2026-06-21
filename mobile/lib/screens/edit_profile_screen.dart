import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';
import '../widgets/user_avatar.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _name = TextEditingController();
  final _picker = ImagePicker();
  final _data = DataService();
  bool _loading = true;
  bool _saving = false;
  bool _avatarBusy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (await _data.hasVerifiedProfile()) {
        await _data.refreshUser();
      }
    } catch (_) {}
    final u = _data.currentUser;
    _name.text = u?['display_name']?.toString() ?? u?['name']?.toString() ?? '';
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: PremiumTheme.blue)),
      );
    }

    final u = _data.currentUser;
    final phone = u?['phone_e164']?.toString() ?? u?['phone']?.toString() ?? '—';
    final role = u?['role']?.toString() ?? 'user';
    final isOfficial = role.contains('official') || u?['is_verified_seller'] == true;
    final displayName = _data.profileDisplayName(u);
    final avatarUrl = _data.profileAvatarUrl;

    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: Column(
        children: [
          _header(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      UserAvatar(
                        imageUrl: avatarUrl,
                        name: displayName,
                        radius: 56,
                        onTap: _avatarBusy ? null : _showAvatarOptions,
                        showEditBadge: true,
                      ),
                      if (_avatarBusy)
                        const SizedBox(
                          width: 112,
                          height: 112,
                          child: CircularProgressIndicator(strokeWidth: 2, color: PremiumTheme.blue),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _avatarBusy ? null : _showAvatarOptions,
                    child: const Text('Modifier la photo de profil'),
                  ),
                  Text(phone, style: PremiumTheme.body.copyWith(fontSize: 13)),
                  const SizedBox(height: 6),
                  _badge(
                    isOfficial ? 'Vendeur officiel' : 'Compte particulier',
                    isOfficial ? PremiumTheme.gold : PremiumTheme.blue,
                  ),
                  if (u?['is_phone_verified'] == true) ...[
                    const SizedBox(height: 8),
                    _badge('Téléphone vérifié', PremiumTheme.emerald),
                  ],
                  const SizedBox(height: 28),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Nom affiché',
                      hintText: 'Ex: Jean Mukendi',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: PremiumTheme.radiusMd),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: PremiumTheme.radiusMd,
                        borderSide: const BorderSide(color: PremiumTheme.blue, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    enabled: false,
                    controller: TextEditingController(text: phone),
                    decoration: InputDecoration(
                      labelText: 'Téléphone (non modifiable)',
                      filled: true,
                      fillColor: const Color(0xFFF3F4F6),
                      border: OutlineInputBorder(borderRadius: PremiumTheme.radiusMd),
                      prefixIcon: const Icon(Icons.phone_rounded, color: PremiumTheme.textMuted),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Le numéro est lié à votre compte pour la sécurité OTP.',
                    style: PremiumTheme.body.copyWith(fontSize: 12, color: PremiumTheme.textMuted),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: PremiumTheme.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusLg),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Enregistrer les modifications', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAvatarOptions() async {
    final hasPhoto = _data.profileAvatarUrl != null && _data.profileAvatarUrl!.isNotEmpty;
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text('Photo de profil', style: PremiumTheme.h1.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: PremiumTheme.blue),
              title: const Text('Choisir dans la galerie'),
              onTap: () => Navigator.pop(ctx, 'gallery'),
            ),
            if (!kIsWeb)
              ListTile(
                leading: const Icon(Icons.photo_camera_rounded, color: PremiumTheme.blue),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: AppColors.danger),
                title: const Text('Supprimer la photo', style: TextStyle(color: AppColors.danger)),
                onTap: () => Navigator.pop(ctx, 'delete'),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'delete') {
      await _deleteAvatar();
    } else {
      await _pickAndUpload(action == 'camera' ? ImageSource.camera : ImageSource.gallery);
    }
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    try {
      final file = await _picker.pickImage(source: source, maxWidth: 1024, maxHeight: 1024, imageQuality: 85);
      if (file == null) return;
      setState(() => _avatarBusy = true);
      if (kIsWeb) {
        final bytes = await file.readAsBytes();
        final name = file.name.isNotEmpty ? file.name : 'avatar.jpg';
        await _data.uploadProfileAvatarBytes(bytes: bytes, filename: name);
      } else {
        await _data.uploadProfileAvatar(filePath: file.path);
      }
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil mise à jour'), backgroundColor: PremiumTheme.emerald),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur photo: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _deleteAvatar() async {
    setState(() => _avatarBusy = true);
    try {
      await _data.deleteProfileAvatar();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Photo de profil supprimée'), backgroundColor: PremiumTheme.emerald),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Widget _header(BuildContext context) {
    return Container(
      decoration: PremiumTheme.heroGradient,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 16, 16),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              Text('Modifier le profil', style: PremiumTheme.display.copyWith(fontSize: 20)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le nom doit contenir au moins 2 caractères'), backgroundColor: AppColors.danger),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _data.updateProfile(displayName: name);
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil enregistré sur le serveur'), backgroundColor: PremiumTheme.emerald),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
