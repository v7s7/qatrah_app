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
  late TextEditingController _durationCtrl; // minutes
  late TextEditingController _litersCtrl;

  late DateTime _start;
  int? _entryId; // null => create, non-null => update same row

  bool _didInit = false; // guard

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    final args = ModalRoute.of(context)?.settings.arguments;

    if (args is UsageEntry) {
      // Editing an existing entry
      _entryId = args.id;
      _start = args.start;
      _activityCtrl = TextEditingController(text: args.activity);
      _durationCtrl = TextEditingController(
        text: args.duration.inMinutes.toString(),
      );
      _litersCtrl = TextEditingController(text: args.liters.toStringAsFixed(0));
    } else if (args is UsageDraft) {
      // Creating from a draft
      _entryId = null;
      _start = args.start;
      _activityCtrl = TextEditingController(text: args.activity);
      _durationCtrl = TextEditingController(
        text: args.duration.inMinutes.toString(),
      );
      _litersCtrl = TextEditingController(text: args.liters.toStringAsFixed(0));
    } else {
      // Fallback new-entry template
      final d = UsageDraft.from(
        activity: 'Washing Dishes',
        duration: const Duration(minutes: 10),
        liters: 8,
      );
      _entryId = null;
      _start = d.start;
      _activityCtrl = TextEditingController(text: d.activity);
      _durationCtrl = TextEditingController(
        text: d.duration.inMinutes.toString(),
      );
      _litersCtrl = TextEditingController(text: d.liters.toStringAsFixed(0));
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
                'Duration (min)',
                _durationCtrl,
                keyboard: TextInputType.number,
              ),
              const SizedBox(height: 14),
              _field(
                'Water quantity (L)',
                _litersCtrl,
                keyboard: TextInputType.number,
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
                    final minutes =
                        int.tryParse(_durationCtrl.text.trim()) ?? 0;
                    final liters =
                        double.tryParse(_litersCtrl.text.trim()) ?? 0;
                    final activity = _activityCtrl.text.trim();

                    if (activity.isEmpty || minutes <= 0 || liters <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter valid values'),
                        ),
                      );
                      return;
                    }

                    final entry = UsageEntry(
                      id: _entryId, // keep id if present (update)
                      activity: activity,
                      start: _start,
                      duration: Duration(minutes: minutes),
                      liters: liters,
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
