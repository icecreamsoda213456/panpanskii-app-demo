import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/demo/demo_media.dart';
import '../../../../core/demo/demo_store.dart';
import '../../data/photobooth_store.dart';
import '../widgets/photo_booth_strip.dart';

class DemoPhotoBoothScreen extends StatefulWidget {
  const DemoPhotoBoothScreen({super.key});
  @override
  State<DemoPhotoBoothScreen> createState() => _DemoPhotoBoothScreenState();
}

class _DemoPhotoBoothScreenState extends State<DemoPhotoBoothScreen> {
  String _style = 'vintage';
  bool _saving = false;
  late final Future<List<PhotoBoothPhoto>> _photos = _preview();

  Future<List<PhotoBoothPhoto>> _preview() async {
    final url = await DemoMedia.url('asset:assets/garden/garden_scene.png');
    return [
      for (var round = 0; round < 5; round++)
        for (final author in [DemoStore.profile, DemoStore.partner])
          PhotoBoothPhoto.fromJson({
            'id': 'preview-$round-${author['username']}',
            ...author,
            'session_id': 'preview',
            'round_index': round,
            'storage_path': 'asset:assets/garden/garden_scene.png'
          }, imageUrl: url),
    ];
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DemoStore.instance.transaction((tables) {
        final session = DemoStore.instance.put(tables, 'photobooth_sessions', {
          'room_name': 'Alex + Sam',
          'created_by': DemoStore.userId,
          'status': 'complete',
          'current_round': 4,
          'total_rounds': 5,
          'participant_frame_style': _style,
        });
        for (var round = 0; round < 5; round++) {
          for (final author in [DemoStore.profile, DemoStore.partner]) {
            DemoStore.instance.put(tables, 'photobooth_photos', {
              ...author,
              'session_id': session['id'],
              'round_index': round,
              'storage_path': 'asset:assets/garden/garden_scene.png'
            });
          }
        }
      });
      if (mounted) context.go('/photobooth-gallery');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Could not save the sample strip. Please try again.')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Photo Booth'),
            leading: IconButton(
                tooltip: 'Back',
                onPressed: () => context.go('/more'),
                icon: const Icon(Icons.arrow_back)),
            actions: [
              IconButton(
                  tooltip: 'Photo gallery',
                  onPressed: () => context.go('/photobooth-gallery'),
                  icon: const Icon(Icons.photo_library_outlined))
            ]),
        body: ListView(padding: const EdgeInsets.all(16), children: [
          const Text(
              'Sample artwork. Live camera calls are unavailable in this local demo.',
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
              child: Wrap(spacing: 8, children: [
            for (final style in ['vintage', 'sakura', 'midnight'])
              ChoiceChip(
                  label: Text('${style[0].toUpperCase()}${style.substring(1)}'),
                  selected: _style == style,
                  onSelected: (_) => setState(() => _style = style)),
          ])),
          const SizedBox(height: 12),
          Center(
              child: FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save sample strip'))),
          const SizedBox(height: 20),
          Center(
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: AspectRatio(
                      aspectRatio: PhotoBoothStrip.logicalWidth /
                          PhotoBoothStrip.logicalHeight,
                      child: FutureBuilder<List<PhotoBoothPhoto>>(
                          future: _photos,
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Center(
                                  child:
                                      Text('Sample artwork could not load.'));
                            }
                            if (!snapshot.hasData) {
                              return const Center(
                                  child: CircularProgressIndicator());
                            }
                            return FittedBox(
                                child: PhotoBoothStrip(
                                    roundIndexes: const [0, 1, 2, 3, 4],
                                    photos: snapshot.data!,
                                    frameStyle: _style,
                                    primaryUserId: DemoStore.userId));
                          })))),
        ]),
      );
}
