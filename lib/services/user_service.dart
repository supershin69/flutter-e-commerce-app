import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';

class UserService {
  final supabase = Supabase.instance.client;

  /// Fetch current user's profile data
  Future<UserModel?> getCurrentUser() async {
    try {
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        return null;
      }

      // Fetch profile data from profiles table
      final profileData = await supabase
          .from('profiles')
          .select('*')
          .eq('user_id', user.id)
          .maybeSingle();

      if (profileData == null) {
        return UserModel(
          id: user.id,
          email: user.email ?? '',
          name: user.email?.split('@')[0] ?? 'User',
          phoneNumber: '',
          shippingAddress: '',
        );
      }

      return UserModel.fromProfilesMap(
        profileData,
        email: user.email,
        userId: user.id,
      );
    } catch (e) {
      debugPrint('Error fetching user: $e');
      return null;
    }
  }

  /// Update user's phone number and shipping address
  Future<bool> updateShippingInfo({
    required String phoneNumber,
    required String shippingAddress,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      
      if (user == null) {
        return false;
      }

      await supabase
          .from('profiles')
          .update({
            'phone': phoneNumber,
            'address': shippingAddress,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', user.id);

      return true;
    } catch (e) {
      debugPrint('Error updating shipping info: $e');
      return false;
    }
  }
}
