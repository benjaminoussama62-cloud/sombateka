import 'package:flutter/material.dart';

import '../services/data_service.dart';
import '../utils/app_feedback.dart';

Future<void> showConversationActions(
  BuildContext context, {
  required DataService data,
  required String peerId,
  String? listingId,
  bool isOfficialPeer = false,
  bool isTeamPeer = false,
  VoidCallback? onChanged,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE74C3C)),
            title: const Text('Supprimer la conversation'),
            onTap: () => Navigator.pop(ctx, 'delete'),
          ),
          ListTile(
            leading: const Icon(Icons.block_rounded),
            title: const Text('Bloquer cet utilisateur'),
            onTap: () => Navigator.pop(ctx, 'block'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Signaler'),
            onTap: () => Navigator.pop(ctx, 'report'),
          ),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  if (action == 'delete') {
    await data.hideConversation(
      peerId: peerId,
      listingId: listingId,
      isOfficialPeer: isOfficialPeer,
      isTeamPeer: isTeamPeer,
    );
    if (context.mounted) {
      showAppSuccess(context, 'Conversation supprimée');
      onChanged?.call();
    }
  } else if (action == 'block') {
    await data.blockPeer(peerId);
    if (context.mounted) {
      showAppSuccess(context, 'Utilisateur bloqué');
      onChanged?.call();
    }
  } else if (action == 'report') {
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final ctrl = TextEditingController();
        return AlertDialog(
          title: const Text('Signaler'),
          content: TextField(controller: ctrl, decoration: const InputDecoration(hintText: 'Motif du signalement')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Envoyer')),
          ],
        );
      },
    );
    if (reason != null && reason.isNotEmpty) {
      await data.reportPeer(peerId: peerId, reason: reason, listingId: listingId);
      if (context.mounted) {
        showAppSuccess(context, 'Signalement envoyé — merci');
        onChanged?.call();
      }
    }
  }
}
