import 'package:material_ui/material_ui.dart';

import '../modelo.dart';
import '../tema.dart';
import '../util.dart';
import 'familia.dart';
import 'partido.dart';

class Inicio extends StatelessWidget {
  final ValueChanged<int> irA;
  const Inicio({super.key, required this.irA});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final hoy = soloDia(DateTime.now());
    if (s.f.hijos.isEmpty) {
      return ListView(padding: const EdgeInsets.all(20), children: [
        const Text('FutData Familia', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
        const SizedBox(height: 24),
        Tarjeta(child: Column(children: [
          const Icon(Icons.sports_soccer, size: 48, color: cAc),
          const SizedBox(height: 8),
          const Text('Agrega a tu primer hijo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Con su posición y su equipo armamos su calendario y su registro.', textAlign: TextAlign.center, style: TextStyle(color: cMu)),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: () => abrirNuevoHijo(context), icon: const Icon(Icons.add), label: const Text('Agregar hijo')),
        ])),
      ]);
    }
    final ultimos = s.ordenados.where((x) => x.finalizado).toList().reversed.take(5).toList();
    final entrenosHoy = [
      for (final t in s.f.equipos)
        if (t.entreno.dias.contains(diaSemana(hoy)) && s.hijosDe(t.id).isNotEmpty) t,
    ];
    final proximos = <String, Partido>{};
    for (final h in s.f.hijos) {
      final p = s.proxDe(h.id);
      if (p != null) proximos[p.id] = p;
    }
    final prox = proximos.values.toList()..sort((a, b) => a.fecha.compareTo(b.fecha));
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 24), children: [
      Row(children: [
        Expanded(child: Text('Hola, ${s.yo.nombre == 'Tú' ? '👋' : primerNombre(s.yo.nombre)}', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900))),
        Row(children: [for (final h in s.f.hijos) Padding(padding: const EdgeInsets.only(left: 4), child: Avatar(h, size: 30))]),
      ]),
      Text('${diasLargos[diaSemana(hoy)]} ${hoy.day} de ${mesesLargos[hoy.month - 1].toLowerCase()}', style: const TextStyle(color: cMu)),
      if (entrenosHoy.isNotEmpty) ...[
        const Seccion('Hoy hay entreno'),
        for (final t in entrenosHoy)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Tarjeta(child: Row(children: [
              const Icon(Icons.directions_run, color: cAc),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${t.nombre} · ${t.entreno.ini}–${t.entreno.fin}', style: const TextStyle(fontWeight: FontWeight.w700)),
                Text([s.hijosDe(t.id).map((h) => primerNombre(h.nombre)).join(' y '), if (t.entreno.lugar.isNotEmpty) t.entreno.lugar].join(' · '), style: const TextStyle(color: cMu, fontSize: 13)),
              ])),
            ])),
          ),
      ],
      Seccion('Próximos partidos', accion: TextButton.icon(onPressed: () => abrirFormPartido(context), icon: const Icon(Icons.add, size: 18), label: const Text('Nuevo'))),
      if (prox.isEmpty) const Tarjeta(child: Text('No hay partidos programados. Agrega el siguiente con “Nuevo”.', style: TextStyle(color: cMu))),
      for (final x in prox) Padding(padding: const EdgeInsets.only(bottom: 10), child: TarjetaProximo(x)),
      Seccion('Últimos resultados', accion: TextButton(onPressed: () => irA(1), child: const Text('Calendario'))),
      if (ultimos.isEmpty) const Tarjeta(child: Text('Aquí verás los resultados cuando registres partidos.', style: TextStyle(color: cMu))),
      for (final x in ultimos) Padding(padding: const EdgeInsets.only(bottom: 8), child: FilaPartido(x)),
    ]);
  }
}

class TarjetaProximo extends StatelessWidget {
  final Partido x;
  const TarjetaProximo(this.x, {super.key});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final t = s.equipo(x.equipoId)!;
    final kids = s.kidsDe(x).map(s.hijo).whereType<Hijo>().toList();
    final dias = soloDia(x.fecha).difference(soloDia(DateTime.now())).inDays;
    final cuando = dias == 0 ? 'Hoy' : dias == 1 ? 'Mañana' : dias < 0 ? 'Pendiente' : 'En $dias días';
    return Tarjeta(
      onTap: () => abrirPartido(context, x.id),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Pastilla(cuando, c: dias <= 1 ? cAcDk : cMu, fondo: dias <= 1 ? cAcSoft : cBg),
          const SizedBox(width: 8),
          Expanded(child: Text('${fFecha(x.fecha)} · ${fHora(x.fecha)}', style: const TextStyle(color: cMu, fontSize: 13))),
          for (final h in kids) Padding(padding: const EdgeInsets.only(left: 4), child: Avatar(h, size: 24)),
        ]),
        const SizedBox(height: 10),
        Text(x.local ? '${t.nombre} vs ${x.rival}' : '${x.rival} vs ${t.nombre}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text([x.comp, if (x.lugar.isNotEmpty) x.lugar].join(' · '), style: const TextStyle(color: cMu, fontSize: 13)),
        const SizedBox(height: 12),
        FilledButton.icon(onPressed: () => abrirPreparar(context, x), icon: const Icon(Icons.play_arrow), label: const Text('Registrar en vivo')),
      ]),
    );
  }
}

class FilaPartido extends StatelessWidget {
  final Partido x;
  final String? soloKid;
  const FilaPartido(this.x, {super.key, this.soloKid});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final t = s.equipo(x.equipoId);
    final kids = (soloKid != null ? [soloKid!] : s.kidsDe(x)).map(s.hijo).whereType<Hijo>().toList();
    return Tarjeta(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      onTap: () => abrirPartido(context, x.id),
      child: Row(children: [
        if (x.finalizado) ResChip(x) else const Icon(Icons.schedule, color: cMu, size: 26),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${x.local ? 'vs' : 'en'} ${x.rival}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${fFecha(x.fecha)} · ${t?.nombre ?? ''}', style: const TextStyle(color: cMu, fontSize: 12)),
        ])),
        for (final h in kids)
          if (x.part[h.id]?.jugo ?? false)
            Padding(padding: const EdgeInsets.only(left: 6), child: Pastilla("${s.minutosEn(x, h.id).round()}'", c: kc(h).d, fondo: kc(h).t)),
        const SizedBox(width: 8),
        if (x.finalizado) Text('${x.gf ?? 0}–${x.gc ?? 0}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
    );
  }
}
