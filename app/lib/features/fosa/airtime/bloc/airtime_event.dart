part of 'airtime_bloc.dart';

abstract class AirtimeEvent {}

class AirtimePurchased extends AirtimeEvent {
  final String memberId;
  final String phoneNumber;
  final String network;
  final double amount;
  AirtimePurchased({
    required this.memberId,
    required this.phoneNumber,
    required this.network,
    required this.amount,
  });
}
