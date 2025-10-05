import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_v2.dart';
import '../../../core/providers/ingest_providers.dart';

class LogReplayScreen extends ConsumerStatefulWidget {
  const LogReplayScreen({super.key});
  @override
  ConsumerState<LogReplayScreen> createState() => _LogReplayState();
}

class _LogReplayState extends ConsumerState<LogReplayScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final replay = ref.watch(replayLogProvider);

    return Scaffold(
      backgroundColor: AppThemeV2.bgNavy,
      appBar: AppBar(
        title: const Text('Replay Serial Log'),
        backgroundColor: Colors.black.withOpacity(0.15),
        actions: [
          IconButton(
            tooltip: 'Replay x1',
            onPressed: () async {
              await replay(_controller.text, speed: 1.0);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Replay complete (x1)')),
              );
            },
            icon: const Icon(Icons.play_arrow),
          ),
          IconButton(
            tooltip: 'Replay x5',
            onPressed: () async {
              await replay(_controller.text, speed: 5.0);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Replay complete (x5)')),
              );
            },
            icon: const Icon(Icons.fast_forward),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: _controller,
          minLines: 12,
          maxLines: null,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText:
                'Paste one JSON event per line...\n'
                '{"t":1711122334,"ev":"start","sid":17,"cls":"plate","conf":0.91,"flow":6.2}\n'
                '{"t":1711122336,"ev":"u","sid":17,"cls":"plate","flow":6.2,"lit":0.21}\n'
                '{"t":1711122344,"ev":"stop","sid":17,"cls":"plate","lit":0.83}',
            hintStyle: TextStyle(color: Colors.white54),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    );
  }
}
