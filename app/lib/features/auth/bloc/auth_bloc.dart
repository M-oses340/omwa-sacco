import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/utils/pin_utils.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();

  static const int _maxPinAttempts = 5;
  static const Duration _lockoutDuration = Duration(minutes: 5);

  AuthBloc() : super(AuthInitial()) {
    on<AuthCheckSession>(_onCheckSession);
    on<AuthNavigateToPhone>((_, emit) => emit(AuthPhoneEntry()));
    on<AuthEmailSubmitted>(_onEmailSubmitted);
    on<AuthOtpSubmitted>(_onOtpSubmitted);
    on<AuthRegisterSubmitted>(_onRegisterSubmitted);
    on<AuthPinFirstEntry>((event, emit) => emit(AuthPinConfirm(event.pin)));
    on<AuthPinSubmitted>(_onPinSubmitted);
    on<AuthBiometricRequested>(_onBiometricRequested);
    on<AuthPinSetup>(_onPinSetup);
    on<AuthLogoutRequested>(_onLogout);
  }

  Future<void> _onCheckSession(
      AuthCheckSession event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final session = _supabase.auth.currentSession;
      if (session == null) {
        emit(AuthUnauthenticated());
        return;
      }
      final user = session.user;

      final lockoutStr = await _storage.read(key: 'pin_lockout_${user.id}');
      if (lockoutStr != null) {
        final unlocksAt = DateTime.tryParse(lockoutStr);
        if (unlocksAt != null && DateTime.now().isBefore(unlocksAt)) {
          emit(AuthPinLocked(unlocksAt));
          return;
        } else {
          await _storage.delete(key: 'pin_lockout_${user.id}');
          await _storage.delete(key: 'pin_attempts_${user.id}');
        }
      }

      var storedPin = await _storage.read(key: 'user_pin_${user.id}');

      // One-time migration: plaintext PIN → wipe and re-setup
      if (storedPin != null &&
          !RegExp(r'^[a-f0-9]{64}$').hasMatch(storedPin)) {
        await _storage.delete(key: 'user_pin_${user.id}');
        storedPin = null;
      }

      if (storedPin == null) {
        final memberData = await _supabase
            .from('members')
            .select('full_name')
            .eq('user_id', user.id)
            .maybeSingle();
        emit(AuthPinEntry(
          needsPinSetup: true,
          memberName: memberData?['full_name'],
        ));
        return;
      }
      emit(AuthPinEntry(needsPinSetup: false));
    } catch (_) {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onEmailSubmitted(
      AuthEmailSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      await ConnectivityService.instance.guard(
        () => _supabase.auth.signInWithOtp(email: event.email),
      );
      emit(AuthOtpEntry(event.email));
    } on AuthException catch (e) {
      emit(AuthError('Failed to send OTP: ${e.message}'));
    } catch (e) {
      emit(AuthError('Failed to send OTP: ${e.toString()}'));
    }
  }

  Future<void> _onOtpSubmitted(
      AuthOtpSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final response = await ConnectivityService.instance.guard(
        () => _supabase.auth.verifyOTP(
          email: event.email,
          token: event.otp,
          type: OtpType.email,
        ),
      );

      if (response.user == null) {
        emit(AuthError('Invalid OTP'));
        return;
      }

      final memberData = await _supabase
          .from('members')
          .select()
          .eq('user_id', response.user!.id)
          .maybeSingle();

      if (memberData == null) {
        emit(AuthRegistration());
      } else {
        final storedPin =
            await _storage.read(key: 'user_pin_${response.user!.id}');
        emit(AuthPinEntry(
          needsPinSetup: storedPin == null,
          memberName: memberData['full_name'],
        ));
      }
    } on AuthException catch (e) {
      emit(AuthError('OTP verification failed: ${e.message}'));
    } catch (e) {
      emit(AuthError('OTP verification failed: ${e.toString()}'));
    }
  }

  Future<void> _onRegisterSubmitted(
      AuthRegisterSubmitted event, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(AuthError('User not authenticated'));
        return;
      }

      await _supabase.rpc('create_member', params: {
        'p_user_id': user.id,
        'p_full_name': event.fullName,
        'p_national_id': event.nationalId,
        'p_phone_number': event.phoneNumber,
        'p_email': user.email,
      });

      emit(AuthPinEntry(needsPinSetup: true));
    } on PostgrestException catch (e) {
      emit(AuthError('Registration failed: ${e.message}'));
    } catch (e) {
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
      final hashedInput = hashPin(event.pin);

      if (storedPin != hashedInput) {
        await _handleFailedAttempt(user.id, emit);
        return;
      }

      await _clearAttempts(user.id);
      await _registerDevice();

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

  Future<void> _onBiometricRequested(
      AuthBiometricRequested event, Emitter<AuthState> emit) async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck || !isSupported) return;

      final success = await _localAuth.authenticate(
        localizedReason: 'Use fingerprint to unlock Omwa Sacco',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );

      if (!success) return;

      emit(AuthLoading());
      final user = _supabase.auth.currentUser;
      if (user == null) {
        emit(AuthError('User not authenticated'));
        return;
      }

      await _registerDevice();
      final memberData = await _supabase
          .from('members')
          .select()
          .eq('user_id', user.id)
          .single();

      emit(AuthAuthenticated(memberData));
    } catch (_) {}
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

      await _storage.write(
          key: 'user_pin_${user.id}', value: hashPin(event.pin));

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

  Future<void> _handleFailedAttempt(
      String userId, Emitter<AuthState> emit) async {
    final attemptsStr =
        await _storage.read(key: 'pin_attempts_$userId') ?? '0';
    final attempts = int.parse(attemptsStr) + 1;
    await _storage.write(
        key: 'pin_attempts_$userId', value: attempts.toString());

    if (attempts >= _maxPinAttempts) {
      final unlocksAt = DateTime.now().add(_lockoutDuration);
      await _storage.write(
          key: 'pin_lockout_$userId', value: unlocksAt.toIso8601String());
      emit(AuthPinLocked(unlocksAt));
    } else {
      final remaining = _maxPinAttempts - attempts;
      emit(AuthError(
          'Invalid PIN. $remaining attempt${remaining == 1 ? '' : 's'} remaining.'));
      emit(AuthPinEntry(needsPinSetup: false, failedAttempts: attempts));
    }
  }

  Future<void> _clearAttempts(String userId) async {
    await _storage.delete(key: 'pin_attempts_$userId');
    await _storage.delete(key: 'pin_lockout_$userId');
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

      final memberData = await _supabase
          .from('members')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (memberData == null) return;

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
    } catch (_) {}
  }

  Future<void> _onLogout(
      AuthLogoutRequested event, Emitter<AuthState> emit) async {
    await _supabase.auth.signOut();
    emit(AuthUnauthenticated());
  }
}
