import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../screens/chat_screen.dart';
import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/constants.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _data = DataService();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await _data.loadNotifications();
    if (mounted) setState(() => _loading = false);
  }

  bool _isSupportNotification(String type) {
    const supportTypes = {
      'support_reply',
      'team_warning',
      'kyc_approved',
      'kyc_rejected',
      'account_banned',
      'account_unbanned',
      'official_revoked',
      'listing_hidden',
    };
    return supportTypes.contains(type);
  }

  Future<void> _onNotificationTap(Map<String, dynamic> item) async {
    final id = item['id'];
    if (id is int) {
      await _data.markNotificationRead(id);
      if (mounted) setState(() {});
    }

    final type = item['type']?.toString() ?? '';
    if (!_isSupportNotification(type) || !mounted) return;

    try {
      final contact = await _data.fetchSupportContact();
      if (!mounted) return;
      final peerId = contact['peer_id']?.toString();
      if (peerId == null) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChatScreen(
            peerId: peerId,
            peerName: contact['display_name']?.toString() ?? 'Équipe SombaTeka',
            isTeamPeer: true,
          ),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final items = _data.notifications;

    return Scaffold(
      backgroundColor: PremiumTheme.surface,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: PremiumTheme.heroGradient,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
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
                          Text('Notifications', style: PremiumTheme.display.copyWith(fontSize: 22)),
                          Text(
                            '${_data.unreadNotificationCount} non lue(s)',
                            style: PremiumTheme.body.copyWith(color: Colors.white60, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (items.isNotEmpty)
                      TextButton(
                        onPressed: () async {
                          await _data.markAllNotificationsRead();
                          if (mounted) setState(() {});
                        },
                        child: const Text('Tout lire', style: TextStyle(color: PremiumTheme.gold)),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: PremiumTheme.blue))
                : items.isEmpty
                    ? _empty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: PremiumTheme.blue,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _NotificationTile(
                            item: items[i],
                            onTap: () => _onNotificationTap(items[i]),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none_rounded, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('Aucune notification', style: PremiumTheme.h1.copyWith(fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              'Les likes, paiements et messages apparaîtront ici.',
              textAlign: TextAlign.center,
              style: PremiumTheme.body,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final type = item['type']?.toString() ?? 'system';
    final read = item['is_read'] == true;
    final icon = _iconFor(type);
    final color = _colorFor(type);

    return Material(
      color: read ? Colors.white : PremiumTheme.blue.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: read ? AppColors.border : PremiumTheme.blue.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item['title']?.toString() ?? '',
                            style: PremiumTheme.h1.copyWith(
                              fontSize: 15,
                              color: read ? AppColors.textPrimary : PremiumTheme.navy,
                            ),
                          ),
                        ),
                        if (!read)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(color: PremiumTheme.blue, shape: BoxShape.circle),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['body']?.toString() ?? '',
                      style: PremiumTheme.body.copyWith(fontSize: 13, height: 1.4),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _formatTime(item['created_at']?.toString()),
                      style: PremiumTheme.label.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'listing_liked':
        return Icons.favorite_rounded;
      case 'payment_cancelled':
        return Icons.cancel_rounded;
      case 'payment_completed':
        return Icons.payments_rounded;
      case 'message':
      case 'support_reply':
        return Icons.support_agent_rounded;
      case 'team_warning':
      case 'kyc_approved':
      case 'kyc_rejected':
      case 'account_banned':
      case 'account_unbanned':
      case 'official_revoked':
      case 'listing_hidden':
        return Icons.chat_rounded;
      case 'welcome':
        return Icons.celebration_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorFor(String type) {
    switch (type) {
      case 'listing_liked':
        return const Color(0xFFEC4899);
      case 'payment_cancelled':
        return AppColors.danger;
      case 'payment_completed':
        return PremiumTheme.emerald;
      case 'message':
      case 'support_reply':
        return PremiumTheme.blue;
      case 'team_warning':
        return AppColors.danger;
      case 'kyc_approved':
      case 'account_unbanned':
        return PremiumTheme.emerald;
      case 'kyc_rejected':
      case 'account_banned':
      case 'listing_hidden':
        return AppColors.danger;
      case 'official_revoked':
        return const Color(0xFFD97706);
      case 'welcome':
        return PremiumTheme.gold;
      default:
        return PremiumTheme.blue;
    }
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inHours < 1) return 'Il y a ${diff.inMinutes} min';
      if (diff.inDays < 1) return 'Il y a ${diff.inHours} h';
      return 'Il y a ${diff.inDays} j';
    } catch (_) {
      return '';
    }
  }
}
