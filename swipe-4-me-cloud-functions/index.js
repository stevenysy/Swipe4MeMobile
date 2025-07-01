/**
 * Import function triggers from their respective submodules:
 *
 * const {onCall} = require("firebase-functions/v2/https");
 * const {onDocumentWritten} = require("firebase-functions/v2/firestore");
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

const { setGlobalOptions } = require("firebase-functions");
const { onRequest } = require("firebase-functions/https");
const logger = require("firebase-functions/logger");
const functions = require("firebase-functions");
const admin = require("firebase-admin");
const { CloudTasksClient } = require("@google-cloud/tasks");

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
exports.updateRequestStatus = functions.https.onRequest(async (req, res) => {
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
});

/**
 * Schedules a Cloud Task to update request status at meeting time
 * Called when a request is accepted
 */
exports.scheduleRequestStatusUpdate = functions.https.onRequest(
  async (req, res) => {
    try {
      // Only allow POST requests
      if (req.method !== "POST") {
        res.status(405).send("Method Not Allowed");
        return;
      }

      const { requestId, meetingTime } = req.body;

      if (!requestId || !meetingTime) {
        res.status(400).send("requestId and meetingTime are required");
        return;
      }

      console.log(`Scheduling task for request ${requestId} at ${meetingTime}`);

      // Initialize Cloud Tasks client
      const client = new CloudTasksClient();

      // Project and queue configuration
      const projectId = "swipe4me-ios";
      const location = "us-central1";
      const queueName = "default";

      // Construct the fully qualified queue name
      const parent = client.queuePath(projectId, location, queueName);

      // Cloud Function URL for the status update
      const url = `https://us-central1-${projectId}.cloudfunctions.net/updateRequestStatus`;

      // Task payload
      const payload = JSON.stringify({ requestId });

      // Convert meetingTime to a timestamp
      const scheduleTime = new Date(meetingTime);

      // Construct the task
      const task = {
        httpRequest: {
          httpMethod: "POST",
          url,
          body: Buffer.from(payload).toString("base64"),
          headers: {
            "Content-Type": "application/json",
          },
        },
        scheduleTime: {
          seconds: Math.floor(scheduleTime.getTime() / 1000),
        },
      };

      // Send the task
      const [response] = await client.createTask({ parent, task });

      console.log(`Created task ${response.name}`);
      res.status(200).json({
        success: true,
        taskName: response.name,
        message: "Task scheduled successfully",
      });
    } catch (error) {
      console.error("Error scheduling task:", error);
      res.status(500).send(`Error scheduling task: ${error.message}`);
    }
  }
);
