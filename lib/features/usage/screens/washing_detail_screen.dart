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

  bool _didInit = false; // <-- guard

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInit) return;
    _didInit = true;

    // SAFE to read ModalRoute here
    final args = ModalRoute.of(context)?.settings.arguments;
    final draft = (args is UsageDraft)
        ? args
        : UsageDraft.from(
            activity: 'Washing Dishes',
            duration: const Duration(minutes: 10),
            liters: 8,
          );

    _activityCtrl = TextEditingController(text: draft.activity);
    _durationCtrl = TextEditingController(
      text: draft.duration.inMinutes.toString(),
    );
    _litersCtrl = TextEditingController(text: draft.liters.toStringAsFixed(0));
    _start = draft.start;
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
    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Washing history'),
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
                width: 180,
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

                    if (_activityCtrl.text.trim().isEmpty ||
                        minutes <= 0 ||
                        liters <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter valid values'),
                        ),
                      );
                      return;
                    }

                    final entry = UsageEntry(
                      activity: _activityCtrl.text.trim(),
                      start: _start,
                      duration: Duration(minutes: minutes),
                      liters: liters,
                    );

                    await ref.read(addUsageEntryProvider(entry).future);

                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Usage saved'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text('Save usage'),
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
