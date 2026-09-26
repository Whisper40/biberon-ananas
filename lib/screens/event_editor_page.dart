import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/baby_event.dart';

class EventEditorPage extends StatefulWidget {
  const EventEditorPage({
    required this.babyId,
    required this.type,
    this.event,
    super.key,
  });

  final String babyId;
  final BabyEventType type;
  final BabyEvent? event;

  @override
  State<EventEditorPage> createState() => _EventEditorPageState();
}

class _EventEditorPageState extends State<EventEditorPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _measurementController;
  late DateTime _startedAt;
  late BreastSide _side;
  late int? _amountMl;
  late int _durationSeconds;
  int _durationBase = 0;
  Stopwatch? _stopwatch;
  Timer? _ticker;
  bool _running = false;

  bool get _isTimed =>
      widget.type == BabyEventType.breastfeeding ||
      widget.type == BabyEventType.pumping;
  bool get _isMeasurement =>
      widget.type == BabyEventType.weight ||
      widget.type == BabyEventType.height;

  @override
  void initState() {
    super.initState();
    final existing = widget.event;
    _startedAt = existing?.startedAt ?? DateTime.now();
    _side = existing?.breastSide ?? BreastSide.left;
    _amountMl = existing?.amountMl;
    _durationSeconds = existing?.durationSeconds ?? 0;
    _measurementController = TextEditingController(
      text: existing?.measurement == null
          ? ''
          : widget.type == BabyEventType.weight
          ? existing!.measurement!.toStringAsFixed(2)
          : existing!.measurement!.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch?.stop();
    _measurementController.dispose();
    super.dispose();
  }

  Future<void> _chooseDateTime() async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: _startedAt.isAfter(now) ? today : _startedAt,
      firstDate: DateTime(2000),
      lastDate: today,
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_startedAt),
    );
    if (time == null || !mounted) return;
    final selected = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (selected.isAfter(now)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Un événement ne peut pas être daté dans le futur.'),
        ),
      );
      return;
    }
    setState(() => _startedAt = selected);
  }

  void _startTimer() {
    _durationBase = _durationSeconds;
    _stopwatch = Stopwatch()..start();
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(
        () => _durationSeconds =
            _durationBase + (_stopwatch?.elapsed.inSeconds ?? 0),
      );
    });
    setState(() => _running = true);
  }

  Future<void> _stopTimer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.timer_off_rounded),
        title: const Text('Terminer cette session ?'),
        content: Text(
          'Durée enregistrée : ${_formatDuration(_currentDuration)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Continuer'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Arrêter'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    _ticker?.cancel();
    _durationSeconds = _currentDuration;
    _stopwatch?.stop();
    setState(() => _running = false);
  }

  int get _currentDuration => _running
      ? _durationBase + (_stopwatch?.elapsed.inSeconds ?? 0)
      : _durationSeconds;

  Future<void> _editDuration() async {
    if (_running) return;
    final duration = Duration(seconds: _durationSeconds);
    final hours = TextEditingController(text: duration.inHours.toString());
    final minutes = TextEditingController(
      text: (duration.inMinutes % 60).toString().padLeft(2, '0'),
    );
    final result = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Modifier la durée'),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: hours,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Heures'),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text(':'),
            ),
            Expanded(
              child: TextField(
                controller: minutes,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(labelText: 'Minutes'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final h = int.tryParse(hours.text) ?? 0;
              final m = int.tryParse(minutes.text) ?? 0;
              Navigator.pop(dialogContext, h * 3600 + m * 60);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    );
    hours.dispose();
    minutes.dispose();
    if (result != null) setState(() => _durationSeconds = result);
  }

  void _save() {
    if (_running) return;
    if (_isMeasurement && !_formKey.currentState!.validate()) return;
    final now = DateTime.now();
    final event = BabyEvent(
      id: widget.event?.id ?? now.microsecondsSinceEpoch.toString(),
      babyId: widget.babyId,
      type: widget.type,
      startedAt: _isMeasurement ? now : _startedAt,
      createdAt: now,
      durationSeconds: _isTimed ? _durationSeconds : null,
      breastSide: _isTimed ? _side : null,
      amountMl: widget.type == BabyEventType.bottle ? _amountMl : null,
      measurement: _isMeasurement
          ? double.parse(_measurementController.text.replaceAll(',', '.'))
          : null,
    );
    Navigator.of(context).pop(event);
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.event != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${existing ? 'Modifier' : 'Ajouter'} · ${widget.type.label}',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            if (!_isMeasurement) ...[
              _DateTimeCard(startedAt: _startedAt, onTap: _chooseDateTime),
              const SizedBox(height: 20),
            ],
            if (_isTimed) ...[
              _SectionTitle(
                title: widget.type == BabyEventType.breastfeeding
                    ? 'Quel sein ?'
                    : 'Sein utilisé',
                subtitle: 'Vous pourrez modifier ces informations plus tard.',
              ),
              const SizedBox(height: 12),
              SegmentedButton<BreastSide>(
                segments: BreastSide.values
                    .map(
                      (side) =>
                          ButtonSegment(value: side, label: Text(side.label)),
                    )
                    .toList(),
                selected: {_side},
                onSelectionChanged: (selection) =>
                    setState(() => _side = selection.first),
              ),
              const SizedBox(height: 24),
              _SectionTitle(
                title: 'Durée',
                subtitle:
                    'Lancez le minuteur, ou ajustez la durée manuellement.',
              ),
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        _formatClock(_currentDuration),
                        style: Theme.of(context).textTheme.displaySmall
                            ?.copyWith(
                              fontFeatures: const [],
                              fontWeight: FontWeight.w700,
                              fontFamily: 'monospace',
                            ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: _running ? _stopTimer : _startTimer,
                            icon: Icon(
                              _running
                                  ? Icons.stop_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                            label: Text(_running ? 'Arrêter' : 'Démarrer'),
                            style: FilledButton.styleFrom(
                              backgroundColor: _running
                                  ? Theme.of(context).colorScheme.error
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.outlined(
                            tooltip: 'Modifier la durée',
                            onPressed: _running ? null : _editDuration,
                            icon: const Icon(Icons.edit_rounded),
                          ),
                        ],
                      ),
                      if (_running) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Le minuteur est en cours.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
            if (widget.type == BabyEventType.bottle) ...[
              const _SectionTitle(
                title: 'Quantité bue',
                subtitle: 'En millilitres (mL)',
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                initialValue: _amountMl,
                decoration: const InputDecoration(
                  labelText: 'Quantité',
                  prefixIcon: Icon(Icons.local_drink_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('N/A')),
                  for (var ml = 10; ml <= 300; ml += 10)
                    DropdownMenuItem<int?>(value: ml, child: Text('$ml mL')),
                ],
                onChanged: (value) => setState(() => _amountMl = value),
              ),
            ],
            if (_isMeasurement) ...[
              const _SectionTitle(
                title: 'Mesure',
                subtitle: 'La mesure sera datée à l’heure de saisie.',
              ),
              const SizedBox(height: 12),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _measurementController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                  ],
                  decoration: InputDecoration(
                    labelText: widget.type == BabyEventType.weight
                        ? 'Poids'
                        : 'Taille',
                    suffixText: widget.type == BabyEventType.weight
                        ? 'kg'
                        : 'cm',
                    prefixIcon: Icon(
                      widget.type == BabyEventType.weight
                          ? Icons.monitor_weight_outlined
                          : Icons.height_rounded,
                    ),
                  ),
                  validator: (value) {
                    final number = double.tryParse(
                      (value ?? '').replaceAll(',', '.'),
                    );
                    if (number == null || number <= 0) {
                      return 'Saisissez une valeur valide.';
                    }
                    if (widget.type == BabyEventType.weight && number > 100) {
                      return 'Le poids semble trop élevé.';
                    }
                    if (widget.type == BabyEventType.height &&
                        (number > 250 || number != number.roundToDouble())) {
                      return 'Saisissez une taille en centimètres entiers.';
                    }
                    if (widget.type == BabyEventType.weight &&
                        (number * 100).roundToDouble() != number * 100) {
                      return 'Utilisez au maximum deux décimales.';
                    }
                    return null;
                  },
                ),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _running ? null : _save,
              icon: const Icon(Icons.check_rounded),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 13),
                child: Text(
                  _running
                      ? 'Arrêtez le minuteur pour valider'
                      : 'Valider et ouvrir le journal',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateTimeCard extends StatelessWidget {
  const _DateTimeCard({required this.startedAt, required this.onTap});

  final DateTime startedAt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Card(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: ListTile(
      onTap: onTap,
      leading: const CircleAvatar(child: Icon(Icons.calendar_month_rounded)),
      title: const Text('Date et heure de début'),
      subtitle: Text(
        '${startedAt.day.toString().padLeft(2, '0')}/${startedAt.month.toString().padLeft(2, '0')}/${startedAt.year} · ${startedAt.hour.toString().padLeft(2, '0')}:${startedAt.minute.toString().padLeft(2, '0')}',
      ),
      trailing: const Icon(Icons.edit_calendar_rounded),
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        subtitle,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    ],
  );
}

String _formatClock(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds ~/ 60) % 60;
  final remainder = seconds % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

String _formatDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds ~/ 60) % 60;
  if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  return '$minutes min ${seconds % 60} s';
}
