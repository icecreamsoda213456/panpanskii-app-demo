import 'package:flutter/material.dart';

class DemoChrome extends StatefulWidget {
  const DemoChrome({super.key, required this.child, required this.onReset});
  final Widget child;
  final Future<void> Function() onReset;

  @override
  State<DemoChrome> createState() => _DemoChromeState();
}

class _DemoChromeState extends State<DemoChrome> {
  bool _confirm = false;
  bool _busy = false;
  String? _error;

  Future<void> _reset() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.onReset();
      if (mounted) setState(() => _confirm = false);
    } catch (_) {
      if (mounted) setState(() => _error = 'Reset failed. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final bannerHeight = 48 + MediaQuery.paddingOf(context).top;
    // Web can request focus before nested navigators have a measured box.
    return FocusTraversalGroup(
        policy: WidgetOrderTraversalPolicy(),
        child: Overlay.wrap(
            child: Stack(children: [
          Positioned.fill(top: bannerHeight, child: widget.child),
          Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: bannerHeight,
              child: Material(
                  color: colors.secondaryContainer,
                  child: SafeArea(
                      bottom: false,
                      child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(children: [
                            const Icon(Icons.science_outlined, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    _error ??
                                        (_confirm
                                            ? 'Reset all sample data?'
                                            : 'Local demo: Alex + Sam'),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600))),
                            if (_busy)
                              const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                            else if (_confirm) ...[
                              IconButton(
                                  tooltip: 'Confirm reset',
                                  onPressed: _reset,
                                  icon: const Icon(Icons.check, size: 19)),
                              IconButton(
                                  tooltip: 'Cancel reset',
                                  onPressed: () =>
                                      setState(() => _confirm = false),
                                  icon: const Icon(Icons.close, size: 19)),
                            ] else ...[
                              const Tooltip(
                                  message:
                                      'Fictional profiles. Saved only in this browser. No real messages, calls, or device notifications.',
                                  triggerMode: TooltipTriggerMode.tap,
                                  child: Padding(
                                      padding: EdgeInsets.all(12),
                                      child:
                                          Icon(Icons.info_outline, size: 17))),
                              IconButton(
                                  tooltip: 'Reset demo data',
                                  onPressed: () =>
                                      setState(() => _confirm = true),
                                  icon:
                                      const Icon(Icons.restart_alt, size: 19)),
                            ],
                          ]))))),
        ])));
  }
}
