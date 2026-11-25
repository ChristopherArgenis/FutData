import 'package:material_ui/material_ui.dart';

import '../modelo.dart';
import '../tema.dart';
import '../util.dart';
import 'inicio.dart';
import 'partido.dart';

/// Un solo calendario para toda la familia, con un color por hijo.
class Calendario extends StatefulWidget {
  const Calendario({super.key});
  @override
  State<Calendario> createState() => _CalendarioState();
}

class _CalendarioState extends State<Calendario> {
  DateTime mes = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime dia = soloDia(DateTime.now());
  String? filtro;

  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final hijos = s.f.hijos.where((h) => filtro == null || h.id == filtro).toList();
    List<Partido> partidosDia(DateTime d) => s.ordenados.where((x) => soloDia(x.fecha) == d && s.kidsDe(x).any((k) => hijos.any((h) => h.id == k))).toList();
    List<Hijo> entrenanDia(DateTime d) => hijos.where((h) {
          final e = s.equipo(h.equipoId)?.entreno;
          if (e == null || !e.dias.contains(diaSemana(d))) return false;
          if (d.isBefore(soloDia(s.f.tempIni)) || d.isAfter(soloDia(s.f.tempFin))) return false;
          return e.hasta == null || !d.isAfter(parseDia(e.hasta!));
        }).toList();
    final primero = DateTime(mes.year, mes.month), offset = diaSemana(primero), diasMes = DateTime(mes.year, mes.month + 1, 0).day;
    final hoy = soloDia(DateTime.now());
    final pDia = partidosDia(dia), eDia = entrenanDia(dia);

    return ListView(padding: const EdgeInsets.fromLTRB(0, 12, 0, 24), children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(children: [
          Expanded(child: Text('${mesesLargos[mes.month - 1]} ${mes.year}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900))),
          IconButton(onPressed: () => setState(() => mes = DateTime(mes.year, mes.month - 1)), icon: const Icon(Icons.chevron_left)),
          IconButton(onPressed: () => setState(() => mes = DateTime(mes.year, mes.month + 1)), icon: const Icon(Icons.chevron_right)),
        ]),
      ),
      if (s.f.hijos.length > 1) SelectorHijo(sel: filtro, todos: true, onSel: (v) => setState(() => filtro = v)),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Tarjeta(
          padding: const EdgeInsets.all(8),
          child: Column(children: [
            Row(children: [for (final l in diasLetra) Expanded(child: Center(child: Text(l, style: const TextStyle(color: cMu, fontWeight: FontWeight.w700, fontSize: 12))))]),
            const SizedBox(height: 4),
            GridView.count(
              crossAxisCount: 7, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: .82,
              children: [
                for (var i = 0; i < offset; i++) const SizedBox(),
                for (var n = 1; n <= diasMes; n++)
                  Builder(builder: (_) {
                    final d = DateTime(mes.year, mes.month, n);
                    final ps = partidosDia(d), es = entrenanDia(d);
                    final sel = d == dia;
                    return InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setState(() => dia = d),
                      child: Container(
                        margin: const EdgeInsets.all(2),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: sel ? cAc : Colors.transparent, width: 2), color: d == hoy ? cAcSoft : null),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text('$n', style: TextStyle(fontWeight: ps.isNotEmpty ? FontWeight.w900 : FontWeight.w500)),
                          const SizedBox(height: 3),
                          Wrap(spacing: 2, runSpacing: 2, alignment: WrapAlignment.center, children: [
                            for (final x in ps)
                              for (final k in s.kidsDe(x).where((k) => hijos.any((h) => h.id == k)))
                                Container(width: 7, height: 7, decoration: BoxDecoration(color: kc(s.hijo(k)!).c, shape: BoxShape.circle)),
                            for (final h in es) Container(width: 7, height: 7, decoration: BoxDecoration(border: Border.all(color: kc(h).c, width: 1.5), shape: BoxShape.circle)),
                          ]),
                        ]),
                      ),
                    );
                  }),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.circle, size: 9, color: cMu), Text(' Partido   ', style: TextStyle(fontSize: 12, color: cMu)),
                Icon(Icons.circle_outlined, size: 9, color: cMu), Text(' Entreno', style: TextStyle(fontSize: 12, color: cMu)),
              ]),
            ),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Seccion('${diasLargos[diaSemana(dia)]} ${dia.day} ${meses[dia.month - 1]}', accion: TextButton.icon(onPressed: () => abrirFormPartido(context, dia: dia), icon: const Icon(Icons.add, size: 18), label: const Text('Partido'))),
          if (pDia.isEmpty && eDia.isEmpty) const Text('Nada programado este día.', style: TextStyle(color: cMu)),
          for (final x in pDia) Padding(padding: const EdgeInsets.only(bottom: 8), child: FilaPartido(x)),
          for (final h in eDia) Padding(padding: const EdgeInsets.only(bottom: 8), child: _FilaEntreno(h: h, dia: dia)),
        ]),
      ),
    ]);
  }
}

class _FilaEntreno extends StatelessWidget {
  final Hijo h;
  final DateTime dia;
  const _FilaEntreno({required this.h, required this.dia});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final t = s.equipo(h.equipoId)!;
    final fue = s.f.asis['${h.id}|${dkey(dia)}'];
    final pasado = !dia.isAfter(soloDia(DateTime.now()));
    return Tarjeta(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      child: Row(children: [
        Container(width: 4, height: 36, decoration: BoxDecoration(color: kc(h).c, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Entreno · ${primerNombre(h.nombre)}', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('${t.entreno.ini}–${t.entreno.fin}${t.entreno.lugar.isEmpty ? '' : ' · ${t.entreno.lugar}'}', style: const TextStyle(color: cMu, fontSize: 12)),
        ])),
        if (pasado) ...[
          IconButton(tooltip: 'Fue', onPressed: () => s.marcarAsistencia(h.id, dkey(dia), true), icon: Icon(fue == true ? Icons.check_circle : Icons.check_circle_outline, color: fue == true ? cWin : cMu)),
          IconButton(tooltip: 'No fue', onPressed: () => s.marcarAsistencia(h.id, dkey(dia), false), icon: Icon(fue == false ? Icons.cancel : Icons.cancel_outlined, color: fue == false ? cLoss : cMu)),
        ],
      ]),
    );
  }
}
