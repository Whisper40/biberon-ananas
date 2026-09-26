import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/baby.dart';
import '../models/baby_event.dart';
import '../services/baby_repository.dart';
import '../services/update_checker.dart';
import 'baby_form_page.dart';
import 'event_editor_page.dart';
import 'journal_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    required this.repository,
    required this.updateChannel,
    required this.onUpdateChannelChanged,
    super.key,
  });

  final BabyRepository repository;
  final UpdateChannel updateChannel;
  final ValueChanged<UpdateChannel> onUpdateChannelChanged;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  BabyEventType? _journalFilter;
  int _journalRevision = 0;
  bool _isBackupBusy = false;

  Baby? get _activeBaby => widget.repository.activeBaby;

  Future<void> _saveBaby(Baby baby) async {
    await widget.repository.addBaby(baby);
    if (mounted) setState(() {});
  }

  Future<void> _addBaby() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => BabyFormPage(
          onSaved: (baby) async {
            await widget.repository.addBaby(baby);
            if (mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _openEvent(BabyEventType type, {BabyEvent? event}) async {
    final baby = _activeBaby;
    if (baby == null) return;
    final result = await Navigator.of(context).push<BabyEvent>(
      MaterialPageRoute(
        builder: (_) =>
            EventEditorPage(babyId: baby.id, type: type, event: event),
      ),
    );
    if (result == null || !mounted) return;
    await widget.repository.saveEvent(result);
    if (!mounted) return;
    setState(() {
      _tab = 1;
      if (event == null) {
        _journalFilter = result.type;
        _journalRevision++;
      }
    });
  }

  Future<void> _deleteEvent(BabyEvent event) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer cet événement ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      await widget.repository.deleteEvent(event.id);
      if (mounted) setState(() {});
    }
  }

  Future<void> _exportBackup() async {
    if (_isBackupBusy) return;
    setState(() => _isBackupBusy = true);
    try {
      final now = DateTime.now();
      String two(int value) => value.toString().padLeft(2, '0');
      final timestamp =
          '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
      final saved = await FilePicker.saveFile(
        dialogTitle: 'Exporter la sauvegarde Biberon Ananas',
        fileName: 'biberon_ananas_$timestamp.json',
        mimeType: 'application/json',
        type: FileType.custom,
        allowedExtensions: const ['json'],
        bytes: Uint8List.fromList(utf8.encode(widget.repository.exportJson())),
      );
      if (mounted && saved != null) {
        _showBackupMessage('Sauvegarde exportée.');
      }
    } catch (error) {
      if (mounted) _showBackupMessage('Export impossible : $error');
    } finally {
      if (mounted) setState(() => _isBackupBusy = false);
    }
  }

  Future<void> _restoreBackup() async {
    if (_isBackupBusy) return;
    setState(() => _isBackupBusy = true);
    try {
      final picked = await FilePicker.pickFile(
        dialogTitle: 'Choisir une sauvegarde Biberon Ananas',
        type: FileType.custom,
        allowedExtensions: const ['json'],
      );
      if (picked == null || !mounted) return;
      final backup = widget.repository.parseBackupData(
        utf8.decode(await picked.readAsBytes()),
      );
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber_rounded),
          title: const Text('Remplacer les données actuelles ?'),
          content: Text(
            'Cette restauration va remplacer ${widget.repository.babies.length} profil(s) et ${widget.repository.events.length} événement(s) par ${backup.babies.length} profil(s) et ${backup.events.length} événement(s). Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Restaurer'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      await widget.repository.restoreBackup(backup);
      if (!mounted) return;
      setState(() {
        _tab = 0;
        _journalFilter = null;
        _journalRevision++;
      });
      _showBackupMessage(
        '${backup.babies.length} profil(s) et ${backup.events.length} événement(s) restauré(s).',
      );
    } on FormatException catch (error) {
      if (mounted) _showBackupMessage('Sauvegarde invalide : ${error.message}');
    } catch (error) {
      if (mounted) _showBackupMessage('Restauration impossible : $error');
    } finally {
      if (mounted) setState(() => _isBackupBusy = false);
    }
  }

  void _showBackupMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectMenuItem(String? value) async {
    if (value == null) return;
    if (value.startsWith('baby:')) {
      await widget.repository.setActiveBaby(value.substring(5));
      if (mounted) setState(() => _journalRevision++);
    } else if (value == 'add-baby') {
      await _addBaby();
    } else if (value == 'export-backup') {
      await _exportBackup();
    } else if (value == 'restore-backup') {
      await _restoreBackup();
    } else if (value.startsWith('channel:')) {
      final channel = UpdateChannel.values.firstWhere(
        (candidate) => candidate.name == value.substring(8),
      );
      widget.onUpdateChannelChanged(channel);
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final baby = _activeBaby;
    if (baby == null) {
      return BabyFormPage(onboarding: true, onSaved: _saveBaby);
    }
    final events = widget.repository.eventsForBaby(baby.id);
    return Scaffold(
      appBar: AppBar(
        title: Text(_tab == 0 ? 'Bonjour, ${baby.name}' : 'Journal'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Enfants et préférences',
            onSelected: _selectMenuItem,
            itemBuilder: (context) => [
              for (final child in widget.repository.babies)
                PopupMenuItem<String>(
                  value: 'baby:${child.id}',
                  child: Row(
                    children: [
                      Icon(
                        child.id == baby.id
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(child.name),
                    ],
                  ),
                ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'add-baby',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.person_add_alt_1_rounded),
                  title: Text('Ajouter un enfant'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'export-backup',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.save_alt_rounded),
                  title: Text('Exporter mes données'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'restore-backup',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.settings_backup_restore_rounded),
                  title: Text('Restaurer une sauvegarde'),
                ),
              ),
              const PopupMenuDivider(),
              for (final channel in UpdateChannel.values)
                PopupMenuItem<String>(
                  value: 'channel:${channel.name}',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      channel == widget.updateChannel
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                    ),
                    title: Text('Mises à jour ${channel.label}'),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _tab,
        children: [
          TodayPage(
            baby: baby,
            events: events,
            onAddEvent: (type) => _openEvent(type),
            onOpenJournal: () => setState(() => _tab = 1),
          ),
          JournalPage(
            key: ValueKey(
              '${baby.id}-${_journalFilter?.name}-$_journalRevision',
            ),
            events: events,
            initialFilter: _journalFilter,
            onEdit: (event) => _openEvent(event.type, event: event),
            onDelete: _deleteEvent,
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) => setState(() => _tab = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Aujourd’hui',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories_rounded),
            label: 'Journal',
          ),
        ],
      ),
    );
  }
}

class TodayPage extends StatelessWidget {
  const TodayPage({
    required this.baby,
    required this.events,
    required this.onAddEvent,
    required this.onOpenJournal,
    super.key,
  });

  final Baby baby;
  final List<BabyEvent> events;
  final ValueChanged<BabyEventType> onAddEvent;
  final VoidCallback onOpenJournal;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayEvents = events
        .where(
          (event) =>
              event.startedAt.year == today.year &&
              event.startedAt.month == today.month &&
              event.startedAt.day == today.day,
        )
        .toList();
    final feedCount = todayEvents
        .where(
          (event) =>
              event.type == BabyEventType.breastfeeding ||
              event.type == BabyEventType.bottle,
        )
        .length;
    final lastFeed = todayEvents
        .where(
          (event) =>
              event.type == BabyEventType.breastfeeding ||
              event.type == BabyEventType.bottle,
        )
        .firstOrNull;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primaryContainer,
                const Color(0xFFFFE9DD),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _dateLabel(today),
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Comment va ${baby.name} ?',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    Text('${_ageLabel(baby.birthDate, today)} de bonheur'),
                  ],
                ),
              ),
              const Icon(Icons.child_friendly_rounded, size: 58),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                icon: Icons.restaurant_rounded,
                value: '$feedCount',
                label: feedCount == 1
                    ? 'repas aujourd’hui'
                    : 'repas aujourd’hui',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SummaryCard(
                icon: Icons.schedule_rounded,
                value: lastFeed == null ? '—' : _timeLabel(lastFeed.startedAt),
                label: 'dernier repas',
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Ajouter un événement',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            IconButton(
              onPressed: onOpenJournal,
              tooltip: 'Voir le journal',
              icon: const Icon(Icons.arrow_forward_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.builder(
          itemCount: BabyEventType.values.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.38,
          ),
          itemBuilder: (context, index) {
            final type = BabyEventType.values[index];
            return _EventActionCard(type: type, onTap: () => onAddEvent(type));
          },
        ),
        const SizedBox(height: 24),
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 8,
            ),
            leading: const CircleAvatar(
              child: Icon(Icons.auto_stories_rounded),
            ),
            title: const Text('Tout le suivi de la journée'),
            subtitle: Text(
              '${todayEvents.length} événement${todayEvents.length == 1 ? '' : 's'} enregistré${todayEvents.length == 1 ? '' : 's'}',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: onOpenJournal,
          ),
        ),
      ],
    );
  }

  static String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  static String _timeLabel(DateTime date) =>
      '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  static String _ageLabel(DateTime birth, DateTime now) {
    final months =
        (now.year - birth.year) * 12 +
        now.month -
        birth.month -
        (now.day < birth.day ? 1 : 0);
    if (months <= 0) {
      final days = now.difference(birth).inDays;
      return '${days < 0 ? 0 : days} jour${days == 1 ? '' : 's'}';
    }
    final years = months ~/ 12;
    final remainingMonths = months % 12;
    if (years == 0) return '$months mois';
    if (remainingMonths == 0) return '$years an${years == 1 ? '' : 's'}';
    return '$years an${years == 1 ? '' : 's'} et $remainingMonths mois';
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _EventActionCard extends StatelessWidget {
  const _EventActionCard({required this.type, required this.onTap});

  final BabyEventType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (icon, tint) = switch (type) {
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
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: tint,
                child: Icon(icon, color: const Color(0xFF49352F)),
              ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      type.label,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.add_circle_outline_rounded, size: 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
