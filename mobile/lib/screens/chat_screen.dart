import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/message_bubble.dart';
import '../services/data_service.dart';
import '../theme/premium_theme.dart';
import '../utils/app_feedback.dart';
import '../utils/api_errors.dart';
import '../utils/constants.dart';
import '../utils/date_format.dart';
import '../widgets/conversation_actions.dart';
import '../widgets/review_sheet.dart';

/// Discussion liée à une annonce ou vendeur officiel.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.peerId,
    required this.peerName,
    this.listingId,
    this.listingTitle,
    this.listingImageUrl,
    this.isOfficialPeer = false,
    this.isTeamPeer = false,
    this.allowHelpdeskCompose = false,
    this.initialDraft,
    this.autoSendMessage,
  });

  final String peerId;
  final String peerName;
  final String? listingId;
  final String? listingTitle;
  final String? listingImageUrl;
  final bool isOfficialPeer;
  final bool isTeamPeer;
  /// Écriture centre d'aide : uniquement depuis Paramètres.
  final bool allowHelpdeskCompose;
  final String? initialDraft;
  /// Si renseigné, envoi automatique au chargement (messages rapides fiche produit).
  final String? autoSendMessage;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _data = DataService();
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  Map<String, dynamic>? _reviewEligibility;

  bool get _isHelpdesk => widget.isTeamPeer;

  bool get _helpdeskReadOnly => _isHelpdesk && !widget.allowHelpdeskCompose;

  bool get _isSellerInbox {
    final me = _data.currentUser;
    if (me == null) return false;
    return me['is_verified_seller'] == true || me['status'] == AppStatus.official;
  }

  static const _quickReplies = [
    'Comment puis-je récupérer l\'article ?',
    'L\'article est-il encore disponible ?',
    'Quel est votre dernier prix ?',
    'Livraison possible ?',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialDraft != null && widget.initialDraft!.isNotEmpty) {
      _input.text = widget.initialDraft!;
    }
    _initChat();
  }

  Future<void> _initChat() async {
    try {
      await _data.prepareChatWithPeer(
        peerId: widget.peerId,
        listingId: widget.listingId,
        isOfficialPeer: widget.isOfficialPeer,
        isTeamPeer: widget.isTeamPeer,
      );
      _reloadMessages();
      await _checkReviewStatus();
      if (widget.autoSendMessage != null && widget.autoSendMessage!.trim().isNotEmpty) {
        await _send(widget.autoSendMessage!.trim());
      }
    } catch (_) {}
    if (mounted) {
      setState(() => _loading = false);
      _scrollToBottom();
    }
  }

  Future<void> _checkReviewStatus() async {
    final lid = int.tryParse(_resolvedListingId() ?? '');
    if (lid == null) return;
    final eligibility = await _data.fetchReviewEligibility(lid);
    if (mounted) setState(() => _reviewEligibility = eligibility);
  }

  void _reloadMessages() {
    _messages = List<Map<String, dynamic>>.from(
      _data.getConversationMessages(
        widget.peerId,
        listingId: widget.listingId,
        isOfficialPeer: widget.isOfficialPeer,
        isTeamPeer: widget.isTeamPeer,
      ),
    );
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? overrideText]) async {
    if (_helpdeskReadOnly) return;
    final text = (overrideText ?? _input.text).trim();
    if (text.isEmpty || _sending) return;
    final user = _data.currentUser;
    if (user == null) {
      Navigator.pushNamed(context, AppRoutes.auth);
      return;
    }
    final listingId = _resolvedListingId();
    if (!_isHelpdesk && (listingId == null || listingId.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Annonce introuvable — ouvrez le chat depuis la fiche produit'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    HapticFeedback.lightImpact();
    _input.clear();
    setState(() {
      _sending = true;
      _messages.add({
        'message': text,
        'isMe': true,
        'timestamp': DateTime.now(),
        'pending': true,
      });
    });
    _scrollToBottom();

    try {
      await _data.sendMessage(
        peerId: widget.peerId,
        senderId: user['id'].toString(),
        content: text,
        listingId: listingId,
        isOfficialPeer: widget.isOfficialPeer,
        isTeamPeer: widget.isTeamPeer,
      );
      if (mounted) {
        setState(() {
          _reloadMessages();
          _sending = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m['pending'] == true);
        _sending = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(friendlyApiError(e, fallback: 'Envoi impossible')),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Widget _buildReviewAction({required bool reviewBuyer}) {
    final canReview = reviewBuyer
        ? (_reviewEligibility?['can_review_buyer'] == true)
        : (_reviewEligibility?['can_review_seller'] == true);
    final alreadyDone = reviewBuyer
        ? (_reviewEligibility?['has_reviewed_buyer'] == true)
        : (_reviewEligibility?['has_reviewed_seller'] == true);

    if (alreadyDone || !canReview && _reviewEligibility != null) {
      if (!alreadyDone) return const SizedBox.shrink();
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF81C784)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 20),
            SizedBox(width: 8),
            Text(
              'Avis déjà envoyé — merci !',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Color(0xFF2E7D32),
              ),
            ),
          ],
        ),
      );
    }

    final target = _reviewEligibility?['review_target_name']?.toString() ??
        (reviewBuyer ? 'l\'acheteur' : 'le vendeur');

    return FilledButton.icon(
      onPressed: () async {
        final lid = int.tryParse(_resolvedListingId()!);
        if (lid == null) return;
        final result = await showReviewSheet(
          context,
          listingTitle: widget.listingTitle ?? 'Annonce',
          title: reviewBuyer ? 'Avis sur l\'acheteur' : 'Votre avis',
          subtitle: 'Évaluez $target',
          submitLabel: reviewBuyer ? 'Envoyer l\'avis acheteur' : 'Envoyer mon avis',
        );
        if (result == null) return;
        try {
          await _data.submitReview(
            listingId: lid,
            rating: result['rating'] as int,
            comment: result['comment']?.toString(),
          );
          if (mounted) {
            await _checkReviewStatus();
            showAppSuccess(context, 'Merci pour votre avis !');
          }
        } catch (e) {
          if (!mounted) return;
          final msg = e.toString();
          if (msg.contains('déjà')) await _checkReviewStatus();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg.contains('déjà') ? 'Vous avez déjà laissé un avis' : 'Impossible d\'envoyer l\'avis'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      },
      icon: const Icon(Icons.star_rounded, size: 18),
      label: Text(reviewBuyer ? 'Noter l\'acheteur' : 'Laisser mon avis'),
      style: FilledButton.styleFrom(
        backgroundColor: PremiumTheme.blue,
        foregroundColor: Colors.white,
      ),
    );
  }

  String? _resolvedListingId() {
    if (widget.listingId != null && widget.listingId!.isNotEmpty) {
      return widget.listingId;
    }
    for (final m in _messages) {
      final lid = m['listingId']?.toString();
      if (lid != null && lid.isNotEmpty) return lid;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        children: [
          _header(),
          if (!_isHelpdesk && widget.listingTitle != null && widget.listingTitle!.isNotEmpty) _listingBanner(),
          if (_isHelpdesk) _helpdeskInfoBanner(),
          Expanded(child: _loading ? const Center(child: CircularProgressIndicator(color: PremiumTheme.blue)) : _messageList()),
          if (!_loading && _messages.isEmpty && !_helpdeskReadOnly) _quickReplyBar(),
          if (_helpdeskReadOnly) _helpdeskReadOnlyBar() else ChatInput(
            controller: _input,
            onSend: () => _send(),
            isLoading: _sending,
            hintText: _isHelpdesk ? 'Votre message au centre d\'aide…' : 'Message…',
          ),
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
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: _isHelpdesk ? PremiumTheme.emerald.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.2),
                child: _isHelpdesk
                    ? const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24)
                    : Text(
                        widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSellerInbox && !_isHelpdesk
                          ? (widget.listingTitle?.isNotEmpty == true ? widget.listingTitle! : widget.peerName)
                          : widget.peerName,
                      style: PremiumTheme.display.copyWith(fontSize: 17),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.isTeamPeer
                          ? 'Centre d\'aide SombaTeka'
                          : _isSellerInbox
                              ? 'Acheteur · ${widget.peerName}'
                              : (widget.isOfficialPeer
                                  ? 'Boutique officielle · ${widget.listingTitle ?? 'Produit'}'
                                  : 'Discussion sur l\'annonce'),
                      style: PremiumTheme.body.copyWith(color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
                onPressed: () => showConversationActions(
                  context,
                  data: _data,
                  peerId: widget.peerId,
                  listingId: widget.listingId,
                  isOfficialPeer: widget.isOfficialPeer,
                  isTeamPeer: widget.isTeamPeer,
                  onChanged: () async {
                    await _initChat();
                    if (mounted) setState(() {});
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _helpdeskInfoBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: const Color(0xFFEFF6FF),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: PremiumTheme.blue.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.verified_rounded, color: PremiumTheme.blue, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Centre d\'aide SombaTeka', style: PremiumTheme.h1.copyWith(fontSize: 13, color: PremiumTheme.blue)),
                Text(
                  _helpdeskReadOnly
                      ? 'Lecture seule ici — réponses officielles de l\'équipe.'
                      : 'Assistance, modération et comptes pro.',
                  style: PremiumTheme.label.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpdeskReadOnlyBar() {
    return Material(
      color: Colors.white,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Pour contacter le support, utilisez Paramètres → Centre d\'aide.',
                textAlign: TextAlign.center,
                style: PremiumTheme.body.copyWith(fontSize: 13, color: PremiumTheme.textMuted),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, AppRoutes.settings);
                  },
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Ouvrir Paramètres', style: TextStyle(fontWeight: FontWeight.w800)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PremiumTheme.blue,
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

  Widget _listingBanner() {
    final img = widget.listingImageUrl ?? '';
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: widget.listingId != null
            ? () => Navigator.pushNamed(context, AppRoutes.detail, arguments: {'id': widget.listingId})
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: img.isNotEmpty
                    ? CachedNetworkImage(imageUrl: img, width: 48, height: 48, fit: BoxFit.cover)
                    : Container(
                        width: 48,
                        height: 48,
                        color: const Color(0xFFE2E8F0),
                        child: const Icon(Icons.image_outlined, color: PremiumTheme.textMuted, size: 22),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isSellerInbox ? 'Produit concerné' : 'Annonce',
                      style: PremiumTheme.label.copyWith(fontSize: 10),
                    ),
                    Text(
                      widget.listingTitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                    if (_isSellerInbox)
                      Text(
                        'Acheteur : ${widget.peerName}',
                        style: PremiumTheme.label.copyWith(fontSize: 11, color: PremiumTheme.blue),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: PremiumTheme.textMuted),
            ],
          ),
        ),
      ),
    );
  }

  List<dynamic> _chatItems() {
    final items = <dynamic>[];
    DateTime? lastDay;
    for (final m in _messages) {
      if (m['pending'] == true) {
        items.add(m);
        continue;
      }
      final ts = m['timestamp'];
      final dt = ts is DateTime
          ? ts
          : (ts != null ? DateTime.tryParse(ts.toString()) ?? DateTime.now() : DateTime.now());
      final day = DateTime(dt.year, dt.month, dt.day);
      if (lastDay == null || day != lastDay) {
        items.add(formatChatDaySeparator(dt));
        lastDay = day;
      }
      items.add(m);
    }
    return items;
  }

  Future<void> _onMessageLongPress(Map<String, dynamic> m) async {
    if (m['pending'] == true) return;
    final isMe = m['isMe'] == true;
    final kind = m['kind']?.toString() ?? 'text';
    if (kind == 'review_request' || kind == 'seller_review_request') return;

    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isMe && m['isRead'] != true)
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Modifier'),
                onTap: () => Navigator.pop(ctx, 'edit'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Color(0xFFE74C3C)),
              title: const Text('Supprimer'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_outlined),
              title: const Text('Copier'),
              onTap: () => Navigator.pop(ctx, 'copy'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    final msgId = int.tryParse(m['id']?.toString() ?? '');
    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: m['message']?.toString() ?? ''));
      if (mounted) showAppSuccess(context, 'Message copié');
      return;
    }
    if (action == 'delete' && msgId != null) {
      try {
        await _data.deleteChatMessage(
          messageId: msgId,
          peerId: widget.peerId,
          listingId: widget.listingId,
          isOfficialPeer: widget.isOfficialPeer,
        );
        if (mounted) {
          setState(_reloadMessages);
          showAppSuccess(context, 'Message supprimé');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Suppression impossible: $e'), backgroundColor: AppColors.danger),
          );
        }
      }
      return;
    }
    if (action == 'edit' && msgId != null && isMe) {
      final ctrl = TextEditingController(text: m['message']?.toString() ?? '');
      final newText = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Modifier le message'),
          content: TextField(controller: ctrl, maxLines: 4, autofocus: true),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      );
      if (newText == null || newText.isEmpty) return;
      try {
        await _data.updateChatMessage(
          messageId: msgId,
          peerId: widget.peerId,
          listingId: widget.listingId,
          isOfficialPeer: widget.isOfficialPeer,
          content: newText,
        );
        if (mounted) {
          setState(_reloadMessages);
          showAppSuccess(context, 'Message modifié');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppColors.danger),
          );
        }
      }
    }
  }

  Widget _messageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.chat_rounded, size: 56, color: PremiumTheme.blue.withValues(alpha: 0.35)),
              const SizedBox(height: 12),
              Text('Négociation', style: PremiumTheme.h1.copyWith(fontSize: 17)),
              const SizedBox(height: 6),
              Text(
                'Choisissez un message rapide ou écrivez au vendeur ci-dessous.',
                textAlign: TextAlign.center,
                style: PremiumTheme.body.copyWith(fontSize: 13),
              ),
            ],
          ),
        ),
      );
    }

    final items = _chatItems();
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      itemBuilder: (_, i) {
        final item = items[i];
        if (item is String) {
          return ChatDateSeparator(label: item);
        }
        final m = item as Map<String, dynamic>;
        final ts = m['timestamp'];
        final dt = ts is DateTime
            ? ts
            : (ts != null ? DateTime.tryParse(ts.toString()) ?? DateTime.now() : DateTime.now());
        final kind = m['kind']?.toString() ?? '';
        final isReviewRequest = kind == 'review_request';
        final isSellerReviewRequest = kind == 'seller_review_request';
        return Column(
          children: [
            MessageBubble(
              message: m['message']?.toString() ?? '',
              isMe: m['isMe'] == true,
              timestamp: dt,
              isEdited: m['edited'] == true,
              isTeamMessage: _isHelpdesk && m['isMe'] != true,
              onLongPress: m['pending'] == true ? null : () => _onMessageLongPress(m),
            ),
            if (isReviewRequest && m['isMe'] != true && _resolvedListingId() != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16, right: 48),
                child: _buildReviewAction(reviewBuyer: false),
              ),
            if (isSellerReviewRequest && m['isMe'] != true && _resolvedListingId() != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 16, right: 48),
                child: _buildReviewAction(reviewBuyer: true),
              ),
          ],
        );
      },
    );
  }

  Widget _quickReplyBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _quickReplies.map((q) {
          return ActionChip(
            label: Text(q, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFBFDBFE)),
            onPressed: _sending ? null : () => _send(q),
          );
        }).toList(),
      ),
    );
  }
}
