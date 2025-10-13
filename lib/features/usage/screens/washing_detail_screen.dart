import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/usage_provider.dart';
import '../../home/models/usage_models.dart';
import '../models/usage_draft.dart';

class WashingDetailScreen extends ConsumerStatefulWidget {
  const WashingDetailScreen({super.key});

  @override
  ConsumerState<WashingDetailScreen> createState() => _WashingDetailState();
}

// Canonical activities + object labels + ESP32 rates
class _ActivityOption {
  final String activity; // UI label
  final String object; // device object label
  final double rate; // L/s
  const _ActivityOption(this.activity, this.object, this.rate);
}

class _WashingDetailState extends ConsumerState<WashingDetailScreen> {
  // --- Rates (L/s) — must match ESP32 ---
  static const double _rateHand = 0.10;
  static const double _rateFruit = 0.15;
  static const double _rateDish = 0.20;
  static const double _rateNormal = 0.25;

  static const _options = <_ActivityOption>[
    _ActivityOption('Washing Hands', 'Hand', _rateHand),
    _ActivityOption('Washing Potato', 'Potato', _rateFruit),
    _ActivityOption('Washing Dishes', 'Dish', _rateDish),
  ];

  _ActivityOption _selected = _options.last; // default: Dishes

  // Base fields
  late TextEditingController _activityCtrl; // kept for persistence
  late TextEditingController _durationCtrl; // seconds (int)
  late TextEditingController _litersCtrl; // Smart used (L) for this entry

  // Device optional fields (auto-filled; only normal & saved are shown)
  late TextEditingController _objectCtrl; // hidden field (kept for saving)
  late TextEditingController _tapOpenSecCtrl; // hidden field (kept for saving)
  late TextEditingController _smartCtrl; // hidden field (kept for saving)
  late TextEditingController _normalCtrl; // shown
  late TextEditingController _savedCtrl; // shown

  late DateTime _start;
  int? _entryId;
  bool _didInit = false;

  bool _updating = false; // prevents feedback loops

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is UsageEntry) {
      _entryId = args.id;
      _start = args.start;

      _activityCtrl = TextEditingController(text: args.activity);
      _durationCtrl = TextEditingController(
        text: args.duration.inSeconds.toString(),
      );
      _litersCtrl = TextEditingController(text: args.liters.toStringAsFixed(3));

      _objectCtrl = TextEditingController(text: (args.object ?? '').trim());
      _tapOpenSecCtrl = TextEditingController(
        text: args.tapOpenSec == null
            ? ''
            : (args.tapOpenSec! % 1 == 0
                  ? args.tapOpenSec!.toStringAsFixed(0)
                  : args.tapOpenSec!.toStringAsFixed(3)),
      );
      _smartCtrl = TextEditingController(
        text: args.smartGlobal == null
            ? ''
            : args.smartGlobal!.toStringAsFixed(3),
      );
      _normalCtrl = TextEditingController(
        text: args.normalGlobal == null
            ? ''
            : args.normalGlobal!.toStringAsFixed(3),
      );
      _savedCtrl = TextEditingController(
        text: args.savedGlobal == null
            ? ''
            : args.savedGlobal!.toStringAsFixed(3),
      );

      _selected = _guessOption(args.activity);
    } else if (args is UsageDraft) {
      _entryId = null;
      _start = args.start;

      _activityCtrl = TextEditingController(text: args.activity);
      _durationCtrl = TextEditingController(
        text: args.duration.inSeconds.toString(),
      );
      _litersCtrl = TextEditingController(text: args.liters.toStringAsFixed(3));

      _objectCtrl = TextEditingController(text: '');
      _tapOpenSecCtrl = TextEditingController(text: '');
      _smartCtrl = TextEditingController(text: '');
      _normalCtrl = TextEditingController(text: '');
      _savedCtrl = TextEditingController(text: '');

      _selected = _guessOption(args.activity);
    } else {
      final d = UsageDraft.from(
        activity: 'Washing Dishes',
        duration: const Duration(minutes: 10),
        liters: 8,
      );
      _entryId = null;
      _start = d.start;

      _activityCtrl = TextEditingController(text: d.activity);
      _durationCtrl = TextEditingController(
        text: d.duration.inSeconds.toString(),
      );
      _litersCtrl = TextEditingController(text: d.liters.toStringAsFixed(3));

      _objectCtrl = TextEditingController(text: '');
      _tapOpenSecCtrl = TextEditingController(text: '');
      _smartCtrl = TextEditingController(text: '');
      _normalCtrl = TextEditingController(text: '');
      _savedCtrl = TextEditingController(text: '');

      _selected = _guessOption(d.activity);
    }

    // Attach reactive listeners (after controllers created)
    _durationCtrl.addListener(_onSecsChanged);
    _litersCtrl.addListener(_onSmartLitersChanged);

    // Initial normalize: prefer seconds → compute everything once
    _recalcFromSecs();
  }

  @override
  void dispose() {
    _activityCtrl.dispose();
    _durationCtrl.dispose();
    _litersCtrl.dispose();

    _objectCtrl.dispose();
    _tapOpenSecCtrl.dispose();
    _smartCtrl.dispose();
    _normalCtrl.dispose();
    _savedCtrl.dispose();

    super.dispose();
  }

  // ------------- mapping/helpers -------------

  _ActivityOption _guessOption(String activity) {
    final v = activity.toLowerCase();
    if (v.contains('hand')) return _options[0];
    if (v.contains('potato') || v.contains('fruit') || v.contains('vegetable'))
      return _options[1];
    if (v.contains('dish') || v.contains('plate')) return _options[2];
    return _options[2]; // default Dishes
  }

  double? _parseDouble(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final v = double.tryParse(t);
    return (v != null && v.isFinite) ? v : null;
  }

  int? _parseInt(TextEditingController c) {
    final t = c.text.trim();
    if (t.isEmpty) return null;
    final v = int.tryParse(t);
    return v;
  }

  String _fmt3(double v) => v.toStringAsFixed(3);

  void _onActivityChanged(_ActivityOption opt) {
    if (_updating) return;
    _selected = opt;
    _activityCtrl.text = opt.activity; // keep persisted label in DB
    // If hidden object is empty, set it from activity
    if (_objectCtrl.text.trim().isEmpty) {
      _objectCtrl.text = opt.object;
    }
    // Recompute from whichever input is present
    final hasLiters = _parseDouble(_litersCtrl) != null;
    if (hasLiters) {
      _recalcFromLiters();
    } else {
      _recalcFromSecs();
    }
    setState(() {});
  }

  void _onSecsChanged() {
    if (_updating) return;
    _recalcFromSecs();
  }

  void _onSmartLitersChanged() {
    if (_updating) return;
    _recalcFromLiters();
  }

  void _recalcFromSecs() {
    final secs = (_parseInt(_durationCtrl) ?? 0).toDouble();
    final rate = _selected.rate;
    final smart = (secs * rate).clamp(0.0, 1e9);
    final normal = (secs * _rateNormal).clamp(0.0, 1e9);
    final saved = (normal - smart).clamp(-1e9, 1e9);

    _updating = true;
    try {
      // Entry smart used
      _litersCtrl.text = _fmt3(smart);

      // Hidden device snapshot mirrors manual add
      _tapOpenSecCtrl.text = secs % 1 == 0
          ? secs.toStringAsFixed(0)
          : _fmt3(secs);
      _smartCtrl.text = _fmt3(smart);

      // Visible in panel
      _normalCtrl.text = _fmt3(normal);
      _savedCtrl.text = _fmt3(saved);

      if (_objectCtrl.text.trim().isEmpty) {
        _objectCtrl.text = _selected.object;
      }
    } finally {
      _updating = false;
    }
  }

  void _recalcFromLiters() {
    final smart = _parseDouble(_litersCtrl) ?? 0.0;
    final rate = _selected.rate;
    final secs = rate > 0 ? (smart / rate) : 0.0;
    final normal = (secs * _rateNormal).clamp(0.0, 1e9);
    final saved = (normal - smart).clamp(-1e9, 1e9);

    _updating = true;
    try {
      // Back-fill duration (int seconds)
      _durationCtrl.text = secs.isFinite ? secs.round().toString() : '0';

      // Hidden device snapshot mirrors
      _tapOpenSecCtrl.text = secs.isFinite
          ? (secs % 1 == 0 ? secs.toStringAsFixed(0) : _fmt3(secs))
          : '';
      _smartCtrl.text = _fmt3(smart.isFinite ? smart : 0.0);

      // Visible in panel
      _normalCtrl.text = _fmt3(normal.isFinite ? normal : 0.0);
      _savedCtrl.text = _fmt3(saved.isFinite ? saved : 0.0);

      if (_objectCtrl.text.trim().isEmpty) {
        _objectCtrl.text = _selected.object;
      }
    } finally {
      _updating = false;
    }
  }

  // ------------------- UI -------------------

  @override
  Widget build(BuildContext context) {
    final isUpdate = _entryId != null;

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: Text(isUpdate ? 'Edit usage' : 'New usage'),
        backgroundColor: Colors.black.withOpacity(0.15),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _infoRow('Time', _format(_start)),
              const SizedBox(height: 14),

              _activityDropdown(),
              const SizedBox(height: 14),

              _field(
                'Duration (sec)',
                _durationCtrl,
                keyboard: const TextInputType.numberWithOptions(decimal: false),
              ),
              const SizedBox(height: 14),

              _field(
                'Smart used (L)',
                _litersCtrl,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),

              const SizedBox(height: 24),

              // Device panel with ONLY Normal & Saved (locked)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: AppGradient.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    _smallField(
                      'normalWaterUsed (L)',
                      _normalCtrl,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      readOnly: true, // 🔒 locked
                    ),
                    const SizedBox(height: 8),

                    _smallField(
                      'waterSaved (L)',
                      _savedCtrl,
                      keyboard: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      readOnly: true, // 🔒 locked
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: 200,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    final secs = int.tryParse(_durationCtrl.text.trim()) ?? 0;
                    final liters =
                        double.tryParse(_litersCtrl.text.trim()) ?? 0;
                    final activity = _activityCtrl.text.trim().isEmpty
                        ? _selected.activity
                        : _activityCtrl.text.trim();

                    if (activity.isEmpty || secs <= 0 || liters <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter valid values'),
                        ),
                      );
                      return;
                    }

                    double? _num(TextEditingController c) {
                      final t = c.text.trim();
                      if (t.isEmpty) return null;
                      final v = double.tryParse(t);
                      return (v != null && v.isFinite) ? v : null;
                    }

                    final entry = UsageEntry(
                      id: _entryId,
                      activity: activity,
                      start: _start,
                      duration: Duration(seconds: secs),
                      liters: liters,

                      // Hidden but still saved for parity with BLE entries
                      object: _objectCtrl.text.trim().isEmpty
                          ? null
                          : _objectCtrl.text.trim(),
                      tapOpenSec: _num(_tapOpenSecCtrl),
                      smartGlobal: _num(_smartCtrl),
                      normalGlobal: _num(_normalCtrl),
                      savedGlobal: _num(_savedCtrl),
                    );

                    if (isUpdate) {
                      await ref.read(updateUsageEntryProvider(entry).future);
                    } else {
                      await ref.read(addUsageEntryProvider(entry).future);
                    }

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          isUpdate ? 'Usage updated' : 'Usage saved',
                        ),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: Text(isUpdate ? 'Update usage' : 'Save usage'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Activity dropdown styled like your inputs
  Widget _activityDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<_ActivityOption>(
        value: _selected,
        dropdownColor: const Color(0xFF0B2A3C),
        iconEnabledColor: Colors.white,
        decoration: const InputDecoration(
          labelText: 'Activity',
          labelStyle: TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
        style: const TextStyle(color: Colors.white),
        items: _options
            .map(
              (o) => DropdownMenuItem<_ActivityOption>(
                value: o,
                child: Text(o.activity),
              ),
            )
            .toList(),
        onChanged: (o) {
          if (o != null) _onActivityChanged(o);
        },
      ),
    );
  }

  Widget _infoRow(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: BoxDecoration(
      gradient: AppGradient.primary,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );

  Widget _field(
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x14FFFFFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white70),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _smallField(
    String label,
    TextEditingController c, {
    TextInputType? keyboard,
    bool readOnly = false, // <- added
  }) {
    final tf = TextField(
      controller: c,
      keyboardType: keyboard,
      readOnly: readOnly,
      style: const TextStyle(color: Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.black54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.2),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
      ),
    );
    // When locked, ignore pointer so it can't be focused/edited.
    return readOnly ? IgnorePointer(child: tf) : tf;
  }

  String _format(DateTime dt) {
    String two(int n) => n.toString().padLeft(2, '0');
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${two(dt.hour)}:${two(dt.minute)}, ${dt.day} ${months[dt.month - 1]}';
  }
}
