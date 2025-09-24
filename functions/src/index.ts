import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Initialize Firebase Admin SDK
admin.initializeApp();

const db = admin.firestore();

// Submit ID for verification
export const submitIdForVerification = functions.https.onCall(
  async (data, context) => {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to submit ID for verification."
      );
    }

    const userId = context.auth.uid;
    const {imageUrl} = data;

    if (!imageUrl) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Image URL is required."
      );
    }

    try {
      // Update user's verification status to pending
      await db.collection("users").doc(userId).update({
        idVerified: "pending",
        idImageUrl: imageUrl,
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create a verification request document
      await db.collection("verification_requests").add({
        userId: userId,
        imageUrl: imageUrl,
        status: "pending",
        submittedAt: admin.firestore.FieldValue.serverTimestamp(),
        reviewedAt: null,
        reviewedBy: null,
        reason: null,
      });

      // Add to audit log
      await db.collection("verification_audit").add({
        userId: userId,
        action: "id_submitted",
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        imageUrl: imageUrl,
      });

      functions.logger.info(`ID verification submitted for user: ${userId}`);

      return {success: true, message: "ID submitted for verification"};
    } catch (error) {
      functions.logger.error("Error submitting ID for verification:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to submit ID for verification."
      );
    }
  }
);

// Get pending verifications (admin only)
export const getPendingVerifications = functions.https.onCall(
  async (data, context) => {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated."
      );
    }

    const userId = context.auth.uid;

    try {
      // Check if user is admin
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists || userDoc.data()?.role !== "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only administrators can access pending verifications."
        );
      }

      // Get pending verification requests
      const pendingQuery = await db
        .collection("verification_requests")
        .where("status", "==", "pending")
        .orderBy("submittedAt", "desc")
        .get();

      const verifications = [];
      for (const doc of pendingQuery.docs) {
        const data = doc.data();
        
        // Get user information
        const userDoc = await db.collection("users").doc(data.userId).get();
        const userData = userDoc.data() || {};

        verifications.push({
          id: doc.id,
          userId: data.userId,
          userName: userData.fullName || "Unknown",
          userEmail: userData.email || "Unknown",
          imageUrl: data.imageUrl,
          submittedAt: data.submittedAt,
          status: data.status,
        });
      }

      functions.logger.info(
        `Admin ${userId} requested pending verifications: ${verifications.length} found`
      );

      return {verifications};
    } catch (error) {
      functions.logger.error("Error getting pending verifications:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to get pending verifications."
      );
    }
  }
);

// Update verification status (admin only)
export const updateVerificationStatus = functions.https.onCall(
  async (data, context) => {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated."
      );
    }

    const adminUserId = context.auth.uid;
    const {userId, status, reason, verificationId} = data;

    if (!userId || !status || !["approved", "rejected"].includes(status)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Valid userId and status (approved/rejected) are required."
      );
    }

    try {
      // Check if user is admin
      const adminDoc = await db.collection("users").doc(adminUserId).get();
      if (!adminDoc.exists || adminDoc.data()?.role !== "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only administrators can update verification status."
        );
      }

      // Update user's verification status
      await db.collection("users").doc(userId).update({
        idVerified: status,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Update the verification request
      if (verificationId) {
        await db.collection("verification_requests").doc(verificationId).update({
          status: status,
          reviewedAt: admin.firestore.FieldValue.serverTimestamp(),
          reviewedBy: adminUserId,
          reason: reason || null,
        });
      }

      // Add to audit log
      await db.collection("verification_audit").add({
        userId: userId,
        adminId: adminUserId,
        action: "status_updated",
        newStatus: status,
        reason: reason || null,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Send notification to user (you can implement push notifications here)
      functions.logger.info(
        `Verification status updated for user ${userId} to ${status} by admin ${adminUserId}`
      );

      return {success: true, message: "Verification status updated successfully"};
    } catch (error) {
      functions.logger.error("Error updating verification status:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to update verification status."
      );
    }
  }
);

// Get verification audit log (admin only)
export const getVerificationAuditLog = functions.https.onCall(
  async (data, context) => {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated."
      );
    }

    const userId = context.auth.uid;
    const {limit = 50} = data;

    try {
      // Check if user is admin
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists || userDoc.data()?.role !== "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only administrators can access audit logs."
        );
      }

      // Get audit log entries
      const auditQuery = await db
        .collection("verification_audit")
        .orderBy("timestamp", "desc")
        .limit(limit)
        .get();

      const auditLog = auditQuery.docs.map((doc) => ({
        id: doc.id,
        ...doc.data(),
      }));

      functions.logger.info(`Admin ${userId} requested audit log`);

      return {auditLog};
    } catch (error) {
      functions.logger.error("Error getting audit log:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to get audit log."
      );
    }
  }
);

// Create signed URL for secure image access (admin only)
export const getSignedImageUrl = functions.https.onCall(
  async (data, context) => {
    // Check if user is authenticated
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated."
      );
    }

    const userId = context.auth.uid;
    const {imagePath} = data;

    if (!imagePath) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Image path is required."
      );
    }

    try {
      // Check if user is admin
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists || userDoc.data()?.role !== "admin") {
        throw new functions.https.HttpsError(
          "permission-denied",
          "Only administrators can access secure image URLs."
        );
      }

      // Get signed URL from Firebase Storage
      const bucket = admin.storage().bucket();
      const file = bucket.file(imagePath);

      const [signedUrl] = await file.getSignedUrl({
        action: "read",
        expires: Date.now() + 15 * 60 * 1000, // 15 minutes
      });

      functions.logger.info(`Admin ${userId} requested signed URL for ${imagePath}`);

      return {signedUrl};
    } catch (error) {
      functions.logger.error("Error getting signed URL:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to get signed URL."
      );
    }
  }
);

// ==========================
// FCM NOTIFICATION FUNCTIONS
// ==========================

// Send notification when a new message is created
export const sendMessageNotification = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    // Only handle message notifications
    if (notification.type !== "message") {
      return null;
    }

    try {
      const toUserId = notification.toUserId;
      const fromUserName = notification.fromUserName;
      const messageText = notification.message;
      const postTitle = notification.postTitle;

      // Get recipient's FCM token
      const userDoc = await db.collection("users").doc(toUserId).get();
      if (!userDoc.exists) {
        functions.logger.error(`User ${toUserId} not found`);
        return null;
      }

      const userData = userDoc.data();
      if (!userData || !userData.fcmToken) {
        functions.logger.info(`No FCM token found for user ${toUserId}`);
        return null;
      }

      // Send FCM notification
      const message = {
        token: userData.fcmToken,
        notification: {
          title: `New message from ${fromUserName}`,
          body: messageText.length > 100 
            ? messageText.substring(0, 100) + "..." 
            : messageText,
        },
        data: {
          type: "message",
          chatId: notification.chatId || "",
          postTitle: postTitle || "",
          fromUserId: notification.fromUserId || "",
          fromUserName: fromUserName || "",
        },
        android: {
          notification: {
            channelId: "messages",
            priority: "high" as const,
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: "default",
              category: "MESSAGE",
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      functions.logger.info(`Message notification sent successfully: ${response}`);
      
      return response;
    } catch (error) {
      functions.logger.error("Error sending message notification:", error);
      return null;
    }
  });

// Send notification when someone shows interest in a post
export const sendInterestNotification = functions.firestore
  .document("notifications/{notificationId}")
  .onCreate(async (snap, context) => {
    const notification = snap.data();
    
    // Only handle interest notifications
    if (notification.type !== "interest") {
      return null;
    }

    try {
      const toUserId = notification.toUserId;
      const fromUserName = notification.fromUserName;
      const postTitle = notification.postTitle;

      // Get recipient's FCM token
      const userDoc = await db.collection("users").doc(toUserId).get();
      if (!userDoc.exists) {
        functions.logger.error(`User ${toUserId} not found`);
        return null;
      }

      const userData = userDoc.data();
      if (!userData || !userData.fcmToken) {
        functions.logger.info(`No FCM token found for user ${toUserId}`);
        return null;
      }

      // Send FCM notification
      const message = {
        token: userData.fcmToken,
        notification: {
          title: "Someone is interested!",
          body: `${fromUserName} is interested in your "${postTitle}"`,
        },
        data: {
          type: "interest",
          postId: notification.postId || "",
          postTitle: postTitle || "",
          fromUserId: notification.fromUserId || "",
          fromUserName: fromUserName || "",
        },
        android: {
          notification: {
            channelId: "interests",
            priority: "high" as const,
            sound: "default",
          },
        },
        apns: {
          payload: {
            aps: {
              badge: 1,
              sound: "default",
              category: "INTEREST",
            },
          },
        },
      };

      const response = await admin.messaging().send(message);
      functions.logger.info(`Interest notification sent successfully: ${response}`);
      
      return response;
    } catch (error) {
      functions.logger.error("Error sending interest notification:", error);
      return null;
    }
  });

// Send notification when a post matches user's saved alerts
export const sendPostAlertNotification = functions.firestore
  .document("posts/{postId}")
  .onCreate(async (snap, context) => {
    const post = snap.data();
    
    try {
      // Get all user alerts that might match this post
      const alertsQuery = await db.collection("user_alerts")
        .where("isActive", "==", true)
        .get();

      const alertPromises = alertsQuery.docs.map(async (alertDoc) => {
        const alert = alertDoc.data();
        const userId = alert.userId;
        
        // Skip if it's the post creator
        if (userId === post.userId) {
          return;
        }

        // Check if post matches alert criteria
        const matchesCategory = !alert.categories || alert.categories.length === 0 || 
          alert.categories.includes(post.category);
        const matchesType = !alert.types || alert.types.length === 0 || 
          alert.types.includes(post.type);
        const matchesKeywords = !alert.keywords || alert.keywords.length === 0 ||
          alert.keywords.some((keyword: string) => 
            post.title.toLowerCase().includes(keyword.toLowerCase()) ||
            post.description.toLowerCase().includes(keyword.toLowerCase()) ||
            post.brand.toLowerCase().includes(keyword.toLowerCase())
          );

        if (!matchesCategory || !matchesType || !matchesKeywords) {
          return;
        }

        // Get user's FCM token
        const userDoc = await db.collection("users").doc(userId).get();
        if (!userDoc.exists) {
          return;
        }

        const userData = userDoc.data();
        if (!userData || !userData.fcmToken) {
          return;
        }

        // Send FCM notification
        const message = {
          token: userData.fcmToken,
          notification: {
            title: "New post matches your alert!",
            body: `"${post.title}" by ${post.userName}`,
          },
          data: {
            type: "post_alert",
            postId: post.id || "",
            postTitle: post.title || "",
            postType: post.type || "",
            category: post.category || "",
            alertId: alertDoc.id,
          },
          android: {
            notification: {
              channelId: "alerts",
              priority: "default" as const,
              sound: "default",
            },
          },
          apns: {
            payload: {
              aps: {
                badge: 1,
                sound: "default",
                category: "ALERT",
              },
            },
          },
        };

        const response = await admin.messaging().send(message);
        functions.logger.info(`Alert notification sent to user ${userId}: ${response}`);
      });

      await Promise.all(alertPromises);
      
      return null;
    } catch (error) {
      functions.logger.error("Error sending post alert notifications:", error);
      return null;
    }
  });

// Function to update FCM token
export const updateFCMToken = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated to update FCM token."
      );
    }

    const userId = context.auth.uid;
    const {token} = data;

    if (!token) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "FCM token is required."
      );
    }

    try {
      await db.collection("users").doc(userId).update({
        fcmToken: token,
        fcmTokenUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info(`FCM token updated for user ${userId}`);
      return {success: true};
    } catch (error) {
      functions.logger.error("Error updating FCM token:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to update FCM token."
      );
    }
  }
);

// Function to test FCM notification (for development)
export const testNotification = functions.https.onCall(
  async (data, context) => {
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated."
      );
    }

    const userId = context.auth.uid;
    const {title, body} = data;

    try {
      // Get user's FCM token
      const userDoc = await db.collection("users").doc(userId).get();
      if (!userDoc.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "User not found."
        );
      }

      const userData = userDoc.data();
      if (!userData || !userData.fcmToken) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "No FCM token found for user."
        );
      }

      // Send test notification
      const message = {
        token: userData.fcmToken,
        notification: {
          title: title || "Test Notification",
          body: body || "This is a test notification from your app!",
        },
        data: {
          type: "test",
        },
      };

      const response = await admin.messaging().send(message);
      functions.logger.info(`Test notification sent: ${response}`);
      
      return {success: true, messageId: response};
    } catch (error) {
      functions.logger.error("Error sending test notification:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to send test notification."
      );
    }
  }
);

// ==========================
// REPUTATION SYSTEM FUNCTIONS
// ==========================

// Update user reputation when reputation log is created
export const updateUserReputation = functions.firestore
  .document("reputation_logs/{logId}")
  .onCreate(async (snap, context) => {
    const log = snap.data();
    
    try {
      const userId = log.userId;
      const points = log.points || 0;
      const action = log.action;
      
      const userReputationRef = db.collection("user_reputation").doc(userId);
      
      await db.runTransaction(async (transaction) => {
        const userReputationDoc = await transaction.get(userReputationRef);
        
        if (!userReputationDoc.exists) {
          // Get user data
          const userDoc = await db.collection("users").doc(userId).get();
          const userData = userDoc.data();
          
          // Create new reputation record
          const newReputation = {
            userId: userId,
            userName: userData?.fullName || "Unknown User",
            userEmail: userData?.email || null,
            totalPoints: points,
            successfulDonations: action === "successfulDonation" ? 1 : 0,
            positiveFeedbacks: action === "positiveFeedback" ? 1 : 0,
            reportedAbuses: action === "reportedAbuse" ? 1 : 0,
            completedPosts: action === "postCompleted" ? 1 : 0,
            averageResponseTime: 0.0,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            level: getLevel(points),
          };
          
          transaction.set(userReputationRef, newReputation);
        } else {
          // Update existing reputation
          const currentData = userReputationDoc.data()!;
          const currentPoints = currentData.totalPoints || 0;
          const newTotalPoints = currentPoints + points;
          
          const updates: any = {
            totalPoints: newTotalPoints,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            level: getLevel(newTotalPoints),
          };
          
          // Update specific counters
          switch (action) {
            case "successfulDonation":
              updates.successfulDonations = admin.firestore.FieldValue.increment(1);
              break;
            case "positiveFeedback":
              updates.positiveFeedbacks = admin.firestore.FieldValue.increment(1);
              break;
            case "reportedAbuse":
              updates.reportedAbuses = admin.firestore.FieldValue.increment(1);
              break;
            case "postCompleted":
              updates.completedPosts = admin.firestore.FieldValue.increment(1);
              break;
          }
          
          transaction.update(userReputationRef, updates);
        }
      });
      
      functions.logger.info(`Reputation updated for user ${userId}: ${points} points for ${action}`);
      
    } catch (error) {
      functions.logger.error("Error updating user reputation:", error);
    }
  });

// Function to calculate level based on points
function getLevel(points: number): string {
  if (points >= 1000) return "Legend";
  if (points >= 500) return "Champion";
  if (points >= 200) return "Donor";
  if (points >= 50) return "Helper";
  return "Beginner";
}

// Add reputation points when post is marked as completed
export const addReputationOnCompletion = functions.firestore
  .document("posts/{postId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    
    // Check if post was just marked as completed
    if (!before.isActive && after.isActive === false && after.completedAt) {
      try {
        const postId = context.params.postId;
        const userId = after.userId;
        const postTitle = after.title;
        
        // Add reputation log for successful donation/completion
        await db.collection("reputation_logs").add({
          userId: userId,
          action: "successfulDonation",
          points: 10,
          postId: postId,
          description: `+10 points for completing post: ${postTitle}`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        functions.logger.info(`Added reputation points for completed post ${postId} by user ${userId}`);
        
      } catch (error) {
        functions.logger.error("Error adding reputation for completed post:", error);
      }
    }
  });

// Add reputation points when positive feedback is submitted
export const addReputationOnFeedback = functions.firestore
  .document("feedbacks/{feedbackId}")
  .onCreate(async (snap, context) => {
    const feedback = snap.data();
    
    // Only add points for positive feedback (rating >= 4)
    if (feedback.isPositive && feedback.rating >= 4) {
      try {
        const toUserId = feedback.toUserId;
        const fromUserName = feedback.fromUserName;
        const postTitle = feedback.postTitle;
        
        // Add reputation log
        await db.collection("reputation_logs").add({
          userId: toUserId,
          action: "positiveFeedback",
          points: 2,
          postId: feedback.postId,
          fromUserId: feedback.fromUserId,
          fromUserName: fromUserName,
          description: `+2 points for positive feedback from ${fromUserName} on "${postTitle}"`,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        });
        
        functions.logger.info(`Added reputation points for positive feedback to user ${toUserId}`);
        
      } catch (error) {
        functions.logger.error("Error adding reputation for positive feedback:", error);
      }
    }
  });

// Deduct reputation points when abuse is reported
export const deductReputationOnAbuse = functions.firestore
  .document("abuse_reports/{reportId}")
  .onCreate(async (snap, context) => {
    const report = snap.data();
    
    try {
      const reportedUserId = report.reportedUserId;
      const reporterUserName = report.reporterUserName;
      const reason = report.reason;
      
      // Add negative reputation log
      await db.collection("reputation_logs").add({
        userId: reportedUserId,
        action: "reportedAbuse",
        points: -5,
        postId: report.postId || null,
        fromUserId: report.reporterUserId,
        fromUserName: reporterUserName,
        description: `-5 points for reported abuse: ${reason}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      functions.logger.info(`Deducted reputation points for reported abuse by user ${reportedUserId}`);
      
    } catch (error) {
      functions.logger.error("Error deducting reputation for abuse report:", error);
    }
  });

// Function to manually adjust reputation (admin only)
export const adjustReputation = functions.https.onCall(
  async (data, context) => {
    // Check if user is authenticated and is admin
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "User must be authenticated."
      );
    }

    // Check admin status
    const adminDoc = await db.collection("users").doc(context.auth.uid).get();
    const adminData = adminDoc.data();
    if (!adminData || adminData.role !== "admin") {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can adjust reputation."
      );
    }

    const {userId, points, reason} = data;

    if (!userId || points === undefined || !reason) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "userId, points, and reason are required."
      );
    }

    try {
      // Add reputation log
      await db.collection("reputation_logs").add({
        userId: userId,
        action: points > 0 ? "positiveFeedback" : "reportedAbuse",
        points: points,
        fromUserId: context.auth.uid,
        fromUserName: adminData.fullName || "Admin",
        description: `Admin adjustment: ${reason}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });

      functions.logger.info(`Admin ${context.auth.uid} adjusted reputation for user ${userId}: ${points} points`);
      
      return {success: true};
    } catch (error) {
      functions.logger.error("Error adjusting reputation:", error);
      throw new functions.https.HttpsError(
        "internal",
        "Failed to adjust reputation."
      );
    }
  }
);