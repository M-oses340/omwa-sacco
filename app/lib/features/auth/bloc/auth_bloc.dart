import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/services/connectivity_service.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  String? _currentPhone;

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckSession>(_onCheckSession);
    on<AuthNavigateToPhone>((event, emit) => emit(AuthPhoneEntry()));
    on<AuthPhoneSubmitted>(_onPhoneSubmitted);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthRegisterSubmitted>(_onRegisterSubmitted);
    on<AuthPinFirstEntry>((event, emit) => emit(AuthPinConfirm(event.pin)));
    on<AuthPinSubmitted>(_onPinSubmitted);
    on<AuthPinSetup>(_onPinSetup);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheckSession(
      AuthCheckSession event, Emitter<AuthState> emit) async {
    final session = _supabase.auth.currentSession;
    debugPrint('[AUTH] Checking session: ${session != null ? 'found' : 'none'}');
    if (session == null) {
      emit(AuthInitial());
      return;
    }
    final user = session.user;
    final storedPin = await _storage.read(key: 'user_pin_${user.id}');
    debugPrint('[AUTH] Stored PIN exists: ${storedPin != null}');
    if (storedPin == null) {
      emit(AuthInitial());
      return;
    }
    debugPrint('[AUTH] Existing session found for user: ${user.id}');
    emit(AuthPinEntry(isNewUser: false));
  }

  Future<void> _onPhoneSubmitted(
      AuthPhoneSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    debugPrint('[AUTH] Sending OTP to email: ${event.phone}');
    try {
      _currentPhone = event.phone;
      await ConnectivityService.instance.guard(
        () => _supabase.auth.signInWithOtp(email: event.phone),
      );
      debugPrint('[AUTH] OTP sent successfully to: ${event.phone}');
      emit(AuthOtpEntry(event.phone));
    } on AuthException catch (e) {
      debugPrint('[AUTH] AuthException sending OTP: ${e.message} (status: ${e.statusCode})');
      emit(AuthError('Failed to send OTP: ${e.message}'));
    } catch (e, stack) {
      debugPrint('[AUTH] Unexpected error sending OTP: $e');
      debugPrint('[AUTH] Stack trace: $stack');
      emit(AuthError('Failed to send OTP: ${e.toString()}'));
    }
  }

  Future<void> _onOtpSubmitted(
      AuthOtpSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    debugPrint('[AUTH] Verifying OTP for phone: $_currentPhone');
    try {
      if (_currentPhone == null) {
        debugPrint('[AUTH] Error: phone number is null');
        emit(AuthError('Phone number not found'));
        return;
      }

      final response = await ConnectivityService.instance.guard(
        () => _supabase.auth.verifyOTP(
          email: _currentPhone!,
          token: event.otp,
          type: OtpType.email,
        ),
      );

      debugPrint('[AUTH] OTP verified. User: ${response.user?.id}');

      if (response.user == null) {
        debugPrint('[AUTH] Error: user is null after OTP verification');
        emit(AuthError('Invalid OTP'));
        return;
      }

      final memberData = await _supabase
          .from('members')
          .select()
          .eq('user_id', response.user!.id)
          .maybeSingle();

      debugPrint('[AUTH] Member lookup result: ${memberData != null ? 'found' : 'not found'}');

      if (memberData == null) {
        emit(AuthRegistration());
      } else {
        final storedPin = await _storage.read(key: 'user_pin_${response.user!.id}');
        debugPrint('[AUTH] Stored PIN exists: ${storedPin != null}');
        if (storedPin == null) {
          emit(AuthPinEntry(isNewUser: true));
        } else {
          emit(AuthPinEntry(isNewUser: false));
        }
      }
    } on AuthException catch (e) {
      debugPrint('[AUTH] AuthException verifying OTP: ${e.message} (status: ${e.statusCode})');
      emit(AuthError('OTP verification failed: ${e.message}'));
    } catch (e, stack) {
      debugPrint('[AUTH] Unexpected error verifying OTP: $e');
      debugPrint('[AUTH] Stack trace: $stack');
      emit(AuthError('OTP verification failed: ${e.toString()}'));
    }
  }

  Future<void> _onRegisterSubmitted(
      AuthRegisterSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint('[REGISTER] Error: no authenticated user');
        emit(AuthError('User not authenticated'));
        return;
      }

      debugPrint('[REGISTER] Creating member for user: ${user.id}');
      debugPrint('[REGISTER] Email: ${user.email}');
      debugPrint('[REGISTER] Full name: ${event.fullName}');
      debugPrint('[REGISTER] National ID: ${event.nationalId}');
      debugPrint('[REGISTER] Phone: ${event.phoneNumber}');

      // Generate member number based on current count
      final countResult = await _supabase.from('members').select('id');
      final memberNumber = 'OM${(countResult.length + 1).toString().padLeft(4, '0')}';
      debugPrint('[REGISTER] Generated member number: $memberNumber');

      await _supabase.from('members').insert({
        'user_id': user.id,
        'member_number': memberNumber,
        'full_name': event.fullName,
        'national_id': event.nationalId,
        'phone_number': event.phoneNumber,
        'email': user.email,
        'status': 'active',
      });

      // Fetch the created member to get the id
      final member = await _supabase
          .from('members')
          .select('id')
          .eq('user_id', user.id)
          .single();

      // Create BOSA account
      await _supabase.from('bosa_accounts').insert({
        'member_id': member['id'],
        'account_number': 'BOSA-$memberNumber',
        'savings_balance': 0.00,
        'shares_balance': 0.00,
      });

      // Create FOSA account
      await _supabase.from('fosa_accounts').insert({
        'member_id': member['id'],
        'account_number': 'FOSA-$memberNumber',
        'balance': 0.00,
      });

      debugPrint('[REGISTER] Member and accounts created successfully');
      emit(AuthPinEntry(isNewUser: true));
    } on PostgrestException catch (e) {
      debugPrint('[REGISTER] PostgrestException: ${e.message}');
      debugPrint('[REGISTER] Code: ${e.code}, Details: ${e.details}, Hint: ${e.hint}');
      emit(AuthError('Registration failed: ${e.message}'));
    } catch (e, stack) {
      debugPrint('[REGISTER] Unexpected error: $e');
      debugPrint('[REGISTER] Stack: $stack');
      emit(AuthError('Registration failed: ${e.toString()}'));
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
      if (storedPin != event.pin && event.pin != '__biometric__') {
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

      final memberData = await _supabase
          .from('members')
          .select()
          .eq('user_id', user.id)
          .single();

      emit(AuthAuthenticated(memberData));
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
          .maybeSingle();

      if (memberData == null) return;

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
      }, onConflict: 'member_id,device_id');
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
