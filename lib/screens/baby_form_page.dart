import 'package:flutter/material.dart';

import '../models/baby.dart';

class BabyFormPage extends StatefulWidget {
  const BabyFormPage({
    required this.onSaved,
    this.onboarding = false,
    super.key,
  });

  final Future<void> Function(Baby baby) onSaved;
  final bool onboarding;

  @override
  State<BabyFormPage> createState() => _BabyFormPageState();
}

class _BabyFormPageState extends State<BabyFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime _birthDate = DateTime.now();
  BabyGender _gender = BabyGender.girl;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _chooseBirthDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Date de naissance',
    );
    if (date != null) setState(() => _birthDate = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final baby = Baby(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: _nameController.text.trim(),
      gender: _gender,
      birthDate: _birthDate,
    );
    try {
      await widget.onSaved(baby);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: widget.onboarding
          ? null
          : AppBar(title: const Text('Ajouter un enfant')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
              children: [
                Container(
                  height: 76,
                  width: 76,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Icon(
                    Icons.child_care_rounded,
                    size: 42,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.onboarding
                      ? 'Commençons par votre bébé'
                      : 'Un nouveau petit profil',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ces informations permettront de garder un journal bien organisé pour chaque enfant.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 28),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        autofocus: widget.onboarding,
                        decoration: const InputDecoration(
                          labelText: 'Prénom de l’enfant',
                          prefixIcon: Icon(Icons.person_outline_rounded),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Saisissez son prénom.'
                            : null,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Sexe',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 10),
                      SegmentedButton<BabyGender>(
                        segments: BabyGender.values
                            .map(
                              (gender) => ButtonSegment(
                                value: gender,
                                label: Text(gender.label),
                                icon: Icon(
                                  gender == BabyGender.girl
                                      ? Icons.auto_awesome_rounded
                                      : Icons.rocket_launch_rounded,
                                ),
                              ),
                            )
                            .toList(),
                        selected: {_gender},
                        onSelectionChanged: (selection) =>
                            setState(() => _gender = selection.first),
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _chooseBirthDate,
                        icon: const Icon(Icons.calendar_month_rounded),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Text(
                            'Né(e) le ${_birthDate.day.toString().padLeft(2, '0')}/${_birthDate.month.toString().padLeft(2, '0')}/${_birthDate.year}',
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.arrow_forward_rounded),
                        label: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            widget.onboarding
                                ? 'Créer le profil'
                                : 'Ajouter cet enfant',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
