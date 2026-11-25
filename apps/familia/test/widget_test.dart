import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:futdata_familia/estado.dart';
import 'package:futdata_familia/main.dart';
import 'package:futdata_familia/modelo.dart';
import 'package:futdata_familia/semilla.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('familia de ejemplo se guarda y se lee igual (JSON)', () {
    final f = familiaDeEjemplo();
    final j = jsonEncode(f.toJson());
    final g = Familia.fromJson(jsonDecode(j));
    expect(jsonEncode(g.toJson()), j);
    expect(g.hijos.length, 3);
  });

  test('en vivo: minutos por hijo, gol con asistencia, deshacer y final', () async {
    final s = Estado(PersistenciaMemoria());
    await s.cargar();
    s.aceptar(ejemplo: true, novedades: false);
    final x = s.partido('pf1')!; // Tigres: Mateo (k1) y Leo (k3)
    s.iniciarLive(x, {'k1': KidLive(), 'k3': KidLive(on: false)}, 60);
    s.liveCorrer();
    s.f.live!.seg = 600; s.f.live!.t0 = DateTime.now().millisecondsSinceEpoch; // minuto 10
    expect(s.minKid('k1').round(), 10);
    expect(s.minKid('k3'), 0);
    s.liveEntraSale('k3'); // Leo entra al 10
    final asis = s.liveStat('k1', 'gol');
    expect(asis, ['k3']);
    s.liveAsistencia('k3');
    expect(x.gf, 1);
    s.liveDeshacer(); // quita asistencia y gol
    expect(x.gf, 0);
    expect(x.part['k1']!.stat('gol'), 0);
    s.liveStat('k1', 'gol');
    s.liveEquipo(false);
    expect(x.gc, 1);
    s.f.live!.seg = 1500; s.f.live!.t0 = DateTime.now().millisecondsSinceEpoch; // minuto 25
    s.liveMedioTiempo();
    s.liveSegundoTiempo();
    s.f.live!.seg = 1500; s.f.live!.t0 = DateTime.now().millisecondsSinceEpoch;
    s.liveTerminar();
    expect(s.live, isNull);
    expect(x.finalizado, isTrue);
    expect(x.part['k1']!.minutos, 50);
    expect(x.part['k3']!.minutos, 40);
    expect(x.part['k1']!.stat('gol'), 1);
  });

  test('máximo 4 hijos y prueba una sola vez', () async {
    final s = Estado(PersistenciaMemoria());
    await s.cargar();
    s.aceptar(ejemplo: true, novedades: false);
    final sofia = s.hijo('k2')!;
    s.plan(sofia, 'prueba');
    expect(s.tieneAnalisis(sofia), isTrue);
    sofia.plan.estado = 'gratis';
    s.plan(sofia, 'prueba');
    expect(sofia.plan.estado, 'gratis');
    expect(s.invitar(), isFalse); // ya hay 2 adultos
    s.quitarHijo('k2');
    expect(s.equipo('t2'), isNull); // su equipo queda sin hijos y se borra
  });

  testWidgets('términos → inicio → progreso → familia', (t) async {
    t.view.physicalSize = const Size(1200, 4800);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final s = Estado(PersistenciaMemoria());
    await s.cargar();
    await t.pumpWidget(FamiliaApp(estado: s));
    await t.pump();
    final lista = find.byType(Scrollable).first;
    await t.scrollUntilVisible(find.text('Acepto los Términos y Condiciones'), 300, scrollable: lista);
    await t.tap(find.text('Acepto los Términos y Condiciones'));
    await t.scrollUntilVisible(find.textContaining('Doy mi consentimiento'), 300, scrollable: lista);
    await t.tap(find.textContaining('Doy mi consentimiento'));
    await t.pump();
    await t.scrollUntilVisible(find.byKey(const Key('aceptar')), 300, scrollable: lista);
    await t.tap(find.byKey(const Key('aceptar')));
    await t.pumpAndSettle();
    expect(find.textContaining('Hola'), findsOneWidget);
    await t.tap(find.text('Progreso'));
    await t.pumpAndSettle();
    expect(find.text('Temporada'.toUpperCase()), findsOneWidget);
    await t.tap(find.text('Calendario').last);
    await t.pumpAndSettle();
    await t.tap(find.text('Familia').last);
    await t.pumpAndSettle();
    expect(find.text('Mateo Ruiz'), findsOneWidget);
    await t.tap(find.byKey(const Key('agregarHijo')));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(find.text('¿Juega en el mismo equipo que alguno de sus hermanos?'), 300, scrollable: find.byType(Scrollable).last);
    expect(find.text('¿Juega en el mismo equipo que alguno de sus hermanos?'), findsOneWidget);
    await s.guardarYa();
  });

  testWidgets('en vivo desde la pantalla y alta de hijo', (t) async {
    t.view.physicalSize = const Size(1200, 2700);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final s = Estado(PersistenciaMemoria());
    await s.cargar();
    s.aceptar(ejemplo: true, novedades: false);
    await t.pumpWidget(FamiliaApp(estado: s));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'paso 1');
    await t.tap(find.text('Registrar en vivo').first);
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'paso 2');
    await t.scrollUntilVisible(find.byKey(const Key('empezarVivo')), 300, scrollable: find.byType(Scrollable).last);
    await t.tap(find.byKey(const Key('empezarVivo')));
    await t.pump();
    expect(t.takeException(), isNull, reason: 'paso 3');
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull, reason: 'paso 4');
    expect(find.text('● EN VIVO'), findsOneWidget);
    await t.tap(find.byKey(const Key('reloj')));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull, reason: 'paso 5');
    final main = s.hijo(s.live!.sel!)!;
    await t.tap(find.byKey(Key('st_${mainStat[main.pos]}')));
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull, reason: 'paso 6');
    if (find.text('Otro compañero / nadie').evaluate().isNotEmpty) {
      await t.tap(find.text('Otro compañero / nadie'));
      await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull, reason: 'paso 7');
    }
    await t.tap(find.byKey(const Key('golRival')));
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull, reason: 'paso 8');
    await t.tap(find.byKey(const Key('entraSale')));
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull, reason: 'paso 9');
    s.liveMedioTiempo();
    s.liveSegundoTiempo();
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull, reason: 'paso 10');
    await t.tap(find.byKey(const Key('terminar')));
    await t.pump(const Duration(milliseconds: 600));
    expect(t.takeException(), isNull, reason: 'paso 11');
    await t.tap(find.text('Terminar'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'paso 12');
    expect(s.live, isNull);
    expect(find.text('Partido'), findsOneWidget);
    await t.pageBack();
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'paso 13');
    for (final tab in ['Calendario', 'Progreso', 'Familia']) {
      await t.tap(find.text(tab).last);
      await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'paso 14');
    }
    await t.tap(find.byKey(const Key('agregarHijo')));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull, reason: 'paso 15');
    await t.enterText(find.byKey(const Key('nombreHijo')), 'Ana Ruiz');
    s.f.hijos.length; // sigue en 3
    final form = find.byType(Scrollable).last;
    await t.tap(find.byKey(const Key('zona_DEL')));
    await t.pump();
    expect(t.takeException(), isNull, reason: 'paso 16');
    await t.scrollUntilVisible(find.text('Sub-11'), 200, scrollable: form);
    await t.tap(find.text('Sub-11'));
    await t.scrollUntilVisible(find.textContaining('Tigres FC (con'), 200, scrollable: form);
    await t.tap(find.textContaining('Tigres FC (con'));
    await t.pump();
    expect(t.takeException(), isNull, reason: 'paso 17');
    // sin fecha de nacimiento no deja guardar
    await t.scrollUntilVisible(find.byKey(const Key('guardarHijo')), 200, scrollable: form);
    await t.tap(find.byKey(const Key('guardarHijo')));
    await t.pump();
    expect(t.takeException(), isNull, reason: 'paso 18');
    expect(s.f.hijos.length, 3);
  });
}
