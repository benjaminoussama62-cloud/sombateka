import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import 'package:flutter/services.dart';

import 'package:image_picker/image_picker.dart';



import '../services/data_service.dart';

import '../theme/premium_theme.dart';

import '../utils/constants.dart';



class OfficialSellerScreen extends StatefulWidget {

  const OfficialSellerScreen({super.key});



  @override

  State<OfficialSellerScreen> createState() => _OfficialSellerScreenState();

}



class _OfficialSellerScreenState extends State<OfficialSellerScreen> {

  final _business = TextEditingController();

  final _rccm = TextEditingController();

  final _taxId = TextEditingController();

  final _legalRep = TextEditingController();

  final _address = TextEditingController();

  final _contactPhone = TextEditingController();

  final _applicantNote = TextEditingController();

  final _data = DataService();

  final _picker = ImagePicker();



  bool _loading = true;

  bool _submitting = false;

  Map<String, dynamic>? _kyc;

  String _category = 'Électronique';



  XFile? _docRccm;

  XFile? _docTax;

  XFile? _docId;

  XFile? _docShop;



  static const _categories = [

    'Électronique',

    'Mode',

    'Maison',

    'Véhicules',

    'Alimentation',

    'Services',

  ];



  bool get _isVerified => _data.currentUser?['is_verified_seller'] == true;

  String? get _kycStatus => _kyc?['status']?.toString();

  bool get _hasPending => _kycStatus == 'pending';



  @override

  void initState() {

    super.initState();

    _load();

  }



  Future<void> _load() async {

    try {

      await _data.refreshUser();

      _kyc = await _data.fetchKycStatus();

      if (_kyc != null) {

        _business.text = _kyc!['business_name']?.toString() ?? '';

        _category = _kyc!['category']?.toString() ?? _kyc!['business_type']?.toString() ?? _category;

        _parseBusinessType(_kyc!['business_type']?.toString() ?? '');

        _rccm.text = _kyc!['rccm']?.toString() ?? _rccm.text;

        _taxId.text = _kyc!['tax_id']?.toString() ?? _taxId.text;

        _legalRep.text = _kyc!['legal_representative']?.toString() ?? '';

        _address.text = _kyc!['business_address']?.toString() ?? '';

        _contactPhone.text = _kyc!['contact_phone']?.toString() ?? '';

        _applicantNote.text = _kyc!['applicant_note']?.toString() ?? '';

      } else {

        final u = _data.currentUser;

        _business.text = u?['official_name']?.toString() ?? '';

        _contactPhone.text = u?['phone']?.toString() ?? '';

      }

    } catch (_) {}

    if (mounted) setState(() => _loading = false);

  }



  void _parseBusinessType(String raw) {

    for (final c in _categories) {

      if (raw.toLowerCase().contains(c.toLowerCase())) {

        _category = c;

        break;

      }

    }

    final rccm = RegExp(r'RCCM:\s*([^|]+)').firstMatch(raw);

    if (rccm != null && _rccm.text.isEmpty) _rccm.text = rccm.group(1)?.trim() ?? '';

    final nif = RegExp(r'NIF:\s*([^|]+)').firstMatch(raw);

    if (nif != null && _taxId.text.isEmpty) _taxId.text = nif.group(1)?.trim() ?? '';

  }



  @override

  void dispose() {

    _business.dispose();

    _rccm.dispose();

    _taxId.dispose();

    _legalRep.dispose();

    _address.dispose();

    _contactPhone.dispose();

    _applicantNote.dispose();

    super.dispose();

  }



  @override

  Widget build(BuildContext context) {

    if (_loading) {

      return const Scaffold(body: Center(child: CircularProgressIndicator(color: PremiumTheme.blue)));

    }



    return Scaffold(

      backgroundColor: PremiumTheme.surface,

      body: Column(

        children: [

          _header(),

          Expanded(

            child: SingleChildScrollView(

              padding: const EdgeInsets.all(20),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  _statusCard(),

                  const SizedBox(height: 20),

                  Text('Avantages vendeur officiel', style: PremiumTheme.h1.copyWith(fontSize: 16)),

                  const SizedBox(height: 10),

                  _benefit(Icons.payments_rounded, 'Paiement Mobile Money in-app'),

                  _benefit(Icons.inventory_2_rounded, 'Stock et commandes gérées'),

                  _benefit(Icons.verified_rounded, 'Badge boutique certifiée'),

                  _benefit(Icons.schedule_rounded, 'Reversement vendeur T+1'),

                  if (_hasPending && (_kyc?['documents'] as List?)?.isNotEmpty == true) ...[

                    const SizedBox(height: 20),

                    Text('Documents envoyés', style: PremiumTheme.h1.copyWith(fontSize: 16)),

                    const SizedBox(height: 8),

                    ...((_kyc!['documents'] as List).map((d) {

                      final m = Map<String, dynamic>.from(d as Map);

                      return Padding(

                        padding: const EdgeInsets.only(bottom: 6),

                        child: Row(

                          children: [

                            const Icon(Icons.check_circle, color: PremiumTheme.emerald, size: 18),

                            const SizedBox(width: 8),

                            Expanded(child: Text(m['label']?.toString() ?? 'Document', style: PremiumTheme.body.copyWith(fontSize: 13))),

                          ],

                        ),

                      );

                    })),

                  ],

                  if (!_isVerified && !_hasPending) ...[

                    const SizedBox(height: 24),

                    Text('Votre demande', style: PremiumTheme.h1.copyWith(fontSize: 16)),

                    const SizedBox(height: 6),

                    Text(

                      'Comme sur les grandes marketplaces : joignez RCCM, pièce d\'identité et NIF. Notre équipe vérifie sous 48h.',

                      style: PremiumTheme.body.copyWith(fontSize: 12, color: PremiumTheme.textMuted, height: 1.4),

                    ),

                    const SizedBox(height: 12),

                    _field(_business, 'Nom de l\'entreprise / boutique', Icons.store_rounded),

                    const SizedBox(height: 12),

                    _dropdown(),

                    const SizedBox(height: 12),

                    _field(_rccm, 'Numéro RCCM', Icons.description_rounded),

                    const SizedBox(height: 12),

                    _field(_taxId, 'Identifiant fiscal (NIF)', Icons.numbers_rounded),

                    const SizedBox(height: 12),

                    _field(_legalRep, 'Représentant légal', Icons.person_rounded),

                    const SizedBox(height: 12),

                    _field(_address, 'Adresse du siège / boutique', Icons.location_on_rounded),

                    const SizedBox(height: 12),

                    _field(_contactPhone, 'Téléphone professionnel', Icons.phone_rounded),

                    const SizedBox(height: 12),

                    _field(_applicantNote, 'Message pour l\'équipe (optionnel)', Icons.notes_rounded, maxLines: 3),

                    const SizedBox(height: 16),

                    Text('Justificatifs', style: PremiumTheme.h1.copyWith(fontSize: 16)),

                    const SizedBox(height: 10),

                    _docTile('Extrait RCCM (obligatoire)', _docRccm, () => _pickDoc((f) => _docRccm = f)),

                    _docTile('Pièce d\'identité (obligatoire)', _docId, () => _pickDoc((f) => _docId = f)),

                    _docTile('Attestation fiscale / NIF (recommandé)', _docTax, () => _pickDoc((f) => _docTax = f)),

                    _docTile('Photo boutique (optionnel)', _docShop, () => _pickDoc((f) => _docShop = f)),

                  ],

                ],

              ),

            ),

          ),

          if (!_isVerified && !_hasPending)

            Padding(

              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),

              child: SizedBox(

                width: double.infinity,

                height: 54,

                child: ElevatedButton(

                  onPressed: _submitting ? null : _submit,

                  style: ElevatedButton.styleFrom(

                    backgroundColor: PremiumTheme.gold,

                    foregroundColor: PremiumTheme.navy,

                    shape: RoundedRectangleBorder(borderRadius: PremiumTheme.radiusLg),

                  ),

                  child: _submitting

                      ? const CircularProgressIndicator(color: PremiumTheme.navy)

                      : const Text('Soumettre pour validation', style: TextStyle(fontWeight: FontWeight.w800)),

                ),

              ),

            ),

        ],

      ),

    );

  }



  Future<void> _pickDoc(void Function(XFile) onPicked) async {

    final source = await showModalBottomSheet<ImageSource>(

      context: context,

      builder: (ctx) => SafeArea(

        child: Column(

          mainAxisSize: MainAxisSize.min,

          children: [

            ListTile(

              leading: const Icon(Icons.photo_library_rounded),

              title: const Text('Galerie'),

              onTap: () => Navigator.pop(ctx, ImageSource.gallery),

            ),

            ListTile(

              leading: const Icon(Icons.photo_camera_rounded),

              title: const Text('Appareil photo'),

              onTap: () => Navigator.pop(ctx, ImageSource.camera),

            ),

          ],

        ),

      ),

    );

    if (source == null) return;

    final file = await _picker.pickImage(source: source, maxWidth: 1600, maxHeight: 1600, imageQuality: 88);

    if (file == null) return;

    onPicked(file);

    setState(() {});

  }



  Widget _docTile(String label, XFile? file, VoidCallback onTap) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 10),

      child: Material(

        color: Colors.white,

        borderRadius: PremiumTheme.radiusMd,

        child: InkWell(

          onTap: onTap,

          borderRadius: PremiumTheme.radiusMd,

          child: Container(

            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),

            decoration: BoxDecoration(

              borderRadius: PremiumTheme.radiusMd,

              border: Border.all(color: file != null ? PremiumTheme.emerald : const Color(0xFFE2E8F0)),

            ),

            child: Row(

              children: [

                Icon(

                  file != null ? Icons.check_circle_rounded : Icons.upload_file_rounded,

                  color: file != null ? PremiumTheme.emerald : PremiumTheme.textMuted,

                ),

                const SizedBox(width: 12),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),

                      if (file != null)

                        Text(

                          file.name,

                          style: PremiumTheme.body.copyWith(fontSize: 11, color: PremiumTheme.textMuted),

                          maxLines: 1,

                          overflow: TextOverflow.ellipsis,

                        ),

                    ],

                  ),

                ),

                const Icon(Icons.chevron_right_rounded, color: PremiumTheme.textMuted),

              ],

            ),

          ),

        ),

      ),

    );

  }



  Widget _header() {

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

              Expanded(

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text('Vendeur professionnel', style: PremiumTheme.display.copyWith(fontSize: 20)),

                    Text('Demande KYC officielle', style: PremiumTheme.body.copyWith(color: Colors.white60, fontSize: 12)),

                  ],

                ),

              ),

              const Icon(Icons.verified_user_rounded, color: PremiumTheme.gold, size: 28),

            ],

          ),

        ),

      ),

    );

  }



  Widget _statusCard() {

    if (_isVerified) {

      return _card(Icons.verified_rounded, PremiumTheme.emerald, 'Compte certifié',

          'Vous êtes vendeur officiel SombaTeka. Paiement in-app activé.');

    }

    if (_hasPending) {

      final docs = (_kyc?['documents'] as List?)?.length ?? 0;

      return _card(Icons.hourglass_top_rounded, PremiumTheme.gold, 'Demande en cours',

          '« ${_kyc!['business_name']} » — $docs document(s) transmis. Validation admin sous 48h.');

    }

    if (_kycStatus == 'rejected') {

      final note = _kyc?['reviewer_note']?.toString();

      return _card(Icons.cancel_rounded, AppColors.danger, 'Demande refusée',

          note != null && note.isNotEmpty ? note : 'Vous pouvez soumettre une nouvelle demande.');

    }

    return _card(Icons.info_outline_rounded, PremiumTheme.blue, 'Pas encore vendeur officiel',

        'Complétez le formulaire et les justificatifs. Données sécurisées sur nos serveurs.');

  }



  Widget _card(IconData icon, Color color, String title, String body) {

    return Container(

      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(

        color: color.withValues(alpha: 0.08),

        borderRadius: PremiumTheme.radiusMd,

        border: Border.all(color: color.withValues(alpha: 0.35)),

      ),

      child: Row(

        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Icon(icon, color: color, size: 28),

          const SizedBox(width: 12),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text(title, style: TextStyle(fontWeight: FontWeight.w800, color: color, fontSize: 15)),

                const SizedBox(height: 4),

                Text(body, style: PremiumTheme.body.copyWith(fontSize: 13, height: 1.4)),

              ],

            ),

          ),

        ],

      ),

    );

  }



  Widget _benefit(IconData icon, String text) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 8),

      child: Row(

        children: [

          Icon(icon, size: 20, color: PremiumTheme.blue),

          const SizedBox(width: 10),

          Expanded(child: Text(text, style: PremiumTheme.body.copyWith(fontSize: 14))),

        ],

      ),

    );

  }



  Widget _field(TextEditingController c, String label, IconData icon, {int maxLines = 1}) {

    return TextField(

      controller: c,

      maxLines: maxLines,

      decoration: InputDecoration(

        labelText: label,

        prefixIcon: Icon(icon, color: PremiumTheme.textMuted, size: 22),

        filled: true,

        fillColor: Colors.white,

        border: OutlineInputBorder(borderRadius: PremiumTheme.radiusMd),

      ),

    );

  }



  Widget _dropdown() {

    return DropdownButtonFormField<String>(

      value: _category,

      decoration: InputDecoration(

        labelText: 'Catégorie principale',

        filled: true,

        fillColor: Colors.white,

        border: OutlineInputBorder(borderRadius: PremiumTheme.radiusMd),

      ),

      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),

      onChanged: (v) => setState(() => _category = v ?? _category),

    );

  }



  Future<({Uint8List bytes, String filename})?> _fileBytes(XFile? file) async {

    if (file == null) return null;

    final bytes = await file.readAsBytes();

    final name = file.name.isNotEmpty ? file.name : 'document.jpg';

    return (bytes: bytes, filename: name);

  }



  Future<void> _submit() async {

    if (_business.text.trim().length < 2) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Nom d\'entreprise requis'), backgroundColor: AppColors.danger),

      );

      return;

    }

    if (_docRccm == null || _docId == null) {

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('RCCM et pièce d\'identité sont obligatoires'),

          backgroundColor: AppColors.danger,

        ),

      );

      return;

    }

    setState(() => _submitting = true);

    try {

      final rccmFile = await _fileBytes(_docRccm);

      final idFile = await _fileBytes(_docId);

      final taxFile = await _fileBytes(_docTax);

      final shopFile = await _fileBytes(_docShop);

      await _data.submitKyc(

        businessName: _business.text.trim(),

        businessType: _category,

        rccm: _rccm.text.trim().isEmpty ? null : _rccm.text.trim(),

        taxId: _taxId.text.trim().isEmpty ? null : _taxId.text.trim(),

        legalRepresentative: _legalRep.text.trim().isEmpty ? null : _legalRep.text.trim(),

        businessAddress: _address.text.trim().isEmpty ? null : _address.text.trim(),

        contactPhone: _contactPhone.text.trim().isEmpty ? null : _contactPhone.text.trim(),

        applicantNote: _applicantNote.text.trim().isEmpty ? null : _applicantNote.text.trim(),

        docRccmBytes: rccmFile?.bytes,

        docRccmFilename: rccmFile?.filename,

        docIdBytes: idFile?.bytes,

        docIdFilename: idFile?.filename,

        docTaxBytes: taxFile?.bytes,

        docTaxFilename: taxFile?.filename,

        docShopBytes: shopFile?.bytes,

        docShopFilename: shopFile?.filename,

      );

      await _data.refreshUser();

      await _load();

      if (!mounted) return;

      HapticFeedback.mediumImpact();

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(

          content: Text('Demande et documents enregistrés — validation sous 48h'),

          backgroundColor: PremiumTheme.emerald,

        ),

      );

    } catch (e) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),

      );

    } finally {

      if (mounted) setState(() => _submitting = false);

    }

  }

}

