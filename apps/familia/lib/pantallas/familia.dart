import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../estado.dart';
import '../modelo.dart';
import '../tema.dart';
import '../util.dart';
import 'progreso.dart';
import 'terminos.dart';

void abrirNuevoHijo(BuildContext c) {
  final s = EstadoScope.of(c);
  if (s.f.hijos.length >= maxHijos) return aviso(c, 'Puedes registrar hasta $maxHijos hijos');
  Navigator.push(c, MaterialPageRoute(builder: (_) => const FormHijo()));
}

class FamiliaPantalla extends StatelessWidget {
  const FamiliaPantalla({super.key});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final f = s.f;
    final invitVigente = f.invitCodigo != null && f.invitExpira != null && f.invitExpira!.isAfter(DateTime.now());
    return ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 32), children: [
      const Text('Familia', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      Seccion('Hijos · ${f.hijos.length} de $maxHijos', accion: f.hijos.length < maxHijos ? TextButton.icon(key: const Key('agregarHijo'), onPressed: () => abrirNuevoHijo(context), icon: const Icon(Icons.add, size: 18), label: const Text('Agregar')) : null),
      if (f.hijos.isEmpty) const Text('Aún no agregas hijos.', style: TextStyle(color: cMu)),
      for (final h in f.hijos)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Tarjeta(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FormHijo(editar: h))),
            child: Row(children: [
              Avatar(h, size: 42),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(h.nombre, style: const TextStyle(fontWeight: FontWeight.w800)),
                Text('${edadDe(h.nac)} años · ${zona(h.zona)?.l} · ${h.cat} · ${s.equipo(h.equipoId)?.nombre ?? ''}', style: const TextStyle(color: cMu, fontSize: 12)),
              ])),
              _plan(context, s, h),
            ]),
          ),
        ),
      const Seccion('Adultos · máximo 2'),
      for (final p in f.papas)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Tarjeta(child: Row(children: [
            CircleAvatar(backgroundColor: cAcSoft, child: Text(iniciales(p.nombre), style: const TextStyle(color: cAcDk, fontWeight: FontWeight.w800))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.nombre}${p.yo ? ' (tú)' : ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(p.rel, style: const TextStyle(color: cMu, fontSize: 12)),
            ])),
            if (p.yo) IconButton(onPressed: () => _editarYo(context, s, p), icon: const Icon(Icons.edit_outlined, color: cMu)),
          ])),
        ),
      if (f.papas.length < 2)
        Tarjeta(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Invita al otro adulto', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Comparte este código. Sirve una sola vez, vence en 3 días y tú apruebas su entrada.', style: TextStyle(color: cMu, fontSize: 13)),
          const SizedBox(height: 10),
          if (invitVigente)
            Row(children: [
              Expanded(child: SelectableText(f.invitCodigo!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5))),
              IconButton(onPressed: () { Clipboard.setData(ClipboardData(text: f.invitCodigo!)); aviso(context, 'Código copiado'); }, icon: const Icon(Icons.copy)),
            ])
          else
            OutlinedButton.icon(onPressed: () => s.invitar(), icon: const Icon(Icons.person_add_alt), label: const Text('Crear código de invitación')),
          if (invitVigente) Text('Vence el ${fFecha(f.invitExpira!)}', style: const TextStyle(color: cMu, fontSize: 12)),
        ])),
      const Seccion('Ajustes'),
      Tarjeta(
        padding: EdgeInsets.zero,
        child: Column(children: [
          ListTile(leading: const Icon(Icons.description_outlined), title: const Text('Términos y privacidad'), subtitle: Text('Aceptados el ${f.legal == null ? '' : fFecha(f.legal!.fecha)} · v${f.legal?.version ?? ''}'), onTap: () => _verTerminos(context)),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.auto_awesome_outlined), title: const Text('Cargar familia de ejemplo'), onTap: () async { if (await confirmar(context, 'Familia de ejemplo', 'Se reemplazan tus datos por los de ejemplo.', si: 'Cargar')) s.reiniciarEjemplo(); }),
          const Divider(height: 1),
          ListTile(leading: const Icon(Icons.restart_alt), title: const Text('Empezar de cero'), onTap: () async { if (await confirmar(context, 'Empezar de cero', 'Se borran hijos, equipos y partidos de este teléfono.', si: 'Borrar todo', peligro: true)) s.empezarDeCero(); }),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.delete_forever_outlined, color: cLoss),
            title: const Text('Borrar mis datos y salir', style: TextStyle(color: cLoss)),
            subtitle: const Text('Elimina todo y vuelve a los términos'),
            onTap: () async { if (await confirmar(context, 'Borrar mis datos', 'Se elimina toda la información guardada en este teléfono. No se puede deshacer.', si: 'Borrar', peligro: true)) await s.borrarCuenta(); },
          ),
        ]),
      ),
      const SizedBox(height: 16),
      const Center(child: Text('FutData Familia · versión 1.0 · tus datos viven en este teléfono', style: TextStyle(color: cMu, fontSize: 12))),
    ]);
  }

  Widget _plan(BuildContext context, Estado s, Hijo h) {
    final activo = s.tieneAnalisis(h);
    final txt = h.plan.estado == 'premium' ? 'Premium' : activo ? 'Prueba · ${h.plan.pruebaFin!.difference(DateTime.now()).inDays + 1} d' : 'Gratis';
    return PopupMenuButton<String>(
      onSelected: (v) {
        if (v == 'prueba') s.plan(h, 'prueba');
        if (v == 'suscribir') suscribir(context, h);
        if (v == 'cancelar') s.plan(h, 'cancelar');
        if (v == 'quitar') _quitar(context, s, h);
      },
      itemBuilder: (_) => [
        if (!h.plan.pruebaUsada) const PopupMenuItem(value: 'prueba', child: Text('Probar Premium $diasPrueba días')),
        if (h.plan.estado != 'premium') const PopupMenuItem(value: 'suscribir', child: Text('Suscribir a Premium')),
        if (h.plan.estado == 'premium') const PopupMenuItem(value: 'cancelar', child: Text('Cancelar Premium')),
        const PopupMenuItem(value: 'quitar', child: Text('Quitar de la familia', style: TextStyle(color: cLoss))),
      ],
      child: Pastilla(txt, c: activo ? const Color(0xFF8A5A00) : cMu, fondo: activo ? cGoldSoft : cBg),
    );
  }

  Future<void> _quitar(BuildContext context, Estado s, Hijo h) async {
    if (await confirmar(context, 'Quitar a ${primerNombre(h.nombre)}', 'Se borran sus minutos, acciones y asistencia.', si: 'Quitar', peligro: true)) s.quitarHijo(h.id);
  }

  Future<void> _editarYo(BuildContext context, Estado s, Papa p) async {
    final n = TextEditingController(text: p.nombre == 'Tú' ? '' : p.nombre);
    var rel = p.rel;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(builder: (d, set) => AlertDialog(
            title: const Text('Tus datos'),
            content: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: n, maxLength: 40, decoration: const InputDecoration(labelText: 'Tu nombre')),
              Wrap(spacing: 8, children: [for (final r in ['Mamá', 'Papá', 'Tutor']) ChoiceChip(label: Text(r), selected: rel == r, onSelected: (_) => set(() => rel = r))]),
            ]),
            actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Guardar'))],
          )),
    );
    if (ok == true && limpio(n.text, 40).isNotEmpty) { p.nombre = limpio(n.text, 40); p.rel = rel; s.cambio(); }
  }

  void _verTerminos(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => DraggableScrollableSheet(expand: false, initialChildSize: .7, builder: (_, sc) => ListView(controller: sc, padding: const EdgeInsets.all(20), children: const [Text('Términos y privacidad', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), SizedBox(height: 12), Text(textoTerminos, style: TextStyle(height: 1.45))])),
      );
}

// ---------------- Agregar / editar hijo ----------------
class FormHijo extends StatefulWidget {
  final Hijo? editar;
  const FormHijo({super.key, this.editar});
  @override
  State<FormHijo> createState() => _FormHijoState();
}

class _FormHijoState extends State<FormHijo> {
  late final TextEditingController nombre, numero, otraCat, equipoNombre, liga, lugar;
  DateTime? nac;
  String pie = 'Derecho', zonaK = 'MED', nivel = 'Competitivo';
  String? cat, zona2, equipoId; // equipoId null = equipo nuevo
  String modalidad = 'F7';
  int dur = 25;
  List<int> dias = [];
  String ini = '18:00', fin = '19:30';
  bool listo = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (listo) return;
    listo = true;
    final s = EstadoScope.of(context);
    final h = widget.editar;
    nombre = TextEditingController(text: h?.nombre ?? '');
    numero = TextEditingController(text: h == null || h.numero == 0 ? '' : '${h.numero}');
    final esOtra = h != null && !categorias.contains(h.cat);
    otraCat = TextEditingController(text: esOtra ? h.cat : '');
    if (h != null) {
      nac = h.nac; pie = h.pie; zonaK = h.zona; zona2 = h.zona2; nivel = h.nivel; cat = esOtra ? 'Otro' : h.cat; equipoId = h.equipoId;
    } else if (s.f.equipos.isNotEmpty) {
      equipoId = null; // se pregunta abajo si juega con su hermano
    }
    final t = equipoId == null ? null : s.equipo(equipoId!);
    equipoNombre = TextEditingController(text: t?.nombre ?? '');
    liga = TextEditingController(text: t?.liga ?? '');
    lugar = TextEditingController(text: t?.entreno.lugar ?? '');
    if (t != null) { modalidad = t.modalidad; dur = t.dur; dias = [...t.entreno.dias]; ini = t.entreno.ini; fin = t.entreno.fin; }
  }

  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    final editando = widget.editar != null;
    final otrosEquipos = s.f.equipos.where((t) => s.hijosDe(t.id).any((h) => h.id != widget.editar?.id)).toList();
    final edad = edadDe(nac);
    final mismoEquipo = equipoId != null && s.hijosDe(equipoId!).any((h) => h.id != widget.editar?.id);
    return Scaffold(
      appBar: AppBar(title: Text(editando ? 'Editar a ${primerNombre(widget.editar!.nombre)}' : 'Agregar hijo')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(key: const Key('nombreHijo'), controller: nombre, maxLength: 40, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Nombre y apellido')),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            key: const Key('nacimiento'),
            icon: const Icon(Icons.cake_outlined),
            label: Text(nac == null ? 'Fecha de nacimiento' : '${nac!.day} ${meses[nac!.month - 1]} ${nac!.year} · $edad años'),
            onPressed: () async {
              final d = await showDatePicker(context: context, initialDate: nac ?? DateTime(DateTime.now().year - 9), firstDate: DateTime(DateTime.now().year - 19), lastDate: DateTime(DateTime.now().year - 3), initialDatePickerMode: DatePickerMode.year);
              if (d != null) setState(() { nac = d; cat ??= categoriaSugerida(edadDe(d)); });
            },
          )),
          const SizedBox(width: 10),
          SizedBox(width: 90, child: TextField(controller: numero, keyboardType: TextInputType.number, maxLength: 2, inputFormatters: [FilteringTextInputFormatter.digitsOnly], decoration: const InputDecoration(labelText: 'Número', counterText: ''))),
        ]),
        const SizedBox(height: 12),
        SegmentedButton<String>(segments: const [ButtonSegment(value: 'Derecho', label: Text('Diestro')), ButtonSegment(value: 'Izquierdo', label: Text('Zurdo')), ButtonSegment(value: 'Ambos', label: Text('Ambos'))], selected: {pie}, onSelectionChanged: (v) => setState(() => pie = v.first)),
        const Seccion('Posición'),
        const Text('Toca su posición principal. Mantén presionada otra para marcarla como secundaria.', style: TextStyle(color: cMu, fontSize: 13)),
        const SizedBox(height: 8),
        AspectRatio(
          aspectRatio: 1.6,
          child: LayoutBuilder(builder: (_, cs) => Stack(children: [
                Positioned.fill(child: CustomPaint(painter: CanchaPainter())),
                for (final z in zonas)
                  Positioned(
                    left: cs.maxWidth * z.x - 30, top: cs.maxHeight * z.y - 18, width: 60, height: 36,
                    child: GestureDetector(
                      key: Key('zona_${z.k}'),
                      onTap: () => setState(() { if (zona2 == z.k) zona2 = null; zonaK = z.k; }),
                      onLongPress: () => setState(() { if (z.k != zonaK) zona2 = zona2 == z.k ? null : z.k; }),
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: zonaK == z.k ? Colors.white : zona2 == z.k ? Colors.white54 : Colors.black26,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: Colors.white, width: zonaK == z.k ? 2 : 1),
                        ),
                        child: Text(z.k, style: TextStyle(color: zonaK == z.k ? cAcDk : Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                      ),
                    ),
                  ),
              ])),
        ),
        const SizedBox(height: 6),
        Text('Principal: ${zona(zonaK)!.l} (${posNombre[zona(zonaK)!.g]})${zona2 == null ? '' : ' · Secundaria: ${zona(zona2)!.l}'}', style: const TextStyle(fontSize: 12, color: cMu)),
        const Seccion('Categoría y nivel'),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final c in [...categorias, 'Otro']) ChoiceChip(label: Text(c), selected: cat == c, onSelected: (_) => setState(() => cat = c)),
        ]),
        if (cat == 'Otro') Padding(padding: const EdgeInsets.only(top: 8), child: TextField(key: const Key('otraCat'), controller: otraCat, maxLength: 20, decoration: const InputDecoration(labelText: 'Escribe la categoría (ej. 6-9, Infantil A)'))),
        const SizedBox(height: 8),
        Wrap(spacing: 8, children: [for (final n in niveles) ChoiceChip(label: Text(n), selected: nivel == n, onSelected: (_) => setState(() => nivel = n))]),
        const Seccion('Equipo'),
        if (otrosEquipos.isNotEmpty) ...[
          Text(widget.editar == null ? '¿Juega en el mismo equipo que alguno de sus hermanos?' : 'Equipo', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Wrap(spacing: 8, runSpacing: 4, children: [
            for (final t in otrosEquipos) ChoiceChip(label: Text('${t.nombre} (con ${s.hijosDe(t.id).where((h) => h.id != widget.editar?.id).map((h) => primerNombre(h.nombre)).join(', ')})'), selected: equipoId == t.id, onSelected: (_) => setState(() => equipoId = t.id)),
            ChoiceChip(key: const Key('otroEquipo'), label: Text(editando && !mismoEquipo && equipoId != null ? 'Su equipo actual' : 'No, otro equipo'), selected: equipoId == null || (equipoId == widget.editar?.equipoId && !mismoEquipo), onSelected: (_) => setState(() => equipoId = editando && !mismoEquipo ? widget.editar!.equipoId : null)),
          ]),
          if (mismoEquipo) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Comparten calendario y entrenos. En el partido en vivo podrás llevar los minutos de cada uno por separado.', style: TextStyle(color: cMu, fontSize: 13))),
          const SizedBox(height: 8),
        ],
        if (!mismoEquipo) ...[
          TextField(key: const Key('equipoNombre'), controller: equipoNombre, maxLength: 40, decoration: const InputDecoration(labelText: 'Nombre del equipo')),
          TextField(controller: liga, maxLength: 50, decoration: const InputDecoration(labelText: 'Liga o escuela (opcional)')),
          Wrap(spacing: 8, children: [for (final m in modalidades.entries) ChoiceChip(label: Text(m.value), selected: modalidad == m.key, onSelected: (_) => setState(() => modalidad = m.key))]),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Minutos por tiempo'),
            Expanded(child: Slider(value: dur.toDouble(), min: 10, max: 45, divisions: 35, label: '$dur', onChanged: (v) => setState(() => dur = v.round()))),
            Text("$dur'", style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          const Text('Días de entreno', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            for (var d in [1, 2, 3, 4, 5, 6, 0])
              Expanded(child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: FilterChip(
                  padding: EdgeInsets.zero, labelPadding: EdgeInsets.zero, showCheckmark: false,
                  label: SizedBox(width: double.infinity, child: Text(diasLetra[d], textAlign: TextAlign.center)),
                  selected: dias.contains(d),
                  onSelected: (v) => setState(() => v ? dias.add(d) : dias.remove(d)),
                ),
              )),
          ]),
          if (dias.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _hora(true), child: Text('De $ini'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton(onPressed: () => _hora(false), child: Text('A $fin'))),
            ]),
            const SizedBox(height: 8),
            TextField(controller: lugar, maxLength: 60, decoration: const InputDecoration(labelText: 'Dónde entrena (opcional)')),
          ],
        ],
        const SizedBox(height: 16),
        FilledButton(key: const Key('guardarHijo'), onPressed: () => _guardar(context, s), child: Text(editando ? 'Guardar cambios' : 'Agregar a la familia')),
        if (editando) TextButton(onPressed: () async {
          final h = widget.editar!;
          if (await confirmar(context, 'Quitar a ${primerNombre(h.nombre)}', 'Se borran sus minutos, acciones y asistencia.', si: 'Quitar', peligro: true)) {
            s.quitarHijo(h.id);
            if (context.mounted) Navigator.pop(context);
          }
        }, child: const Text('Quitar de la familia', style: TextStyle(color: cLoss))),
      ]),
    );
  }

  Future<void> _hora(bool inicio) async {
    final v = (inicio ? ini : fin).split(':');
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: int.parse(v[0]), minute: int.parse(v[1])));
    if (t != null) setState(() => inicio ? ini = '${dos(t.hour)}:${dos(t.minute)}' : fin = '${dos(t.hour)}:${dos(t.minute)}');
  }

  void _guardar(BuildContext context, Estado s) {
    final n = limpio(nombre.text, 40);
    if (n.isEmpty) return aviso(context, 'Escribe su nombre');
    if (nac == null) return aviso(context, 'Elige su fecha de nacimiento');
    final categoria = cat == 'Otro' ? limpio(otraCat.text, 20) : cat;
    if (categoria == null || categoria.isEmpty) return aviso(context, 'Elige o escribe su categoría');
    final mismo = equipoId != null && s.hijosDe(equipoId!).any((h) => h.id != widget.editar?.id);
    final nomEq = limpio(equipoNombre.text, 40);
    if (!mismo && nomEq.isEmpty) return aviso(context, 'Escribe el nombre de su equipo');
    if (widget.editar == null && s.f.hijos.length >= maxHijos) return aviso(context, 'Puedes registrar hasta $maxHijos hijos');

    String tid;
    if (mismo) {
      tid = equipoId!;
    } else {
      final propio = widget.editar != null && equipoId == widget.editar!.equipoId ? s.equipo(equipoId!) : null;
      final t = propio ?? Equipo(id: nuevoId('t'), nombre: nomEq);
      t..nombre = nomEq..liga = limpio(liga.text, 50)..modalidad = modalidad..dur = dur
        ..entreno = Entreno(dias: [...dias]..sort(), ini: ini, fin: fin, lugar: limpio(lugar.text, 60));
      if (propio == null) s.f.equipos.add(t);
      tid = t.id;
    }
    final num = int.tryParse(numero.text) ?? 0;
    final h = widget.editar;
    if (h == null) {
      final nuevo = Hijo(id: nuevoId('k'), nombre: n, nac: nac!, pie: pie, numero: num, zona: zonaK, zona2: zona2, cat: categoria, nivel: nivel, equipoId: tid, color: s.colorLibre());
      s.f.hijos.add(nuevo);
      s.kidSel = nuevo.id;
    } else {
      final antes = h.equipoId;
      h..nombre = n..nac = nac!..pie = pie..numero = num..zona = zonaK..zona2 = zona2..cat = categoria..nivel = nivel..equipoId = tid;
      if (antes != tid) s.limpiarEquipo(antes);
    }
    s.cambio();
    Navigator.pop(context);
    aviso(context, h == null ? '$n ya está en la familia' : 'Cambios guardados');
  }
}
