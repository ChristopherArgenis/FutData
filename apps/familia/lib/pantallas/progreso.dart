import 'package:material_ui/material_ui.dart';

import '../estado.dart';
import '../modelo.dart';
import '../tema.dart';
import '../util.dart';
import 'inicio.dart';

class Progreso extends StatelessWidget {
  const Progreso({super.key});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    if (s.f.hijos.isEmpty) return const Center(child: Text('Agrega a un hijo para ver su progreso.', style: TextStyle(color: cMu)));
    final h = s.hijo(s.kidSel ?? '') ?? s.f.hijos.first;
    final fin = s.finDe(h.id), jug = s.jugadosDe(h.id);
    final mins = jug.fold<double>(0, (a, x) => a + s.minutosEn(x, h.id));
    final posibles = fin.fold<int>(0, (a, x) => a + s.durTotal(x));
    final main = mainStat[h.pos]!;
    final totMain = jug.fold<int>(0, (a, x) => a + x.part[h.id]!.stat(main));
    final asis = s.f.asis.entries.where((e) => e.key.startsWith('${h.id}|')).toList();
    final fue = asis.where((e) => e.value).length;
    final g = fin.where((x) => x.resultado == 'G').length, e = fin.where((x) => x.resultado == 'E').length;
    final mejor = jug.isEmpty ? null : jug.reduce((a, b) => s.minutosEn(a, h.id) >= s.minutosEn(b, h.id) ? a : b);

    return ListView(padding: const EdgeInsets.fromLTRB(0, 12, 0, 24), children: [
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Progreso', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
      const SizedBox(height: 8),
      SelectorHijo(sel: h.id, onSel: (v) { s.kidSel = v; s.cambio(); }),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SizedBox(height: 12),
          Tarjeta(child: Row(children: [
            Avatar(h, size: 48),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(h.nombre, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              Text('${zona(h.zona)?.l ?? ''} · #${h.numero} · ${h.cat} · ${s.equipo(h.equipoId)?.nombre ?? ''}', style: const TextStyle(color: cMu, fontSize: 13)),
            ])),
            if (s.tieneAnalisis(h)) Pastilla(h.plan.estado == 'premium' ? 'Premium' : 'Prueba', c: const Color(0xFF8A5A00), fondo: cGoldSoft),
          ])),
          const Seccion('Temporada'),
          Tarjeta(child: Column(children: [
            Row(children: [
              Expanded(child: Dato('${jug.length}', 'Partidos\njugados')),
              Expanded(child: Dato("${mins.round()}'", 'Minutos\njugados')),
              Expanded(child: Dato('$totMain', '${nombreStat(main)}${totMain == 1 ? '' : 's'}', c: kc(h).d)),
            ]),
            const Divider(height: 24),
            Row(children: [
              Expanded(child: Dato('${pct(mins, posibles)}%', 'De los minutos\nposibles')),
              Expanded(child: Dato('$g-$e-${fin.length - g - e}', 'Equipo\nG-E-P')),
              Expanded(child: Dato(asis.isEmpty ? '—' : '${pct(fue, asis.length)}%', 'Asistencia\na entrenos')),
            ]),
          ])),
          if (mejor != null) ...[
            const Seccion('Logros'),
            Tarjeta(child: Column(children: [
              _logro('⏱️', "Más minutos en un partido: ${s.minutosEn(mejor, h.id).round()}'", 'vs ${mejor.rival} · ${fFecha(mejor.fecha)}'),
              _logro('🔥', 'Racha actual: ${_racha(s, h)} partidos seguidos jugando', 'Cuenta los partidos en los que entró a la cancha'),
              if (totMain > 0) _logro('⭐', '$totMain ${nombreStat(main).toLowerCase()}${totMain == 1 ? '' : 's'} en la temporada', 'Su acción principal como ${posNombre[h.pos]!.toLowerCase()}'),
            ])),
          ],
          const Seccion('Últimos partidos'),
          if (fin.isEmpty) const Text('Todavía no hay partidos terminados.', style: TextStyle(color: cMu)),
          for (final x in fin.reversed.take(5)) Padding(padding: const EdgeInsets.only(bottom: 8), child: FilaPartido(x, soloKid: h.id)),
          const Seccion('Análisis avanzado'),
          if (s.tieneAnalisis(h)) _Avanzado(h: h) else _Bloqueado(h: h),
        ]),
      ),
    ]);
  }

  static int _racha(Estado s, Hijo h) {
    var n = 0;
    for (final x in s.finDe(h.id).reversed) {
      if (!x.part[h.id]!.jugo) break;
      n++;
    }
    return n;
  }

  Widget _logro(String i, String t, String sub) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Text(i, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.w700)), Text(sub, style: const TextStyle(color: cMu, fontSize: 12))])),
        ]),
      );
}

class _Bloqueado extends StatelessWidget {
  final Hijo h;
  const _Bloqueado({required this.h});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    return Tarjeta(
      color: cGoldSoft,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [Icon(Icons.lock_outline, color: Color(0xFF8A5A00)), SizedBox(width: 8), Text('Premium', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]),
        const SizedBox(height: 8),
        Text('Mira cómo evoluciona ${primerNombre(h.nombre)}: minutos partido a partido, tendencia de sus acciones, promedio por partido, titular vs. cambio y comparación con sus últimos partidos.'),
        const SizedBox(height: 6),
        const Text('\$$precioPremium MXN al mes por hijo · cancela cuando quieras', style: TextStyle(color: cMu, fontSize: 13)),
        const SizedBox(height: 12),
        if (!h.plan.pruebaUsada)
          FilledButton(key: const Key('prueba'), onPressed: () { s.plan(h, 'prueba'); aviso(context, '$diasPrueba días de prueba activados para ${primerNombre(h.nombre)}'); }, child: const Text('Probar $diasPrueba días gratis'))
        else
          const Text('Ya usó su prueba gratis.', style: TextStyle(color: cMu, fontSize: 13)),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: () => suscribir(context, h), child: const Text('Suscribirme')),
      ]),
    );
  }
}

Future<void> suscribir(BuildContext context, Hijo h) async {
  final s = EstadoScope.of(context);
  final ok = await confirmar(context, 'Premium para ${primerNombre(h.nombre)}',
      'El pago (\$$precioPremium MXN al mes) se hace con tarjeta en nuestro sitio web, no en la tienda de apps.\n\nEn esta versión de prueba se activa sin cobro.', si: 'Activar');
  if (ok) {
    s.plan(h, 'suscribir');
    if (context.mounted) aviso(context, 'Premium activo para ${primerNombre(h.nombre)}');
  }
}

class _Avanzado extends StatelessWidget {
  final Hijo h;
  const _Avanzado({required this.h});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final fin = s.finDe(h.id);
    final ult = fin.length > 10 ? fin.sublist(fin.length - 10) : fin;
    final jug = s.jugadosDe(h.id);
    final rec = jug.length > 5 ? jug.sublist(jug.length - 5) : jug;
    final ant = jug.length > 5 ? jug.sublist(0, jug.length - 5) : <Partido>[];
    final tit = jug.where((x) => x.part[h.id]!.titular).length;
    double prom(List<Partido> l, String k) => promedio(l.map((x) => x.part[h.id]!.stat(k)));
    final maxMin = ult.isEmpty ? 1 : ult.map(s.durTotal).reduce((a, b) => a > b ? a : b);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Tarjeta(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Minutos por partido', style: TextStyle(fontWeight: FontWeight.w800)),
        const Text('Últimos 10 partidos', style: TextStyle(color: cMu, fontSize: 12)),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (final x in ult)
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(children: [
                  Text('${s.minutosEn(x, h.id).round()}', style: const TextStyle(fontSize: 10, color: cMu)),
                  const SizedBox(height: 2),
                  Expanded(child: FractionallySizedBox(alignment: Alignment.bottomCenter, heightFactor: (s.minutosEn(x, h.id) / maxMin).clamp(.02, 1.0), child: Container(decoration: BoxDecoration(color: x.part[h.id]!.titular ? kc(h).c : kc(h).c.withValues(alpha: .45), borderRadius: BorderRadius.circular(4))))),
                  const SizedBox(height: 4),
                  Text('${x.fecha.day}/${x.fecha.month}', style: const TextStyle(fontSize: 9, color: cMu)),
                ]),
              )),
          ]),
        ),
        const SizedBox(height: 6),
        Text('Titular en $tit de ${jug.length} · color claro = entró de cambio', style: const TextStyle(color: cMu, fontSize: 12)),
      ])),
      const SizedBox(height: 10),
      Tarjeta(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Promedio por partido', style: TextStyle(fontWeight: FontWeight.w800)),
        Text(ant.isEmpty ? 'Con más partidos verás la tendencia' : 'Últimos 5 comparado con los anteriores', style: const TextStyle(color: cMu, fontSize: 12)),
        const SizedBox(height: 8),
        for (final st in stats[h.pos]!)
          Builder(builder: (_) {
            final a = prom(rec, st.k), b = prom(ant, st.k);
            final mejora = st.tipo == 'neg' ? a < b : a > b;
            final igual = ant.isEmpty || (a - b).abs() < .05;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                Expanded(child: Text(nombreStat(st.k))),
                Text(a.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                SizedBox(width: 64, child: igual ? const Text('—', textAlign: TextAlign.right, style: TextStyle(color: cMu)) : Text('${mejora ? '▲' : '▼'} ${b.toStringAsFixed(1)}', textAlign: TextAlign.right, style: TextStyle(color: mejora ? cWin : cLoss, fontSize: 13, fontWeight: FontWeight.w700))),
              ]),
            );
          }),
      ])),
      const SizedBox(height: 10),
      Tarjeta(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Por cada 40 minutos en la cancha', style: TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Builder(builder: (_) {
          final m = jug.fold<double>(0, (a, x) => a + s.minutosEn(x, h.id));
          final tot = jug.fold<int>(0, (a, x) => a + x.part[h.id]!.stat(mainStat[h.pos]!));
          return Text(m == 0 ? '—' : '${(tot * 40 / m).toStringAsFixed(2)} ${nombreStat(mainStat[h.pos]!).toLowerCase()}s', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kc(h).d));
        }),
        const Text('Así comparas partidos donde jugó poco con los que jugó completo.', style: TextStyle(color: cMu, fontSize: 12)),
      ])),
    ]);
  }
}
