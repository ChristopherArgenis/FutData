// Estado de la app: consultas, cambios y guardado local en SQLite.
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'modelo.dart';
import 'semilla.dart';
import 'util.dart';

const versionLegal = '1.0';
const maxHijos = 4, precioPremium = 100, diasPrueba = 7;

/// Dónde se guarda la familia. En el teléfono: SQLite. En pruebas: memoria.
abstract class Persistencia {
  Future<String?> leer();
  Future<void> guardar(String json);
  Future<void> borrar();
}

class PersistenciaSqlite implements Persistencia {
  Database? _db;
  Future<Database> _abrir() async => _db ??= await openDatabase(p.join(await getDatabasesPath(), 'futdata_familia.db'), version: 1,
      onCreate: (db, _) => db.execute('CREATE TABLE estado (id INTEGER PRIMARY KEY CHECK (id = 1), json TEXT NOT NULL, actualizado TEXT NOT NULL)'));
  @override
  Future<String?> leer() async { final r = await (await _abrir()).query('estado', where: 'id = 1'); return r.isEmpty ? null : r.first['json'] as String; }
  @override
  Future<void> guardar(String json) async => (await _abrir()).insert('estado', {'id': 1, 'json': json, 'actualizado': DateTime.now().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
  @override
  Future<void> borrar() async => (await _abrir()).delete('estado');
}

class PersistenciaMemoria implements Persistencia {
  String? dato;
  @override
  Future<String?> leer() async => dato;
  @override
  Future<void> guardar(String json) async => dato = json;
  @override
  Future<void> borrar() async => dato = null;
}

class Estado extends ChangeNotifier {
  final Persistencia almacen;
  Familia f = familiaVacia();
  bool cargado = false;
  String? kidSel;
  Timer? _guardado;
  Estado(this.almacen);

  Future<void> cargar() async {
    try {
      final j = await almacen.leer();
      if (j != null) f = Familia.fromJson(jsonDecode(j));
    } catch (_) { f = familiaVacia(); }
    kidSel = f.hijos.firstOrNull?.id;
    cargado = true;
    notifyListeners();
  }

  /// Notifica a la interfaz y guarda (agrupando cambios seguidos).
  void cambio() {
    if (kidSel != null && hijo(kidSel!) == null) kidSel = f.hijos.firstOrNull?.id;
    kidSel ??= f.hijos.firstOrNull?.id;
    notifyListeners();
    _guardado?.cancel();
    _guardado = Timer(const Duration(milliseconds: 300), guardarYa);
  }

  Future<void> guardarYa() async { _guardado?.cancel(); await almacen.guardar(jsonEncode(f.toJson())); }

  // ---------- consultas ----------
  Hijo? hijo(String id) => f.hijos.where((h) => h.id == id).firstOrNull;
  Equipo? equipo(String id) => f.equipos.where((t) => t.id == id).firstOrNull;
  Partido? partido(String id) => f.partidos.where((x) => x.id == id).firstOrNull;
  Papa get yo => f.papas.firstWhere((x) => x.yo, orElse: () => f.papas.first);
  List<Hijo> hijosDe(String equipoId) => f.hijos.where((h) => h.equipoId == equipoId).toList();
  List<Hijo> hermanos(Hijo h) => f.hijos.where((x) => x.id != h.id && x.equipoId == h.equipoId).toList();
  List<Partido> get ordenados => [...f.partidos]..sort((a, b) => a.fecha.compareTo(b.fecha));
  List<String> kidsDe(Partido x) => x.part.isNotEmpty ? x.part.keys.where((k) => hijo(k) != null).toList() : hijosDe(x.equipoId).map((h) => h.id).toList();
  int durTotal(Partido x) => 2 * (equipo(x.equipoId)?.dur ?? 25);
  List<Partido> finDe(String kid) => ordenados.where((x) => x.finalizado && x.part.containsKey(kid)).toList();
  List<Partido> jugadosDe(String kid) => finDe(kid).where((x) => x.part[kid]!.jugo).toList();
  double minutosEn(Partido x, String kid) => x.part[kid]?.minutos ?? 0;
  Partido? proxDe(String kid) {
    final h = hijo(kid); if (h == null) return null;
    final hoy = soloDia(DateTime.now());
    final prog = ordenados.where((x) => !x.finalizado && x.equipoId == h.equipoId);
    return prog.where((x) => !soloDia(x.fecha).isBefore(hoy)).firstOrNull ?? prog.firstOrNull;
  }
  bool tieneAnalisis(Hijo h) => h.plan.estado == 'premium' || (h.plan.estado == 'prueba' && h.plan.pruebaFin != null && h.plan.pruebaFin!.isAfter(DateTime.now()));

  // ---------- términos ----------
  void aceptar({required bool ejemplo, required bool novedades}) {
    f = ejemplo ? familiaDeEjemplo() : familiaVacia();
    f.legal = Legal(version: versionLegal, fecha: DateTime.now(), novedades: novedades);
    kidSel = f.hijos.firstOrNull?.id;
    cambio();
  }
  void reiniciarEjemplo() { final lg = f.legal; f = familiaDeEjemplo()..legal = lg; kidSel = f.hijos.firstOrNull?.id; cambio(); }
  void empezarDeCero() { final lg = f.legal; f = familiaVacia()..legal = lg; kidSel = null; cambio(); }
  Future<void> borrarCuenta() async { await almacen.borrar(); f = familiaVacia(); kidSel = null; notifyListeners(); }

  // ---------- partidos ----------
  void guardarPartido(Partido x) { if (partido(x.id) == null) f.partidos.add(x); cambio(); }
  void borrarPartido(String id) { f.partidos.removeWhere((x) => x.id == id); cambio(); }
  void agregarNota(Partido x, String txt, String? kid) {
    final a = DateTime.now();
    x.notas.add(Nota(id: nuevoId('n'), autor: yo.nombre == 'Tú' ? 'Tú' : primerNombre(yo.nombre), hora: '${dos(a.hour)}:${dos(a.minute)}', txt: limpio(txt, 300), kid: kid));
    cambio();
  }
  void marcarAsistencia(String kid, String dia, bool fue) { final k = '$kid|$dia'; if (f.asis[k] == fue) { f.asis.remove(k); } else { f.asis[k] = fue; } cambio(); }

  // ---------- en vivo ----------
  Live? get live => f.live;
  int get durLive => equipo(partido(f.live!.pid)!.equipoId)!.dur;
  double segLive() { final l = f.live!; return l.seg + (l.run && l.t0 != null ? (DateTime.now().millisecondsSinceEpoch - l.t0!) / 1000 * l.vel : 0); }
  double absMin() { final l = f.live!, d = durLive; if (l.per == 0) return d.toDouble(); return (l.per - 1) * d + (segLive() / 60).clamp(0, d + 15.0); }
  double minKid(String kid) { final l = f.live!, k = l.k[kid]!, x = partido(l.pid)!; return minutosEn(x, kid) + (k.on && k.desde != null ? (absMin() - k.desde!).clamp(0, 999) : 0); }
  String minTxt() { final d = durLive, a = absMin(); return f.live!.per == 2 || a > d ? '2T ${(a - d).ceil().clamp(0, 99)}\'' : '1T ${a.ceil()}\''; }

  void iniciarLive(Partido x, Map<String, KidLive> k, int vel) {
    x.part = {for (final e in k.entries) e.key: Participacion(jugo: e.value.va, titular: e.value.on)};
    x.gf = 0; x.gc = 0;
    f.live = Live(pid: x.id, vel: vel, k: k, sel: k.entries.firstWhere((e) => e.value.va).key);
    cambio();
  }
  void _cerrar(String kid, double hasta) {
    final l = f.live!, k = l.k[kid]!, x = partido(l.pid)!;
    if (k.on && k.desde != null) { final a = k.desde!, b = hasta < a ? a : hasta; if (b > a) x.part[kid]!.segs.add([double.parse(a.toStringAsFixed(2)), double.parse(b.toStringAsFixed(2))]); k.desde = null; }
  }
  void liveCorrer() {
    final l = f.live!;
    if (l.run) { l.seg = segLive(); l.run = false; }
    else {
      l.t0 = DateTime.now().millisecondsSinceEpoch; l.run = true;
      if (!l.started) { l.started = true; final a = absMin(); for (final k in l.k.values) { if (k.on && k.va && k.desde == null) k.desde = a; } }
    }
    cambio();
  }
  void liveMedioTiempo() { final l = f.live!, d = durLive; l.seg = segLive(); l.run = false; for (final k in l.k.keys) { _cerrar(k, absMin() < d + 15 ? absMin() : d + 15.0); } l.per = 0; cambio(); }
  void liveSegundoTiempo() { final l = f.live!, d = durLive; l.per = 2; l.seg = 0; l.t0 = DateTime.now().millisecondsSinceEpoch; l.run = true; l.started = true; for (final k in l.k.values) { if (k.on && k.va) k.desde = d.toDouble(); } cambio(); }
  void liveEntraSale(String kid) {
    final l = f.live!, k = l.k[kid]!;
    if (k.on) { if (l.per != 0) _cerrar(kid, absMin()); k.on = false; l.undo.add(Deshacer(kid: kid, txt: '${minTxt()} · salió a la banca')); }
    else { k.on = true; k.desde = (l.started && l.per != 0) ? absMin() : null; l.undo.add(Deshacer(kid: kid, txt: '${minTxt()} · entró a la cancha')); }
    cambio();
  }
  /// Suma una acción. Devuelve los hermanos en la cancha si fue gol (para preguntar la asistencia).
  List<String> liveStat(String kid, String s) {
    final l = f.live!, x = partido(l.pid)!, pt = x.part[kid]!;
    pt.st[s] = pt.stat(s) + 1;
    final team = s == 'gol' ? 'gf' : s == 'grec' ? 'gc' : null;
    if (team == 'gf') x.gf = (x.gf ?? 0) + 1;
    if (team == 'gc') x.gc = (x.gc ?? 0) + 1;
    l.undo.add(Deshacer(kid: kid, s: s, team: team, txt: '${minTxt()} · ${nombreStat(s)}'));
    cambio();
    return s == 'gol' ? l.k.entries.where((e) => e.key != kid && e.value.va && e.value.on).map((e) => e.key).toList() : [];
  }
  void liveAsistencia(String kid) { final l = f.live!, pt = partido(l.pid)!.part[kid]!; pt.st['asist'] = pt.stat('asist') + 1; l.undo.add(Deshacer(kid: kid, s: 'asist', txt: '${minTxt()} · asistencia', asistencia: true)); cambio(); }
  void liveEquipo(bool nuestro) {
    final l = f.live!, x = partido(l.pid)!;
    final u = Deshacer(team: nuestro ? 'gf' : 'gc', txt: '${minTxt()} · ${nuestro ? 'gol de un compañero' : 'gol del rival'}');
    if (nuestro) { x.gf = (x.gf ?? 0) + 1; } else {
      x.gc = (x.gc ?? 0) + 1;
      final por = l.k.entries.where((e) => e.value.on && e.value.va && hijo(e.key)?.pos == Pos.por).firstOrNull?.key;
      if (por != null) { final pt = x.part[por]!; pt.st['grec'] = pt.stat('grec') + 1; u.kid = por; u.s = 'grec'; }
    }
    l.undo.add(u); cambio();
  }
  /// Deshace la última acción. Devuelve falso si no había nada o si era una entrada/salida.
  bool liveDeshacer() {
    final l = f.live!; if (l.undo.isEmpty) return false;
    final x = partido(l.pid)!, u = l.undo.removeLast();
    void restar(String kid, String s) { final pt = x.part[kid]!; final v = pt.stat(s) - 1; if (v > 0) { pt.st[s] = v; } else { pt.st.remove(s); } }
    if (u.s != null && u.kid != null) restar(u.kid!, u.s!);
    if (u.team == 'gf') x.gf = ((x.gf ?? 0) - 1).clamp(0, 99);
    if (u.team == 'gc') x.gc = ((x.gc ?? 0) - 1).clamp(0, 99);
    if (u.asistencia && l.undo.isNotEmpty && l.undo.last.s == 'gol') { final g = l.undo.removeLast(); restar(g.kid!, 'gol'); x.gf = ((x.gf ?? 0) - 1).clamp(0, 99); }
    cambio();
    return u.s != null || u.team != null;
  }
  void liveDescartar() { final x = partido(f.live!.pid)!; x.part = {}; x.gf = null; x.gc = null; f.live = null; cambio(); }
  String liveTerminar() {
    final l = f.live!, x = partido(l.pid)!, d = durLive;
    if (l.per != 0) { for (final k in l.k.keys) { _cerrar(k, absMin() < 2 * d ? absMin() : 2.0 * d); } }
    for (final e in l.k.entries) {
      final pt = x.part[e.key]!;
      pt.segs = pt.segs.map((s) => [s[0].roundToDouble(), s[1].roundToDouble()]).where((s) => s[1] > s[0]).toList();
      pt.jugo = e.value.va && (pt.segs.isNotEmpty || pt.st.values.any((v) => v > 0));
    }
    x.estado = 'FINALIZADO'; f.live = null; cambio();
    return x.id;
  }

  // ---------- hijos, equipos y papás ----------
  int colorLibre() { final usados = f.hijos.map((h) => h.color).toSet(); return [0, 1, 2, 3].firstWhere((c) => !usados.contains(c), orElse: () => 0); }
  void limpiarEquipo(String equipoId) { if (hijosDe(equipoId).isEmpty) { f.equipos.removeWhere((t) => t.id == equipoId); f.partidos.removeWhere((x) => x.equipoId == equipoId); } }
  void quitarHijo(String kid) {
    final h = hijo(kid)!, t = h.equipoId;
    f.hijos.remove(h);
    for (final x in f.partidos) { x.part.remove(kid); }
    f.asis.removeWhere((k, _) => k.startsWith('$kid|'));
    limpiarEquipo(t);
    cambio();
  }
  void plan(Hijo h, String accion) {
    if (accion == 'prueba' && !h.plan.pruebaUsada) { h.plan = Plan(estado: 'prueba', pruebaUsada: true, pruebaFin: DateTime.now().add(const Duration(days: diasPrueba))); }
    if (accion == 'suscribir') h.plan.estado = 'premium';
    if (accion == 'cancelar') h.plan.estado = 'gratis';
    cambio();
  }
  bool invitar() { if (f.papas.length >= 2) return false; f.invitCodigo = codigoInvitacion(); f.invitExpira = DateTime.now().add(const Duration(days: 3)); cambio(); return true; }
}
