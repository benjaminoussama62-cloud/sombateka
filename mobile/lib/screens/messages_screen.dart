import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../services/onboarding_service.dart';
import '../utils/constants.dart';
import '../utils/date_format.dart';
import '../widgets/app_tour_overlay.dart';
import '../widgets/conversation_actions.dart';
import 'chat_screen.dart';
import '../theme/premium_theme.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _data = DataService();

  bool get _isSeller => _data.isOfficialSeller;

  List<Map<String, dynamic>> get _all =>
      _data.currentUser == null ? [] : _data.getUserConversations(_data.currentUser!['id'].toString());

  List<Map<String, dynamic>> get _support =>
      _all.where((c) => c['isTeamPeer'] == true).toList();

  List<Map<String, dynamic>> get _marketplace =>
      _all.where((c) => c['isTeamPeer'] != true).toList();

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppTourPresenter.maybeShow(context, AppTourPage.messages);
    });
  }

  Future<void> _load() async {
    try {
      await _data.refreshConversations();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: Column(
        children: [
          _header(),
          Expanded(child: _inbox()),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      decoration: PremiumTheme.heroGradient,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 12, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text('💬', style: TextStyle(fontSize: 22)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Messages', style: PremiumTheme.display.copyWith(fontSize: 22)),
                    Text(
                      _isSeller
                          ? '${_marketplace.length} ventes · ${_support.length} aide'
                          : '${_marketplace.length} achats · centre d\'aide en lecture seule',
                      style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _inbox() {
    if (_all.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: PremiumTheme.blue.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat_bubble_outline_rounded, size: 56, color: PremiumTheme.blue.withValues(alpha: 0.5)),
              ),
              const SizedBox(height: 20),
              Text('Aucune conversation', style: PremiumTheme.h1),
              const SizedBox(height: 8),
              Text(
                'Contactez un vendeur depuis une fiche produit.\nLe centre d\'aide se trouve dans Paramètres.',
                style: PremiumTheme.body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Centre d\'aide'),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_support.isNotEmpty) ...[
          _sectionTitle('Centre d\'aide', 'Lecture seule · réponses officielles', Icons.support_agent_rounded),
          const SizedBox(height: 8),
          ..._support.map(_supportTile),
          const SizedBox(height: 20),
        ],
        if (_marketplace.isNotEmpty) ...[
          _sectionTitle(
            _isSeller ? 'Discussions ventes' : 'Mes achats & négociations',
            'Un fil par produit',
            Icons.storefront_rounded,
          ),
          const SizedBox(height: 8),
          ..._marketplace.map(_marketTile),
        ],
      ],
    );
  }

  Widget _sectionTitle(String title, String subtitle, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: PremiumTheme.blue),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: PremiumTheme.h1.copyWith(fontSize: 15)),
              Text(subtitle, style: PremiumTheme.label.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _supportTile(Map<String, dynamic> c) {
    final unread = (c['unreadCount'] as int?) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFEFF6FF),
        borderRadius: PremiumTheme.radiusMd,
        child: InkWell(
          onTap: () => _openChat(c, readOnly: true),
          borderRadius: PremiumTheme.radiusMd,
          child: Ink(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: PremiumTheme.radiusMd,
              border: Border.all(color: PremiumTheme.blue.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: PremiumTheme.blue.withValues(alpha: 0.15),
                  child: const Icon(Icons.support_agent_rounded, color: PremiumTheme.blue),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Centre d\'aide SombaTeka', style: PremiumTheme.h1.copyWith(fontSize: 14, color: PremiumTheme.blue)),
                      Text(
                        c['lastMessage']?.toString() ?? 'Aucun message',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: PremiumTheme.body.copyWith(fontSize: 13),
                      ),
                      if (c['lastMessageTime'] != null)
                        Text(formatMessageTime(c['lastMessageTime']), style: PremiumTheme.label.copyWith(fontSize: 10)),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: PremiumTheme.blue, borderRadius: BorderRadius.circular(12)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                const Icon(Icons.chevron_right_rounded, color: PremiumTheme.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _marketTile(Map<String, dynamic> c) {
    final unread = (c['unreadCount'] as int?) ?? 0;
    final thumb = c['listingImageUrl']?.toString() ?? '';
    final listingTitle = c['listingTitle']?.toString() ?? '';
    final peerName = c['userName']?.toString() ?? 'Utilisateur';
    final isShop = c['isOfficialPeer'] == true;
    final primaryTitle = _isSeller && listingTitle.isNotEmpty ? listingTitle : (isShop && listingTitle.isNotEmpty ? listingTitle : peerName);
    final subtitle = _isSeller
        ? 'Acheteur · $peerName'
        : (isShop ? 'Boutique · $peerName' : (listingTitle.isNotEmpty ? listingTitle : 'Annonce'));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: PremiumTheme.radiusMd,
        child: InkWell(
          onTap: () => _openChat(c, readOnly: false),
          onLongPress: () => showConversationActions(
            context,
            data: _data,
            peerId: c['peer_id']?.toString() ?? '',
            listingId: c['listingId']?.toString(),
            isOfficialPeer: isShop,
            isTeamPeer: false,
            onChanged: _load,
          ),
          borderRadius: PremiumTheme.radiusMd,
          child: Ink(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: PremiumTheme.radiusMd,
              boxShadow: PremiumTheme.softShadow,
            ),
            child: Row(
              children: [
                if (thumb.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(thumb, width: 52, height: 52, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _avatar(c)),
                  )
                else
                  _avatar(c),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(primaryTitle, style: PremiumTheme.h1.copyWith(fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          if (isShop) const Icon(Icons.verified_rounded, size: 14, color: PremiumTheme.blue),
                        ],
                      ),
                      if (subtitle.isNotEmpty)
                        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: PremiumTheme.label.copyWith(fontSize: 11, color: PremiumTheme.blue)),
                      const SizedBox(height: 4),
                      Text(c['lastMessage']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: PremiumTheme.body.copyWith(fontSize: 13)),
                      if (c['lastMessageTime'] != null)
                        Text(formatMessageTime(c['lastMessageTime']), style: PremiumTheme.label.copyWith(fontSize: 11, color: PremiumTheme.textMuted)),
                    ],
                  ),
                ),
                if (unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: PremiumTheme.blue, borderRadius: BorderRadius.circular(12)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatar(Map<String, dynamic> c) {
    return CircleAvatar(
      radius: 26,
      backgroundColor: PremiumTheme.blue.withValues(alpha: 0.15),
      child: Text(
        (c['userName'] as String? ?? 'U').substring(0, 1).toUpperCase(),
        style: const TextStyle(fontWeight: FontWeight.bold, color: PremiumTheme.blue),
      ),
    );
  }

  Future<void> _openChat(Map<String, dynamic> c, {required bool readOnly}) async {
    final peerId = c['peer_id']?.toString() ?? '';
    if (peerId.isEmpty) return;
    final isTeam = c['isTeamPeer'] == true;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: peerId,
          peerName: isTeam ? 'Centre d\'aide SombaTeka' : (c['userName']?.toString() ?? 'Utilisateur'),
          listingId: c['listingId']?.toString(),
          listingTitle: c['listingTitle']?.toString(),
          listingImageUrl: c['listingImageUrl']?.toString(),
          isOfficialPeer: c['isOfficialPeer'] == true,
          isTeamPeer: isTeam,
          allowHelpdeskCompose: isTeam && !readOnly,
        ),
      ),
    );
    if (mounted) await _load();
  }
}
