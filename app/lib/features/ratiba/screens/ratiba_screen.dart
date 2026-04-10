import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../bloc/ratiba_bloc.dart';

Future<void> showRatibaSheet(BuildContext context, Map<String, dynamic> member) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BlocProvider(
      create: (_) => RatibaBloc()..add(RatibaSchedulesLoaded(member['id'])),
      child: _RatibaSheet(member: member),
    ),
  );
}

class _RatibaSheet extends StatefulWidget {
  final Map<String, dynamic> member;
  const _RatibaSheet({required this.member});
  @override
  State<_RatibaSheet> createState() => _RatibaSheetState();
}

class _RatibaSheetState extends State<_RatibaSheet> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocListener<RatibaBloc, RatibaState>(
      listener: (ctx, state) {
        if (state is RatibaActionSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.green),
          );
          _tabCtrl.animateTo(0);
        } else if (state is RatibaError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: cs.error),
          );
        }
      },
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: cs.outlineVariant, borderRadius: BorderRadius.circular(2))),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(children: [
                  Icon(Icons.schedule, color: cs.primary),
                  const SizedBox(width: 10),
                  Text('Ratiba', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Text('Scheduled Payments', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.5))),
                ]),
              ),
              TabBar(controller: _tabCtrl, tabs: const [Tab(text: 'My Schedules'), Tab(text: 'New Schedule')]),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _SchedulesList(member: widget.member, scrollCtrl: scrollCtrl),
                    _NewScheduleForm(member: widget.member),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SchedulesList extends StatelessWidget {
  final Map<String, dynamic> member;
  final ScrollController scrollCtrl;
  const _SchedulesList({required this.member, required this.scrollCtrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<RatibaBloc, RatibaState>(
      builder: (ctx, state) {
        if (state is RatibaLoading || state is RatibaInitial) {
          return const Center(child: CircularProgressIndicator());
        }
        final schedules = state is RatibaLoaded
            ? state.schedules
            : state is RatibaActionSuccess
                ? state.schedules
                : <Map<String, dynamic>>[];

        if (schedules.isEmpty) {
          return Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule_outlined, size: 48, color: cs.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Text('No scheduled payments', style: TextStyle(color: cs.onSurface.withValues(alpha: 0.5))),
            ]),
          );
        }
        return ListView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(16),
          itemCount: schedules.length,
          itemBuilder: (_, i) {
            final s = schedules[i];
            final amount = double.tryParse(s['amount'].toString()) ?? 0;
            final nextRun = DateTime.tryParse(s['next_run_date'] ?? '');
            final isActive = s['status'] == 'active';
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isActive ? cs.primary.withValues(alpha: 0.3) : cs.outlineVariant),
              ),
              child: Row(children: [
                Icon(Icons.repeat, color: isActive ? cs.primary : cs.onSurface.withValues(alpha: 0.4)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(s['payment_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'PAYMENT',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('KES ${amount.toStringAsFixed(2)} · ${s['frequency'] ?? ''}',
                        style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6))),
                    if (nextRun != null)
                      Text('Next: ${nextRun.day}/${nextRun.month}/${nextRun.year}',
                          style: TextStyle(fontSize: 11, color: cs.primary)),
                  ]),
                ),
                if (isActive)
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    onPressed: () => ctx.read<RatibaBloc>().add(
                          RatibaScheduleCancelled(scheduleId: s['id'].toString(), memberId: member['id']),
                        ),
                    tooltip: 'Cancel',
                  ),
              ]),
            );
          },
        );
      },
    );
  }
}

class _NewScheduleForm extends StatefulWidget {
  final Map<String, dynamic> member;
  const _NewScheduleForm({required this.member});
  @override
  State<_NewScheduleForm> createState() => _NewScheduleFormState();
}

class _NewScheduleFormState extends State<_NewScheduleForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _paymentType = 'savings';
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));

  static const _paymentTypes = ['savings', 'loan_repayment', 'shares'];
  static const _frequencies = ['daily', 'weekly', 'monthly'];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  void _submit(BuildContext ctx) {
    if (!_formKey.currentState!.validate()) return;
    ctx.read<RatibaBloc>().add(RatibaScheduleCreated(
      memberId: widget.member['id'],
      paymentType: _paymentType,
      amount: double.parse(_amountCtrl.text.trim()),
      frequency: _frequency,
      startDate: _startDate,
      description: _descCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<RatibaBloc, RatibaState>(
      builder: (ctx, state) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Payment Type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _paymentTypes.map((t) => ChoiceChip(
                  label: Text(t.replaceAll('_', ' ')),
                  selected: _paymentType == t,
                  onSelected: (_) => setState(() => _paymentType = t),
                )).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],
                decoration: const InputDecoration(labelText: 'Amount (KES)', prefixIcon: Icon(Icons.payments_outlined)),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return 'Enter a valid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Frequency', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _frequencies.map((f) => ChoiceChip(
                  label: Text(f),
                  selected: _frequency == f,
                  onSelected: (_) => setState(() => _frequency = f),
                )).toList(),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Start Date', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(labelText: 'Description (optional)', prefixIcon: Icon(Icons.notes)),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: state is RatibaLoading ? null : () => _submit(ctx),
                  child: state is RatibaLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Create Schedule'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
