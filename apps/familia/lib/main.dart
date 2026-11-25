import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'estado.dart';
import 'pantallas/calendario.dart';
import 'pantallas/familia.dart';
import 'pantallas/inicio.dart';
import 'pantallas/progreso.dart';
import 'pantallas/terminos.dart';
import 'pantallas/vivo.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final estado = Estado(PersistenciaSqlite());
  await estado.cargar();
  runApp(FamiliaApp(estado: estado));
}

class FamiliaApp extends StatelessWidget {
  final Estado estado;
  const FamiliaApp({super.key, required this.estado});
  @override
  Widget build(BuildContext context) => EstadoScope(
        estado: estado,
        child: MaterialApp(
          title: 'FutData Familia',
          debugShowCheckedModeBanner: false,
          theme: temaFamilia(),
          themeMode: ThemeMode.light,
          home: const Raiz(),
        ),
      );
}

class Raiz extends StatelessWidget {
  const Raiz({super.key});
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    if (!s.cargado) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (s.f.legal == null) return const Terminos();
    if (s.f.live != null) return const EnVivo();
    return const Principal();
  }
}

class Principal extends StatefulWidget {
  const Principal({super.key});
  @override
  State<Principal> createState() => _PrincipalState();
}

class _PrincipalState extends State<Principal> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    final paginas = [Inicio(irA: (i) => setState(() => tab = i)), const Calendario(), const Progreso(), const FamiliaPantalla()];
    return Scaffold(
      body: SafeArea(bottom: false, child: IndexedStack(index: tab, children: paginas)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => setState(() => tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'Calendario'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Progreso'),
          NavigationDestination(icon: Icon(Icons.family_restroom_outlined), selectedIcon: Icon(Icons.family_restroom), label: 'Familia'),
        ],
      ),
    );
  }
}
