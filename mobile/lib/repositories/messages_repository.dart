import '../core/api/api_client.dart';

class MessagesRepository {
  MessagesRepository(this._api);

  final ApiClient _api;

  Future<List<Map<String, dynamic>>> fetchConversations() async {
    try {
      final r = await _api.get<Map<String, dynamic>>('/messages/conversations');
      final items = (r.data?['items'] as List?) ?? [];
      return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchThread(int peerId, {int? listingId}) async {
    final query = <String, dynamic>{'peer_id': peerId};
    if (listingId != null) query['listing_id'] = listingId;
    final r = await _api.get<List<dynamic>>('/messages/', query: query);
    final list = r.data ?? [];
    return list.map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      return {
        'id': map['id'].toString(),
        'senderId': map['sender_id'].toString(),
        'recipientId': map['recipient_id'].toString(),
        'content': map['content'],
        'isRead': map['is_read'],
        'createdAt': map['created_at'],
        'updatedAt': map['updated_at'],
        'kind': map['kind']?.toString() ?? 'text',
        'listingId': map['listing_id']?.toString(),
      };
    }).toList();
  }

  Future<void> sendMessage({
    required int recipientId,
    required String content,
    int? listingId,
  }) async {
    await _api.post('/messages/', data: {
      'recipient_id': recipientId,
      'content': content,
      if (listingId != null) 'listing_id': listingId,
    });
  }

  Future<void> markRead(int senderId, {int? listingId}) async {
    final query = listingId != null ? {'listing_id': listingId} : null;
    await _api.post('/messages/read-all/$senderId', query: query);
  }

  Future<void> hideConversation({required int peerId, int? listingId}) async {
    await _api.delete(
      '/messages/conversations',
      query: {
        'peer_id': peerId,
        if (listingId != null) 'listing_id': listingId,
      },
    );
  }

  Future<void> blockPeer(int peerId) async {
    await _api.post('/messages/block/$peerId');
  }

  Future<void> unblockPeer(int peerId) async {
    await _api.delete('/messages/block/$peerId');
  }

  Future<void> updateMessage(int messageId, String content) async {
    await _api.patch('/messages/$messageId', data: {'content': content});
  }

  Future<void> deleteMessage(int messageId) async {
    await _api.delete('/messages/$messageId');
  }

  Future<void> reportUser({
    required int targetUserId,
    required String reason,
    String? details,
    int? listingId,
  }) async {
    await _api.post('/reports/', data: {
      'target_user_id': targetUserId,
      'reason': reason,
      if (details != null) 'details': details,
      if (listingId != null) 'listing_id': listingId,
    });
  }
}
