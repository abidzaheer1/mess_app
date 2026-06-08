abstract final class Roles {
  static const String admin = 'admin';
  static const String member = 'member';
}

abstract final class ExpenseStatuses {
  static const String paid = 'paid';
  static const String pending = 'pending';
}

abstract final class JoinRequestStatuses {
  static const String pending = 'pending';
  static const String approved = 'approved';
  static const String rejected = 'rejected';
}

class PendingJoin {
  const PendingJoin({
    required this.messId,
    required this.requestId,
    required this.status,
  });

  factory PendingJoin.fromMap(Map<String, dynamic>? data) {
    if (data == null) return const PendingJoin(messId: '', requestId: '', status: '');
    return PendingJoin(
      messId: (data['messId'] as String?) ?? '',
      requestId: (data['requestId'] as String?) ?? '',
      status: (data['status'] as String?) ?? '',
    );
  }

  final String messId;
  final String requestId;
  final String status;

  bool get isPending => status == JoinRequestStatuses.pending;
  bool get isRejected => status == JoinRequestStatuses.rejected;
}

class JoinRequest {
  const JoinRequest({
    required this.id,
    required this.uid,
    required this.displayName,
    required this.status,
    required this.requestedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.inviteCode,
  });

  factory JoinRequest.fromDoc(String id, Map<String, dynamic> data) {
    return JoinRequest(
      id: id,
      uid: (data['uid'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      status: (data['status'] as String?) ?? JoinRequestStatuses.pending,
      requestedAt: ((data['requestedAt'] as num?) ?? 0).toInt(),
      reviewedAt: (data['reviewedAt'] as num?)?.toInt(),
      reviewedBy: data['reviewedBy'] as String?,
      inviteCode: data['inviteCode'] as String?,
    );
  }

  final String id;
  final String uid;
  final String displayName;
  final String status;
  final int requestedAt;
  final int? reviewedAt;
  final String? reviewedBy;
  final String? inviteCode;
}

class UserProfile {
  const UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.phone,
    required this.dateOfBirth,
    required this.photoURL,
    required this.messId,
    required this.role,
    required this.profileComplete,
    this.pendingJoin,
  });

  factory UserProfile.fromMap(String uid, Map<String, dynamic> data) {
    return UserProfile(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      displayName: (data['displayName'] as String?) ?? '',
      phone: data['phone'] as String?,
      dateOfBirth: data['dateOfBirth'] as String?,
      photoURL: data['photoURL'] as String?,
      messId: data['messId'] as String?,
      role: data['role'] as String?,
      profileComplete: (data['profileComplete'] as bool?) ?? false,
      pendingJoin: _parsePendingJoinField(data['pendingJoin']),
    );
  }

  final String uid;
  final String email;
  final String displayName;
  final String? phone;
  final String? dateOfBirth;
  final String? photoURL;
  final String? messId;
  final String? role;
  final bool profileComplete;
  final PendingJoin? pendingJoin;

  Map<String, dynamic> toUpdateMap({
    String? displayName,
    String? phone,
    String? dateOfBirth,
    bool? profileComplete,
  }) {
    return <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (phone != null) 'phone': phone,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      if (profileComplete != null) 'profileComplete': profileComplete,
    };
  }
}

class Mess {
  const Mess({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    required this.currentDuty,
    this.currency = 'AED',
    this.rotationOrder = const [],
    this.rotationCycle = 'daily',
    this.lastDutyDate,
  });

  factory Mess.fromDoc(String id, Map<String, dynamic> data) {
    final dutyRaw = data['currentDuty'];
    final rotationRaw = data['rotationOrder'];
    return Mess(
      id: id,
      name: (data['name'] as String?) ?? 'Mess',
      inviteCode: (data['inviteCode'] as String?) ?? '',
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: ((data['createdAt'] as num?) ?? 0).toInt(),
      currentDuty:
          dutyRaw is Map<String, dynamic> ? DutyInfo.fromMap(dutyRaw) : null,
      currency: (data['currency'] as String?) ?? 'AED',
      rotationOrder: rotationRaw is List
          ? rotationRaw.map((e) => e.toString()).toList()
          : const [],
      rotationCycle: (data['rotationCycle'] as String?) ?? 'daily',
      lastDutyDate: data['lastDutyDate'] as String?,
    );
  }

  final String id;
  final String name;
  final String inviteCode;
  final String createdBy;
  final int createdAt;
  final DutyInfo? currentDuty;
  final String currency;
  final List<String> rotationOrder;
  final String rotationCycle;
  final String? lastDutyDate;
}

class DutyInfo {
  const DutyInfo({
    required this.assigneeUid,
    required this.assigneeName,
    required this.type,
    required this.description,
    required this.date,
  });

  factory DutyInfo.fromMap(Map<String, dynamic> m) {
    return DutyInfo(
      assigneeUid: (m['assigneeUid'] as String?) ?? '',
      assigneeName: (m['assigneeName'] as String?) ?? '',
      type: (m['type'] as String?) ?? '',
      description: (m['description'] as String?) ?? '',
      date: (m['date'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'assigneeUid': assigneeUid,
      'assigneeName': assigneeName,
      'type': type,
      'description': description,
      'date': date,
    };
  }

  final String assigneeUid;
  final String assigneeName;
  final String type;
  final String description;
  final String date;
}

class Member {
  const Member({
    required this.uid,
    required this.displayName,
    required this.photoURL,
    required this.role,
    required this.joinedAt,
    this.chatLastReadAt,
  });

  factory Member.fromMap(Map<String, dynamic> m, String fallbackUid) {
    return Member(
      uid: (m['uid'] as String?) ?? fallbackUid,
      displayName: (m['displayName'] as String?) ?? 'Member',
      photoURL: m['photoURL'] as String?,
      role: (m['role'] as String?) ?? Roles.member,
      joinedAt: ((m['joinedAt'] as num?) ?? 0).toInt(),
      chatLastReadAt: (m['chatLastReadAt'] as num?)?.toInt(),
    );
  }

  final String uid;
  final String displayName;
  final String? photoURL;
  final String role;
  final int joinedAt;
  final int? chatLastReadAt;
}

class Expense {
  const Expense({
    required this.id,
    required this.title,
    required this.amount,
    required this.category,
    required this.paidByUid,
    required this.paidByName,
    required this.status,
    required this.createdAt,
    required this.expenseDate,
    this.receiptUrl,
    this.receiptBase64,
    this.receiptContentType,
    this.eventId,
  });

  factory Expense.fromDoc(String id, Map<String, dynamic> data) {
    final amountRaw = data['amount'];
    final amount = switch (amountRaw) {
      num v => v.toDouble(),
      _ => double.tryParse(amountRaw?.toString() ?? '') ?? 0.0,
    };
    return Expense(
      id: id,
      title: (data['title'] as String?) ?? '',
      amount: amount,
      category: (data['category'] as String?) ?? 'general',
      paidByUid: (data['paidByUid'] as String?) ?? '',
      paidByName: (data['paidByName'] as String?) ?? '',
      status: (data['status'] as String?) ?? ExpenseStatuses.pending,
      createdAt: ((data['createdAt'] as num?) ?? 0).toInt(),
      expenseDate: (data['expenseDate'] as String?) ?? '',
      receiptUrl: data['receiptUrl'] as String?,
      receiptBase64: data['receiptBase64'] as String?,
      receiptContentType: data['receiptContentType'] as String?,
      eventId: data['eventId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'title': title,
      'amount': amount,
      'category': category,
      'paidByUid': paidByUid,
      'paidByName': paidByName,
      'status': status,
      'expenseDate': expenseDate,
      if (receiptUrl != null && receiptUrl!.isNotEmpty) 'receiptUrl': receiptUrl,
      if (receiptBase64 != null && receiptBase64!.isNotEmpty) 'receiptBase64': receiptBase64,
      if (receiptContentType != null && receiptContentType!.isNotEmpty)
        'receiptContentType': receiptContentType,
      if (eventId != null && eventId!.isNotEmpty) 'eventId': eventId,
    };
  }

  final String id;
  final String title;
  final double amount;
  final String category;
  final String paidByUid;
  final String paidByName;
  final String status;
  final int createdAt;
  final String expenseDate;
  final String? receiptUrl;
  final String? receiptBase64;
  final String? receiptContentType;
  final String? eventId;

  bool get hasReceipt =>
      (receiptBase64 != null && receiptBase64!.isNotEmpty) ||
      (receiptUrl != null && receiptUrl!.isNotEmpty);

  DateTime? get expenseDateParsed {
    try {
      return DateTime.parse(expenseDate);
    } catch (_) {
      final ts = DateTime.fromMillisecondsSinceEpoch(
        createdAt,
        isUtc: false,
      );
      return DateTime(ts.year, ts.month, ts.day);
    }
  }
}

/// Equal split among members who had already joined when each expense was recorded.
/// Skips event-tagged expenses — those are split only among event joiners.
double netBalanceEqualSplit({
  required String uid,
  required List<Expense> expensesInPeriod,
  required List<Member> members,
}) {
  if (members.isEmpty) return 0;
  var owedShare = 0.0;
  var paid = 0.0;
  for (final e in expensesInPeriod) {
    if (e.eventId != null && e.eventId!.isNotEmpty) continue;
    final expenseMs = _expenseMillis(e);
    final active = members.where((m) => m.joinedAt <= expenseMs).toList();
    final n = active.length;
    if (n == 0) continue;
    if (active.any((m) => m.uid == uid)) {
      owedShare += e.amount / n;
    }
    if (e.paidByUid == uid) paid += e.amount;
  }
  return paid - owedShare;
}

int _expenseMillis(Expense e) {
  final parsed = e.expenseDateParsed;
  if (parsed != null) {
    return DateTime(parsed.year, parsed.month, parsed.day).millisecondsSinceEpoch;
  }
  return e.createdAt;
}

String messInviteQrPayload(String inviteCode) => 'ALPHAMESS:JOIN:$inviteCode';

/// Retention window for expenses, chat, alerts (matches the user's request).
const Duration appRetentionWindow = Duration(days: 60);

int retentionCutoffMillis() {
  return DateTime.now().subtract(appRetentionWindow).millisecondsSinceEpoch;
}

abstract final class ChatMessageKinds {
  static const String text = 'text';
  static const String voice = 'voice';
  static const String system = 'system';
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.kind,
    required this.senderUid,
    required this.senderName,
    required this.createdAt,
    this.text,
    this.audioBase64,
    this.audioContentType,
    this.audioDurationMs,
    this.eventId,
  });

  factory ChatMessage.fromDoc(String id, Map<String, dynamic> data) {
    return ChatMessage(
      id: id,
      kind: (data['kind'] as String?) ?? ChatMessageKinds.text,
      senderUid: (data['senderUid'] as String?) ?? '',
      senderName: (data['senderName'] as String?) ?? 'Member',
      createdAt: ((data['createdAt'] as num?) ?? 0).toInt(),
      text: data['text'] as String?,
      audioBase64: data['audioBase64'] as String?,
      audioContentType: data['audioContentType'] as String?,
      audioDurationMs: (data['audioDurationMs'] as num?)?.toInt(),
      eventId: data['eventId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'kind': kind,
      'senderUid': senderUid,
      'senderName': senderName,
      'createdAt': createdAt,
      if (text != null && text!.isNotEmpty) 'text': text,
      if (audioBase64 != null && audioBase64!.isNotEmpty) 'audioBase64': audioBase64,
      if (audioContentType != null) 'audioContentType': audioContentType,
      if (audioDurationMs != null) 'audioDurationMs': audioDurationMs,
      if (eventId != null && eventId!.isNotEmpty) 'eventId': eventId,
    };
  }

  final String id;
  final String kind;
  final String senderUid;
  final String senderName;
  final int createdAt;
  final String? text;
  final String? audioBase64;
  final String? audioContentType;
  final int? audioDurationMs;
  final String? eventId;

  bool get isVoice => kind == ChatMessageKinds.voice && audioBase64 != null;
  bool get isSystem => kind == ChatMessageKinds.system;
}

abstract final class EventStatuses {
  static const String upcoming = 'upcoming';
  static const String active = 'active';
  static const String closed = 'closed';
}

class MessEvent {
  const MessEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.createdAt,
    required this.startsAt,
    required this.status,
    required this.joinerUids,
    this.estimatedCost,
  });

  factory MessEvent.fromDoc(String id, Map<String, dynamic> data) {
    final joiners = data['joinerUids'];
    final costRaw = data['estimatedCost'];
    final estimatedCost = switch (costRaw) {
      num v => v.toDouble(),
      _ => double.tryParse(costRaw?.toString() ?? ''),
    };
    return MessEvent(
      id: id,
      title: (data['title'] as String?) ?? 'Event',
      description: (data['description'] as String?) ?? '',
      createdBy: (data['createdBy'] as String?) ?? '',
      createdAt: ((data['createdAt'] as num?) ?? 0).toInt(),
      startsAt: ((data['startsAt'] as num?) ?? 0).toInt(),
      status: (data['status'] as String?) ?? EventStatuses.upcoming,
      joinerUids: joiners is List
          ? joiners.map((e) => e.toString()).toList()
          : const <String>[],
      estimatedCost: estimatedCost,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'startsAt': startsAt,
      'status': status,
      'joinerUids': joinerUids,
      if (estimatedCost != null && estimatedCost! > 0) 'estimatedCost': estimatedCost,
    };
  }

  bool isJoiner(String uid) => joinerUids.contains(uid);

  double get estimatedPerPerson {
    if (estimatedCost == null || estimatedCost! <= 0 || joinerUids.isEmpty) return 0;
    return estimatedCost! / joinerUids.length;
  }

  final String id;
  final String title;
  final String description;
  final String createdBy;
  final int createdAt;
  final int startsAt;
  final String status;
  final List<String> joinerUids;
  final double? estimatedCost;
}

/// Equal split among the event joiners on expenses tagged with this eventId.
double eventNetBalance({
  required String uid,
  required MessEvent event,
  required List<Expense> eventExpenses,
}) {
  if (event.joinerUids.isEmpty) return 0;
  if (!event.isJoiner(uid)) {
    return event.joinerUids.contains(uid) ? 0 : 0;
  }
  var paid = 0.0;
  var owed = 0.0;
  for (final e in eventExpenses) {
    final n = event.joinerUids.length;
    if (event.isJoiner(uid)) owed += e.amount / n;
    if (e.paidByUid == uid) paid += e.amount;
  }
  return paid - owed;
}

abstract final class NotificationKinds {
  static const String join = 'join';
  static const String chat = 'chat';
  static const String event = 'event';
  static const String groceryDuty = 'grocery_duty';
  static const String dutySwap = 'duty_swap';
}

abstract final class DutySwapRequestStatuses {
  static const String pending = 'pending';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';
  static const String cancelled = 'cancelled';
}

class DutySwapRequest {
  const DutySwapRequest({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory DutySwapRequest.fromDoc(String id, Map<String, dynamic> data) {
    return DutySwapRequest(
      id: id,
      fromUid: (data['fromUid'] as String?) ?? '',
      fromName: (data['fromName'] as String?) ?? '',
      toUid: (data['toUid'] as String?) ?? '',
      toName: (data['toName'] as String?) ?? '',
      status: (data['status'] as String?) ?? DutySwapRequestStatuses.pending,
      createdAt: ((data['createdAt'] as num?) ?? 0).toInt(),
      respondedAt: (data['respondedAt'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'fromUid': fromUid,
      'fromName': fromName,
      'toUid': toUid,
      'toName': toName,
      'status': status,
      'createdAt': createdAt,
      if (respondedAt != null) 'respondedAt': respondedAt,
    };
  }

  final String id;
  final String fromUid;
  final String fromName;
  final String toUid;
  final String toName;
  final String status;
  final int createdAt;
  final int? respondedAt;

  bool get isPending => status == DutySwapRequestStatuses.pending;
}

class MessNotification {
  const MessNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.targetUid,
    this.refId,
  });

  factory MessNotification.fromDoc(String id, Map<String, dynamic> data) {
    return MessNotification(
      id: id,
      kind: (data['kind'] as String?) ?? '',
      title: (data['title'] as String?) ?? '',
      body: (data['body'] as String?) ?? '',
      createdAt: ((data['createdAt'] as num?) ?? 0).toInt(),
      targetUid: (data['targetUid'] as String?) ?? '',
      refId: data['refId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return <String, dynamic>{
      'kind': kind,
      'title': title,
      'body': body,
      'createdAt': createdAt,
      'targetUid': targetUid,
      if (refId != null) 'refId': refId,
    };
  }

  final String id;
  final String kind;
  final String title;
  final String body;
  final int createdAt;
  final String targetUid;
  final String? refId;
}

PendingJoin? _parsePendingJoinField(Object? raw) {
  if (raw is! Map) return null;
  return PendingJoin.fromMap(Map<String, dynamic>.from(raw));
}

String? parseInviteCodeFromQr(String raw) {
  final trimmed = raw.trim().toUpperCase();
  const prefix = 'ALPHAMESS:JOIN:';
  if (trimmed.startsWith(prefix)) {
    return trimmed.substring(prefix.length).trim();
  }
  if (trimmed.length >= 4 && trimmed.length <= 12) return trimmed;
  return null;
}
