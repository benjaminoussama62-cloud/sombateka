import 'package:flutter/material.dart';
import '../services/data_service.dart';
import '../utils/date_format.dart';
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

  List<Map<String, dynamic>> get _conversations {
    if (_data.currentUser == null) return [];
    return _data.getUserConversations(_data.currentUser!['id'].toString());
  }

  @override
  void initState() {
    super.initState();
    _load();
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
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
          child: Row(
            children: [
              const Icon(Icons.forum_rounded, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Messages', style: PremiumTheme.display.copyWith(fontSize: 22)),
                    Text(
                      _isSeller
                          ? '${_conversations.length} discussions · produit + acheteur'
                          : '${_conversations.length} conversations · 1 fil par produit',
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
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline_rounded, size: 64, color: PremiumTheme.blue.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text('Aucun message', style: PremiumTheme.h1),
            Text('Contactez depuis une annonce (chaque produit = une discussion)', style: PremiumTheme.body, textAlign: TextAlign.center),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final c = _conversations[i];
        final unread = (c['unreadCount'] as int?) ?? 0;
        final thumb = c['listingImageUrl']?.toString() ?? '';
        final listingTitle = c['listingTitle']?.toString() ?? '';
        final peerName = c['userName']?.toString() ?? 'Utilisateur';
        final isShop = c['isOfficialPeer'] == true;
        final primaryTitle = _isSeller && listingTitle.isNotEmpty
            ? listingTitle
            : (isShop && listingTitle.isNotEmpty ? listingTitle : peerName);
        final subtitle = _isSeller
            ? 'Acheteur · $peerName'
            : (isShop ? 'Boutique · $peerName' : (listingTitle.isNotEmpty ? listingTitle : 'Annonce'));
        return Material(
          color: Colors.white,
          borderRadius: PremiumTheme.radiusMd,
          child: InkWell(
            onTap: () => _openChat(c),
            onLongPress: () => showConversationActions(
              context,
              data: _data,
              peerId: c['peer_id']?.toString() ?? '',
              listingId: c['listingId']?.toString(),
              isOfficialPeer: c['isOfficialPeer'] == true,
              isTeamPeer: c['isTeamPeer'] == true,
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
                      child: Image.network(thumb, width: 52, height: 52, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatar(c)),
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
                              child: Text(
                                primaryTitle,
                                style: PremiumTheme.h1.copyWith(fontSize: 14),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isShop)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.verified_rounded, size: 14, color: PremiumTheme.gold),
                              ),
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: PremiumTheme.label.copyWith(fontSize: 11, color: PremiumTheme.blue),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          c['lastMessage']?.toString() ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PremiumTheme.body.copyWith(fontSize: 13),
                        ),
                        if (c['lastMessageTime'] != null)
                          Text(
                            formatMessageTime(c['lastMessageTime']),
                            style: PremiumTheme.label.copyWith(fontSize: 11, color: PremiumTheme.textMuted),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert_rounded, size: 20),
                    onPressed: () => showConversationActions(
                      context,
                      data: _data,
                      peerId: c['peer_id']?.toString() ?? '',
                      listingId: c['listingId']?.toString(),
                      isOfficialPeer: c['isOfficialPeer'] == true,
                      isTeamPeer: c['isTeamPeer'] == true,
                      onChanged: _load,
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
        );
      },
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

  Future<void> _openChat(Map<String, dynamic> c) async {
    final peerId = c['peer_id']?.toString() ?? '';
    if (peerId.isEmpty) return;
    final name = c['userName']?.toString() ?? 'Utilisateur';
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerId: peerId,
          peerName: name,
          listingId: c['listingId']?.toString(),
          listingTitle: c['listingTitle']?.toString(),
          listingImageUrl: c['listingImageUrl']?.toString(),
          isOfficialPeer: c['isOfficialPeer'] == true,
          isTeamPeer: c['isTeamPeer'] == true,
        ),
      ),
    );
    if (mounted) await _load();
  }
}
