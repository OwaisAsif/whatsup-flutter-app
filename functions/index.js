const { onValueCreated, onValueUpdated } = require("firebase-functions/v2/database");
const admin = require("firebase-admin");

admin.initializeApp();

exports.triggerMessageNotification = onValueCreated(
    {
        ref: "/messages/{messageId}",
        region: "us-central1",
    },
    async (event) => {
        const message = event.data?.val();

        if (!message || message.type == 'audio' || message.type == 'video') return;

        let topic = "";
        let group = null;
        if (message.groupId) {
            topic = `group_${message.groupId}`;
            group = await admin.database().ref(`/groups/${message.groupId}`).once("value");
        } else if (message.receiverId) {
            topic = `user_${message.receiverId}`;
        } else {
            console.warn("Message missing groupId and receiverId", message);
            return;
        }

        const fcmMessage = {
            notification: {
                title: message.groupId ? group.val().name || "New Message" : message.senderName || "New Message",
                body: message.groupId ? message.senderName + ": " + message.text || "You have a new message" : message.text || "You have a new message",
                image: message.senderImage || undefined,
            },
            topic: topic,
            data: {
                type: String(message.type || "text"),
                isGroup: message.groupId ? "true" : "false",
                groupId: String(message.groupId || ""),
                groupName: group ? group.val().name || "" : "",
                senderName: String(message.senderName || ""),
                receiverId: String(message.receiverId || ""),
                senderId: String(message.senderId || ""),
                messageId: event.params.messageId,
                clickEvent: message.groupId ? "OPEN_GROUP_CHAT" : "OPEN_CHAT",
            },
        };

        try {
            const response = await admin.messaging().send(fcmMessage);
            console.log(`Notification sent to topic ${topic}`, response);
        } catch (error) {
            console.error("Error sending notification:", error);
        }
    }
);

// Send FCM when a new call entry is created
exports.triggerCallNotification = onValueCreated(
    {
        ref: "/calls/{callId}",
        region: "us-central1",
    },
    async (event) => {
        const call = event.data?.val();
        if (!call) return;

        const calleeId = call.calleeId;
        if (!calleeId) return;

        const topic = `user_${calleeId}`;
        const callType = (call.type || "audio").toString();
        const callerName = call.callerName || "Incoming call";
        // dont create notifications for call status updates, only for new calls
        const fcmMessage = {
            notification: {
                title: callType === "video" ? "Incoming video call" : "Incoming audio call",
                body: `Call from ${callerName}`,
            },
            topic,
            data: {
                type: "call",
                callType,
                callId: event.params.callId,
                callerId: String(call.callerId || ""),
                calleeId: String(calleeId),
                groupId: String(call.groupId || ""),
                clickEvent: "OPEN_CALL",
                callStatus: String(call.status || "ringing"),
                callDirection: "incoming",
            },
        };

        try {
            const response = await admin.messaging().send(fcmMessage);
            console.log(`Call notification sent to topic ${topic}`, response);
        } catch (error) {
            console.error("Error sending call notification:", error);
        }
    }
);

exports.triggerCallStatusNotification = onValueUpdated(
    {
        ref: "/calls/{callId}",
        region: "us-central1",
    },
    async (event) => {
        const before = event.data?.before?.val();
        const after = event.data?.after?.val();
        if (!after) {
            return;
        }

        const previousStatus = before?.status || "ringing";
        const currentStatus = after.status || "ringing";

        if (previousStatus === currentStatus) {
            return;
        }

        const trackedStatuses = new Set(["accepted", "ended", "rejected"]);
        if (!trackedStatuses.has(currentStatus)) {
            return;
        }

        const messageData = {
            type: "call",
            callType: after.type || "audio",
            callId: event.params.callId,
            callerId: String(after.callerId || ""),
            calleeId: String(after.calleeId || ""),
            callStatus: currentStatus,
            clickEvent: "CALL_STATUS",
        };

        const targets = [];
        if (after.callerId) {
            targets.push(`user_${after.callerId}`);
        }
        if (after.calleeId) {
            targets.push(`user_${after.calleeId}`);
        }

        if (targets.length === 0) {
            return;
        }

        const notification = {
            title:
                currentStatus === "accepted"
                    ? "Call connected"
                    : currentStatus === "rejected"
                        ? "Call rejected"
                        : "Call ended",
            body: `Status: ${currentStatus}`,
        };

        // dont show notifications for call status updates, only send data messages to update the call screen
        try {
            await Promise.all(
                targets.map((topic) =>
                    admin.messaging().send({
                        // notification,
                        data: messageData,
                        topic,
                    })
                )
            );
        } catch (error) {
            console.error("Error notifying call status change:", error);
        }
    }
);