import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CloudFunctionService {
  final Dio _dio = Dio();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Base URL for your Firebase Cloud Functions
  // Replace with your actual project URL
  static const String baseUrl = 'https://your-region-your-project-id.cloudfunctions.net';

  // Get Firebase ID token for authentication
  Future<String?> _getIdToken() async {
    User? user = _auth.currentUser;
    if (user != null) {
      return await user.getIdToken();
    }
    return null;
  }

  // Submit ID for verification
  Future<void> submitIdForVerification(String imageUrl) async {
    try {
      String? idToken = await _getIdToken();
      if (idToken == null) {
        throw Exception('User not authenticated');
      }

      await _dio.post(
        '$baseUrl/submitIdForVerification',
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'imageUrl': imageUrl,
        },
      );
    } catch (e) {
      if (e is DioException) {
        throw Exception('Network error: ${e.message}');
      }
      throw Exception('Failed to submit ID for verification: $e');
    }
  }

  // Get pending verifications (admin only)
  Future<List<Map<String, dynamic>>> getPendingVerifications() async {
    try {
      String? idToken = await _getIdToken();
      if (idToken == null) {
        throw Exception('User not authenticated');
      }

      Response response = await _dio.get(
        '$baseUrl/getPendingVerifications',
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
      );

      return List<Map<String, dynamic>>.from(response.data['verifications']);
    } catch (e) {
      if (e is DioException) {
        throw Exception('Network error: ${e.message}');
      }
      throw Exception('Failed to get pending verifications: $e');
    }
  }

  // Update verification status (admin only)
  Future<void> updateVerificationStatus(String userId, String status, String reason) async {
    try {
      String? idToken = await _getIdToken();
      if (idToken == null) {
        throw Exception('User not authenticated');
      }

      await _dio.post(
        '$baseUrl/updateVerificationStatus',
        options: Options(
          headers: {
            'Authorization': 'Bearer $idToken',
            'Content-Type': 'application/json',
          },
        ),
        data: {
          'userId': userId,
          'status': status,
          'reason': reason,
        },
      );
    } catch (e) {
      if (e is DioException) {
        throw Exception('Network error: ${e.message}');
      }
      throw Exception('Failed to update verification status: $e');
    }
  }
}