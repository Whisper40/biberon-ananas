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
  BabyEventType? _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final firstDateTime = now.subtract(const Duration(days: 30));
    final filtered =
        widget.events
            .where(
              (event) =>
                  !event.startedAt.isBefore(firstDateTime) &&
                  !event.startedAt.isAfter(now) &&
                  (_filter == null || event.type == _filter),
            )
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '30 derniers jours',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
              ? _EmptyJournal(filter: _filter)
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) => _TimelineGap(
                    newerEvent: filtered[index],
                    olderEvent: filtered[index + 1],
                  ),
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

class _TimelineGap extends StatelessWidget {
  const _TimelineGap({required this.newerEvent, required this.olderEvent});

  final BabyEvent newerEvent;
  final BabyEvent olderEvent;

  @override
  Widget build(BuildContext context) {
    final elapsed = newerEvent.startedAt.difference(olderEvent.startedAt);
    return SizedBox(
      height: 54,
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Center(
              child: Container(
                width: 2,
                height: 32,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          Icon(
            Icons.schedule_rounded,
            size: 16,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${_durationLabel(elapsed.inSeconds)} depuis ${_dateTimeLabel(olderEvent.startedAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
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
        Icons.child_care_rounded,
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
      key: ValueKey('journal-event-${event.id}'),
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
                    _dateTimeLabel(event.startedAt),
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
  const _EmptyJournal({required this.filter});

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
                ? 'Aucun événement enregistré au cours des 30 derniers jours.'
                : 'Aucun événement « ${filter!.label.toLowerCase()} » au cours des 30 derniers jours.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

String _dateTimeLabel(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _durationLabel(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds ~/ 60) % 60;
  final remainder = seconds % 60;
  if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  if (minutes > 0) return '$minutes min${remainder > 0 ? ' $remainder s' : ''}';
  return '$remainder s';
}
