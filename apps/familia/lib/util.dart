// Utilidades de fechas y texto (español de México).
import 'dart:math';

const diasCortos = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
const diasLargos = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado'];
const diasLetra = ['D', 'L', 'M', 'M', 'J', 'V', 'S'];
const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
const mesesLargos = ['Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio', 'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'];

/// Índice 0 = domingo … 6 = sábado (como en JavaScript).
int diaSemana(DateTime d) => d.weekday % 7;
String dos(int n) => n.toString().padLeft(2, '0');
String fFecha(DateTime d) => '${diasCortos[diaSemana(d)]} ${d.day} ${meses[d.month - 1]}';
String fHora(DateTime d) => '${dos(d.hour)}:${dos(d.minute)}';
String dkey(DateTime d) => '${d.year}-${dos(d.month)}-${dos(d.day)}';
DateTime soloDia(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime parseDia(String k) => DateTime.parse(k);
String mmss(double segundos) { final s = segundos.isFinite ? segundos.floor() : 0; return '${dos(s ~/ 60)}:${dos(s % 60)}'; }

int? edadDe(DateTime? nac) {
  if (nac == null) return null;
  final h = DateTime.now();
  var e = h.year - nac.year;
  if (h.month < nac.month || (h.month == nac.month && h.day < nac.day)) e--;
  return e;
}

String iniciales(String n) {
  final p = n.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).take(2).map((w) => w[0].toUpperCase()).join();
  return p.isEmpty ? '?' : p;
}

String primerNombre(String n) => n.trim().split(RegExp(r'\s+')).first;
String limpio(String? v, [int max = 60]) { final t = (v ?? '').replaceAll(RegExp(r'\s+'), ' ').trim(); return t.length > max ? t.substring(0, max) : t; }
double promedio(Iterable<num> xs) => xs.isEmpty ? 0 : xs.fold<double>(0, (a, b) => a + b) / xs.length;
int pct(num a, num b) => b == 0 ? 0 : (100 * a / b).round();

final _rnd = Random.secure();
int _seq = 0;
String nuevoId(String p) => '$p${(++_seq).toRadixString(36)}${_rnd.nextInt(1 << 30).toRadixString(36)}';

/// Código de invitación de un solo uso, sin letras que se confunden (0/O, 1/I/L).
String codigoInvitacion() {
  const alfa = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  final c = List.generate(10, (_) => alfa[_rnd.nextInt(alfa.length)]).join();
  return 'FUT-${c.substring(0, 5)}-${c.substring(5)}';
}

/// Generador pseudoaleatorio con semilla (datos de ejemplo reproducibles).
class Semilla {
  int _s;
  Semilla(this._s);
  double next() { _s = (_s * 16807) % 2147483647; return _s / 2147483647; }
  int entre(int a, int b) => a + (next() * (b - a)).round();
}
