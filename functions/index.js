/**
 * TaskFlow Cloud Functions.
 *
 * Push notifications are sent from here — never from the app.
 * The app only writes an in-app notification document to
 *   users/{uid}/notifications/{notificationId}
 * and this function delivers the matching FCM push to that user's
 * registered device token (users/{uid}.fcmToken).
 *
 * This replaces the old client-side FcmV1Service, which embedded a
 * Firebase service-account private key inside the app binary.
 */

const {setGlobalOptions} = require("firebase-functions");
const {onDocumentCreated} = require("firebase-functions/v2/firestore");
const logger = require("firebase-functions/logger");
const admin = require("firebase-admin");

admin.initializeApp();

setGlobalOptions({maxInstances: 10});

exports.sendPushOnNotification = onDocumentCreated(
    "users/{uid}/notifications/{notificationId}",
    async (event) => {
      const snap = event.data;
      if (!snap) return;

      const notif = snap.data() || {};
      const uid = event.params.uid;

      const userSnap = await admin.firestore().collection("users").doc(uid).get();
      const token = userSnap.exists ? userSnap.data().fcmToken : null;
      if (!token) {
        logger.info(`No FCM token for user ${uid}; skipping push.`);
        return;
      }

      // FCM data payloads must be string -> string.
      const rawData = notif.data || {};
      const data = {};
      for (const [key, value] of Object.entries(rawData)) {
        if (value !== undefined && value !== null) data[key] = String(value);
      }

      try {
        await admin.messaging().send({
          token,
          notification: {
            title: notif.title || "TaskFlow",
            body: notif.body || "",
          },
          data,
          android: {
            priority: "high",
            notification: {clickAction: "FLUTTER_NOTIFICATION_CLICK"},
          },
          apns: {
            payload: {aps: {sound: "default"}},
          },
        });
        logger.info(`Push sent to user ${uid} for notification ${event.params.notificationId}.`);
      } catch (err) {
        // A stale token should not fail the function; clean it up so
        // future notifications don't keep retrying a dead device.
        if (
          err.code === "messaging/registration-token-not-registered" ||
          err.code === "messaging/invalid-registration-token"
        ) {
          await admin.firestore().collection("users").doc(uid)
              .update({fcmToken: admin.firestore.FieldValue.delete()});
          logger.info(`Removed stale FCM token for user ${uid}.`);
        } else {
          logger.error(`Failed to send push to user ${uid}:`, err);
        }
      }
    },
);

/**
 * Hourly deadline reminders.
 *  - "Due soon": deadline within the next hour, not done -> notify assignee once.
 *  - "Overdue": deadline passed, not done -> notify assignee once.
 * Reminders are written as in-app notification docs, which the
 * sendPushOnNotification trigger above turns into FCM pushes.
 * Requires the Blaze plan (Cloud Scheduler) — same as all v2 functions.
 */
const {onSchedule} = require("firebase-functions/v2/scheduler");

exports.deadlineReminders = onSchedule("every 60 minutes", async () => {
  const db = admin.firestore();
  const now = admin.firestore.Timestamp.now();
  const inOneHour = admin.firestore.Timestamp.fromMillis(Date.now() + 60 * 60 * 1000);

  async function remind(taskDoc, flag, title, body) {
    const task = taskDoc.data();
    await db.collection("users").doc(task.assignedTo)
        .collection("notifications").add({
          title,
          body,
          timestamp: new Date().toISOString(),
          data: {type: "DEADLINE_REMINDER", taskId: taskDoc.id},
          isRead: false,
          senderPhoto: null,
        });
    await taskDoc.ref.update({[flag]: true});
    logger.info(`Reminder (${flag}) sent for task ${taskDoc.id}.`);
  }

  const dueSoon = await db.collection("tasks")
      .where("isDone", "==", false)
      .where("deadline", ">", now)
      .where("deadline", "<=", inOneHour)
      .get();
  for (const doc of dueSoon.docs) {
    if (doc.data().reminderDueSoon !== true) {
      await remind(doc, "reminderDueSoon", "⏰ Task due soon",
          `"${doc.data().title}" is due within the hour.`);
    }
  }

  const overdue = await db.collection("tasks")
      .where("isDone", "==", false)
      .where("deadline", "<=", now)
      .get();
  for (const doc of overdue.docs) {
    if (doc.data().reminderOverdue !== true) {
      await remind(doc, "reminderOverdue", "🔴 Task overdue",
          `"${doc.data().title}" has passed its deadline.`);
    }
  }
});
