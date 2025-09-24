import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;

class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload ID image with progress tracking
  Future<String> uploadIdImage(
    File imageFile,
    String userId, {
    Function(double)? onProgress,
  }) async {
    try {
      // Create a unique filename
      String fileName = 'id_${userId}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      
      // Create reference to the file location
      Reference ref = _storage
          .ref()
          .child('id_verifications')
          .child(userId)
          .child(fileName);

      // Create upload task
      UploadTask uploadTask = ref.putFile(imageFile);

      // Listen to upload progress
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        double progress = snapshot.bytesTransferred / snapshot.totalBytes;
        onProgress?.call(progress);
      });

      // Wait for upload to complete
      TaskSnapshot snapshot = await uploadTask;
      
      // Get download URL
      String downloadUrl = await snapshot.ref.getDownloadURL();
      
      return downloadUrl;
    } catch (e) {
      throw Exception('Failed to upload ID image: $e');
    }
  }

  // Upload post images with progress tracking
  Future<List<String>> uploadPostImages(
    List<File> imageFiles,
    String userId,
    String postId, {
    Function(double)? onProgress,
  }) async {
    try {
      List<String> downloadUrls = [];
      int totalFiles = imageFiles.length;
      int completedFiles = 0;

      for (int i = 0; i < imageFiles.length; i++) {
        File imageFile = imageFiles[i];
        String fileName = 'post_${postId}_${i}_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
        
        Reference ref = _storage
            .ref()
            .child('post_images')
            .child(userId)
            .child(postId)
            .child(fileName);

        UploadTask uploadTask = ref.putFile(imageFile);
        
        // Listen to individual file progress
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          double fileProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          double overallProgress = (completedFiles + fileProgress) / totalFiles;
          onProgress?.call(overallProgress);
        });

        TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();
        downloadUrls.add(downloadUrl);
        
        completedFiles++;
        onProgress?.call(completedFiles / totalFiles);
      }

      return downloadUrls;
    } catch (e) {
      throw Exception('Failed to upload post images: $e');
    }
  }

  // Delete image from storage
  Future<void> deleteImage(String imageUrl) async {
    try {
      Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }

  // Get signed URL for secure access (used by admin)
  Future<String> getSignedUrl(String imagePath, Duration expiration) async {
    try {
      Reference ref = _storage.ref().child(imagePath);
      
      // Firebase Storage doesn't support signed URLs directly like GCS
      // For now, return the download URL (consider implementing Cloud Functions for signed URLs)
      return await ref.getDownloadURL();
    } catch (e) {
      throw Exception('Failed to get signed URL: $e');
    }
  }
}