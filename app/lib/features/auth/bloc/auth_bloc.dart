import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _currentPhone;

  AuthBloc() : super(AuthInitial()) {
    on<AuthNavigateToPhone>((event, emit) => emit(AuthPhoneEntry()));
    on<AuthPhoneSubmitted>(_onPhoneSubmitted);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthPinFirstEntry>((event, emit) => emit(AuthPinConfirm(event.pin)));
    on<AuthPinSubmitted>(_onPinSubmitted);
    on<AuthPinSetup>(_onPinSetup);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onPhoneSubmitted(
      AuthPhoneSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      _currentPhone = event.phone;
      await _supabase.auth.signInWithOtp(phone: event.phone);
      emit(AuthOtpEntry(event.phone));
    } catch (e) {
      emit(AuthError('Failed to send OTP: ${e.toString()}'));
    }
  }

  Future<void> _onOtpSubmitted(
      AuthOtpSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      if (_currentPhone == null) {
        emit(AuthError('Phone number not found'));
        return;
      }

      final response = await _supabase.auth.verifyOTP(
        phone: _currentPhone!,
        token: event.otp,
        type: OtpType.sms,
      );

      if (response.user == null) {
        emit(AuthError('Invalid OTP'));
        return;
      }

      // Check if member exists
      final memberData = await _supabase
          .from('members')
          .select()
          .eq('user_id', response.user!.id)
          .maybeSingle();

      if (memberData == null) {
        // New user - needs PIN setup
        emit(AuthPinEntry(isNewUser: true));
      } else {
        // Existing user - check PIN
        final storedPin = await _storage.read(key: 'user_pin_${response.user!.id}');
        if (storedPin == null) {
          emit(AuthPinEntry(isNewUser: true));
        } else {
          emit(AuthPinEntry(isNewUser: false));
        }
      }
    } catch (e) {
      emit(AuthError('OTP verification failed: ${e.toString()}'));
    }
  }

  Future<void> _onPinSubmitted(
      AuthPinSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(AuthError('User not authenticated'));
        return;
      }

      final storedPin = await _storage.read(key: 'user_pin_${user.id}');
      if (storedPin != event.pin) {
        emit(AuthError('Invalid PIN'));
        emit(AuthPinEntry(isNewUser: false));
        return;
      }

      // Register device
      await _registerDevice();

      // Fetch member data
      final memberData = await _supabase
          .from('members')
          .select()
          .eq('user_id', user.id)
          .single();

      emit(AuthAuthenticated(memberData));
    } catch (e) {
      emit(AuthError('Login failed: ${e.toString()}'));
    }
  }

  Future<void> _onPinSetup(
      AuthPinSetup event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(AuthError('User not authenticated'));
        return;
      }

      // Store PIN securely
      await _storage.write(key: 'user_pin_${user.id}', value: event.pin);

      // Register device
      await _registerDevice();

      // Fetch or create member record
      final memberData = await _supabase
          .from('members')
          .select()
          .eq('user_id', user.id)
          .maybeSingle();

      if (memberData != null) {
        emit(AuthAuthenticated(memberData));
      } else {
        // Member record doesn't exist - this shouldn't happen in production
        // but handle gracefully
        emit(AuthError('Member profile not found. Contact admin.'));
      }
    } catch (e) {
      emit(AuthError('PIN setup failed: ${e.toString()}'));
    }
  }

  Future<void> _registerDevice() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final deviceInfo = DeviceInfoPlugin();
      String deviceId = '';
      String deviceName = '';
      String deviceModel = '';
      String platform = '';

      try {
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
        deviceName = androidInfo.device;
        deviceModel = androidInfo.model;
        platform = 'android';
      } catch (_) {
        try {
          final iosInfo = await deviceInfo.iosInfo;
          deviceId = iosInfo.identifierForVendor ?? '';
          deviceName = iosInfo.name;
          deviceModel = iosInfo.model;
          platform = 'ios';
        } catch (_) {}
      }

      // Get member_id
      final memberData = await _supabase
          .from('members')
          .select('id')
          .eq('user_id', user.id)
          .single();

      // Register device
      await _supabase.from('member_devices').upsert({
        'member_id': memberData['id'],
        'device_id': deviceId,
        'device_name': deviceName,
        'device_model': deviceModel,
        'platform': platform,
        'status': 'active',
        'otp_verified': true,
        'last_used_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      // Log but don't fail auth
      debugPrint('Device registration failed: $e');
    }
  }

  Future<void> _onLogout(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _supabase.auth.signOut();
    emit(AuthInitial());
  }
}
