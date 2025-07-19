/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { setGlobalOptions } = require("firebase-functions");
const logger = require("firebase-functions/logger");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { CloudTasksClient } = require("@google-cloud/tasks");
const {
  onDocumentUpdated,
  onDocumentCreated,
} = require("firebase-functions/v2/firestore");

admin.initializeApp();
const db = admin.firestore();

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
setGlobalOptions({ maxInstances: 10 });

// Create and deploy your first functions
// https://firebase.google.com/docs/functions/get-started

/**
 * Updates a swipe request status to "inProgress"
 * Called by Cloud Task at the scheduled meeting time
 */
exports.updateRequestStatusToInProgress = functions.https.onRequest(
  async (req, res) => {
    try {
      // Only allow POST requests
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      const { requestId } = req.body;

      if (!requestId) {
        res.status(400).send("requestId is required");
        return;
      }

      console.log(`Processing request ID: ${requestId}`);

      // Get the current request
      const requestDoc = await db
        .collection("swipeRequests")
        .doc(requestId)
        .get();

      if (!requestDoc.exists) {
        console.log(`Request ${requestId} not found`);
        res.status(404).send("Request not found");
        return;
      }

      const requestData = requestDoc.data();
      console.log(`Current status: ${requestData.status}`);

      // Only update if the request is still scheduled
      if (requestData.status !== "scheduled") {
        console.log(
          `Request ${requestId} is no longer scheduled (current status: ${requestData.status})`
        );
        res
          .status(200)
          .send(
            `Request status is already ${requestData.status}, no update needed`
          );
        return;
      }

      // Update the status to inProgress
      await db.collection("swipeRequests").doc(requestId).update({
        status: "inProgress",
      });

      console.log(
        `Successfully updated request ${requestId} status to inProgress`
      );
      res.status(200).send("Status updated successfully");
    } catch (error) {
      console.error("Error updating request status:", error);
      res.status(500).send(`Error updating status: ${error.message}`);
    }
  }
);

/**
 * Schedules Cloud Tasks for reminder notification and status update
 * Called when a request is accepted
 */
exports.scheduleRequestStatusUpdate = functions.https.onCall(
  async (data, context) => {
    // Authentication is automatically handled by Firebase
    // You can check if user is authenticated: context.auth

    // Firebase wraps the data in a 'data' field for onCall functions
    const { requestId, meetingTime } = data.data;

    console.log("Extracted requestId:", requestId);
    console.log("Extracted meetingTime:", meetingTime);

    if (!requestId || !meetingTime) {
      console.log(
        "Missing data - requestId:",
        !!requestId,
        "meetingTime:",
        !!meetingTime
      );
      throw new functions.https.HttpsError(
        "invalid-argument",
        "requestId and meetingTime are required"
      );
    }

    try {
      console.log(
        `Scheduling tasks for request ${requestId} at ${meetingTime}`
      );

      // Initialize Cloud Tasks client
      const client = new CloudTasksClient();

      // Project and queue configuration
      const projectId = "swipe4me-ios";
      const location = "us-central1";
      const queueName = "default";

      // Construct the fully qualified queue name
      const parent = client.queuePath(projectId, location, queueName);

      // Convert meetingTime to a timestamp
      const meetingDate = new Date(meetingTime);

      // Calculate reminder time (30 minutes before meeting)
      const reminderDate = new Date(meetingDate.getTime() - 30 * 60 * 1000);

      // Task payload
      const payload = JSON.stringify({ requestId });

      // Construct the reminder notification task
      const reminderTask = {
        httpRequest: {
          httpMethod: "POST",
          url: `https://us-central1-${projectId}.cloudfunctions.net/sendReminderNotification`,
          body: Buffer.from(payload).toString("base64"),
          headers: {
            "Content-Type": "application/json",
          },
        },
        scheduleTime: {
          seconds: Math.floor(reminderDate.getTime() / 1000),
        },
      };

      // Construct the status update task
      const statusTask = {
        httpRequest: {
          httpMethod: "POST",
          url: `https://us-central1-${projectId}.cloudfunctions.net/updateRequestStatusToInProgress`,
          body: Buffer.from(payload).toString("base64"),
          headers: {
            "Content-Type": "application/json",
          },
        },
        scheduleTime: {
          seconds: Math.floor(meetingDate.getTime() / 1000),
        },
      };

      // Schedule both tasks
      const [reminderResponse, statusResponse] = await Promise.all([
        client.createTask({ parent, task: reminderTask }),
        client.createTask({ parent, task: statusTask }),
      ]);

      console.log(`Created reminder task ${reminderResponse.name}`);
      console.log(`Created status update task ${statusResponse.name}`);

      return {
        success: true,
        reminderTaskName: reminderResponse.name,
        statusTaskName: statusResponse.name,
        message: "Tasks scheduled successfully",
      };
    } catch (error) {
      console.error("Error scheduling tasks:", error);
      throw new functions.https.HttpsError(
        "internal",
        `Error scheduling tasks: ${error.message}`
      );
    }
  }
);

/**
 * Sends reminder notification 30 minutes before meeting time
 * Called by Cloud Task at the scheduled reminder time
 */
exports.sendReminderNotification = functions.https.onRequest(
  async (req, res) => {
    try {
      // Only allow POST requests
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      const { requestId } = req.body;

      if (!requestId) {
        res.status(400).send("requestId is required");
        return;
      }

      console.log(`Processing reminder for request ID: ${requestId}`);

      // Get the current request
      const requestDoc = await db
        .collection("swipeRequests")
        .doc(requestId)
        .get();

      if (!requestDoc.exists) {
        console.log(`Request ${requestId} not found`);
        res.status(404).send("Request not found");
        return;
      }

      const requestData = requestDoc.data();
      console.log(`Current status: ${requestData.status}`);

      // Only send reminder if the request is still scheduled
      if (requestData.status !== "scheduled") {
        console.log(
          `Request ${requestId} is no longer scheduled (current status: ${requestData.status})`
        );
        res
          .status(200)
          .send(`Request status is ${requestData.status}, no reminder needed`);
        return;
      }

      // Get both participants
      const [requesterDoc, swiperDoc] = await Promise.all([
        db.collection("users").doc(requestData.requesterId).get(),
        db.collection("users").doc(requestData.swiperId).get(),
      ]);

      const notifications = [];

      // Send reminder to requester
      if (requesterDoc.exists && requesterDoc.data()?.fcmToken) {
        notifications.push(
          admin.messaging().send({
            token: requesterDoc.data().fcmToken,
            notification: {
              title: "Meeting Reminder",
              body: `Your swipe session at ${requestData.location} starts in 30 minutes!`,
            },
            data: {
              requestId: requestId,
              type: "meetingReminder",
            },
          })
        );
      }

      // Send reminder to swiper
      if (swiperDoc.exists && swiperDoc.data()?.fcmToken) {
        notifications.push(
          admin.messaging().send({
            token: swiperDoc.data().fcmToken,
            notification: {
              title: "Meeting Reminder",
              body: `Your swipe session at ${requestData.location} starts in 30 minutes!`,
            },
            data: {
              requestId: requestId,
              type: "meetingReminder",
            },
          })
        );
      }

      if (notifications.length === 0) {
        console.log("No FCM tokens found for participants");
        res.status(200).send("No notifications sent - no FCM tokens");
        return;
      }

      // Send all notifications
      await Promise.all(notifications);

      console.log(
        `Successfully sent ${notifications.length} reminder notification(s) for request ${requestId}`
      );
      res.status(200).send("Reminder notifications sent successfully");
    } catch (error) {
      console.error("Error sending reminder notification:", error);
      res.status(500).send(`Error sending reminder: ${error.message}`);
    }
  }
);

/**
 * Sends push notification when someone accepts a swipe request
 */
exports.sendAcceptanceNotification = onDocumentUpdated(
  "swipeRequests/{requestId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();

    // Check if request was just accepted
    const wasAccepted =
      !before.swiperId && after.swiperId && after.status === "scheduled";

    if (!wasAccepted) {
      return;
    }

    try {
      const requesterDoc = await db
        .collection("users")
        .doc(after.requesterId)
        .get();

      const fcmToken = requesterDoc.data()?.fcmToken;
      if (!fcmToken) {
        console.log("No FCM token found for requester");
        return;
      }

      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: "Request Accepted!",
          body: `Someone accepted your swipe request at ${after.location}`,
        },
      });

      console.log("Acceptance notification sent successfully");
    } catch (error) {
      console.error("Error sending notification:", error);
    }
  }
);

/**
 * Sends push notification when someone sends a message in a chat room
 */
exports.sendChatMessageNotification = onDocumentCreated(
  "chatRooms/{chatRoomId}/messages/{messageId}",
  async (event) => {
    const messageData = event.data.data();
    const chatRoomId = event.params.chatRoomId;
    const messageId = event.params.messageId;

    console.log(`New message in chat room ${chatRoomId}: ${messageId}`);

    // Send notifications for user messages, change proposals, and proposal responses (skip system messages)
    if (
      messageData.messageType !== "userMessage" &&
      messageData.messageType !== "changeProposal" &&
      messageData.messageType !== "proposalAccepted" &&
      messageData.messageType !== "proposalDeclined"
    ) {
      console.log(
        `Skipping notification for message type: ${messageData.messageType}`
      );
      return;
    }

    try {
      // Get the chat room to find participants
      const chatRoomDoc = await db
        .collection("chatRooms")
        .doc(chatRoomId)
        .get();

      if (!chatRoomDoc.exists) {
        console.log(`Chat room ${chatRoomId} not found`);
        return;
      }

      const chatRoomData = chatRoomDoc.data();
      const senderId = messageData.senderId;

      // Determine the recipient (the participant who didn't send the message)
      let recipientId;
      if (senderId === chatRoomData.requesterId) {
        recipientId = chatRoomData.swiperId;
      } else if (senderId === chatRoomData.swiperId) {
        recipientId = chatRoomData.requesterId;
      } else {
        console.log(
          `Sender ${senderId} is not a participant in chat room ${chatRoomId}`
        );
        return;
      }

      // Skip if no recipient (e.g., swiperId is empty for open requests)
      if (!recipientId) {
        console.log("No recipient found for message notification");
        return;
      }

      // Get recipient's FCM token
      const recipientDoc = await db.collection("users").doc(recipientId).get();

      if (!recipientDoc.exists) {
        console.log(`Recipient ${recipientId} not found`);
        return;
      }

      const recipientData = recipientDoc.data();

      // Check if recipient is actively viewing this chat
      if (recipientData.activeChat === chatRoomId) {
        console.log(
          `Recipient ${recipientId} is actively viewing chat ${chatRoomId}, skipping notification`
        );
        return;
      }

      const fcmToken = recipientData.fcmToken;

      if (!fcmToken) {
        console.log(`No FCM token found for recipient ${recipientId}`);
        return;
      }

      // Get sender's name for the notification
      const senderDoc = await db.collection("users").doc(senderId).get();
      let senderName = "Someone";

      if (senderDoc.exists) {
        const senderData = senderDoc.data();
        senderName = `${senderData.firstName} ${senderData.lastName}`.trim();
      }

      // Get the swipe request for location context
      const requestDoc = await db
        .collection("swipeRequests")
        .doc(chatRoomId)
        .get();
      let locationContext = "";

      if (requestDoc.exists) {
        const requestData = requestDoc.data();
        locationContext = ` (${requestData.location})`;
      }

      // Customize notification based on message type
      let notificationTitle = `${senderName}${locationContext}`;
      let notificationBody = messageData.content;
      let notificationType = "chatMessage";

      if (messageData.messageType === "changeProposal") {
        notificationTitle = `${senderName} sent a change proposal${locationContext}`;
        notificationBody = "Tap to view and respond to the proposed changes";
        notificationType = "changeProposal";
      } else if (messageData.messageType === "proposalAccepted") {
        notificationTitle = `${senderName} accepted your proposal${locationContext}`;
        notificationBody = "Your proposed changes have been accepted";
        notificationType = "proposalAccepted";
      } else if (messageData.messageType === "proposalDeclined") {
        notificationTitle = `${senderName} declined your proposal${locationContext}`;
        notificationBody = "Your proposed changes were declined";
        notificationType = "proposalDeclined";
      }

      // Send the notification
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: notificationTitle,
          body: notificationBody,
        },
        data: {
          chatRoomId: chatRoomId,
          messageId: messageId,
          type: notificationType,
          senderId: senderId,
        },
      });

      console.log(`Chat message notification sent to ${recipientId}`);
    } catch (error) {
      console.error("Error sending chat message notification:", error);
    }
  }
);
