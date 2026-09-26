import 'package:flutter/material.dart';

import '../models/baby_event.dart';

class JournalPage extends StatefulWidget {
  const JournalPage({
    required this.events,
    required this.onEdit,
    required this.onDelete,
    this.initialFilter,
    super.key,
  });

  final List<BabyEvent> events;
  final BabyEventType? initialFilter;
  final ValueChanged<BabyEvent> onEdit;
  final ValueChanged<BabyEvent> onDelete;

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  late DateTime _selectedDate;
  BabyEventType? _filter;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
    _filter = widget.initialFilter;
  }

  bool _sameDay(DateTime left, DateTime right) =>
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  void _changeDay(int delta) {
    final next = _selectedDate.add(Duration(days: delta));
    if (next.isAfter(DateTime.now())) return;
    setState(() => _selectedDate = next);
  }

  Future<void> _pickDay() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: 'Choisir une journée',
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.events
            .where(
              (event) =>
                  _sameDay(event.startedAt, _selectedDate) &&
                  (_filter == null || event.type == _filter),
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Column(
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => _changeDay(-1),
                      tooltip: 'Jour précédent',
                      icon: const Icon(Icons.chevron_left_rounded),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: _pickDay,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Text(
                          _dayLabel(_selectedDate),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _sameDay(_selectedDate, DateTime.now())
                          ? null
                          : () => _changeDay(1),
                      tooltip: 'Jour suivant',
                      icon: const Icon(Icons.chevron_right_rounded),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'Tout',
                      selected: _filter == null,
                      onSelected: () => setState(() => _filter = null),
                    ),
                    const SizedBox(width: 8),
                    for (final type in BabyEventType.values) ...[
                      _FilterChip(
                        label: type.label,
                        selected: _filter == type,
                        onSelected: () => setState(() => _filter = type),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyJournal(date: _selectedDate, filter: _filter)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _EventTile(
                    event: filtered[index],
                    onEdit: () => widget.onEdit(filtered[index]),
                    onDelete: () => widget.onDelete(filtered[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label),
    selected: selected,
    onSelected: (_) => onSelected(),
    showCheckmark: false,
  );
}

class _EventTile extends StatelessWidget {
  const _EventTile({
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  final BabyEvent event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final details = switch (event.type) {
      BabyEventType.breastfeeding || BabyEventType.pumping =>
        '${event.breastSide?.label ?? 'Sein non précisé'} · ${_durationLabel(event.durationSeconds ?? 0)}',
      BabyEventType.bottle =>
        event.amountMl == null ? 'Quantité : N/A' : '${event.amountMl} mL',
      BabyEventType.weight =>
        '${event.measurement?.toStringAsFixed(2).replaceAll('.', ',') ?? '—'} kg',
      BabyEventType.height =>
        '${event.measurement?.toStringAsFixed(0) ?? '—'} cm',
    };
    final (icon, color) = switch (event.type) {
      BabyEventType.breastfeeding => (
        Icons.favorite_rounded,
        const Color(0xFFFCE3E2),
      ),
      BabyEventType.bottle => (
        Icons.local_drink_rounded,
        const Color(0xFFE2F0FF),
      ),
      BabyEventType.pumping => (
        Icons.water_drop_rounded,
        const Color(0xFFE8E2FF),
      ),
      BabyEventType.weight => (
        Icons.monitor_weight_rounded,
        const Color(0xFFFFEBCD),
      ),
      BabyEventType.height => (Icons.height_rounded, const Color(0xFFE1F2E8)),
    };
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color,
              child: Icon(icon, color: const Color(0xFF49352F)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.type.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(details, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 3),
                  Text(
                    _timeLabel(event.startedAt),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'Actions sur l’événement',
              onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Modifier'),
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: ListTile(
                    leading: Icon(Icons.delete_outline),
                    title: Text('Supprimer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyJournal extends StatelessWidget {
  const _EmptyJournal({required this.date, required this.filter});

  final DateTime date;
  final BabyEventType? filter;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_note_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun événement',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            filter == null
                ? 'Rien n’est enregistré le ${_dayLabel(date)}. Les événements ajoutés apparaîtront ici.'
                : 'Aucun événement « ${filter!.label.toLowerCase()} » ce jour-là.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

String _dayLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

String _timeLabel(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _durationLabel(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds ~/ 60) % 60;
  final remainder = seconds % 60;
  if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  if (minutes > 0) return '$minutes min${remainder > 0 ? ' $remainder s' : ''}';
  return '$remainder s';
}
