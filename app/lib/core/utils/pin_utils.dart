import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Hashes a PIN using SHA-256 so it is never stored in plaintext.
String hashPin(String pin) {
  final bytes = utf8.encode(pin);
  return sha256.convert(bytes).toString();
}
