const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');

initializeApp();

exports.sendMessPushOnNotification = onDocumentCreated(
  'messes/{messId}/notifications/{notifId}',
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const targetUid = data.targetUid;
    if (!targetUid) return;

    const userSnap = await getFirestore().doc(`users/${targetUid}`).get();
    const token = userSnap.data()?.fcmToken;
    if (!token) return;

    try {
      await getMessaging().send({
        token,
        notification: {
          title: data.title || 'Alpha Mess',
          body: data.body || '',
        },
        data: {
          kind: String(data.kind || ''),
          messId: String(event.params.messId || ''),
          refId: String(data.refId || ''),
        },
        android: {
          priority: 'high',
          notification: { channelId: 'mess_alerts' },
        },
      });
    } catch (err) {
      console.warn('FCM send failed', targetUid, err.message);
    }
  },
);
