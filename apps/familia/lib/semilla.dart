// Familia de ejemplo: Mateo y Leo (gemelos, mismo equipo) y Sofía (otro equipo).
import 'modelo.dart';
import 'util.dart';

Familia familiaDeEjemplo() {
  final r = Semilla(2026);
  final hoy = soloDia(DateTime.now());
  DateTime at(int dias, int h, [int m = 0]) { final d = hoy.add(Duration(days: dias)); return DateTime(d.year, d.month, d.day, h, m); }
  final sab = -(((diaSemana(hoy) + 1) % 7) == 0 ? 7 : (diaSemana(hoy) + 1) % 7);
  final dom = -(diaSemana(hoy) == 0 ? 7 : diaSemana(hoy));

  final equipos = [
    Equipo(id: 't1', nombre: 'Tigres FC', liga: 'Liga Infantil Municipal', modalidad: 'F7', dur: 25, entreno: Entreno(dias: [2, 4], ini: '18:00', fin: '19:30', lugar: 'Cancha Tigres · Col. Las Flores')),
    Equipo(id: 't2', nombre: 'Águilas', liga: 'Liga Femenil Infantil', modalidad: 'F7', dur: 20, entreno: Entreno(dias: [3], ini: '17:00', fin: '18:30', lugar: 'Campo Las Palmas')),
  ];
  final hijos = [
    Hijo(id: 'k1', nombre: 'Mateo Ruiz', nac: DateTime(2016, 3, 14), numero: 9, zona: 'DEL', zona2: 'EXTD', cat: '9-11', nivel: 'Competitivo', equipoId: 't1', color: 0, plan: Plan(estado: 'premium', pruebaUsada: true)),
    Hijo(id: 'k2', nombre: 'Sofía Ruiz', nac: DateTime(2018, 6, 2), pie: 'Izquierdo', numero: 1, zona: 'POR', cat: 'Sub-9', nivel: 'Recreativo', equipoId: 't2', color: 1),
    Hijo(id: 'k3', nombre: 'Leo Ruiz', nac: DateTime(2016, 3, 14), numero: 4, zona: 'CEN', zona2: 'LATD', cat: '9-11', nivel: 'Competitivo', equipoId: 't1', color: 2, plan: Plan(estado: 'prueba', pruebaUsada: true, pruebaFin: at(5, 23, 59))),
  ];
  List<List<double>> segsDe(int m, int dur) {
    if (m >= 2 * dur) return [[0, 2.0 * dur]];
    final a = (m * .55).round().clamp(0, dur), b = m - a;
    return [if (a > 0) [0, a.toDouble()], if (b > 0) [2.0 * dur - b, 2.0 * dur]];
  }

  const rivT = ['Halcones', 'Pumitas', 'Real Sur', 'Atlético Lomas', 'Deportivo Mar', 'Leones', 'Unión Norte', 'Halcones', 'Pumitas', 'Real Sur', 'Atlético Lomas', 'Deportivo Mar'];
  const rivA = ['Halconcitas', 'Estrellas', 'Gacelas', 'Panteras', 'Halconcitas', 'Estrellas', 'Gacelas', 'Panteras'];
  const minM = [30, 25, 42, 18, 35, 40, 22, 38, 45, 50, 36, 38], minL = [20, 30, 25, 35, 28, 40, 25, 30, 22, 35, 29, 33];
  const golesM = [1, 0, 2, 0, 1, 1, 0, 2, 1, 0, 1, 2];
  final partidos = <Partido>[];
  for (var i = 0; i < 12; i++) {
    final stM = <String, int>{'gol': golesM[i], 'asist': i % 4 == 1 ? 1 : 0, 'tdesv': r.entre(0, 2), 'frec': r.entre(0, 2), 'offside': r.next() > .7 ? 1 : 0};
    stM['tpuerta'] = golesM[i] + r.entre(0, 2);
    final stL = <String, int>{'recup': r.entre(2, 6), 'despeje': r.entre(1, 4), 'duelo': r.entre(1, 4), 'bloqueo': r.entre(0, 2), 'gol': i == 6 ? 1 : 0, 'fcom': r.entre(0, 2)};
    stM.removeWhere((_, v) => v == 0); stL.removeWhere((_, v) => v == 0);
    partidos.add(Partido(id: 'pt${i + 1}', equipoId: 't1', rival: rivT[i], fecha: at(sab - 7 * (11 - i), i % 3 == 0 ? 9 : 10), lugar: i.isOdd ? 'Unidad Deportiva Sur' : 'Cancha Tigres',
        comp: i == 9 ? 'Copa Primavera' : 'Liga', local: i.isEven, estado: 'FINALIZADO', gf: (stM['gol'] ?? 0) + (stL['gol'] ?? 0) + r.entre(0, 2), gc: r.entre(0, 3),
        part: {'k1': Participacion(titular: minM[i] >= 25 || i.isEven, segs: segsDe(minM[i], 25), st: stM), 'k3': Participacion(titular: minL[i] >= 25, segs: segsDe(minL[i], 25), st: stL)}));
  }
  partidos[11].notas.addAll([
    Nota(id: 'n1', autor: 'Ana', hora: '11:20', kid: 'k1', txt: 'El segundo gol fue de cabeza, primera vez que lo intenta.'),
    Nota(id: 'n2', autor: 'Luis', hora: '11:42', kid: 'k1', txt: 'El entrenador lo puso de extremo en el segundo tiempo.'),
  ]);
  for (var i = 0; i < 8; i++) {
    final rec = r.entre(0, 3);
    final st = <String, int>{'atajada': r.entre(3, 7), 'grec': rec, 'salida': r.entre(0, 3), 'despeje': r.entre(1, 3), 'penal': r.next() > .85 ? 1 : 0, 'saque': r.entre(1, 4)}..removeWhere((_, v) => v == 0);
    partidos.add(Partido(id: 'pa${i + 1}', equipoId: 't2', rival: rivA[i], fecha: at(dom - 7 * (7 - i), 12, 30), lugar: 'Campo Las Palmas', local: i.isOdd, estado: 'FINALIZADO', gf: r.entre(0, 3), gc: rec,
        part: {'k2': Participacion(segs: i == 3 ? [[0, 20]] : [[0, 40]], st: st)}));
  }
  partidos.addAll([
    Partido(id: 'pf1', equipoId: 't1', rival: 'Pumitas', fecha: at(1, 9), lugar: 'Unidad Deportiva Sur'),
    Partido(id: 'pf2', equipoId: 't2', rival: 'Halconcitas', fecha: at(1, 12, 30), lugar: 'Campo Las Palmas', local: false),
    Partido(id: 'pf3', equipoId: 't2', rival: 'Estrellas', fecha: at(6, 11), lugar: 'Campo Las Palmas'),
    Partido(id: 'pf4', equipoId: 't1', rival: 'Real Sur', fecha: at(7, 10), lugar: 'Campo Real Sur', local: false),
  ]);
  final asis = <String, bool>{};
  for (var d = -42; d < 0; d++) {
    final f = hoy.add(Duration(days: d));
    for (final t in equipos) {
      if (!t.entreno.dias.contains(diaSemana(f))) continue;
      for (final h in hijos.where((h) => h.equipoId == t.id)) { asis['${h.id}|${dkey(f)}'] = r.next() < .87; }
    }
  }
  return Familia(
    papas: [Papa(id: 'p1', nombre: 'Ana López', rel: 'Mamá', yo: true), Papa(id: 'p2', nombre: 'Luis Ruiz', rel: 'Papá')],
    hijos: hijos, equipos: equipos, partidos: partidos, asis: asis, tempIni: hoy.subtract(const Duration(days: 100)), tempFin: hoy.add(const Duration(days: 70)),
  );
}

Familia familiaVacia() {
  final hoy = soloDia(DateTime.now());
  return Familia(papas: [Papa(id: 'p1', nombre: 'Tú', rel: 'Mamá o papá', yo: true)], hijos: [], equipos: [], partidos: [], asis: {}, tempIni: hoy.subtract(const Duration(days: 30)), tempFin: hoy.add(const Duration(days: 180)));
}
