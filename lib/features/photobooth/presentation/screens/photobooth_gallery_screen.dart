import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/data/local_account_store.dart';
import '../../data/photobooth_store.dart';
import '../widgets/photo_booth_strip.dart';

class PhotoBoothGalleryScreen extends StatefulWidget {
  const PhotoBoothGalleryScreen({super.key, required this.account});

  final LocalAccount account;

  @override
  State<PhotoBoothGalleryScreen> createState() =>
      _PhotoBoothGalleryScreenState();
}

class _PhotoBoothGalleryScreenState extends State<PhotoBoothGalleryScreen> {
  final _store = PhotoBoothStore();
  List<PhotoBoothSession> _sessions = [];
  bool _isLoading = true;
  String? _selectedFrameStyle;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final sessions = await _store.loadCompletedSessions(
        frameStyle: _selectedFrameStyle,
        startDate: _startDate,
        endDate: _endDate,
      );
      if (!mounted) return;
      setState(() {
        _sessions = sessions;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedFrameStyle = null;
      _startDate = null;
      _endDate = null;
    });
    _loadSessions();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B1720),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            _buildFilters(),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD9A8D7),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFFFB5B5),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _sessions.isEmpty
                          ? _buildEmptyState()
                          : _buildGalleryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: 'Back',
            onPressed: () => context.go('/photobooth'),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PHOTO GALLERY',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'Your shared memories',
                  style: TextStyle(
                    color: Color(0xFFC8B8CB),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Column(
        children: [
          // Frame Style Filter
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text(
                  'Frame Style:',
                  style: TextStyle(
                    color: Color(0xFFC8B8CB),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                _FrameFilterChip(
                  label: 'All',
                  isSelected: _selectedFrameStyle == null,
                  onTap: () {
                    setState(() => _selectedFrameStyle = null);
                    _loadSessions();
                  },
                ),
                const SizedBox(width: 6),
                _FrameFilterChip(
                  label: 'Vintage',
                  isSelected: _selectedFrameStyle == 'vintage',
                  onTap: () {
                    setState(() => _selectedFrameStyle = 'vintage');
                    _loadSessions();
                  },
                ),
                const SizedBox(width: 6),
                _FrameFilterChip(
                  label: 'Sakura',
                  isSelected: _selectedFrameStyle == 'sakura',
                  onTap: () {
                    setState(() => _selectedFrameStyle = 'sakura');
                    _loadSessions();
                  },
                ),
                const SizedBox(width: 6),
                _FrameFilterChip(
                  label: 'Midnight',
                  isSelected: _selectedFrameStyle == 'midnight',
                  onTap: () {
                    setState(() => _selectedFrameStyle = 'midnight');
                    _loadSessions();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Date Filter
          Row(
            children: [
              const Text(
                'Date Range:',
                style: TextStyle(
                  color: Color(0xFFC8B8CB),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              _DateFilterChip(
                label: _startDate == null && _endDate == null
                    ? 'All Time'
                    : '${_startDate?.toString().split(' ')[0] ?? ''} - ${_endDate?.toString().split(' ')[0] ?? ''}',
                onTap: () => _showDatePicker(),
              ),
              const SizedBox(width: 8),
              if (_selectedFrameStyle != null ||
                  _startDate != null ||
                  _endDate != null)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      color: Color(0xFFD9A8D7),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF312A35)),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 64,
            color: const Color(0xFF8F7797),
          ),
          const SizedBox(height: 16),
          const Text(
            'No photo strips yet',
            style: TextStyle(
              color: Color(0xFFC8B8CB),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Start a photo booth session to create memories',
            style: TextStyle(
              color: Color(0xFF8F7797),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/photobooth'),
            icon: const Icon(Icons.camera_alt_rounded),
            label: const Text('Start Photo Booth'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD9A8D7),
              foregroundColor: const Color(0xFF2B1F2E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(14),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.7,
      ),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return _SessionCard(
          session: session,
          onTap: () => _showSessionDetail(session),
        );
      },
    );
  }

  Future<void> _showDatePicker() async {
    final now = DateTime.now();
    final firstDate = DateTime(now.year - 1);
    final lastDate = now;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: firstDate,
      lastDate: lastDate,
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFD9A8D7),
              onPrimary: Color(0xFF2B1F2E),
              surface: Color(0xFF1B1720),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadSessions();
    }
  }

  Future<void> _showSessionDetail(PhotoBoothSession session) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1B1720),
      builder: (context) => _PhotoStripDetailSheet(
        store: _store,
        session: session,
      ),
    );
  }
}

class _PhotoStripDetailSheet extends StatefulWidget {
  const _PhotoStripDetailSheet({
    required this.store,
    required this.session,
  });

  final PhotoBoothStore store;
  final PhotoBoothSession session;

  @override
  State<_PhotoStripDetailSheet> createState() => _PhotoStripDetailSheetState();
}

class _PhotoStripDetailSheetState extends State<_PhotoStripDetailSheet> {
  List<PhotoBoothPhoto> _photos = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      final photos = await widget.store.loadPhotos(widget.session.id);
      if (!mounted) return;
      setState(() {
        _photos = photos;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not load this photo strip. Please try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final frames = List<int>.generate(session.totalRounds, (index) => index);
    return SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .9,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      session.createdAt.toLocal().toString().split(' ').first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(color: Color(0xFF312A35), height: 1),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFFD9A8D7),
                      ),
                    )
                  : _errorMessage != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _errorMessage!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFFFB5B5),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        )
                      : _photos.isEmpty
                          ? const Center(
                              child: Text(
                                'This photo strip has no saved frames yet.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFFC8B8CB)),
                              ),
                            )
                          : SingleChildScrollView(
                              padding:
                                  const EdgeInsets.fromLTRB(18, 20, 18, 32),
                              child: Center(
                                child: PhotoBoothStripPreview(
                                  child: PhotoBoothStrip(
                                    roundIndexes: frames,
                                    photos: _photos,
                                    frameStyle: session.participantFrameStyle ??
                                        'vintage',
                                    primaryUserId: session.createdBy,
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
}

class _FrameFilterChip extends StatelessWidget {
  const _FrameFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? const Color(0xFF2B1F2E) : const Color(0xFFC8B8CB),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: const Color(0xFF312A35),
      selectedColor: const Color(0xFFD9A8D7),
      checkmarkColor: const Color(0xFF2B1F2E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? const Color(0xFFD9A8D7) : const Color(0xFF312A35),
        ),
      ),
    );
  }
}

class _DateFilterChip extends StatelessWidget {
  const _DateFilterChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(
        label,
        style: const TextStyle(
          color: Color(0xFFC8B8CB),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: false,
      onSelected: (_) => onTap(),
      backgroundColor: const Color(0xFF312A35),
      selectedColor: const Color(0xFFD9A8D7),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFF312A35)),
      ),
      avatar: const Icon(
        Icons.calendar_today_rounded,
        size: 14,
        color: Color(0xFFD9A8D7),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({
    required this.session,
    required this.onTap,
  });

  final PhotoBoothSession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final frameStyle = session.participantFrameStyle ?? 'vintage';
    final isSakura = frameStyle == 'sakura';
    final isMidnight = frameStyle == 'midnight';

    final bgColor = isSakura
        ? const Color(0xFFFFE7EE)
        : isMidnight
            ? const Color(0xFF10182D)
            : const Color(0xFFFFF7E7);

    final borderColor = isSakura
        ? const Color(0xFFE68CA8)
        : isMidnight
            ? const Color(0xFFD7B66B)
            : const Color(0xFF604032);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Center(
                  child: _FrameThumbnail(
                    frameStyle: frameStyle,
                    borderColor: borderColor,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      frameStyle.toUpperCase(),
                      style: TextStyle(
                        color:
                            isMidnight ? Colors.white : const Color(0xFF35251F),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatSessionDate(session.createdAt),
                      style: TextStyle(
                        color: isMidnight
                            ? const Color(0xFFD8C28F)
                            : const Color(0xFF765A4A),
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatSessionDate(DateTime dateTime) {
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
    final local = dateTime.toLocal();
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }
}

class _FrameThumbnail extends StatelessWidget {
  const _FrameThumbnail({required this.frameStyle, required this.borderColor});

  final String frameStyle;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final isSakura = frameStyle == 'sakura';
    final isMidnight = frameStyle == 'midnight';
    final stripColor = isSakura
        ? const Color(0xFFFFF8FA)
        : isMidnight
            ? const Color(0xFF17223B)
            : const Color(0xFFFFFCF4);
    final photoColor = isSakura
        ? const Color(0xFFF3B4C6)
        : isMidnight
            ? const Color(0xFF384C75)
            : const Color(0xFFD5BFA0);
    final accentColor = isSakura
        ? const Color(0xFFC45D81)
        : isMidnight
            ? const Color(0xFFE7C66E)
            : const Color(0xFF8B6048);

    return SizedBox(
      width: 62,
      height: 104,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: stripColor,
          borderRadius: BorderRadius.circular(isMidnight ? 4 : 6),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(5, 5, 5, 4),
          child: Column(
            children: [
              Container(width: 30, height: 2, color: accentColor),
              const SizedBox(height: 4),
              for (var index = 0; index < 5; index += 1) ...[
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _ThumbnailPhoto(color: photoColor)),
                      const SizedBox(width: 2),
                      Expanded(child: _ThumbnailPhoto(color: photoColor)),
                    ],
                  ),
                ),
                if (index != 4) const SizedBox(height: 2),
              ],
              const SizedBox(height: 4),
              Container(width: 24, height: 2, color: accentColor),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbnailPhoto extends StatelessWidget {
  const _ThumbnailPhoto({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
