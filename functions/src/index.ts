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