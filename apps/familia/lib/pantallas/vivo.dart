import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../modelo.dart';
import '../tema.dart';
import '../util.dart';
import 'partido.dart';

/// Captura en vivo. El reloj usa la hora del teléfono: si se cierra la app, sigue contando.
class EnVivo extends StatefulWidget {
  const EnVivo({super.key});
  @override
  State<EnVivo> createState() => _EnVivoState();
}

class _EnVivoState extends State<EnVivo> {
  Timer? _tic;
  @override
  void initState() {
    super.initState();
    _tic = Timer.periodic(const Duration(milliseconds: 500), (_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _tic?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final l = s.live;
    if (l == null) return const SizedBox();
    final x = s.partido(l.pid)!;
    final t = s.equipo(x.equipoId)!;
    final van = l.k.entries.where((e) => e.value.va).map((e) => s.hijo(e.key)!).toList();
    final sel = s.hijo(l.sel ?? van.first.id) ?? van.first;
    final ks = l.k[sel.id]!;
    final reloj = l.per == 0 ? 'Medio tiempo' : mmss(s.segLive());
    final periodo = l.per == 0 ? 'Descanso' : l.per == 1 ? '1er tiempo' : '2º tiempo';
    final pasado = l.per != 0 && s.segLive() / 60 >= t.dur;

    return Scaffold(
      backgroundColor: cBg,
      body: SafeArea(
        child: Column(children: [
          // Marcador
          Container(
            color: cAcDk,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 14),
            child: Column(children: [
              Row(children: [
                const Pastilla('● EN VIVO', c: Colors.white, fondo: cLoss),
                const SizedBox(width: 8),
                Expanded(child: Text(l.vel > 1 ? 'Modo prueba · 1 s = 1 min' : x.comp, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                PopupMenuButton<String>(
                  iconColor: Colors.white,
                  onSelected: (v) async {
                    if (v == 'nota') _nota(context, x.id, sel);
                    if (v == 'descartar' && await confirmar(context, 'Descartar en vivo', 'Se borra lo capturado y el partido vuelve a quedar programado.', si: 'Descartar', peligro: true)) s.liveDescartar();
                  },
                  itemBuilder: (_) => const [PopupMenuItem(value: 'nota', child: Text('Agregar nota')), PopupMenuItem(value: 'descartar', child: Text('Descartar en vivo', style: TextStyle(color: cLoss)))],
                ),
              ]),
              Row(children: [
                Expanded(child: Text(t.nombre, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
                Text('${x.gf ?? 0} – ${x.gc ?? 0}', key: const Key('marcador'), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
                Expanded(child: Text(x.rival, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
              ]),
              Text('$periodo · $reloj', style: TextStyle(color: pasado ? cGold : Colors.white, fontSize: 18, fontWeight: FontWeight.w800, fontFeatures: const [FontFeature.tabularFigures()])),
              if (pasado) const Text('Ya se cumplió el tiempo: agrega el descuento o marca el final', style: TextStyle(color: cGoldSoft, fontSize: 12)),
              const SizedBox(height: 10),
              Row(children: [
                if (l.per != 0)
                  Expanded(child: FilledButton.icon(
                    key: const Key('reloj'),
                    style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: cAcDk),
                    onPressed: s.liveCorrer,
                    icon: Icon(l.run ? Icons.pause : Icons.play_arrow),
                    label: Text(l.run ? 'Pausar' : (l.started ? 'Reanudar' : 'Iniciar')),
                  )),
                if (l.per == 1 && l.started) ...[const SizedBox(width: 8), Expanded(child: OutlinedButton(style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)), onPressed: s.liveMedioTiempo, child: const Text('Medio tiempo')))],
                if (l.per == 0) Expanded(child: FilledButton(style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: cAcDk), onPressed: s.liveSegundoTiempo, child: const Text('Iniciar 2º tiempo'))),
                if (l.per == 2) ...[
                  const SizedBox(width: 8),
                  Expanded(child: OutlinedButton(
                    key: const Key('terminar'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white54)),
                    onPressed: () async {
                      if (!await confirmar(context, 'Terminar partido', 'Se guardan los minutos y las acciones de cada hijo.', si: 'Terminar')) return;
                      if (!context.mounted) return;
                      final nav = Navigator.of(context);
                      final id = s.liveTerminar();
                      nav.push(MaterialPageRoute(builder: (_) => DetallePartido(id: id)));
                    },
                    child: const Text('Final'),
                  )),
                ],
              ]),
            ]),
          ),
          if (van.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 4, children: [
                for (final h in van)
                  Padding(
                    padding: EdgeInsets.zero,
                    child: ChoiceChip(
                      avatar: CircleAvatar(backgroundColor: kc(h).c, radius: 6),
                      label: Text("${primerNombre(h.nombre)} ${s.minKid(h.id).floor()}'${l.k[h.id]!.on ? '' : ' · banca'}"),
                      selected: sel.id == h.id,
                      selectedColor: kc(h).t,
                      showCheckmark: false,
                      onSelected: (_) { l.sel = h.id; s.cambio(); },
                    ),
                  ),
              ]),
            ),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 16), children: [
              Tarjeta(child: Row(children: [
                Avatar(sel, size: 40),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sel.nombre, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  Text("${posNombre[sel.pos]} · ${s.minKid(sel.id).floor()}' jugados · ${ks.on ? 'en la cancha' : 'en la banca'}", style: const TextStyle(color: cMu, fontSize: 13)),
                ])),
                OutlinedButton(
                  key: const Key('entraSale'),
                  onPressed: () { HapticFeedback.selectionClick(); s.liveEntraSale(sel.id); },
                  style: OutlinedButton.styleFrom(foregroundColor: ks.on ? cLoss : cAc, minimumSize: const Size(80, 44)),
                  child: Text(ks.on ? 'Sale' : 'Entra'),
                ),
              ])),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.1,
                children: [
                  for (final st in stats[sel.pos]!)
                    _BotonStat(
                      def: st, n: x.part[sel.id]!.stat(st.k), color: kc(sel),
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final comp = s.liveStat(sel.id, st.k);
                        if (comp.isNotEmpty && context.mounted) {
                          final a = await showDialog<String>(
                            context: context,
                            builder: (d) => SimpleDialog(title: const Text('¿Quién dio la asistencia?'), children: [
                              for (final k in comp) SimpleDialogOption(onPressed: () => Navigator.pop(d, k), child: Text(s.hijo(k)!.nombre, style: const TextStyle(fontSize: 16))),
                              SimpleDialogOption(onPressed: () => Navigator.pop(d), child: const Text('Otro compañero / nadie', style: TextStyle(color: cMu))),
                            ]),
                          );
                          if (a != null) s.liveAsistencia(a);
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton.icon(key: const Key('golNuestro'), onPressed: () => s.liveEquipo(true), icon: const Icon(Icons.add), label: const Text('Gol compañero'))),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(key: const Key('golRival'), onPressed: () => s.liveEquipo(false), icon: const Icon(Icons.add), label: const Text('Gol rival'))),
              ]),
              const SizedBox(height: 12),
              if (l.undo.isNotEmpty)
                Tarjeta(child: Row(children: [
                  const Icon(Icons.history, color: cMu),
                  const SizedBox(width: 8),
                  Expanded(child: Text([if (l.undo.last.kid != null && s.hijo(l.undo.last.kid!) != null) primerNombre(s.hijo(l.undo.last.kid!)!.nombre), l.undo.last.txt].join(' · '), style: const TextStyle(fontSize: 13))),
                  TextButton(
                    key: const Key('deshacer'),
                    onPressed: () { if (!s.liveDeshacer()) aviso(context, 'Para entradas y salidas usa Entra / Sale'); },
                    child: const Text('Deshacer'),
                  ),
                ])),
            ]),
          ),
        ]),
      ),
    );
  }

  Future<void> _nota(BuildContext context, String pid, Hijo h) async {
    final s = EstadoScope.of(context);
    final ctl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Nota sobre ${primerNombre(h.nombre)}'),
        content: TextField(controller: ctl, autofocus: true, maxLength: 300, maxLines: 3),
        actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar'))],
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) s.agregarNota(s.partido(pid)!, ctl.text, h.id);
  }
}

class _BotonStat extends StatelessWidget {
  final StatDef def;
  final int n;
  final KidColor color;
  final VoidCallback onTap;
  const _BotonStat({required this.def, required this.n, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final main = def.tipo == 'main', neg = def.tipo == 'neg';
    final bg = main ? color.c : neg ? const Color(0xFFFBECEA) : Colors.white;
    final fg = main ? Colors.white : neg ? cLoss : cFg;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        key: Key('st_${def.k}'),
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: main ? color.c : cLine)),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(children: [
            Expanded(child: Text(def.n, style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 15))),
            Text('$n', style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 22)),
          ]),
        ),
      ),
    );
  }
}
