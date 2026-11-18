import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import 'dart:convert';

import 'package:letter_signing/api/api_client.dart';
import 'package:letter_signing/letters/letterhead.dart';
import 'package:letter_signing/screens/auth_screens.dart';
import 'package:letter_signing/letters/letter_widgets.dart';
import 'package:letter_signing/theme/widgets.dart';

const int _maxLogoBytes = 200 * 1024;

/// Manager: fills the header (logo, name, contact) and footer printed on every letter.
class LetterheadCard extends StatefulWidget {
  const LetterheadCard({super.key, required this.api, required this.initial});
  final ApiClient api;
  final Letterhead initial;

  @override
  State<LetterheadCard> createState() => _LetterheadCardState();
}

class _LetterheadCardState extends State<LetterheadCard> {
  late final Map<String, TextEditingController> _fields = {
    for (final k in Letterhead.textFields)
      k: TextEditingController(text: widget.initial.toJson()[k] as String),
  };
  late String _logo = widget.initial.logo;
  String? _error;

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Letterhead get _current => Letterhead.fromJson({
    for (final e in _fields.entries) e.key: e.value.text,
    'logo': _logo,
  });

  Future<void> _pickLogo() async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['png', 'jpg', 'jpeg'],
    );
    if (res.isEmpty) return;
    final file = res.first;
    final bytes = await file.readAsBytes();
    if (bytes.length > _maxLogoBytes) {
      setState(() => _error = 'Logo must be a PNG or JPEG under 200 KB');
      return;
    }
    final mime = file.name.toLowerCase().endsWith('.png') ? 'png' : 'jpeg';
    setState(() {
      _error = null;
      _logo = 'data:image/$mime;base64,${base64Encode(bytes)}';
    });
  }

  Future<void> _save() async {
    final ok = await runGuarded(
      context,
      () => widget.api.call(
        'PATCH',
        '/manage/company',
        body: {'letterhead': _current.toJson()},
      ),
    );
    if (ok && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Letterhead saved')));
    }
  }

  static const _labels = {
    'name': 'Company name',
    'tagline': 'Subtitle',
    'address': 'Address',
    'phone': 'Phone',
    'email': 'Email',
    'website': 'Website',
    'footer': 'Address / phone (bottom of every page)',
  };

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Letterhead', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text('Printed at the top and bottom of every letter.'),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickLogo,
              icon: const Icon(Icons.image_outlined),
              label: Text(_logo.isEmpty ? 'Add logo' : 'Change logo'),
            ),
            if (_logo.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _logo = ''),
                child: const Text('Remove logo'),
              ),
          ],
        ),
        for (final k in Letterhead.textFields)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: TextField(
              controller: _fields[k],
              maxLength: 300,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _labels[k],
                counterText: '',
              ),
            ),
          ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          color: Colors.white,
          child: LetterheadHeader(head: _current),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          ErrorBanner(_error!),
        ],
        const SizedBox(height: 12),
        FilledButton(onPressed: _save, child: const Text('Save letterhead')),
      ],
    ),
  );
}
