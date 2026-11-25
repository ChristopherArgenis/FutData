// Colores, tema claro y piezas visuales compartidas.
import 'package:material_ui/material_ui.dart';

import 'estado.dart';
import 'modelo.dart';
import 'util.dart';

const cAc = Color(0xFF13924D), cAcDk = Color(0xFF0B6B38), cAcSoft = Color(0xFFE3F4EA);
const cBg = Color(0xFFF3F6F1), cFg = Color(0xFF13251A), cMu = Color(0xFF677769), cLine = Color(0xFFE2E9E2);
const cWin = Color(0xFF13924D), cDraw = Color(0xFF9AA59C), cLoss = Color(0xFFE0483B);
const cGold = Color(0xFFF0A92A), cGoldSoft = Color(0xFFFFF8E6), cFam = Color(0xFFE08A2E);

class KidColor {
  final Color c, t, d;
  const KidColor(this.c, this.t, this.d);
}

const kidColores = [
  KidColor(Color(0xFFE08A2E), Color(0xFFFDF0E3), Color(0xFFB8621A)),
  KidColor(Color(0xFF3B7FC4), Color(0xFFE6F0FA), Color(0xFF2D6AA8)),
  KidColor(Color(0xFF8A4FD1), Color(0xFFF2EAFB), Color(0xFF7A3FC0)),
  KidColor(Color(0xFFD0457A), Color(0xFFFBE8EF), Color(0xFFA8325E)),
];
KidColor kc(Hijo h) => kidColores[h.color % 4];
Color colorRes(String r) => r == 'G' ? cWin : r == 'E' ? cDraw : cLoss;

ThemeData temaFamilia() {
  final cs = ColorScheme.fromSeed(seedColor: cAc, brightness: Brightness.light).copyWith(primary: cAc, onPrimary: Colors.white, surface: Colors.white, onSurface: cFg);
  return ThemeData(
    useMaterial3: true,
    colorScheme: cs,
    scaffoldBackgroundColor: cBg,
    appBarTheme: const AppBarTheme(backgroundColor: cBg, foregroundColor: cFg, elevation: 0, scrolledUnderElevation: 0, centerTitle: false, titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: cFg)),
    cardTheme: CardThemeData(color: Colors.white, elevation: 0, margin: EdgeInsets.zero, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: cLine))),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: Colors.white, indicatorColor: cAcSoft, labelTextStyle: WidgetStateProperty.all(const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(backgroundColor: cAc, minimumSize: const Size(48, 48), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(foregroundColor: cFg, minimumSize: const Size(48, 48), side: const BorderSide(color: cLine), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cLine)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: cLine)), isDense: true),
    chipTheme: const ChipThemeData(side: BorderSide(color: cLine), backgroundColor: Colors.white),
  );
}

/// Acceso al estado desde cualquier pantalla.
class EstadoScope extends InheritedNotifier<Estado> {
  const EstadoScope({super.key, required Estado estado, required super.child}) : super(notifier: estado);
  static Estado of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<EstadoScope>()!.notifier!;
}

class Avatar extends StatelessWidget {
  final Hijo h;
  final double size;
  const Avatar(this.h, {super.key, this.size = 36});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size, alignment: Alignment.center,
        decoration: BoxDecoration(color: kc(h).c, shape: BoxShape.circle),
        child: Text(iniciales(h.nombre), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * .38)),
      );
}

class Seccion extends StatelessWidget {
  final String t;
  final Widget? accion;
  const Seccion(this.t, {super.key, this.accion});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
        child: Row(children: [Expanded(child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 12, letterSpacing: .8, fontWeight: FontWeight.w800, color: cMu))), ?accion]),
      );
}

class Tarjeta extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const Tarjeta({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Card(
        color: color,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

class Pastilla extends StatelessWidget {
  final String t;
  final Color c, fondo;
  const Pastilla(this.t, {super.key, this.c = cAcDk, this.fondo = cAcSoft});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: fondo, borderRadius: BorderRadius.circular(99)),
        child: Text(t, style: TextStyle(color: c, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class ResChip extends StatelessWidget {
  final Partido x;
  const ResChip(this.x, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 26, height: 26, alignment: Alignment.center,
        decoration: BoxDecoration(color: colorRes(x.resultado), borderRadius: BorderRadius.circular(7)),
        child: Text(x.resultado, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      );
}

class Dato extends StatelessWidget {
  final String v, l;
  final Color? c;
  const Dato(this.v, this.l, {super.key, this.c});
  @override
  Widget build(BuildContext context) => Column(children: [
        Text(v, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c ?? cFg)),
        Text(l, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: cMu)),
      ]);
}

/// Selector de hijo (chips de color). [todos] agrega la opción "Todos".
class SelectorHijo extends StatelessWidget {
  final String? sel;
  final ValueChanged<String?> onSel;
  final bool todos;
  const SelectorHijo({super.key, required this.sel, required this.onSel, this.todos = false});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    return SizedBox(
      height: 44,
      child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
        if (todos) Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('Todos'), selected: sel == null, onSelected: (_) => onSel(null), showCheckmark: false)),
        for (final h in s.f.hijos)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: CircleAvatar(backgroundColor: kc(h).c, radius: 6),
              label: Text(primerNombre(h.nombre)),
              selected: sel == h.id,
              selectedColor: kc(h).t,
              side: BorderSide(color: sel == h.id ? kc(h).c : cLine),
              showCheckmark: false,
              onSelected: (_) => onSel(h.id),
            ),
          ),
      ]),
    );
  }
}

void aviso(BuildContext c, String t) => ScaffoldMessenger.of(c)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(t), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 2)));

Future<bool> confirmar(BuildContext c, String titulo, String txt, {String si = 'Sí', bool peligro = false}) async =>
    await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(title: Text(titulo), content: Text(txt), actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')),
        FilledButton(style: peligro ? FilledButton.styleFrom(backgroundColor: cLoss) : null, onPressed: () => Navigator.pop(d, true), child: Text(si)),
      ]),
    ) ??
    false;

/// Cancha dibujada (horizontal: portería propia a la izquierda).
class CanchaPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(12));
    c.drawRRect(r, Paint()..color = const Color(0xFF2E9E5B));
    final l = Paint()..color = Colors.white.withValues(alpha: .7)..style = PaintingStyle.stroke..strokeWidth = 1.5;
    c.drawRRect(r.deflate(6), l);
    c.drawLine(Offset(s.width / 2, 6), Offset(s.width / 2, s.height - 6), l);
    c.drawCircle(Offset(s.width / 2, s.height / 2), s.height * .16, l);
    final aw = s.width * .14, ah = s.height * .5;
    c.drawRect(Rect.fromLTWH(6, (s.height - ah) / 2, aw, ah), l);
    c.drawRect(Rect.fromLTWH(s.width - 6 - aw, (s.height - ah) / 2, aw, ah), l);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
