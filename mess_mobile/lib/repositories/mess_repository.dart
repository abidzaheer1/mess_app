import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/app_models.dart';
import '../utils/receipt_firestore.dart';

class MessRepository {
  MessRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance {
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

  final FirebaseFirestore _db;

  /// Web client ID from Firebase (required for Google Sign-In on Android/iOS).
  static const _googleWebClientId =
      '588825672161-j3ndc3p5psijkq85eb610e12hj6kujo8.apps.googleusercontent.com';

  GoogleSignIn get _googleSignIn => GoogleSignIn(
        serverClientId: kIsWeb ? null : _googleWebClientId,
      );

  static final _rng = Random.secure();

  String _genInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      6,
      (_) => chars[_rng.nextInt(chars.length)],
    ).join();
  }

  Stream<auth.User?> get authChanges =>
      auth.FirebaseAuth.instance.authStateChanges();

  auth.User? get currentUser => auth.FirebaseAuth.instance.currentUser;

  Future<void> signIn(String email, String password) {
    return auth.FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> register(String email, String password) {
    return auth.FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> sendPasswordResetEmail(String email) {
    return auth.FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
  }

  Future<bool> signInWithGoogle() async {
    auth.UserCredential cred;
    if (kIsWeb) {
      cred = await auth.FirebaseAuth.instance.signInWithPopup(auth.GoogleAuthProvider());
    } else {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return false;
      final googleAuth = await googleUser.authentication;
      final credential = auth.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      cred = await auth.FirebaseAuth.instance.signInWithCredential(credential);
    }
    await ensureUserBasics(
      uid: cred.user!.uid,
      email: cred.user!.email ?? '',
      displayName: cred.user!.displayName,
    );
    return true;
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } catch (_) {}
    }
    await auth.FirebaseAuth.instance.signOut();
  }

  Stream<UserProfile?> profileStream(String uid) {
    return _db.doc('users/$uid').snapshots().map((snap) {
      if (!snap.exists) return null;
      return UserProfile.fromMap(uid, snap.data()!);
    });
  }

  Future<UserProfile?> fetchUserProfile(String uid) async {
    final snap = await _db.doc('users/$uid').get();
    if (!snap.exists) return null;
    return UserProfile.fromMap(uid, snap.data()!);
  }

  Stream<Member?> memberStream(String messId, String uid) {
    return _db.doc('messes/$messId/members/$uid').snapshots().map((snap) {
      if (!snap.exists) return null;
      return Member.fromMap(snap.data()!, uid);
    });
  }

  /// Copies role from the mess member doc when the user profile is missing it.
  Future<UserProfile?> hydrateProfileRole(UserProfile profile) async {
    final messId = profile.messId;
    if (messId == null || profile.role != null) return profile;

    final memberSnap = await _db.doc('messes/$messId/members/${profile.uid}').get();
    if (!memberSnap.exists) return profile;

    final role = memberSnap.data()?['role'] as String?;
    if (role == null || role.isEmpty) return profile;

    await _db.doc('users/${profile.uid}').set(
      <String, dynamic>{'role': role},
      SetOptions(merge: true),
    );
    return fetchUserProfile(profile.uid);
  }

  Future<void> ensureUserBasics({
    required String uid,
    required String email,
    String? displayName,
  }) async {
    final ref = _db.doc('users/$uid');
    final snap = await ref.get();
    final name = (displayName ?? '').trim().isNotEmpty
        ? displayName!.trim()
        : email.split('@').first;
    if (!snap.exists) {
      await ref.set(<String, dynamic>{
        'uid': uid,
        'email': email,
        'displayName': name,
        'messId': null,
        'role': null,
        'profileComplete': false,
      });
      return;
    }
    if (displayName != null && displayName.trim().isNotEmpty) {
      await ref.set(<String, dynamic>{'displayName': displayName.trim()}, SetOptions(merge: true));
    }
  }

  Future<void> saveProfile({
    required String uid,
    String? displayName,
    String? phone,
    String? dateOfBirth,
    bool? profileComplete,
  }) async {
    final data = <String, dynamic>{
      if (displayName != null) 'displayName': displayName,
      if (phone != null) 'phone': phone,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      if (profileComplete != null) 'profileComplete': profileComplete,
    };
    if (data.isEmpty) return;
    await _db.doc('users/$uid').update(data);
  }

  Stream<Mess?> messStream(String messId) {
    return _db.doc('messes/$messId').snapshots().map((snap) {
      if (!snap.exists) return null;
      return Mess.fromDoc(snap.id, snap.data()!);
    });
  }

  Stream<List<Member>> membersStream(String messId) {
    return _db.collection('messes/$messId/members').snapshots().map(
      (q) =>
          q.docs
              .map((d) => Member.fromMap(d.data(), d.id))
              .toList()
            ..sort((a, b) => a.displayName.compareTo(b.displayName)),
    );
  }

  Stream<List<Expense>> expensesStream(String messId) {
    final cutoff = retentionCutoffMillis();
    final q = _db
        .collection('messes/$messId/expenses')
        .orderBy('createdAt', descending: true)
        .limit(400);

    return q.snapshots().map(
      (s) => s.docs
          .map((d) => Expense.fromDoc(d.id, d.data()))
          .where((e) => e.createdAt == 0 || e.createdAt >= cutoff)
          .toList(),
    );
  }

  Stream<List<Expense>> eventExpensesStream(String messId, String eventId) {
    return _db
        .collection('messes/$messId/expenses')
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((s) {
      final list = s.docs.map((d) => Expense.fromDoc(d.id, d.data())).toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<String> allocateInvite(Transaction tx, {int maxAttempts = 12}) async {
    for (var i = 0; i < maxAttempts; i++) {
      final code = _genInviteCode();
      final inviteRef = _db.doc('messInvites/$code');
      final snap = await tx.get(inviteRef);
      if (!snap.exists) return code;
    }
    throw StateError('Could not allocate invite code.');
  }

  Future<({String messId, String inviteCode})> createMess({
    required String uid,
    required String userName,
    required String name,
  }) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        late final ({String messId, String inviteCode}) result;

        await _db.runTransaction((tx) async {
          final messRef = _db.collection('messes').doc();
          final inviteCode = await allocateInvite(tx);

          tx.set(messRef, <String, dynamic>{
            'name': name.trim(),
            'inviteCode': inviteCode,
            'createdBy': uid,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
            'currentDuty': null,
          });

          tx.set(_db.doc('messInvites/$inviteCode'), <String, dynamic>{
            'messId': messRef.id,
            'createdBy': uid,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });

          tx.set(
            _db.doc('messes/${messRef.id}/members/$uid'),
            <String, dynamic>{
              'uid': uid,
              'displayName': userName.trim(),
              'role': Roles.admin,
              'joinedAt': DateTime.now().millisecondsSinceEpoch,
            },
          );

          tx.set(
            _db.doc('users/$uid'),
            <String, dynamic>{
              'messId': messRef.id,
              'role': Roles.admin,
            },
            SetOptions(merge: true),
          );

          result = (messId: messRef.id, inviteCode: inviteCode);
        });
        return result;
      } catch (_) {
        continue;
      }
    }
    throw StateError('Failed to create mess. Try again.');
  }

  Future<String> resolveMessIdFromInvite(String inviteCodeRaw) async {
    final parsed = parseInviteCodeFromQr(inviteCodeRaw.trim()) ??
        inviteCodeRaw.trim().toUpperCase();
    if (parsed.isEmpty) throw StateError('Enter a valid invite code.');

    final inviteSnap = await _db.doc('messInvites/$parsed').get();
    if (!inviteSnap.exists) {
      throw StateError(
        'Invalid invite code. Ask your admin for the latest code from Profile or Mess settings.',
      );
    }
    final messId = inviteSnap.data()?['messId'] as String?;
    if (messId == null || messId.isEmpty) {
      throw StateError('Invite is missing mess id.');
    }
    return messId;
  }

  Stream<JoinRequest?> joinRequestStream(String messId, String requestId) {
    return _db.doc('messes/$messId/joinRequests/$requestId').snapshots().map((snap) {
      if (!snap.exists) return null;
      return JoinRequest.fromDoc(snap.id, snap.data()!);
    });
  }

  DocumentReference<Map<String, dynamic>> _joinAlertRef(String messId, String requestId) {
    return _db.doc('messes/$messId/joinAlerts/$requestId');
  }

  void _setJoinAlert(
    WriteBatch batch, {
    required String messId,
    required String requestId,
    required String uid,
    required String displayName,
    required int requestedAt,
  }) {
    batch.set(_joinAlertRef(messId, requestId), <String, dynamic>{
      'requestId': requestId,
      'uid': uid,
      'displayName': displayName,
      'requestedAt': requestedAt,
    });
  }

  Future<void> _clearJoinAlert(String messId, String requestId) async {
    try {
      await _joinAlertRef(messId, requestId).delete();
    } catch (_) {
      // Alert may already be gone.
    }
  }

  /// Admin inbox for pending join requests (backed by joinAlerts for reliable reads).
  Stream<List<JoinRequest>> pendingJoinRequestsStream(String messId) {
    return _db.collection('messes/$messId/joinAlerts').snapshots().map((q) {
      final list = q.docs.map((d) {
        final data = d.data();
        return JoinRequest(
          id: (data['requestId'] as String?) ?? d.id,
          uid: (data['uid'] as String?) ?? '',
          displayName: (data['displayName'] as String?) ?? '',
          status: JoinRequestStatuses.pending,
          requestedAt: ((data['requestedAt'] as num?) ?? 0).toInt(),
        );
      }).toList();
      list.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return list;
    });
  }

  Stream<int> pendingJoinRequestCountStream(String messId) {
    return pendingJoinRequestsStream(messId).map((list) => list.length);
  }

  /// Copies pending joinRequests into joinAlerts (for requests created before alerts existed).
  Future<void> syncJoinAlertsFromRequests(String messId) async {
    try {
      final snaps = await _db.collection('messes/$messId/joinRequests').get();
      final batch = _db.batch();
      var pending = 0;
      for (final doc in snaps.docs) {
        final data = doc.data();
        if ((data['status'] as String?) != JoinRequestStatuses.pending) continue;
        pending++;
        batch.set(
          _joinAlertRef(messId, doc.id),
          <String, dynamic>{
            'requestId': doc.id,
            'uid': data['uid'],
            'displayName': data['displayName'],
            'requestedAt': data['requestedAt'],
          },
          SetOptions(merge: true),
        );
      }
      if (pending > 0) await batch.commit();
    } catch (_) {
      // Non-admins or offline — ignore.
    }
  }

  /// Submits a join request for admin approval (does not add member yet).
  Future<({String messId, String requestId})> requestJoinMess({
    required String uid,
    required String userName,
    required String inviteCodeRaw,
  }) async {
    final authUid = currentUser?.uid;
    if (authUid == null || authUid != uid) {
      throw StateError('You must be signed in to join a mess.');
    }

    final code = inviteCodeRaw.trim().toUpperCase();
    final messId = await resolveMessIdFromInvite(code);

    final memberSnap = await _db.doc('messes/$messId/members/$authUid').get();
    if (memberSnap.exists) {
      final md = memberSnap.data();
      final role = (md?['role'] as String?) ?? Roles.member;
      await _db.doc('users/$authUid').set(
        <String, dynamic>{
          'messId': messId,
          'role': role,
          'pendingJoin': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      return (messId: messId, requestId: '');
    }

    final existingForUser = await _db
        .collection('messes/$messId/joinRequests')
        .where('uid', isEqualTo: authUid)
        .get();
    final existingPending = existingForUser.docs.where(
      (d) => (d.data()['status'] as String?) == JoinRequestStatuses.pending,
    );
    if (existingPending.isNotEmpty) {
      final doc = existingPending.first;
      final data = doc.data();
      final requestedAt = ((data['requestedAt'] as num?) ?? DateTime.now().millisecondsSinceEpoch).toInt();
      final alertBatch = _db.batch();
      _setJoinAlert(
        alertBatch,
        messId: messId,
        requestId: doc.id,
        uid: authUid,
        displayName: (data['displayName'] as String?) ?? userName.trim(),
        requestedAt: requestedAt,
      );
      alertBatch.set(
        _db.doc('users/$authUid'),
        <String, dynamic>{
          'pendingJoin': <String, dynamic>{
            'messId': messId,
            'requestId': doc.id,
            'status': JoinRequestStatuses.pending,
          },
        },
        SetOptions(merge: true),
      );
      await alertBatch.commit();
      return (messId: messId, requestId: doc.id);
    }

    final requestRef = _db.collection('messes/$messId/joinRequests').doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    batch.set(requestRef, <String, dynamic>{
      'uid': authUid,
      'displayName': userName.trim(),
      'status': JoinRequestStatuses.pending,
      'requestedAt': now,
      'inviteCode': code,
    });
    _setJoinAlert(
      batch,
      messId: messId,
      requestId: requestRef.id,
      uid: authUid,
      displayName: userName.trim(),
      requestedAt: now,
    );
    batch.set(
      _db.doc('users/$authUid'),
      <String, dynamic>{
        'pendingJoin': <String, dynamic>{
          'messId': messId,
          'requestId': requestRef.id,
          'status': JoinRequestStatuses.pending,
        },
      },
      SetOptions(merge: true),
    );
    await batch.commit();

    // Fan out notifications to admins so they see it on their bell, not just Members tab.
    try {
      final membersSnap = await _db.collection('messes/$messId/members').get();
      final notifBatch = _db.batch();
      var i = 0;
      for (final doc in membersSnap.docs) {
        final role = (doc.data()['role'] as String?) ?? Roles.member;
        if (role != Roles.admin) continue;
        final ref = _db.collection('messes/$messId/notifications').doc();
        notifBatch.set(ref, MessNotification(
          id: ref.id,
          kind: NotificationKinds.join,
          title: 'New join request',
          body: '${userName.trim()} wants to join your mess.',
          createdAt: now + i,
          targetUid: doc.id,
          refId: requestRef.id,
        ).toFirestore());
        i++;
      }
      if (i > 0) await notifBatch.commit();
    } catch (_) {
      // Non-fatal.
    }

    return (messId: messId, requestId: requestRef.id);
  }

  /// Called on the requester's device after admin approves.
  Future<void> finalizeJoinAfterApproval({
    required String uid,
    required String messId,
    required String requestId,
  }) async {
    final reqSnap = await _db.doc('messes/$messId/joinRequests/$requestId').get();
    if (!reqSnap.exists) throw StateError('Join request not found.');
    final req = JoinRequest.fromDoc(reqSnap.id, reqSnap.data()!);
    if (req.uid != uid) throw StateError('This request is not yours.');
    if (req.status != JoinRequestStatuses.approved) {
      throw StateError('Join request is not approved yet.');
    }

    await _db.doc('users/$uid').set(
      <String, dynamic>{
        'messId': messId,
        'role': Roles.member,
        'pendingJoin': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> clearPendingJoin(String uid) async {
    await _db.doc('users/$uid').set(
      <String, dynamic>{'pendingJoin': FieldValue.delete()},
      SetOptions(merge: true),
    );
  }

  Future<void> cancelJoinRequest({
    required String messId,
    required String requestId,
    required String uid,
  }) async {
    final ref = _db.doc('messes/$messId/joinRequests/$requestId');
    final snap = await ref.get();
    if (snap.exists && (snap.data()?['uid'] as String?) == uid) {
      await ref.update(<String, dynamic>{
        'status': JoinRequestStatuses.rejected,
        'reviewedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await _clearJoinAlert(messId, requestId);
    }
    await clearPendingJoin(uid);
  }

  Future<void> approveJoinRequest({
    required String messId,
    required String requestId,
    required String adminUid,
  }) async {
    final reqRef = _db.doc('messes/$messId/joinRequests/$requestId');
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) throw StateError('Join request not found.');
    final req = JoinRequest.fromDoc(reqSnap.id, reqSnap.data()!);
    if (req.status != JoinRequestStatuses.pending) {
      throw StateError('This request was already reviewed.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final batch = _db.batch();
    batch.update(reqRef, <String, dynamic>{
      'status': JoinRequestStatuses.approved,
      'reviewedAt': now,
      'reviewedBy': adminUid,
    });
    batch.set(
      _db.doc('messes/$messId/members/${req.uid}'),
      <String, dynamic>{
        'uid': req.uid,
        'displayName': req.displayName,
        'role': Roles.member,
        'joinedAt': now,
      },
    );
    batch.delete(_joinAlertRef(messId, requestId));

    final notifRef = _db.collection('messes/$messId/notifications').doc();
    batch.set(notifRef, MessNotification(
      id: notifRef.id,
      kind: NotificationKinds.join,
      title: 'Welcome to the mess!',
      body: '${req.displayName}, your join was approved.',
      createdAt: now,
      targetUid: req.uid,
    ).toFirestore());

    await batch.commit();
  }

  Future<void> rejectJoinRequest({
    required String messId,
    required String requestId,
    required String adminUid,
  }) async {
    final reqRef = _db.doc('messes/$messId/joinRequests/$requestId');
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) throw StateError('Join request not found.');
    final req = JoinRequest.fromDoc(reqSnap.id, reqSnap.data()!);
    if (req.status != JoinRequestStatuses.pending) {
      throw StateError('This request was already reviewed.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    await reqRef.update(<String, dynamic>{
      'status': JoinRequestStatuses.rejected,
      'reviewedAt': now,
      'reviewedBy': adminUid,
    });
    await _clearJoinAlert(messId, requestId);
  }

  @Deprecated('Use requestJoinMess for approval flow')
  Future<String> joinMess({
    required String uid,
    required String userName,
    required String inviteCodeRaw,
  }) async {
    final res = await requestJoinMess(
      uid: uid,
      userName: userName,
      inviteCodeRaw: inviteCodeRaw,
    );
    return res.messId;
  }

  Future<String> createExpense(
    String messId,
    Expense expense, {
    Uint8List? receiptBytes,
    String receiptContentType = 'image/jpeg',
  }) async {
    final docRef = _db.collection('messes/$messId/expenses').doc();
    final data = expense.toFirestore()
      ..['createdAt'] = DateTime.now().millisecondsSinceEpoch;

    if (receiptBytes != null && receiptBytes.isNotEmpty) {
      final receipt = encodeReceiptForFirestore(
        receiptBytes,
        contentType: receiptContentType,
      );
      data.addAll(receipt);
    }

    await docRef.set(data);

    // System chat note + notifications so members see new expenses promptly.
    final ts = DateTime.now().millisecondsSinceEpoch;
    final chatRef = _chatRef(messId).doc();
    await chatRef.set(ChatMessage(
      id: chatRef.id,
      kind: ChatMessageKinds.system,
      senderUid: 'system',
      senderName: 'Expenses',
      createdAt: ts,
      text: '${expense.paidByName} added "${expense.title}" — ${expense.amount.toStringAsFixed(2)}',
      eventId: expense.eventId,
    ).toFirestore());

    await _notifyAllOtherMembers(
      messId: messId,
      senderUid: expense.paidByUid,
      kind: NotificationKinds.chat,
      title: 'New expense',
      body: '${expense.paidByName} added "${expense.title}".',
      refId: docRef.id,
    );

    return docRef.id;
  }

  Future<void> updateMemberRole(
    String messId,
    String uid,
    String role,
  ) async {
    final batch = _db.batch();
    batch.update(_db.doc('messes/$messId/members/$uid'), <String, dynamic>{
      'role': role,
    });
    batch.set(
      _db.doc('users/$uid'),
      <String, dynamic>{'role': role},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Removes the signed-in user from a mess and clears their profile link.
  Future<void> leaveMess({
    required String uid,
    required String messId,
  }) async {
    final authUid = currentUser?.uid;
    if (authUid == null || authUid != uid) {
      throw StateError('You must be signed in to leave a mess.');
    }

    final memberSnap = await _db.doc('messes/$messId/members/$uid').get();
    if (!memberSnap.exists) {
      throw StateError('You are not a member of this mess.');
    }

    final membersSnap = await _db.collection('messes/$messId/members').get();
    final adminCount = membersSnap.docs
        .where((d) => (d.data()['role'] as String?) == Roles.admin)
        .length;
    final otherMembers =
        membersSnap.docs.where((d) => d.id != uid).length;
    final isAdmin = (memberSnap.data()?['role'] as String?) == Roles.admin;

    if (isAdmin && adminCount <= 1 && otherMembers > 0) {
      throw StateError(
        'You are the only admin. Promote another member to admin before leaving.',
      );
    }

    final messSnap = await _db.doc('messes/$messId').get();
    final mess =
        messSnap.exists ? Mess.fromDoc(messId, messSnap.data()!) : null;

    final batch = _db.batch();
    batch.delete(_db.doc('messes/$messId/members/$uid'));
    batch.set(
      _db.doc('users/$uid'),
      <String, dynamic>{
        'messId': FieldValue.delete(),
        'role': FieldValue.delete(),
        'pendingJoin': FieldValue.delete(),
      },
      SetOptions(merge: true),
    );

    if (mess != null && mess.rotationOrder.contains(uid)) {
      final newOrder =
          mess.rotationOrder.where((id) => id != uid).toList(growable: false);
      final messUpdates = <String, dynamic>{
        'rotationOrder': newOrder,
        'rotationUpdatedAt': DateTime.now().millisecondsSinceEpoch,
      };

      if (mess.currentDuty?.assigneeUid == uid) {
        if (newOrder.isNotEmpty) {
          final nextSnap =
              await _db.doc('messes/$messId/members/${newOrder.first}').get();
          if (nextSnap.exists) {
            final assignee =
                Member.fromMap(nextSnap.data()!, newOrder.first);
            messUpdates['currentDuty'] = <String, dynamic>{
              'assigneeUid': assignee.uid,
              'assigneeName': assignee.displayName,
              'type': mess.currentDuty?.type ?? 'grocery',
              'description':
                  mess.currentDuty?.description ?? 'Grocery duty for today.',
              'date': _todayDateStr(),
            };
          } else {
            messUpdates['currentDuty'] = FieldValue.delete();
          }
        } else {
          messUpdates['currentDuty'] = FieldValue.delete();
        }
      }

      batch.update(_db.doc('messes/$messId'), messUpdates);
    }

    await batch.commit();
  }

  Future<void> updateMessDuty(String messId, DutyInfo? duty) {
    final ref = _db.doc('messes/$messId');
    if (duty == null) {
      return ref.update(<String, dynamic>{'currentDuty': FieldValue.delete()});
    }
    return ref.update(<String, dynamic>{'currentDuty': duty.toFirestore()});
  }

  Future<void> updateMessGeneral(
    String messId, {
    String? name,
    String? currency,
  }) {
    final data = <String, dynamic>{};
    if (name != null) data['name'] = name.trim();
    if (currency != null) data['currency'] = currency;
    if (data.isEmpty) return Future<void>.value();
    return _db.doc('messes/$messId').update(data);
  }

  Future<String> refreshInviteCode({
    required String messId,
    required String uid,
  }) async {
    for (var attempt = 0; attempt < 8; attempt++) {
      try {
        late String newCode;
        await _db.runTransaction((tx) async {
          final messRef = _db.doc('messes/$messId');
          final messSnap = await tx.get(messRef);
          if (!messSnap.exists) throw StateError('Mess not found.');

          newCode = await allocateInvite(tx);
          tx.update(messRef, <String, dynamic>{'inviteCode': newCode});
          tx.set(_db.doc('messInvites/$newCode'), <String, dynamic>{
            'messId': messId,
            'createdBy': uid,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });
        });
        return newCode;
      } catch (_) {
        continue;
      }
    }
    throw StateError('Failed to refresh invite code. Try again.');
  }

  Future<void> updateRotationOrder(
    String messId,
    List<String> memberUids, {
    String? rotationCycle,
    bool applyDutyNow = true,
  }) async {
    final data = <String, dynamic>{
      'rotationOrder': memberUids,
      if (rotationCycle != null) 'rotationCycle': rotationCycle,
      'rotationUpdatedAt': DateTime.now().millisecondsSinceEpoch,
    };

    if (applyDutyNow && memberUids.isNotEmpty) {
      final firstSnap = await _db.doc('messes/$messId/members/${memberUids.first}').get();
      if (firstSnap.exists) {
        final assignee = Member.fromMap(firstSnap.data()!, memberUids.first);
        final dateStr = _todayDateStr();
        data['lastDutyDate'] = dateStr;
        data['dutyInitialized'] = true;
        data['currentDuty'] = <String, dynamic>{
          'assigneeUid': assignee.uid,
          'assigneeName': assignee.displayName,
          'type': 'grocery',
          'description': 'Grocery duty for today.',
          'date': dateStr,
        };
      }
    }

    return _db.doc('messes/$messId').update(data);
  }

  String _todayDateStr() {
    final today = DateTime.now();
    return '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
  }

  // ---------- Duty swap requests ----------

  CollectionReference<Map<String, dynamic>> _dutySwapRef(String messId) {
    return _db.collection('messes/$messId/dutySwapRequests');
  }

  Stream<List<DutySwapRequest>> dutySwapRequestsStream(String messId, String uid) {
    return _dutySwapRef(messId)
        .where('status', isEqualTo: DutySwapRequestStatuses.pending)
        .snapshots()
        .map((q) {
      return q.docs
          .map((d) => DutySwapRequest.fromDoc(d.id, d.data()))
          .where((r) => r.fromUid == uid || r.toUid == uid)
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  Future<void> createDutySwapRequest({
    required String messId,
    required String fromUid,
    required String fromName,
    required String toUid,
    required String toName,
  }) async {
    final messSnap = await _db.doc('messes/$messId').get();
    if (!messSnap.exists) throw StateError('Mess not found.');
    final mess = Mess.fromDoc(messSnap.id, messSnap.data()!);
    final duty = mess.currentDuty;
    if (duty == null) throw StateError('No duty is assigned right now.');
    if (duty.assigneeUid != fromUid) {
      throw StateError('Only the person currently on duty can request a swap.');
    }
    if (toUid == fromUid) throw StateError('Pick a different member.');

    final pending = await _dutySwapRef(messId).where('fromUid', isEqualTo: fromUid).get();
    final hasPending = pending.docs.any(
      (d) => (d.data()['status'] as String?) == DutySwapRequestStatuses.pending,
    );
    if (hasPending) {
      throw StateError('You already have a pending swap request.');
    }

    final ref = _dutySwapRef(messId).doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    await ref.set(DutySwapRequest(
      id: ref.id,
      fromUid: fromUid,
      fromName: fromName,
      toUid: toUid,
      toName: toName,
      status: DutySwapRequestStatuses.pending,
      createdAt: now,
    ).toFirestore());

    final notifRef = _db.doc('messes/$messId/notifications/swap_${toUid}_${ref.id}');
    await notifRef.set(MessNotification(
      id: notifRef.id,
      kind: NotificationKinds.dutySwap,
      title: 'Shift swap request',
      body: '$fromName wants to swap grocery duty with you.',
      createdAt: now,
      targetUid: toUid,
      refId: ref.id,
    ).toFirestore());
  }

  Future<void> respondToDutySwapRequest({
    required String messId,
    required String requestId,
    required String responderUid,
    required bool accept,
  }) async {
    final reqRef = _dutySwapRef(messId).doc(requestId);
    final reqSnap = await reqRef.get();
    if (!reqSnap.exists) throw StateError('Swap request not found.');
    final req = DutySwapRequest.fromDoc(reqSnap.id, reqSnap.data()!);
    if (!req.isPending) throw StateError('This request was already handled.');
    if (req.toUid != responderUid) {
      throw StateError('Only the requested member can accept or reject.');
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    if (!accept) {
      await reqRef.update(<String, dynamic>{
        'status': DutySwapRequestStatuses.rejected,
        'respondedAt': now,
      });
      return;
    }

    await _applyDutySwap(
      messId: messId,
      fromUid: req.fromUid,
      swapWithUid: req.toUid,
      actorUid: responderUid,
      fromName: req.fromName,
      toName: req.toName,
    );

    await reqRef.update(<String, dynamic>{
      'status': DutySwapRequestStatuses.accepted,
      'respondedAt': now,
    });
  }

  Future<void> _applyDutySwap({
    required String messId,
    required String fromUid,
    required String swapWithUid,
    required String actorUid,
    required String fromName,
    required String toName,
  }) async {
    final messSnap = await _db.doc('messes/$messId').get();
    if (!messSnap.exists) throw StateError('Mess not found.');
    final mess = Mess.fromDoc(messSnap.id, messSnap.data()!);
    final duty = mess.currentDuty;
    if (duty == null) throw StateError('No duty is assigned right now.');

    final swapMemberSnap = await _db.doc('messes/$messId/members/$swapWithUid').get();
    if (!swapMemberSnap.exists) throw StateError('Member not found.');
    final swapMember = Member.fromMap(swapMemberSnap.data()!, swapWithUid);

    final order = List<String>.from(mess.rotationOrder);
    if (order.isEmpty) {
      order.addAll([fromUid, swapWithUid]);
    } else {
      final fromIdx = order.indexOf(fromUid);
      final toIdx = order.indexOf(swapWithUid);
      if (fromIdx >= 0 && toIdx >= 0) {
        order[fromIdx] = swapWithUid;
        order[toIdx] = fromUid;
      } else if (fromIdx >= 0) {
        order[fromIdx] = swapWithUid;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final dateStr = _todayDateStr();

    final batch = _db.batch();
    batch.update(_db.doc('messes/$messId'), <String, dynamic>{
      'rotationOrder': order,
      'rotationUpdatedAt': now,
      'lastDutyDate': dateStr,
      'dutyInitialized': true,
      'currentDuty': <String, dynamic>{
        'assigneeUid': swapMember.uid,
        'assigneeName': swapMember.displayName,
        'type': duty.type,
        'description': duty.description,
        'date': dateStr,
      },
    });

    final chatRef = _db.collection('messes/$messId/messages').doc();
    batch.set(
      chatRef,
      ChatMessage(
        id: chatRef.id,
        kind: ChatMessageKinds.system,
        senderUid: 'system',
        senderName: 'Mess',
        createdAt: now,
        text: '$fromName swapped grocery duty with $toName.',
      ).toFirestore(),
    );

    await batch.commit();

    await _notifyAllOtherMembers(
      messId: messId,
      senderUid: actorUid,
      kind: NotificationKinds.groceryDuty,
      title: 'Grocery duty swapped',
      body: '${swapMember.displayName} is now on grocery duty.',
    );
  }

  /// @deprecated Use [createDutySwapRequest] — swaps require acceptance.
  Future<void> swapGroceryDuty({
    required String messId,
    required String requesterUid,
    required String swapWithUid,
  }) async {
    final messSnap = await _db.doc('messes/$messId').get();
    if (!messSnap.exists) throw StateError('Mess not found.');
    final mess = Mess.fromDoc(messSnap.id, messSnap.data()!);
    final duty = mess.currentDuty;
    if (duty == null) throw StateError('No duty is assigned right now.');

    final requesterMemberSnap = await _db.doc('messes/$messId/members/$requesterUid').get();
    if (!requesterMemberSnap.exists) {
      throw StateError('You must be a mess member to swap duty.');
    }
    final requesterRole = (requesterMemberSnap.data()?['role'] as String?) ?? Roles.member;
    final isAdmin = requesterRole == Roles.admin || mess.createdBy == requesterUid;
    final isAssignee = duty.assigneeUid == requesterUid;
    if (!isAdmin && !isAssignee) {
      throw StateError('Only the person on duty or an admin can swap shifts.');
    }
    if (swapWithUid == duty.assigneeUid) {
      throw StateError('Pick a different member to swap with.');
    }

    final swapMemberSnap = await _db.doc('messes/$messId/members/$swapWithUid').get();
    if (!swapMemberSnap.exists) throw StateError('That member was not found.');
    final swapMember = Member.fromMap(swapMemberSnap.data()!, swapWithUid);

    final order = List<String>.from(mess.rotationOrder);
    if (order.isEmpty) {
      order.addAll([duty.assigneeUid, swapWithUid]);
    } else {
      final fromIdx = order.indexOf(duty.assigneeUid);
      final toIdx = order.indexOf(swapWithUid);
      if (fromIdx >= 0 && toIdx >= 0) {
        order[fromIdx] = swapWithUid;
        order[toIdx] = duty.assigneeUid;
      } else if (fromIdx >= 0) {
        order[fromIdx] = swapWithUid;
        if (!order.contains(duty.assigneeUid)) order.add(duty.assigneeUid);
      } else {
        order.insert(0, swapWithUid);
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final today = DateTime.now();
    final dateStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final batch = _db.batch();
    batch.update(_db.doc('messes/$messId'), <String, dynamic>{
      'rotationOrder': order,
      'rotationUpdatedAt': now,
      'dutyInitialized': true,
      'currentDuty': <String, dynamic>{
        'assigneeUid': swapMember.uid,
        'assigneeName': swapMember.displayName,
        'type': duty.type,
        'description': duty.description,
        'date': dateStr,
      },
    });

    final chatRef = _db.collection('messes/$messId/messages').doc();
    batch.set(
      chatRef,
      ChatMessage(
        id: chatRef.id,
        kind: ChatMessageKinds.system,
        senderUid: 'system',
        senderName: 'Mess',
        createdAt: now,
        text: '${duty.assigneeName} swapped grocery duty with ${swapMember.displayName}.',
      ).toFirestore(),
    );

    await batch.commit();

    await _notifyAllOtherMembers(
      messId: messId,
      senderUid: requesterUid,
      kind: NotificationKinds.groceryDuty,
      title: 'Grocery duty swapped',
      body: '${swapMember.displayName} is now on grocery duty.',
    );
  }

  /// Advances grocery duty daily — next person in rotation order each calendar day.
  Future<void> maybeAdvanceRotation(String messId) async {
    final messSnap = await _db.doc('messes/$messId').get();
    if (!messSnap.exists) return;
    final mess = Mess.fromDoc(messSnap.id, messSnap.data()!);
    if (mess.rotationOrder.isEmpty) return;

    final dateStr = _todayDateStr();
    final lastDutyDate = mess.lastDutyDate ?? '';
    final hasDuty = mess.currentDuty != null;
    final dutyInitialized = messSnap.data()?['dutyInitialized'] == true;

    if (lastDutyDate == dateStr && hasDuty) return;

    final membersSnap = await _db.collection('messes/$messId/members').get();
    final members = membersSnap.docs
        .map((d) => Member.fromMap(d.data(), d.id))
        .toList();
    final memberByUid = {for (final m in members) m.uid: m};

    String nextUid;
    List<String> nextOrder;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (lastDutyDate.isNotEmpty && lastDutyDate != dateStr && hasDuty) {
      final firstUid = mess.rotationOrder.first;
      nextOrder = [...mess.rotationOrder.sublist(1), firstUid];
      nextUid = nextOrder.first;
    } else if (!hasDuty || !dutyInitialized) {
      nextOrder = mess.rotationOrder;
      nextUid = mess.rotationOrder.first;
    } else {
      return;
    }

    final assignee = memberByUid[nextUid];
    if (assignee == null) return;

    final batch = _db.batch();
    batch.update(_db.doc('messes/$messId'), <String, dynamic>{
      'rotationOrder': nextOrder,
      'rotationUpdatedAt': now,
      'lastDutyDate': dateStr,
      'dutyInitialized': true,
      'currentDuty': <String, dynamic>{
        'assigneeUid': assignee.uid,
        'assigneeName': assignee.displayName,
        'type': 'grocery',
        'description': 'Grocery duty for today.',
        'date': dateStr,
      },
    });

    final chatRef = _db.collection('messes/$messId/messages').doc();
    batch.set(chatRef, ChatMessage(
      id: chatRef.id,
      kind: ChatMessageKinds.system,
      senderUid: 'system',
      senderName: 'Mess',
      createdAt: now,
      text: '${assignee.displayName} is on grocery duty today.',
    ).toFirestore());

    for (final m in members) {
      final notifRef = _db.doc('messes/$messId/notifications/grocery_${m.uid}');
      batch.set(notifRef, MessNotification(
        id: notifRef.id,
        kind: NotificationKinds.groceryDuty,
        title: 'Grocery duty updated',
        body: '${assignee.displayName} is on duty today.',
        createdAt: now,
        targetUid: m.uid,
      ).toFirestore());
    }

    await batch.commit();
  }

  // ---------- Chat ----------

  CollectionReference<Map<String, dynamic>> _chatRef(String messId) {
    return _db.collection('messes/$messId/messages');
  }

  Stream<List<ChatMessage>> chatStream(String messId) {
    final cutoff = retentionCutoffMillis();
    return _chatRef(messId)
        .orderBy('createdAt', descending: true)
        .limit(300)
        .snapshots()
        .map((q) {
      final list = q.docs
          .map((d) => ChatMessage.fromDoc(d.id, d.data()))
          .where((m) => m.createdAt == 0 || m.createdAt >= cutoff)
          .toList();
      return list;
    });
  }

  Future<void> markMessChatRead(String messId, String uid) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.doc('messes/$messId/members/$uid').set(
      <String, dynamic>{'chatLastReadAt': now},
      SetOptions(merge: true),
    );
  }

  Stream<int> unreadMessChatCountStream(String messId, String uid) {
    final controller = StreamController<int>.broadcast();
    Member? member;
    List<ChatMessage>? messages;

    void emit() {
      if (member == null || messages == null) return;
      final lastRead = member!.chatLastReadAt ?? 0;
      final count = messages!.where((m) {
        final general = m.eventId == null || m.eventId!.isEmpty;
        return general &&
            m.senderUid != uid &&
            !m.isSystem &&
            m.createdAt > lastRead;
      }).length;
      controller.add(count);
    }

    final memberSub = memberStream(messId, uid).listen((m) {
      member = m;
      emit();
    });
    final chatSub = chatStream(messId).listen((list) {
      messages = list;
      emit();
    });

    controller.onCancel = () {
      memberSub.cancel();
      chatSub.cancel();
    };

    return controller.stream;
  }

  Future<void> sendChatMessage({
    required String messId,
    required String senderUid,
    required String senderName,
    String? text,
    Uint8List? voiceBytes,
    String voiceContentType = 'audio/mp4',
    int? voiceDurationMs,
    String? eventId,
  }) async {
    final memberSnap = await _db.doc('messes/$messId/members/$senderUid').get();
    if (!memberSnap.exists) {
      throw StateError('You must be an approved mess member to send messages.');
    }

    final ref = _chatRef(messId).doc();
    final now = DateTime.now().millisecondsSinceEpoch;

    final ChatMessage msg;
    if (voiceBytes != null && voiceBytes.isNotEmpty) {
      const maxBytes = 700 * 1024;
      if (voiceBytes.length > maxBytes) {
        throw StateError('Voice note too large. Keep it under 30 seconds.');
      }
      msg = ChatMessage(
        id: ref.id,
        kind: ChatMessageKinds.voice,
        senderUid: senderUid,
        senderName: senderName,
        createdAt: now,
        audioBase64: _bytesToBase64(voiceBytes),
        audioContentType: voiceContentType,
        audioDurationMs: voiceDurationMs,
        eventId: eventId,
      );
    } else {
      final body = (text ?? '').trim();
      if (body.isEmpty) throw StateError('Message is empty.');
      msg = ChatMessage(
        id: ref.id,
        kind: ChatMessageKinds.text,
        senderUid: senderUid,
        senderName: senderName,
        createdAt: now,
        text: body,
        eventId: eventId,
      );
    }

    await ref.set(msg.toFirestore());
    try {
      await _notifyAllOtherMembers(
        messId: messId,
        senderUid: senderUid,
        kind: NotificationKinds.chat,
        title: 'New message from $senderName',
        body: msg.isVoice ? 'Voice note' : (msg.text ?? ''),
        refId: ref.id,
      );
    } catch (_) {
      // Message saved; notification fan-out is best-effort.
    }
  }

  // ---------- Events ----------

  Stream<List<MessEvent>> eventsStream(String messId) {
    return _db
        .collection('messes/$messId/events')
        .orderBy('startsAt', descending: false)
        .snapshots()
        .map((q) => q.docs.map((d) => MessEvent.fromDoc(d.id, d.data())).toList());
  }

  Stream<MessEvent?> eventStream(String messId, String eventId) {
    return _db.doc('messes/$messId/events/$eventId').snapshots().map((snap) {
      if (!snap.exists) return null;
      return MessEvent.fromDoc(snap.id, snap.data()!);
    });
  }

  Future<String> createEvent({
    required String messId,
    required String title,
    required String description,
    required int startsAt,
    required String createdBy,
    required String createdByName,
    double? estimatedCost,
    bool autoJoinCreator = true,
  }) async {
    final ref = _db.collection('messes/$messId/events').doc();
    final now = DateTime.now().millisecondsSinceEpoch;
    final event = MessEvent(
      id: ref.id,
      title: title.trim(),
      description: description.trim(),
      createdBy: createdBy,
      createdAt: now,
      startsAt: startsAt,
      status: EventStatuses.upcoming,
      joinerUids: autoJoinCreator ? [createdBy] : const [],
      estimatedCost: estimatedCost,
    );
    await ref.set(event.toFirestore());
    await _notifyAllOtherMembers(
      messId: messId,
      senderUid: createdBy,
      kind: NotificationKinds.event,
      title: 'New event: ${event.title}',
      body: '$createdByName just created an event. Tap to join.',
      refId: ref.id,
    );
    return ref.id;
  }

  Future<void> setEventJoined({
    required String messId,
    required String eventId,
    required String uid,
    required bool join,
  }) {
    return _db.doc('messes/$messId/events/$eventId').update(<String, dynamic>{
      'joinerUids': join
          ? FieldValue.arrayUnion([uid])
          : FieldValue.arrayRemove([uid]),
    });
  }

  Future<void> closeEvent(String messId, String eventId) {
    return _db.doc('messes/$messId/events/$eventId').update(<String, dynamic>{
      'status': EventStatuses.closed,
    });
  }

  // ---------- Notifications ----------

  Stream<List<MessNotification>> notificationsStream(String messId, String uid) {
    final cutoff = retentionCutoffMillis();
    return _db
        .collection('messes/$messId/notifications')
        .where('targetUid', isEqualTo: uid)
        .snapshots()
        .map((q) {
      final list = q.docs
          .map((d) => MessNotification.fromDoc(d.id, d.data()))
          .where((n) => n.createdAt == 0 || n.createdAt >= cutoff)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> dismissNotification(String messId, String id) {
    return _db.doc('messes/$messId/notifications/$id').delete();
  }

  Future<void> _notifyAllOtherMembers({
    required String messId,
    required String senderUid,
    required String kind,
    required String title,
    required String body,
    String? refId,
  }) async {
    try {
      final membersSnap = await _db.collection('messes/$messId/members').get();
      final batch = _db.batch();
      final now = DateTime.now().millisecondsSinceEpoch;
      var i = 0;
      for (final doc in membersSnap.docs) {
        final uid = doc.id;
        if (uid == senderUid) continue;
        final notif = MessNotification(
          id: '',
          kind: kind,
          title: title,
          body: body.length > 140 ? body.substring(0, 140) : body,
          createdAt: now + i,
          targetUid: uid,
          refId: refId,
        );
        final ref = _db.collection('messes/$messId/notifications').doc();
        batch.set(ref, notif.toFirestore());
        i++;
      }
      await batch.commit();
    } catch (_) {
      // Notification fan-out is best-effort.
    }
  }

  // ---------- Retention cleanup ----------

  Future<void> runRetentionCleanup(String messId) async {
    final cutoff = retentionCutoffMillis();
    Future<void> deleteOlder(String path, String field) async {
      try {
        final snaps = await _db
            .collection(path)
            .where(field, isLessThan: cutoff)
            .limit(200)
            .get();
        if (snaps.docs.isEmpty) return;
        final batch = _db.batch();
        for (final doc in snaps.docs) {
          batch.delete(doc.reference);
        }
        await batch.commit();
      } catch (_) {
        // Permission or index errors swallow — non-blocking maintenance.
      }
    }

    await deleteOlder('messes/$messId/expenses', 'createdAt');
    await deleteOlder('messes/$messId/messages', 'createdAt');
    await deleteOlder('messes/$messId/notifications', 'createdAt');
  }

  String _bytesToBase64(Uint8List bytes) {
    return base64Encode(bytes);
  }
}
