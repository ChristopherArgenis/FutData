// Modelo de datos de FutData Familia y su conversión a JSON (se guarda en SQLite).
import 'util.dart';

enum Pos { por, def, med, del }

const posNombre = {Pos.por: 'Portero', Pos.def: 'Defensa', Pos.med: 'Medio', Pos.del: 'Delantero'};

class Zona {
  final String k, l;
  final Pos g;
  final double x, y;
  const Zona(this.k, this.l, this.g, this.x, this.y);
}

const zonas = [
  Zona('POR', 'Portero', Pos.por, .09, .50), Zona('LATI', 'Lateral', Pos.def, .27, .20), Zona('CEN', 'Central', Pos.def, .25, .50),
  Zona('LATD', 'Lateral', Pos.def, .27, .80), Zona('MED', 'Medio', Pos.med, .50, .50), Zona('EXTI', 'Extremo', Pos.del, .68, .20),
  Zona('DEL', 'Delantero', Pos.del, .84, .50), Zona('EXTD', 'Extremo', Pos.del, .68, .80),
];
Zona? zona(String? k) => zonas.where((z) => z.k == k).firstOrNull;
Zona? _zonaPorClave(String? k) => zona(k);

class StatDef {
  final String k, n, tipo; // tipo: '', 'main', 'neg'
  const StatDef(this.k, this.n, [this.tipo = '']);
}

const stats = {
  Pos.del: [StatDef('gol', '⚽ Gol', 'main'), StatDef('asist', 'Asistencia'), StatDef('tpuerta', 'Tiro a puerta'), StatDef('tdesv', 'Tiro desviado'), StatDef('frec', 'Falta recibida'), StatDef('offside', 'Fuera de lugar', 'neg')],
  Pos.med: [StatDef('pclave', 'Pase clave', 'main'), StatDef('recup', 'Recuperación'), StatDef('asist', 'Asistencia'), StatDef('gol', '⚽ Gol'), StatDef('tpuerta', 'Tiro a puerta'), StatDef('perdida', 'Balón perdido', 'neg')],
  Pos.def: [StatDef('recup', 'Recuperación', 'main'), StatDef('despeje', 'Despeje'), StatDef('duelo', 'Duelo ganado'), StatDef('bloqueo', 'Bloqueo'), StatDef('gol', '⚽ Gol'), StatDef('fcom', 'Falta cometida', 'neg')],
  Pos.por: [StatDef('atajada', '🧤 Atajada', 'main'), StatDef('grec', 'Gol recibido', 'neg'), StatDef('salida', 'Salida / achique'), StatDef('despeje', 'Despeje'), StatDef('penal', 'Penal atajado'), StatDef('saque', 'Saque a compañero')],
};
const mainStat = {Pos.del: 'gol', Pos.med: 'pclave', Pos.def: 'recup', Pos.por: 'atajada'};
String nombreStat(String k) {
  if (k == 'amarilla') return 'Amarilla';
  if (k == 'roja') return 'Roja';
  for (final l in stats.values) {
    for (final s in l) {
      if (s.k == k) return s.n.replaceAll(RegExp(r'^[^\wÁ-úñÑ]+\s*'), '');
    }
  }
  return k;
}

const categorias = ['Sub-7', 'Sub-9', 'Sub-11', 'Sub-13', 'Sub-15', 'Sub-17'];
const niveles = ['Recreativo', 'Competitivo', 'Selectivo', 'Escuela'];
const modalidades = {'F7': 'Fútbol 7', 'F9': 'Fútbol 9', 'F11': 'Fútbol 11'};
String? categoriaSugerida(int? edad) => edad == null ? null : categorias.firstWhere((c) => int.parse(c.substring(4)) > edad, orElse: () => 'Sub-17');

class Entreno {
  List<int> dias; // 0 = domingo … 6 = sábado
  String ini, fin, lugar, aviso;
  String? hasta; // null = fin de temporada; si no, 'AAAA-MM-DD'
  Entreno({List<int>? dias, this.ini = '18:00', this.fin = '19:30', this.lugar = '', this.aviso = '1h', this.hasta}) : dias = dias ?? [];
  Map<String, dynamic> toJson() => {'dias': dias, 'ini': ini, 'fin': fin, 'lugar': lugar, 'aviso': aviso, 'hasta': hasta};
  factory Entreno.fromJson(Map<String, dynamic> j) => Entreno(dias: (j['dias'] as List).cast<int>(), ini: j['ini'], fin: j['fin'], lugar: j['lugar'] ?? '', aviso: j['aviso'] ?? '1h', hasta: j['hasta']);
}

class Equipo {
  String id, nombre, liga, modalidad;
  int dur; // minutos por tiempo
  Entreno entreno;
  Equipo({required this.id, required this.nombre, this.liga = '', this.modalidad = 'F7', this.dur = 25, Entreno? entreno}) : entreno = entreno ?? Entreno();
  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'liga': liga, 'modalidad': modalidad, 'dur': dur, 'entreno': entreno.toJson()};
  factory Equipo.fromJson(Map<String, dynamic> j) => Equipo(id: j['id'], nombre: j['nombre'], liga: j['liga'] ?? '', modalidad: j['modalidad'] ?? 'F7', dur: j['dur'] ?? 25, entreno: Entreno.fromJson(j['entreno']));
}

class Plan {
  String estado; // gratis · prueba · premium
  bool pruebaUsada;
  DateTime? pruebaFin;
  Plan({this.estado = 'gratis', this.pruebaUsada = false, this.pruebaFin});
  Map<String, dynamic> toJson() => {'estado': estado, 'pruebaUsada': pruebaUsada, 'pruebaFin': pruebaFin?.toIso8601String()};
  factory Plan.fromJson(Map<String, dynamic> j) => Plan(estado: j['estado'], pruebaUsada: j['pruebaUsada'] ?? false, pruebaFin: j['pruebaFin'] == null ? null : DateTime.parse(j['pruebaFin']));
}

class Hijo {
  String id, nombre, pie, zona, cat, nivel, equipoId;
  String? zona2;
  DateTime nac;
  int numero, color;
  Plan plan;
  Hijo({required this.id, required this.nombre, required this.nac, this.pie = 'Derecho', this.numero = 0, required this.zona, this.zona2, required this.cat, this.nivel = 'Competitivo', required this.equipoId, this.color = 0, Plan? plan}) : plan = plan ?? Plan();
  Pos get pos => _zonaPorClave(zona)?.g ?? Pos.med;
  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'nac': dkey(nac), 'pie': pie, 'numero': numero, 'zona': zona, 'zona2': zona2, 'cat': cat, 'nivel': nivel, 'equipoId': equipoId, 'color': color, 'plan': plan.toJson()};
  factory Hijo.fromJson(Map<String, dynamic> j) => Hijo(id: j['id'], nombre: j['nombre'], nac: DateTime.parse(j['nac']), pie: j['pie'], numero: j['numero'], zona: j['zona'], zona2: j['zona2'], cat: j['cat'], nivel: j['nivel'], equipoId: j['equipoId'], color: j['color'], plan: Plan.fromJson(j['plan']));
}

class Participacion {
  bool jugo, titular;
  List<List<double>> segs; // tramos en la cancha, en minutos del partido [desde, hasta]
  Map<String, int> st;
  Participacion({this.jugo = true, this.titular = true, List<List<double>>? segs, Map<String, int>? st}) : segs = segs ?? [], st = st ?? {};
  double get minutos => segs.fold(0.0, (a, s) => a + (s[1] - s[0]).clamp(0, 999));
  int stat(String k) => st[k] ?? 0;
  Map<String, dynamic> toJson() => {'jugo': jugo, 'titular': titular, 'segs': segs, 'st': st};
  factory Participacion.fromJson(Map<String, dynamic> j) => Participacion(jugo: j['jugo'], titular: j['titular'], segs: (j['segs'] as List).map((s) => (s as List).map((v) => (v as num).toDouble()).toList()).toList(), st: (j['st'] as Map).map((k, v) => MapEntry(k as String, v as int)));
}

class Nota {
  String id, autor, hora, txt;
  String? kid;
  Nota({required this.id, required this.autor, required this.hora, required this.txt, this.kid});
  Map<String, dynamic> toJson() => {'id': id, 'autor': autor, 'hora': hora, 'txt': txt, 'kid': kid};
  factory Nota.fromJson(Map<String, dynamic> j) => Nota(id: j['id'], autor: j['autor'], hora: j['hora'], txt: j['txt'], kid: j['kid']);
}

class Partido {
  String id, equipoId, rival, lugar, comp, estado; // PROGRAMADO · FINALIZADO
  DateTime fecha;
  bool local;
  int? gf, gc;
  Map<String, Participacion> part;
  List<Nota> notas;
  Partido({required this.id, required this.equipoId, required this.rival, required this.fecha, this.lugar = '', this.comp = 'Liga', this.estado = 'PROGRAMADO', this.local = true, this.gf, this.gc, Map<String, Participacion>? part, List<Nota>? notas}) : part = part ?? {}, notas = notas ?? [];
  bool get finalizado => estado == 'FINALIZADO';
  String get resultado => (gf ?? 0) > (gc ?? 0) ? 'G' : gf == gc ? 'E' : 'P';
  Map<String, dynamic> toJson() => {'id': id, 'equipoId': equipoId, 'rival': rival, 'fecha': fecha.toIso8601String(), 'lugar': lugar, 'comp': comp, 'estado': estado, 'local': local, 'gf': gf, 'gc': gc, 'part': part.map((k, v) => MapEntry(k, v.toJson())), 'notas': notas.map((n) => n.toJson()).toList()};
  factory Partido.fromJson(Map<String, dynamic> j) => Partido(id: j['id'], equipoId: j['equipoId'], rival: j['rival'], fecha: DateTime.parse(j['fecha']), lugar: j['lugar'] ?? '', comp: j['comp'] ?? 'Liga', estado: j['estado'], local: j['local'] ?? true, gf: j['gf'], gc: j['gc'],
      part: (j['part'] as Map).map((k, v) => MapEntry(k as String, Participacion.fromJson(v))), notas: (j['notas'] as List).map((n) => Nota.fromJson(n)).toList());
}

class Papa {
  String id, nombre, rel, estado; // activo · por_aprobar
  bool yo;
  Papa({required this.id, required this.nombre, required this.rel, this.yo = false, this.estado = 'activo'});
  Map<String, dynamic> toJson() => {'id': id, 'nombre': nombre, 'rel': rel, 'yo': yo, 'estado': estado};
  factory Papa.fromJson(Map<String, dynamic> j) => Papa(id: j['id'], nombre: j['nombre'], rel: j['rel'], yo: j['yo'] ?? false, estado: j['estado'] ?? 'activo');
}

class KidLive {
  bool va, on;
  double? desde;
  KidLive({this.va = true, this.on = true, this.desde});
  Map<String, dynamic> toJson() => {'va': va, 'on': on, 'desde': desde};
  factory KidLive.fromJson(Map<String, dynamic> j) => KidLive(va: j['va'], on: j['on'], desde: (j['desde'] as num?)?.toDouble());
}

class Deshacer {
  String? kid, s, team;
  String txt;
  bool asistencia;
  Deshacer({this.kid, this.s, this.team, required this.txt, this.asistencia = false});
  Map<String, dynamic> toJson() => {'kid': kid, 's': s, 'team': team, 'txt': txt, 'asistencia': asistencia};
  factory Deshacer.fromJson(Map<String, dynamic> j) => Deshacer(kid: j['kid'], s: j['s'], team: j['team'], txt: j['txt'], asistencia: j['asistencia'] ?? false);
}

/// Partido en vivo. El reloj se calcula con la hora del teléfono, así sigue corriendo aunque se cierre la app.
class Live {
  String pid;
  int per; // 1 = primer tiempo, 0 = medio tiempo, 2 = segundo tiempo
  double seg; // segundos acumulados del tiempo en curso
  bool run, started;
  int? t0; // milisegundos (epoch) cuando se reanudó
  int vel; // 1 = tiempo real; 60 = modo prueba (1 s = 1 min)
  Map<String, KidLive> k;
  String? sel;
  List<Deshacer> undo;
  Live({required this.pid, this.per = 1, this.seg = 0, this.run = false, this.started = false, this.t0, this.vel = 1, required this.k, this.sel, List<Deshacer>? undo}) : undo = undo ?? [];
  Map<String, dynamic> toJson() => {'pid': pid, 'per': per, 'seg': seg, 'run': run, 'started': started, 't0': t0, 'vel': vel, 'k': k.map((a, b) => MapEntry(a, b.toJson())), 'sel': sel, 'undo': undo.map((u) => u.toJson()).toList()};
  factory Live.fromJson(Map<String, dynamic> j) => Live(pid: j['pid'], per: j['per'], seg: (j['seg'] as num).toDouble(), run: j['run'], started: j['started'], t0: j['t0'], vel: j['vel'], k: (j['k'] as Map).map((a, b) => MapEntry(a as String, KidLive.fromJson(b))), sel: j['sel'], undo: (j['undo'] as List).map((u) => Deshacer.fromJson(u)).toList());
}

class Legal {
  String version;
  DateTime fecha;
  bool novedades;
  Legal({required this.version, required this.fecha, this.novedades = false});
  Map<String, dynamic> toJson() => {'version': version, 'fecha': fecha.toIso8601String(), 'novedades': novedades};
  factory Legal.fromJson(Map<String, dynamic> j) => Legal(version: j['version'], fecha: DateTime.parse(j['fecha']), novedades: j['novedades'] ?? false);
}

class Familia {
  List<Papa> papas;
  List<Hijo> hijos;
  List<Equipo> equipos;
  List<Partido> partidos;
  Map<String, bool> asis; // 'hijoId|AAAA-MM-DD' -> fue a entrenar
  DateTime tempIni, tempFin;
  Live? live;
  String? invitCodigo;
  DateTime? invitExpira;
  Legal? legal;
  Familia({required this.papas, required this.hijos, required this.equipos, required this.partidos, required this.asis, required this.tempIni, required this.tempFin, this.live, this.invitCodigo, this.invitExpira, this.legal});
  Map<String, dynamic> toJson() => {
        'v': 1, 'papas': papas.map((p) => p.toJson()).toList(), 'hijos': hijos.map((h) => h.toJson()).toList(), 'equipos': equipos.map((e) => e.toJson()).toList(),
        'partidos': partidos.map((p) => p.toJson()).toList(), 'asis': asis, 'tempIni': dkey(tempIni), 'tempFin': dkey(tempFin), 'live': live?.toJson(),
        'invitCodigo': invitCodigo, 'invitExpira': invitExpira?.toIso8601String(), 'legal': legal?.toJson(),
      };
  factory Familia.fromJson(Map<String, dynamic> j) => Familia(
        papas: (j['papas'] as List).map((p) => Papa.fromJson(p)).toList(), hijos: (j['hijos'] as List).map((h) => Hijo.fromJson(h)).toList(),
        equipos: (j['equipos'] as List).map((e) => Equipo.fromJson(e)).toList(), partidos: (j['partidos'] as List).map((p) => Partido.fromJson(p)).toList(),
        asis: (j['asis'] as Map).map((k, v) => MapEntry(k as String, v as bool)), tempIni: DateTime.parse(j['tempIni']), tempFin: DateTime.parse(j['tempFin']),
        live: j['live'] == null ? null : Live.fromJson(j['live']), invitCodigo: j['invitCodigo'], invitExpira: j['invitExpira'] == null ? null : DateTime.parse(j['invitExpira']),
        legal: j['legal'] == null ? null : Legal.fromJson(j['legal']),
      );
}
