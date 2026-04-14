import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'transactions_event.dart';
part 'transactions_state.dart';

class TransactionsBloc extends Bloc<TransactionsEvent, TransactionsState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  TransactionsBloc() : super(TransactionsInitial()) {
    on<TransactionsLoaded>(_onLoaded);
  }

  Future<void> _onLoaded(TransactionsLoaded event, Emitter<TransactionsState> emit) async {
    emit(TransactionsLoading());
    try {
      var query = _supabase
          .from('transactions')
          .select()
          .eq('member_id', event.memberId);

      if (event.type != null) {
        query = query.eq('transaction_type', event.type!);
      }

      final data = await query.order('created_at', ascending: false);
      emit(TransactionsSuccess(
        transactions: (data as List).cast<Map<String, dynamic>>(),
        filter: event.type,
      ));
    } catch (e) {
      emit(TransactionsError(e.toString().replaceAll('Exception: ', '')));
    }
  }
}
