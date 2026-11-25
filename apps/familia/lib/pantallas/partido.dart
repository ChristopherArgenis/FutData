import 'package:material_ui/material_ui.dart';

import '../modelo.dart';
import '../tema.dart';
import '../util.dart';

void abrirPartido(BuildContext c, String id) => Navigator.push(c, MaterialPageRoute(builder: (_) => DetallePartido(id: id)));
void abrirFormPartido(BuildContext c, {Partido? editar, DateTime? dia}) => Navigator.push(c, MaterialPageRoute(builder: (_) => FormPartido(editar: editar, dia: dia)));
void abrirPreparar(BuildContext c, Partido x) => Navigator.push(c, MaterialPageRoute(builder: (_) => PrepararVivo(id: x.id)));

class DetallePartido extends StatelessWidget {
  final String id;
  const DetallePartido({super.key, required this.id});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final x = s.partido(id);
    if (x == null) return const Scaffold(body: Center(child: Text('Este partido ya no existe')));
    final t = s.equipo(x.equipoId)!;
    final kids = s.kidsDe(x).map(s.hijo).whereType<Hijo>().toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Partido'), actions: [
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'editar') abrirFormPartido(context, editar: x);
            if (v == 'resultado') Navigator.push(context, MaterialPageRoute(builder: (_) => FormResultado(id: x.id)));
            if (v == 'borrar' && await confirmar(context, 'Eliminar partido', 'Se borrará el partido con sus minutos y notas.', si: 'Eliminar', peligro: true)) {
              s.borrarPartido(x.id);
              if (context.mounted) Navigator.pop(context);
            }
          },
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'editar', child: Text('Editar datos')),
            PopupMenuItem(value: 'resultado', child: Text(x.finalizado ? 'Corregir resultado' : 'Registrar resultado sin en vivo')),
            const PopupMenuItem(value: 'borrar', child: Text('Eliminar', style: TextStyle(color: cLoss))),
          ],
        ),
      ]),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        Tarjeta(child: Column(children: [
          Text('${fFecha(x.fecha)} · ${fHora(x.fecha)} · ${x.comp}', style: const TextStyle(color: cMu, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: Text(x.local ? t.nombre : x.rival, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: x.finalizado ? colorRes(x.resultado).withValues(alpha: .12) : cBg, borderRadius: BorderRadius.circular(10)),
              child: Text(x.finalizado ? (x.local ? '${x.gf}–${x.gc}' : '${x.gc}–${x.gf}') : 'vs', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: x.finalizado ? colorRes(x.resultado) : cMu)),
            ),
            Expanded(child: Text(x.local ? x.rival : t.nombre, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ]),
          if (x.lugar.isNotEmpty) ...[const SizedBox(height: 10), Text('📍 ${x.lugar}', style: const TextStyle(color: cMu, fontSize: 13))],
          if (!x.finalizado) ...[
            const SizedBox(height: 14),
            FilledButton.icon(onPressed: () => abrirPreparar(context, x), icon: const Icon(Icons.play_arrow), label: const Text('Registrar en vivo')),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormResultado(id: x.id))), child: const Text('Ya terminó: capturar resultado')),
          ],
        ])),
        if (x.finalizado)
          for (final h in kids) ...[
            Seccion(h.nombre),
            _KidResumen(x: x, h: h),
          ],
        Seccion('Notas', accion: TextButton.icon(onPressed: () => _nuevaNota(context, x, kids), icon: const Icon(Icons.edit_note, size: 18), label: const Text('Agregar'))),
        if (x.notas.isEmpty) const Text('Anota lo que quieras recordar de este partido.', style: TextStyle(color: cMu)),
        for (final n in x.notas)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Tarjeta(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text([n.autor, n.hora, if (n.kid != null && s.hijo(n.kid!) != null) 'sobre ${primerNombre(s.hijo(n.kid!)!.nombre)}'].join(' · '), style: const TextStyle(color: cMu, fontSize: 12)),
              const SizedBox(height: 4),
              Text(n.txt),
            ])),
          ),
      ]),
    );
  }

  Future<void> _nuevaNota(BuildContext context, Partido x, List<Hijo> kids) async {
    final s = EstadoScope.of(context);
    final ctl = TextEditingController();
    String? kid = kids.length == 1 ? kids.first.id : null;
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(d).viewInsets.bottom + 16),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const Text('Nueva nota', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (kids.length > 1)
              Wrap(spacing: 8, children: [
                ChoiceChip(label: const Text('General'), selected: kid == null, onSelected: (_) => set(() => kid = null)),
                for (final h in kids) ChoiceChip(label: Text(primerNombre(h.nombre)), selected: kid == h.id, onSelected: (_) => set(() => kid = h.id)),
              ]),
            const SizedBox(height: 10),
            TextField(controller: ctl, autofocus: true, maxLength: 300, maxLines: 4, minLines: 2, decoration: const InputDecoration(hintText: 'Ej. Hoy se animó a tirar de lejos')),
            FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar nota')),
          ]),
        ),
      ),
    );
    if (ok == true && ctl.text.trim().isNotEmpty) s.agregarNota(x, ctl.text, kid);
  }
}

class _KidResumen extends StatelessWidget {
  final Partido x;
  final Hijo h;
  const _KidResumen({required this.x, required this.h});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final pt = x.part[h.id];
    if (pt == null || !pt.jugo) return const Tarjeta(child: Text('No jugó este partido.', style: TextStyle(color: cMu)));
    final mins = s.minutosEn(x, h.id), tot = s.durTotal(x);
    return Tarjeta(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Avatar(h, size: 32),
        const SizedBox(width: 10),
        Expanded(child: Text("${mins.round()}' de $tot' · ${pt.titular ? 'Titular' : 'Entró de cambio'}", style: const TextStyle(fontWeight: FontWeight.w700))),
        Text('${pct(mins, tot)}%', style: TextStyle(color: kc(h).d, fontWeight: FontWeight.w800)),
      ]),
      const SizedBox(height: 10),
      // Línea del partido con los tramos en la cancha.
      LayoutBuilder(builder: (_, cs) => Container(
            height: 12,
            decoration: BoxDecoration(color: cBg, borderRadius: BorderRadius.circular(6)),
            child: Stack(children: [
              for (final sg in pt.segs) Positioned(left: cs.maxWidth * sg[0] / tot, width: (cs.maxWidth * (sg[1] - sg[0]) / tot).clamp(2, cs.maxWidth), top: 0, bottom: 0, child: Container(decoration: BoxDecoration(color: kc(h).c, borderRadius: BorderRadius.circular(6)))),
              Positioned(left: cs.maxWidth / 2 - 1, width: 2, top: 0, bottom: 0, child: Container(color: Colors.white)),
            ]),
          )),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final e in pt.st.entries.where((e) => e.value > 0)) Pastilla('${nombreStat(e.key)} ${e.value}', c: cFg, fondo: cBg),
        if (pt.st.values.every((v) => v == 0)) const Text('Sin acciones registradas', style: TextStyle(color: cMu, fontSize: 13)),
      ]),
    ]));
  }
}

// ---------------- Nuevo / editar partido ----------------
class FormPartido extends StatefulWidget {
  final Partido? editar;
  final DateTime? dia;
  const FormPartido({super.key, this.editar, this.dia});
  @override
  State<FormPartido> createState() => _FormPartidoState();
}

class _FormPartidoState extends State<FormPartido> {
  late String? equipoId;
  late DateTime fecha;
  late bool local;
  late String comp;
  late final TextEditingController rival, lugar;
  @override
  void initState() {
    super.initState();
    final e = widget.editar;
    equipoId = e?.equipoId;
    final d = widget.dia ?? DateTime.now().add(const Duration(days: 1));
    fecha = e?.fecha ?? DateTime(d.year, d.month, d.day, 10);
    local = e?.local ?? true;
    comp = e?.comp ?? 'Liga';
    rival = TextEditingController(text: e?.rival ?? '');
    lugar = TextEditingController(text: e?.lugar ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final equipos = s.f.equipos.where((t) => s.hijosDe(t.id).isNotEmpty).toList();
    equipoId ??= equipos.firstOrNull?.id;
    return Scaffold(
      appBar: AppBar(title: Text(widget.editar == null ? 'Nuevo partido' : 'Editar partido')),
      body: equipos.isEmpty
          ? const Center(child: Text('Primero agrega a un hijo con su equipo.'))
          : ListView(padding: const EdgeInsets.all(16), children: [
              const Text('Equipo', style: TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Wrap(spacing: 8, children: [
                for (final t in equipos)
                  ChoiceChip(label: Text('${t.nombre} · ${s.hijosDe(t.id).map((h) => primerNombre(h.nombre)).join(', ')}'), selected: equipoId == t.id, onSelected: widget.editar == null ? (_) => setState(() => equipoId = t.id) : null),
              ]),
              const SizedBox(height: 14),
              TextField(key: const Key('rival'), controller: rival, maxLength: 40, decoration: const InputDecoration(labelText: 'Rival')),
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text(fFecha(fecha)),
                  onPressed: () async {
                    final d = await showDatePicker(context: context, initialDate: fecha, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (d != null) setState(() => fecha = DateTime(d.year, d.month, d.day, fecha.hour, fecha.minute));
                  },
                )),
                const SizedBox(width: 10),
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.schedule),
                  label: Text(fHora(fecha)),
                  onPressed: () async {
                    final h = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(fecha));
                    if (h != null) setState(() => fecha = DateTime(fecha.year, fecha.month, fecha.day, h.hour, h.minute));
                  },
                )),
              ]),
              const SizedBox(height: 14),
              SegmentedButton<bool>(segments: const [ButtonSegment(value: true, label: Text('Local')), ButtonSegment(value: false, label: Text('Visitante'))], selected: {local}, onSelectionChanged: (v) => setState(() => local = v.first)),
              const SizedBox(height: 14),
              Wrap(spacing: 8, children: [for (final c in ['Liga', 'Copa', 'Torneo', 'Amistoso']) ChoiceChip(label: Text(c), selected: comp == c, onSelected: (_) => setState(() => comp = c))]),
              const SizedBox(height: 14),
              TextField(controller: lugar, maxLength: 60, decoration: const InputDecoration(labelText: 'Cancha o lugar (opcional)')),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('guardarPartido'),
                onPressed: () {
                  final r = limpio(rival.text, 40);
                  if (r.isEmpty) return aviso(context, 'Escribe el nombre del rival');
                  final x = widget.editar ?? Partido(id: nuevoId('p'), equipoId: equipoId!, rival: r, fecha: fecha);
                  x..rival = r..fecha = fecha..local = local..comp = comp..lugar = limpio(lugar.text, 60);
                  s.guardarPartido(x);
                  Navigator.pop(context);
                  aviso(context, widget.editar == null ? 'Partido agregado' : 'Cambios guardados');
                },
                child: const Text('Guardar'),
              ),
            ]),
    );
  }
}

// ---------------- Resultado sin en vivo ----------------
class FormResultado extends StatefulWidget {
  final String id;
  const FormResultado({super.key, required this.id});
  @override
  State<FormResultado> createState() => _FormResultadoState();
}

class _FormResultadoState extends State<FormResultado> {
  late int gf, gc;
  late Map<String, Participacion> part;
  late Partido x;
  bool listo = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (listo) return;
    final s = EstadoScope.of(context);
    x = s.partido(widget.id)!;
    gf = x.gf ?? 0;
    gc = x.gc ?? 0;
    final tot = s.durTotal(x).toDouble();
    part = {
      for (final k in s.kidsDe(x))
        k: x.part[k] != null
            ? Participacion(jugo: x.part[k]!.jugo, titular: x.part[k]!.titular, segs: [[0, x.part[k]!.minutos.roundToDouble()]], st: Map.of(x.part[k]!.st))
            : Participacion(segs: [[0, tot]]),
    };
    listo = true;
  }

  Widget _contador(String l, int v, ValueChanged<int> on, {int max = 99}) => Row(children: [
        Expanded(child: Text(l)),
        IconButton(onPressed: v > 0 ? () => on(v - 1) : null, icon: const Icon(Icons.remove_circle_outline)),
        SizedBox(width: 30, child: Text('$v', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
        IconButton(onPressed: v < max ? () => on(v + 1) : null, icon: const Icon(Icons.add_circle_outline, color: cAc)),
      ]);

  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final tot = s.durTotal(x);
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Tarjeta(child: Column(children: [
          _contador('Goles de ${s.equipo(x.equipoId)!.nombre}', gf, (v) => setState(() => gf = v)),
          _contador('Goles de ${x.rival}', gc, (v) => setState(() => gc = v)),
        ])),
        for (final e in part.entries) ...[
          Seccion(s.hijo(e.key)!.nombre),
          Tarjeta(child: Column(children: [
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Jugó'), value: e.value.jugo, onChanged: (v) => setState(() => e.value.jugo = v)),
            if (e.value.jugo) ...[
              SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Fue titular'), value: e.value.titular, onChanged: (v) => setState(() => e.value.titular = v)),
              Row(children: [
                const Text('Minutos'),
                Expanded(child: Slider(value: e.value.minutos.clamp(0, tot.toDouble()), min: 0, max: tot.toDouble(), divisions: tot, label: "${e.value.minutos.round()}'", onChanged: (v) => setState(() => e.value.segs = [[0, v.roundToDouble()]]))),
                SizedBox(width: 36, child: Text("${e.value.minutos.round()}'", style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
              for (final st in stats[s.hijo(e.key)!.pos]!) _contador(nombreStat(st.k), e.value.stat(st.k), (v) => setState(() => v == 0 ? e.value.st.remove(st.k) : e.value.st[st.k] = v)),
            ],
          ])),
        ],
        const SizedBox(height: 16),
        FilledButton(
          key: const Key('guardarResultado'),
          onPressed: () {
            x..gf = gf..gc = gc..estado = 'FINALIZADO';
            for (final e in part.entries) {
              final m = e.value.minutos;
              final old = x.part[e.key];
              // Si los minutos no cambiaron, conserva los tramos reales del en vivo.
              e.value.segs = old != null && old.minutos.round() == m.round() ? old.segs : (m > 0 ? [[0, m]] : []);
              x.part[e.key] = e.value;
            }
            s.guardarPartido(x);
            Navigator.pop(context);
            aviso(context, 'Resultado guardado');
          },
          child: const Text('Guardar resultado'),
        ),
      ]),
    );
  }
}

// ---------------- Preparar el en vivo ----------------
class PrepararVivo extends StatefulWidget {
  final String id;
  const PrepararVivo({super.key, required this.id});
  @override
  State<PrepararVivo> createState() => _PrepararVivoState();
}

class _PrepararVivoState extends State<PrepararVivo> {
  Map<String, KidLive>? k;
  bool prueba = false;
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final x = s.partido(widget.id)!;
    k ??= {for (final id in s.hijosDe(x.equipoId).map((h) => h.id)) id: KidLive()};
    final t = s.equipo(x.equipoId)!;
    return Scaffold(
      appBar: AppBar(title: const Text('Antes de empezar')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${t.nombre} vs ${x.rival}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text('2 tiempos de ${t.dur} min · ${modalidades[t.modalidad] ?? t.modalidad}', style: const TextStyle(color: cMu)),
        if (k!.length > 1) const Padding(padding: EdgeInsets.only(top: 10), child: Text('Están en el mismo equipo: el reloj de minutos se lleva por separado para cada uno.', style: TextStyle(color: cMu, fontSize: 13))),
        for (final e in k!.entries) ...[
          Seccion(s.hijo(e.key)!.nombre),
          Tarjeta(child: Column(children: [
            SwitchListTile(contentPadding: EdgeInsets.zero, secondary: Avatar(s.hijo(e.key)!), title: const Text('Va a jugar'), value: e.value.va, onChanged: (v) => setState(() => e.value.va = v)),
            if (e.value.va)
              SegmentedButton<bool>(
                segments: const [ButtonSegment(value: true, label: Text('Titular')), ButtonSegment(value: false, label: Text('Empieza en la banca'))],
                selected: {e.value.on},
                onSelectionChanged: (v) => setState(() => e.value.on = v.first),
              ),
          ])),
        ],
        const SizedBox(height: 10),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Modo prueba'), subtitle: const Text('El reloj corre rápido (1 segundo = 1 minuto) para probar la app.'), value: prueba, onChanged: (v) => setState(() => prueba = v)),
        const SizedBox(height: 10),
        FilledButton.icon(
          key: const Key('empezarVivo'),
          icon: const Icon(Icons.sports_soccer),
          label: const Text('Ir al partido'),
          onPressed: k!.values.any((v) => v.va)
              ? () {
                  s.iniciarLive(x, k!, prueba ? 60 : 1);
                  Navigator.popUntil(context, (r) => r.isFirst);
                }
              : null,
        ),
      ]),
    );
  }
}
