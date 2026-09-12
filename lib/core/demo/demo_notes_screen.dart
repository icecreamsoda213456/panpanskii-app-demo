import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'demo_media.dart';
import 'demo_store.dart';

class DemoNotesScreen extends StatelessWidget {
  const DemoNotesScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Saved drawings'),
            leading: IconButton(
                tooltip: 'Back',
                onPressed: () => context.go('/more'),
                icon: const Icon(Icons.arrow_back)),
            actions: [
              IconButton(
                  tooltip: 'New drawing',
                  onPressed: () => context.push('/widget-notes'),
                  icon: const Icon(Icons.draw_outlined))
            ]),
        body: StreamBuilder<List<DemoRow>>(
          stream: DemoStore.instance
              .watch('widget_notes', order: 'created_at', descending: true),
          builder: (context, snapshot) =>
              ListView(padding: const EdgeInsets.all(16), children: [
            const Text(
                'Browser-local drawings. Phone widgets are unavailable in this demo.'),
            const SizedBox(height: 16),
            for (final row in snapshot.data ?? <DemoRow>[])
              Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(children: [
                            Text(
                                '${row['username']} - ${row['caption'] ?? 'A little note'}'),
                            const SizedBox(height: 8),
                            FutureBuilder(
                                future: DemoMedia.bytes(
                                    row['storage_path'] as String),
                                builder: (context, image) => image.hasData
                                    ? Image.memory(image.data!,
                                        height: 280, fit: BoxFit.contain)
                                    : const SizedBox(
                                        height: 280,
                                        child: Center(
                                            child:
                                                CircularProgressIndicator()))),
                          ])))),
          ]),
        ),
      );
}
