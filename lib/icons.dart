import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'main.dart';

/// Icônes Nqata : traits fins, une seule couleur (celle du texte).
/// Motifs tirés du logo : store, étiquette, carte, panier.
enum NI { scan, clients, shop, stats, profile, offer, points, gift, money, basket, repeat, clock, calendar, search, sort, edit, copy, badge, tune, lock, torch, camera, photos, info, undo, check }

class NIcon extends StatelessWidget {
  final NI icon;
  final double? size;
  final Color? color, accent;
  const NIcon(this.icon, {super.key, this.size, this.color, this.accent});

  @override
  Widget build(BuildContext context) {
    final ink = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    final s = size ?? IconTheme.of(context).size ?? 24;
    return SizedBox(width: s, height: s, child: CustomPaint(painter: _NPainter(icon, ink, accent ?? kAccent)));
  }
}

/// Affiche une icône Nqata ou, à défaut, une icône Material.
Widget ic(Object i, {double? size, Color? color, Color? accent}) =>
    i is NI ? NIcon(i, size: size, color: color, accent: accent) : Icon(i as IconData, size: size, color: color);

class _NPainter extends CustomPainter {
  final NI i;
  final Color ink, accent;
  _NPainter(this.i, this.ink, this.accent);

  @override
  bool shouldRepaint(_NPainter o) => o.i != i || o.ink != ink || o.accent != accent;

  @override
  void paint(Canvas c, Size sz) {
    c.scale(sz.width / 24, sz.height / 24);
    final line = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = Colors.transparent // pas de remplissage : icônes au trait
      ..style = PaintingStyle.fill;
    final solid = Paint()
      ..color = ink
      ..style = PaintingStyle.fill;
    void rr(double x, double y, double w, double h, double r, {bool f = false}) {
      final q = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), Radius.circular(r));
      if (f) c.drawRRect(q, fill);
      c.drawRRect(q, line);
    }

    void ci(double x, double y, double r, {bool f = false, bool s = true}) {
      if (f) c.drawCircle(Offset(x, y), r, fill);
      if (s) c.drawCircle(Offset(x, y), r, line);
    }

    void ln(double a, double b, double x, double y) => c.drawLine(Offset(a, b), Offset(x, y), line);
    Path poly(List<double> v, {bool close = false}) {
      final p = Path()..moveTo(v[0], v[1]);
      for (var k = 2; k < v.length; k += 2) {
        p.lineTo(v[k], v[k + 1]);
      }
      if (close) p.close();
      return p;
    }

    void fl(Path p) => c.drawPath(p, fill);
    void st(Path p) => c.drawPath(p, line);

    switch (i) {
      case NI.scan:
        {
          st(poly([4, 8, 4, 4, 8, 4]));
          st(poly([16, 4, 20, 4, 20, 8]));
          st(poly([20, 16, 20, 20, 16, 20]));
          st(poly([8, 20, 4, 20, 4, 16]));
          rr(6.5, 10.8, 11, 2.4, 1.2, f: true);
        }
      case NI.clients:
        {
          ci(9, 8, 3.2);
          st(Path()
            ..moveTo(3.5, 19.5)
            ..cubicTo(3.5, 15.8, 6, 14, 9, 14)
            ..cubicTo(12, 14, 14.5, 15.8, 14.5, 19.5));
          ci(16.8, 9, 2.4, f: true);
          st(Path()
            ..moveTo(16, 14.2)
            ..cubicTo(19, 14, 20.5, 15.8, 20.5, 18.5));
        }
      case NI.shop:
        {
          // Le store rayé du logo
          final aw = poly([4, 4, 20, 4, 21.5, 9.5, 2.5, 9.5], close: true);
          fl(aw);
          st(aw);
          ln(9, 4, 8.3, 9.5);
          ln(15, 4, 15.7, 9.5);
          st(poly([4.5, 9.5, 4.5, 20, 19.5, 20, 19.5, 9.5]));
          st(poly([10, 20, 10, 14.5, 14, 14.5, 14, 20]));
        }
      case NI.stats:
        {
          rr(4, 13, 4, 7, 1.2);
          rr(10, 8, 4, 12, 1.2, f: true);
          rr(16, 4, 4, 16, 1.2);
        }
      case NI.profile:
        {
          ci(12, 8, 3.6, f: true);
          st(Path()
            ..moveTo(5, 20)
            ..cubicTo(5, 15.5, 8, 14, 12, 14)
            ..cubicTo(16, 14, 19, 15.5, 19, 20));
        }
      case NI.offer:
        {
          // L'étiquette % du logo
          final t = poly([3.5, 12, 12, 3.5, 20.5, 3.5, 20.5, 12, 12, 20.5], close: true);
          fl(t);
          st(t);
          ci(16.5, 7.5, 1.1);
          ln(9.5, 14.5, 14.5, 9.5);
          ci(10.2, 10.2, 0.9);
          ci(13.8, 13.8, 0.9);
        }
      case NI.points:
        {
          ci(12, 12, 8.5, f: true);
          final star = Path();
          for (var k = 0; k < 10; k++) {
            final ang = -math.pi / 2 + k * math.pi / 5;
            final r = k.isEven ? 4.6 : 1.9;
            final x = 12 + r * math.cos(ang), y = 12 + r * math.sin(ang);
            if (k == 0) {
              star.moveTo(x, y);
            } else {
              star.lineTo(x, y);
            }
          }
          star.close();
          c.drawPath(star, solid);
        }
      case NI.gift:
        {
          rr(4, 10, 16, 10, 2);
          rr(3, 7, 18, 3.5, 1.5);
          rr(10.8, 7, 2.4, 13, 0.6, f: true);
          st(Path()
            ..moveTo(12, 7)
            ..cubicTo(12, 3.8, 8, 3.2, 8, 5.4)
            ..cubicTo(8, 7, 10.6, 7, 12, 7));
          st(Path()
            ..moveTo(12, 7)
            ..cubicTo(12, 3.8, 16, 3.2, 16, 5.4)
            ..cubicTo(16, 7, 13.4, 7, 12, 7));
        }
      case NI.money:
        {
          // La carte bancaire du logo
          rr(3, 6, 18, 12, 2.5);
          ln(3, 10.5, 21, 10.5);
          ln(6.5, 15, 10.5, 15);
        }
      case NI.basket:
        {
          fl(poly([6.4, 7.5, 20, 7.5, 18.2, 15, 7.6, 15], close: true));
          st(Path()
            ..moveTo(3, 4)
            ..lineTo(5.6, 4)
            ..lineTo(7.7, 15)
            ..lineTo(18.2, 15)
            ..lineTo(20.2, 7.5)
            ..lineTo(6.2, 7.5));
          ci(9.6, 19, 1.4);
          ci(16.4, 19, 1.4);
        }
      case NI.repeat:
        {
          st(Path()
            ..moveTo(5.2, 11)
            ..arcToPoint(const Offset(17.4, 7.2), radius: const Radius.circular(7)));
          st(poly([14.6, 6.8, 17.6, 7.2, 17.4, 4.2]));
          st(Path()
            ..moveTo(18.8, 13)
            ..arcToPoint(const Offset(6.6, 16.8), radius: const Radius.circular(7)));
          st(poly([9.4, 17.2, 6.4, 16.8, 6.6, 19.8]));
          ci(12, 12, 1.8, f: true, s: false);
        }
      case NI.clock:
        {
          ci(12, 12, 8.5, f: true);
          st(poly([12, 7.5, 12, 12, 15.5, 14]));
        }
      case NI.calendar:
        {
          fl(Path()..addRect(Rect.fromLTWH(4, 5.5, 16, 4.5)));
          rr(4, 5.5, 16, 14.5, 2.5);
          ln(4, 10, 20, 10);
          ln(8, 3.5, 8, 7.5);
          ln(16, 3.5, 16, 7.5);
          c.drawCircle(const Offset(9, 14.5), 1, solid);
          c.drawCircle(const Offset(13, 14.5), 1, solid);
        }
      case NI.search:
        {
          ci(10.5, 10.5, 6, f: true);
          ln(15, 15, 20, 20);
        }
      case NI.sort:
        {
          ln(4, 7, 20, 7);
          ln(4, 12, 15, 12);
          ln(4, 17, 10, 17);
          ci(19, 17, 1.8, f: true);
        }
      case NI.edit:
        {
          final p = poly([4.2, 19.8, 5.2, 15.2, 16, 4.4, 19.6, 8, 8.8, 18.8], close: true);
          fl(p);
          st(p);
          ln(14, 6.5, 17.5, 10);
        }
      case NI.copy:
        {
          rr(9, 9, 11, 11, 2.5, f: true);
          rr(4, 4, 11, 11, 2.5);
        }
      case NI.badge:
        {
          rr(3, 5, 18, 14, 2.5);
          ci(8.5, 11, 2, f: true);
          st(Path()
            ..moveTo(5.6, 16.6)
            ..cubicTo(6, 14.8, 7.2, 14.2, 8.5, 14.2)
            ..cubicTo(9.8, 14.2, 11, 14.8, 11.4, 16.6));
          ln(14, 10, 18, 10);
          ln(14, 13.5, 17, 13.5);
        }
      case NI.tune:
        {
          ln(4, 8, 20, 8);
          ln(4, 16, 20, 16);
          ci(9, 8, 2.5, f: true);
          ci(15, 16, 2.5, f: true);
        }
      case NI.lock:
        {
          rr(5, 11, 14, 9.5, 2.5, f: true);
          st(Path()
            ..moveTo(8.5, 11)
            ..lineTo(8.5, 8)
            ..arcToPoint(const Offset(15.5, 8), radius: const Radius.circular(3.5))
            ..lineTo(15.5, 11));
          c.drawCircle(const Offset(12, 15.5), 1.2, solid);
        }
      case NI.torch:
        {
          final b = poly([13.2, 3, 6, 13.6, 11, 13.6, 10, 21, 18, 10.2, 13, 10.2], close: true);
          fl(b);
          st(b);
        }
      case NI.camera:
        {
          rr(3, 7, 18, 13, 3);
          st(poly([8.5, 7, 10, 4.5, 14, 4.5, 15.5, 7]));
          ci(12, 13.5, 3.2, f: true);
        }
      case NI.photos:
        {
          rr(3.5, 4.5, 17, 15, 2.5);
          ci(9, 10, 1.8, f: true);
          st(poly([4, 17.5, 9.5, 13, 13, 16, 16, 13.5, 20, 17]));
        }
      case NI.info:
        {
          ci(12, 12, 8.5, f: true);
          ln(12, 11, 12, 16.5);
          ln(12, 7.8, 12, 7.9);
        }
      case NI.undo:
        {
          st(poly([9, 6, 4.5, 10.5, 9, 15]));
          st(Path()
            ..moveTo(5, 10.5)
            ..lineTo(14.5, 10.5)
            ..arcToPoint(const Offset(14.5, 20), radius: const Radius.circular(4.75))
            ..lineTo(10, 20));
        }
      case NI.check:
        {
          ci(12, 12, 9, f: true, s: false);
          st(poly([7.5, 12.5, 10.8, 15.8, 16.8, 9]));
        }
    }
  }
}
