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

  void _confirmCancel(BuildContext ctx, String scheduleId) {
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Schedule'),
        content: const Text('Are you sure you want to cancel this scheduled payment?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              ctx.read<RatibaBloc>().add(
                    RatibaScheduleCancelled(scheduleId: scheduleId, memberId: member['id']),
                  );
            },
            child: const Text('Cancel Schedule'),
          ),
        ],
      ),
    );
  }

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
            final status = s['status'] as String? ?? 'active';
            final isActive = status == 'active';
            final isPaused = status == 'paused';
            final isCancelled = status == 'cancelled';

            Color statusColor = isActive
                ? cs.primary
                : isPaused
                    ? Colors.orange
                    : cs.onSurface.withValues(alpha: 0.3);

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.repeat, color: statusColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(
                      s['payment_type']?.toString().replaceAll('_', ' ').toUpperCase() ?? 'PAYMENT',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    Text(
                      'KES ${amount.toStringAsFixed(2)} · ${s['frequency'] ?? ''}',
                      style: TextStyle(fontSize: 12, color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                    if (s['destination_name'] != null && (s['destination_name'] as String).isNotEmpty)
                      Text(
                        '→ ${s['destination_name']} (${s['destination_type']?.toString().toUpperCase() ?? ''})',
                        style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.5)),
                      ),
                    if (nextRun != null && !isCancelled)
                      Text(
                        'Next: ${nextRun.day}/${nextRun.month}/${nextRun.year}',
                        style: TextStyle(fontSize: 11, color: statusColor),
                      ),
                    if (isCancelled)
                      Text('Cancelled', style: TextStyle(fontSize: 11, color: cs.onSurface.withValues(alpha: 0.4))),
                    if (isPaused)
                      const Text('Paused', style: TextStyle(fontSize: 11, color: Colors.orange)),
                  ]),
                ),
                if (!isCancelled) ...[
                  // Pause / Resume toggle
                  if (isActive || isPaused)
                    IconButton(
                      icon: Icon(
                        isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                        color: isActive ? Colors.orange : Colors.green,
                      ),
                      tooltip: isActive ? 'Pause' : 'Resume',
                      onPressed: () => ctx.read<RatibaBloc>().add(
                            RatibaScheduleStatusToggled(
                              scheduleId: s['id'].toString(),
                              memberId: member['id'],
                              newStatus: isActive ? 'paused' : 'active',
                            ),
                          ),
                    ),
                  // Cancel
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                    tooltip: 'Cancel',
                    onPressed: () => _confirmCancel(ctx, s['id'].toString()),
                  ),
                ],
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
  final _destAccountCtrl = TextEditingController();
  final _destNameCtrl = TextEditingController();
  final _destRefCtrl = TextEditingController();

  String _paymentType = 'savings';
  String _frequency = 'monthly';
  String _destType = 'mpesa';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));

  static const _paymentTypes = ['savings', 'loan_repayment', 'shares'];
  static const _frequencies = ['daily', 'weekly', 'monthly'];
  static const _destTypes = ['mpesa', 'paybill', 'till', 'pesalink'];

  static const _destLabels = {
    'mpesa':    'M-Pesa Phone Number',
    'paybill':  'Business Number',
    'till':     'Till Number',
    'pesalink': 'Bank Account Number',
  };
  static const _destIcons = {
    'mpesa':    Icons.phone_android,
    'paybill':  Icons.receipt_long,
    'till':     Icons.store,
    'pesalink': Icons.account_balance,
  };

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    _destAccountCtrl.dispose();
    _destNameCtrl.dispose();
    _destRefCtrl.dispose();
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
      memberId:           widget.member['id'],
      paymentType:        _paymentType,
      amount:             double.parse(_amountCtrl.text.trim()),
      frequency:          _frequency,
      startDate:          _startDate,
      description:        _descCtrl.text.trim(),
      destinationType:    _destType,
      destinationAccount: _destAccountCtrl.text.trim(),
      destinationName:    _destNameCtrl.text.trim(),
      destinationRef:     _destRefCtrl.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BlocBuilder<RatibaBloc, RatibaState>(
      builder: (ctx, state) => SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Payment type
              Text('Payment Type', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: _paymentTypes.map((t) => ChoiceChip(
                label: Text(t.replaceAll('_', ' ')),
                selected: _paymentType == t,
                onSelected: (_) => setState(() => _paymentType = t),
              )).toList()),
              const SizedBox(height: 16),

              // Amount
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

              // Frequency
              Text('Frequency', style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: _frequencies.map((f) => ChoiceChip(
                label: Text(f),
                selected: _frequency == f,
                onSelected: (_) => setState(() => _frequency = f),
              )).toList()),
              const SizedBox(height: 16),

              // Start date
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: InputDecorator(
                  decoration: const InputDecoration(labelText: 'Start Date', prefixIcon: Icon(Icons.calendar_today)),
                  child: Text('${_startDate.day}/${_startDate.month}/${_startDate.year}'),
                ),
              ),
              const SizedBox(height: 20),

              // Destination section
              Row(children: [
                Icon(Icons.send, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text('Send To', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: cs.primary)),
              ]),
              const SizedBox(height: 10),

              // Destination type
              Wrap(spacing: 8, runSpacing: 4, children: _destTypes.map((d) => ChoiceChip(
                avatar: Icon(_destIcons[d], size: 14),
                label: Text(d.toUpperCase()),
                selected: _destType == d,
                onSelected: (_) => setState(() {
                  _destType = d;
                  _destAccountCtrl.clear();
                  _destRefCtrl.clear();
                }),
              )).toList()),
              const SizedBox(height: 14),

              // Recipient name
              TextFormField(
                controller: _destNameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Recipient Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),

              // Account number / phone / till / business
              TextFormField(
                controller: _destAccountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _destLabels[_destType] ?? 'Account',
                  prefixIcon: Icon(_destIcons[_destType] ?? Icons.account_circle),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),

              // Account reference — only for paybill and pesalink
              if (_destType == 'paybill' || _destType == 'pesalink') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _destRefCtrl,
                  decoration: InputDecoration(
                    labelText: _destType == 'paybill' ? 'Account Reference (e.g. meter no.)' : 'Bank Code',
                    prefixIcon: const Icon(Icons.tag),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 12),

              // Description
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  prefixIcon: Icon(Icons.notes),
                ),
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
