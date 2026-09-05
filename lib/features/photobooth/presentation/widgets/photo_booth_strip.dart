import 'package:flutter/material.dart';

import '../../data/photobooth_store.dart';

/// The one canonical renderer for an in-progress result, gallery detail, and
/// exported Photo Booth strip. Its fixed logical size keeps exports consistent.
class PhotoBoothStrip extends StatelessWidget {
  const PhotoBoothStrip({
    super.key,
    required this.roundIndexes,
    required this.photos,
    required this.frameStyle,
    this.primaryUserId,
  });

  static const double logicalWidth = 360;
  static const double logicalHeight = 1156;

  final List<int> roundIndexes;
  final List<PhotoBoothPhoto> photos;
  final String frameStyle;

  /// The creator of the shared session. When present in the captured photos,
  /// this person always occupies the left column of every row.
  final String? primaryUserId;

  @override
  Widget build(BuildContext context) {
    final theme = _StripTheme.forStyle(frameStyle);
    final rounds = _fiveRounds();
    final participantIds = _participantIds();
    final leftUserId = participantIds.isNotEmpty ? participantIds.first : null;
    final rightUserId = participantIds.length > 1 ? participantIds[1] : null;
    final leftIdentity = _participantIdentity(
      _firstPhotoFor(leftUserId),
      fallbackMascot: 'PANDA',
    );
    final rightIdentity = _participantIdentity(
      _firstPhotoFor(rightUserId),
      fallbackMascot: leftIdentity.mascot == 'PANDA' ? 'KOALA' : 'YOUR PERSON',
    );

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: SizedBox(
        width: logicalWidth,
        height: logicalHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.background,
            borderRadius: BorderRadius.circular(theme.stripRadius),
            border: Border.all(color: theme.border, width: theme.borderWidth),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.stripRadius),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(painter: _StripDecorationPainter(theme)),
                  ),
                ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                    child: Column(
                      children: [
                        SizedBox(height: 46, child: _StripHeader(theme: theme)),
                        const SizedBox(height: 6),
                        _ParticipantLabels(
                          left: leftIdentity,
                          right: rightIdentity,
                          theme: theme,
                        ),
                        const SizedBox(height: 8),
                        for (var index = 0; index < rounds.length; index++) ...[
                          _RoundPair(
                            first: _photoFor(rounds[index], leftUserId),
                            second: _photoFor(rounds[index], rightUserId),
                            theme: theme,
                          ),
                          if (index != rounds.length - 1)
                            _RowSeparator(theme: theme),
                        ],
                        const Spacer(),
                        const SizedBox(height: 6),
                        SizedBox(height: 54, child: _StripFooter(theme: theme)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<int> _fiveRounds() {
    final suppliedRounds = <int>{...roundIndexes}.toList()..sort();
    return List<int>.generate(
      5,
      (index) => index < suppliedRounds.length ? suppliedRounds[index] : index,
    );
  }

  List<String> _participantIds() {
    final orderedIds = <String>[];
    final availableIds = photos
        .map((photo) => photo.userId)
        .where((userId) => userId.isNotEmpty)
        .toSet();

    void add(String? userId) {
      if (userId == null || userId.isEmpty || !availableIds.contains(userId)) {
        return;
      }
      if (!orderedIds.contains(userId)) orderedIds.add(userId);
    }

    // A shared session's creator is the durable, meaningful left-side owner.
    add(primaryUserId);

    // Older sessions may not have a creator. Their first capture establishes a
    // stable fallback order without sorting arbitrary user UUIDs.
    final orderedPhotos = List<PhotoBoothPhoto>.from(photos)
      ..sort((first, second) {
        final byRound = first.roundIndex.compareTo(second.roundIndex);
        if (byRound != 0) return byRound;
        final byCreatedAt = first.createdAt.compareTo(second.createdAt);
        if (byCreatedAt != 0) return byCreatedAt;
        return first.id.compareTo(second.id);
      });
    for (final photo in orderedPhotos) {
      add(photo.userId);
      if (orderedIds.length == 2) break;
    }
    return orderedIds;
  }

  PhotoBoothPhoto? _firstPhotoFor(String? userId) {
    if (userId == null) return null;
    for (final photo in photos) {
      if (photo.userId == userId) return photo;
    }
    return null;
  }

  PhotoBoothPhoto? _photoFor(int round, String? userId) {
    if (userId == null) return null;
    for (final photo in photos) {
      if (photo.roundIndex == round && photo.userId == userId) return photo;
    }
    return null;
  }

  _ParticipantIdentity _participantIdentity(
    PhotoBoothPhoto? photo, {
    required String fallbackMascot,
  }) {
    final mascot = photo == null ? '' : photo.mascot.name.trim();
    final username = photo?.username.trim() ?? '';
    final normalizedUsername = username.replaceFirst(RegExp(r'^@+'), '');
    return _ParticipantIdentity(
      mascot: mascot.isEmpty
          ? fallbackMascot
          : mascot.replaceAll('_', ' ').toUpperCase(),
      username:
          normalizedUsername.isEmpty ? '@panpanskii' : '@$normalizedUsername',
    );
  }
}

/// Responsively scales the fixed export-size strip without changing the strip
/// itself or stretching its images.
class PhotoBoothStripPreview extends StatelessWidget {
  const PhotoBoothStripPreview({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : PhotoBoothStrip.logicalWidth;
        final previewWidth = availableWidth < PhotoBoothStrip.logicalWidth
            ? availableWidth
            : PhotoBoothStrip.logicalWidth;
        final previewHeight = previewWidth *
            PhotoBoothStrip.logicalHeight /
            PhotoBoothStrip.logicalWidth;

        return SizedBox(
          width: previewWidth,
          height: previewHeight,
          child: FittedBox(
            fit: BoxFit.contain,
            alignment: Alignment.topCenter,
            child: child,
          ),
        );
      },
    );
  }
}

class _RoundPair extends StatelessWidget {
  const _RoundPair({
    required this.first,
    required this.second,
    required this.theme,
  });

  final PhotoBoothPhoto? first;
  final PhotoBoothPhoto? second;
  final _StripTheme theme;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _PhotoCell(photo: first, theme: theme)),
        const SizedBox(width: 8),
        Expanded(child: _PhotoCell(photo: second, theme: theme)),
      ],
    );
  }
}

class _PhotoCell extends StatelessWidget {
  const _PhotoCell({required this.photo, required this.theme});

  final PhotoBoothPhoto? photo;
  final _StripTheme theme;

  @override
  Widget build(BuildContext context) {
    final imageUrl = photo?.imageUrl;
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.photoMat,
          borderRadius: BorderRadius.circular(theme.photoRadius),
          border: Border.all(color: theme.photoBorder, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .11),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(theme.innerPhotoRadius),
            clipBehavior: Clip.antiAlias,
            child: ColoredBox(
              color: theme.placeholder,
              child: imageUrl == null || imageUrl.isEmpty
                  ? Icon(
                      Icons.photo_outlined,
                      color: theme.photoBorder.withValues(alpha: .6),
                      size: 24,
                    )
                  : Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                      filterQuality: FilterQuality.high,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.broken_image_outlined,
                        color: theme.photoBorder.withValues(alpha: .7),
                        size: 24,
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.accent,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StripHeader extends StatelessWidget {
  const _StripHeader({required this.theme});

  final _StripTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(theme.headerIcon, size: 13, color: theme.accent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                theme.header,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.text,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.05,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Icon(theme.headerIcon, size: 13, color: theme.accent),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          theme.headerDetail,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.subtleText,
            fontSize: 6.4,
            fontWeight: FontWeight.w800,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 5),
        Container(
          width: 98,
          height: 1,
          color: theme.accent.withValues(alpha: .52),
        ),
      ],
    );
  }
}

class _ParticipantLabels extends StatelessWidget {
  const _ParticipantLabels({
    required this.left,
    required this.right,
    required this.theme,
  });

  final _ParticipantIdentity left;
  final _ParticipantIdentity right;
  final _StripTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: Row(
        children: [
          Expanded(child: _ParticipantLabel(identity: left, theme: theme)),
          SizedBox(
            width: 18,
            child: Center(
              child: Icon(
                Icons.favorite_rounded,
                size: 9,
                color: theme.accent,
              ),
            ),
          ),
          Expanded(child: _ParticipantLabel(identity: right, theme: theme)),
        ],
      ),
    );
  }
}

class _ParticipantLabel extends StatelessWidget {
  const _ParticipantLabel({required this.identity, required this.theme});

  final _ParticipantIdentity identity;
  final _StripTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          identity.mascot,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.text,
            fontSize: 7.6,
            fontWeight: FontWeight.w900,
            letterSpacing: .75,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          identity.username,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.subtleText,
            fontSize: 6.2,
            fontWeight: FontWeight.w700,
            letterSpacing: .25,
          ),
        ),
      ],
    );
  }
}

class _RowSeparator extends StatelessWidget {
  const _RowSeparator({required this.theme});

  final _StripTheme theme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 5,
      child: Align(
        alignment: Alignment.center,
        child: Container(
          width: 52,
          height: 1,
          color: theme.accent.withValues(alpha: .32),
        ),
      ),
    );
  }
}

class _StripFooter extends StatelessWidget {
  const _StripFooter({required this.theme});

  final _StripTheme theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 132,
          height: 1,
          color: theme.accent.withValues(alpha: .52),
        ),
        const SizedBox(height: 7),
        Text(
          theme.footerMain,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.text,
            fontSize: 9,
            fontWeight: FontWeight.w900,
            letterSpacing: .9,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          theme.footerSecondary,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: theme.subtleText,
            fontSize: 6.3,
            fontWeight: FontWeight.w900,
            letterSpacing: .45,
          ),
        ),
      ],
    );
  }
}

class _ParticipantIdentity {
  const _ParticipantIdentity({required this.mascot, required this.username});

  final String mascot;
  final String username;
}

class _StripDecorationPainter extends CustomPainter {
  const _StripDecorationPainter(this.theme);

  final _StripTheme theme;

  @override
  void paint(Canvas canvas, Size size) {
    switch (theme.kind) {
      case _StripKind.vintage:
        _paintVintage(canvas, size);
      case _StripKind.sakura:
        _paintSakura(canvas, size);
      case _StripKind.midnight:
        _paintMidnight(canvas, size);
    }
  }

  void _paintVintage(Canvas canvas, Size size) {
    final speckle = Paint()..color = theme.accent.withValues(alpha: .075);
    final xSpan = (size.width - 18).round();
    final ySpan = (size.height - 18).round();
    for (var index = 0; index < 38; index += 1) {
      final x = 9 + (index * 47 % xSpan).toDouble();
      final y = 9 + (index * 83 % ySpan).toDouble();
      canvas.drawCircle(Offset(x, y), index.isEven ? 1 : .65, speckle);
    }

    final line = Paint()
      ..color = theme.accent.withValues(alpha: .36)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    canvas.drawLine(const Offset(9, 10), Offset(size.width - 9, 10), line);
    canvas.drawLine(
      Offset(9, size.height - 10),
      Offset(size.width - 9, size.height - 10),
      line,
    );

    final mark = Paint()..color = theme.accent.withValues(alpha: .23);
    final step = (size.height - 176) / 6;
    for (var index = 0; index < 7; index += 1) {
      final y = 88 + index * step;
      canvas.drawRect(Rect.fromLTWH(4, y, 4, 16), mark);
      canvas.drawRect(Rect.fromLTWH(size.width - 8, y + 6, 4, 16), mark);
    }
  }

  void _paintSakura(Canvas canvas, Size size) {
    final petal = Paint()..color = theme.accent.withValues(alpha: .23);
    _drawPetal(canvas, const Offset(24, 26), .3, petal);
    _drawPetal(canvas, const Offset(47, 20), -.7, petal);
    _drawPetal(canvas, Offset(size.width - 30, 31), .8, petal);
    _drawPetal(canvas, Offset(size.width - 52, 20), -.2, petal);
    _drawPetal(canvas, Offset(24, size.height - 28), -.4, petal);
    _drawPetal(canvas, Offset(size.width - 27, size.height - 25), .4, petal);

    final heart = Paint()..color = theme.accent.withValues(alpha: .14);
    canvas.drawCircle(Offset(17, size.height * .42), 2.5, heart);
    canvas.drawCircle(Offset(size.width - 17, size.height * .58), 2.5, heart);
  }

  void _paintMidnight(Canvas canvas, Size size) {
    final star = Paint()..color = theme.accent.withValues(alpha: .72);
    final stars = [
      const Offset(22, 24),
      const Offset(52, 37),
      Offset(size.width - 42, 27),
      Offset(size.width - 22, 52),
      Offset(27, size.height - 48),
      Offset(size.width - 31, size.height - 30),
      Offset(size.width - 54, size.height - 56),
    ];
    for (final point in stars) {
      canvas.drawCircle(point, 1.45, star);
      canvas.drawLine(
        Offset(point.dx - 2.5, point.dy),
        Offset(point.dx + 2.5, point.dy),
        star..strokeWidth = .6,
      );
      canvas.drawLine(
        Offset(point.dx, point.dy - 2.5),
        Offset(point.dx, point.dy + 2.5),
        star,
      );
    }

    final constellation = Paint()
      ..color = theme.accent.withValues(alpha: .25)
      ..strokeWidth = .8;
    canvas.drawLine(const Offset(23, 66), const Offset(52, 82), constellation);
    canvas.drawLine(const Offset(52, 82), const Offset(78, 62), constellation);
    canvas.drawLine(
      Offset(size.width - 82, size.height - 66),
      Offset(size.width - 50, size.height - 84),
      constellation,
    );

    final moon = Paint()..color = theme.accent.withValues(alpha: .7);
    canvas.drawCircle(Offset(size.width - 30, 30), 9, moon);
    canvas.drawCircle(
      Offset(size.width - 26, 26),
      9,
      Paint()..color = theme.background,
    );
  }

  void _drawPetal(Canvas canvas, Offset center, double angle, Paint paint) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(const Rect.fromLTWH(-6, -3, 12, 6), paint);
    canvas.drawOval(const Rect.fromLTWH(-3, -6, 6, 12), paint);
    canvas.drawCircle(
      Offset.zero,
      2,
      Paint()..color = theme.text.withValues(alpha: .18),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StripDecorationPainter oldDelegate) {
    return oldDelegate.theme.kind != theme.kind;
  }
}

enum _StripKind { vintage, sakura, midnight }

class _StripTheme {
  const _StripTheme({
    required this.kind,
    required this.background,
    required this.border,
    required this.accent,
    required this.text,
    required this.subtleText,
    required this.photoMat,
    required this.photoBorder,
    required this.placeholder,
    required this.header,
    required this.headerDetail,
    required this.footerMain,
    required this.footerSecondary,
    required this.headerIcon,
    required this.stripRadius,
    required this.photoRadius,
    required this.innerPhotoRadius,
    required this.borderWidth,
  });

  final _StripKind kind;
  final Color background;
  final Color border;
  final Color accent;
  final Color text;
  final Color subtleText;
  final Color photoMat;
  final Color photoBorder;
  final Color placeholder;
  final String header;
  final String headerDetail;
  final String footerMain;
  final String footerSecondary;
  final IconData headerIcon;
  final double stripRadius;
  final double photoRadius;
  final double innerPhotoRadius;
  final double borderWidth;

  factory _StripTheme.forStyle(String style) {
    switch (style) {
      case 'sakura':
        return const _StripTheme(
          kind: _StripKind.sakura,
          background: Color(0xFFFFE7EE),
          border: Color(0xFFE68CA8),
          accent: Color(0xFFC45D81),
          text: Color(0xFF612E40),
          subtleText: Color(0xFF8B5367),
          photoMat: Color(0xFFFFFCFD),
          photoBorder: Color(0xFFF1AAC0),
          placeholder: Color(0xFFEABAC8),
          header: 'BLOOMING TOGETHER',
          headerDetail: 'OUR LITTLE MOMENTS',
          footerMain: 'PANPANSKII \u2661 2026',
          footerSecondary: 'EST. 2026 \u2022 ALWAYS IN BLOOM',
          headerIcon: Icons.favorite_border_rounded,
          stripRadius: 12,
          photoRadius: 9,
          innerPhotoRadius: 6,
          borderWidth: 2,
        );
      case 'midnight':
        return const _StripTheme(
          kind: _StripKind.midnight,
          background: Color(0xFF10182D),
          border: Color(0xFFD7B66B),
          accent: Color(0xFFE7C66E),
          text: Color(0xFFFFF4D8),
          subtleText: Color(0xFFD8C28F),
          photoMat: Color(0xFF1D2944),
          photoBorder: Color(0xFFB8934F),
          placeholder: Color(0xFF2D3D61),
          header: 'UNDER THE SAME SKY',
          headerDetail: 'PANPANSKII PHOTO BOOTH',
          footerMain: 'PANPANSKII \u2726 2026',
          footerSecondary: 'EST. 2026 \u2022 UNDER THE SAME SKY',
          headerIcon: Icons.auto_awesome_rounded,
          stripRadius: 9,
          photoRadius: 5,
          innerPhotoRadius: 3,
          borderWidth: 2,
        );
      default:
        return const _StripTheme(
          kind: _StripKind.vintage,
          background: Color(0xFFFFF7E7),
          border: Color(0xFF604032),
          accent: Color(0xFF8B6048),
          text: Color(0xFF35251F),
          subtleText: Color(0xFF765A4A),
          photoMat: Color(0xFFFFFDF7),
          photoBorder: Color(0xFF50362B),
          placeholder: Color(0xFFCCB99C),
          header: 'MEMORIES ON FILM',
          headerDetail: 'PANPANSKII PHOTO BOOTH \u2022 35MM',
          footerMain: 'PANPANSKII \u2022 2026',
          footerSecondary: 'EST. 2026 \u2022 FOREVER TOGETHER',
          headerIcon: Icons.camera_alt_outlined,
          stripRadius: 5,
          photoRadius: 2,
          innerPhotoRadius: 1,
          borderWidth: 2,
        );
    }
  }
}
