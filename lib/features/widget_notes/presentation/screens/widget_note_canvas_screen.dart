import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/presentation/pan_ui.dart';
import '../../../../features/auth/data/local_account_store.dart';
import '../../data/widget_note_home_widget_service.dart';
import '../../data/widget_note_store.dart';
import '../painters/widget_note_painter.dart';

/// Drawing canvas for a home-screen widget note.
///
/// The user draws with their finger on a warm paper square, then sends it:
/// the PNG lands in Supabase Storage, a `widget_notes` row points to it, the
/// partner gets a push, and their phone downloads it into the home widget.
class WidgetNoteCanvasScreen extends StatefulWidget {
  const WidgetNoteCanvasScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<WidgetNoteCanvasScreen> createState() => _WidgetNoteCanvasScreenState();
}

class _WidgetNoteCanvasScreenState extends State<WidgetNoteCanvasScreen> {
  static const List<Color> palette = [
    Color(0xFFFF6F91), // pink
    Color(0xFFE49A35), // gold
    Color(0xFF43A878), // green
    Color(0xFF91B8E8), // sky
    Color(0xFF322A68), // deep plum
  ];

  final GlobalKey _canvasBoundaryKey = GlobalKey();
  final List<WidgetNoteStroke> _strokes = <WidgetNoteStroke>[];

  Color _currentColor = palette.first;
  double _strokeWidth = 8;
  bool _isSending = false;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _strokes.add(
        WidgetNoteStroke(
          color: _currentColor,
          width: _strokeWidth,
          points: [details.localPosition],
        ),
      );
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_strokes.isEmpty) {
      return;
    }
    setState(() {
      _strokes.last.points.add(details.localPosition);
    });
  }

  void _undo() {
    if (_strokes.isEmpty) {
      return;
    }
    setState(() {
      _strokes.removeLast();
    });
  }

  void _clear() {
    if (_strokes.isEmpty) {
      return;
    }
    setState(() {
      _strokes.clear();
    });
  }

  Future<Uint8List?> _exportPng() async {
    final boundary = _canvasBoundaryKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null || boundary.size.width == 0) {
      return null;
    }
    final pixelRatio = (512 / boundary.size.width).clamp(0.5, 4.0);
    // Make sure any setState from the final drag (e.g. the last stroke) has
    // been painted before we snapshot the RepaintBoundary, otherwise the very
    // last few points can be missing from the exported PNG.
    await WidgetsBinding.instance.endOfFrame;
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _send() async {
    if (_isSending) {
      return;
    }
    if (_strokes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mag-draw muna ng maliit na note! 🐼'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final pngBytes = await _exportPng();
      if (pngBytes == null || pngBytes.isEmpty) {
        throw Exception('Hindi ma-export ang drawing.');
      }

      await WidgetNoteStore().sendNote(
        account: widget.account,
        pngBytes: pngBytes,
      );
      await WidgetNoteHomeWidgetService.syncLatest();

      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note sent! Makikita na ito sa widget nila. 🐨'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1800),
        ),
      );
      context.pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      final message = error is Exception
          ? error.toString().replaceFirst('Exception: ', '')
          : 'May nangyaring mali. Subukan uli.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final compact = MediaQuery.sizeOf(context).width <= 520;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            PanFeatureHeader(
              title: 'Widget Note',
              subtitle: 'Draw something to light up their home screen',
              leading: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: const SizedBox.square(
                  dimension: 46,
                  child: Icon(Icons.draw_rounded),
                ),
              ),
              trailing: const Icon(Icons.favorite_rounded),
              accentColor: scheme.primary,
              onBack: () => context.pop(),
            ),
            Expanded(
              // Hindi scrollable ito — pinag-uusapan natin dito ang gesture:
              // kapag nasa loob ng SingleChildScrollView ang canvas, nananalo
              // ang scroll sa pan-drag kaya hindi makakapag-draw ang user.
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      children: [
                        Expanded(
                          // Square na canvas na kasya sa natitirang space —
                          // mas malaki pa kaysa dati (hindi na napipilitan
                          // na maliit dahil sa scroll).
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: RepaintBoundary(
                              key: _canvasBoundaryKey,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onPanStart: _onPanStart,
                                onPanUpdate: _onPanUpdate,
                                child: CustomPaint(
                                  painter:
                                      WidgetNotePainter(strokes: _strokes),
                                  child: const SizedBox.expand(),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 14 : 18),
                        _buildToolbar(scheme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar(ColorScheme scheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final color in palette)
                _PaletteDot(
                  color: color,
                  isSelected: color == _currentColor,
                  onTap: () => setState(() => _currentColor = color),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.brush_rounded, size: 18),
              Expanded(
                child: Slider(
                  value: _strokeWidth,
                  min: 3,
                  max: 18,
                  divisions: 15,
                  label: _strokeWidth.toStringAsFixed(0),
                  onChanged: (value) => setState(() => _strokeWidth = value),
                ),
              ),
              _ToolButton(
                icon: Icons.undo_rounded,
                tooltip: 'Undo',
                onTap: _strokes.isEmpty ? null : _undo,
              ),
              const SizedBox(width: 8),
              _ToolButton(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Clear',
                onTap: _strokes.isEmpty ? null : _clear,
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSending ? null : _send,
              icon: _isSending
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_isSending ? 'Sending…' : 'Send to Widget'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaletteDot extends StatelessWidget {
  const _PaletteDot({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: isSelected ? 34 : 28,
        height: isSelected ? 34 : 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: isSelected ? 0.55 : 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton.filledTonal(
        onPressed: onTap,
        icon: Icon(icon),
      ),
    );
  }
}
