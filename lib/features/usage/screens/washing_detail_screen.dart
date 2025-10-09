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

class _WashingDetailState extends ConsumerState<WashingDetailScreen> {
  late TextEditingController _activityCtrl;
  late TextEditingController _durationCtrl; // seconds
  late TextEditingController _litersCtrl;

  late DateTime _start;
  int? _entryId;
  bool _didInit = false;

  // Read-only snapshot from device (if provided)
  String? _deviceObject;
  double? _tapOpenSec;
  double? _smartGlobal;
  double? _normalGlobal;
  double? _savedGlobal;

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
      _litersCtrl = TextEditingController(text: args.liters.toStringAsFixed(2));

      // capture device snapshot (if present)
      _deviceObject = args.object;
      _tapOpenSec = args.tapOpenSec;
      _smartGlobal = args.smartGlobal;
      _normalGlobal = args.normalGlobal;
      _savedGlobal = args.savedGlobal;
    } else if (args is UsageDraft) {
      _entryId = null;
      _start = args.start;
      _activityCtrl = TextEditingController(text: args.activity);
      _durationCtrl = TextEditingController(
        text: args.duration.inSeconds.toString(),
      );
      _litersCtrl = TextEditingController(text: args.liters.toStringAsFixed(2));
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
      _litersCtrl = TextEditingController(text: d.liters.toStringAsFixed(2));
    }
  }

  @override
  void dispose() {
    _activityCtrl.dispose();
    _durationCtrl.dispose();
    _litersCtrl.dispose();
    super.dispose();
  }

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
              _field('Activity', _activityCtrl),
              const SizedBox(height: 14),
              _field(
                'Duration (sec)',
                _durationCtrl,
                keyboard: const TextInputType.numberWithOptions(decimal: false),
              ),
              const SizedBox(height: 14),
              _field(
                'Water quantity (L)',
                _litersCtrl,
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 24),
              if (_hasDeviceSnapshot)
                _DevStatsPanel(
                  object: _deviceObject,
                  tapOpenSec: _tapOpenSec,
                  smart: _smartGlobal,
                  normal: _normalGlobal,
                  saved: _savedGlobal,
                ),
              if (_hasDeviceSnapshot) const SizedBox(height: 24),
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
                    final activity = _activityCtrl.text.trim();

                    if (activity.isEmpty || secs <= 0 || liters <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter valid values'),
                        ),
                      );
                      return;
                    }

                    final entry = UsageEntry(
                      id: _entryId,
                      activity: activity,
                      start: _start,
                      duration: Duration(seconds: secs),
                      liters: liters,

                      // pass-through device snapshot (kept read-only here)
                      object: _deviceObject,
                      tapOpenSec: _tapOpenSec,
                      smartGlobal: _smartGlobal,
                      normalGlobal: _normalGlobal,
                      savedGlobal: _savedGlobal,
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

  bool get _hasDeviceSnapshot =>
      _deviceObject != null ||
      _tapOpenSec != null ||
      _smartGlobal != null ||
      _normalGlobal != null ||
      _savedGlobal != null;

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

class _DevStatsPanel extends StatelessWidget {
  final String? object;
  final double? tapOpenSec;
  final double? smart;
  final double? normal;
  final double? saved;

  const _DevStatsPanel({
    required this.object,
    required this.tapOpenSec,
    required this.smart,
    required this.normal,
    required this.saved,
  });

  @override
  Widget build(BuildContext context) {
    Text label(String s) => Text(
      s,
      style: const TextStyle(
        color: Colors.black87,
        fontWeight: FontWeight.w700,
      ),
    );
    Text value(String s) =>
        Text(s, style: const TextStyle(color: Colors.black));
    Widget row(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [label(l), const Spacer(), value(v)]),
    );
    String? fmt3(double? v) => v == null ? null : v.toStringAsFixed(3);
    String? fmtS(double? v) => v == null
        ? null
        : (v == v.truncateToDouble()
              ? v.toStringAsFixed(0)
              : v.toStringAsFixed(3));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppGradient.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          row('Object', object ?? '—'),
          row('tapOpenTime (sec)', fmtS(tapOpenSec) ?? '—'),
          row('smartWaterUsed (L)', fmt3(smart) ?? '—'),
          row('normalWaterUsed (L)', fmt3(normal) ?? '—'),
          row('waterSaved (L)', fmt3(saved) ?? '—'),
        ],
      ),
    );
  }
}
