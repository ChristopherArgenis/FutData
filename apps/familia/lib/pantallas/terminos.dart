import 'package:material_ui/material_ui.dart';

import '../estado.dart';
import '../tema.dart';

const textoTerminos = '''FutData Familia te ayuda a llevar el registro deportivo de tus hijos: partidos, minutos jugados, entrenamientos y su progreso.

• Tú eres responsable de la información que registras. Al agregar a un menor declaras que eres su madre, padre o tutor.
• Solo guardamos datos deportivos (partidos, minutos, acciones, asistencia y notas). No registramos datos de salud ni lesiones.
• Tus datos se guardan en este teléfono. No los vendemos ni los compartimos con terceros.
• Hasta 2 adultos por familia. El segundo entra con un código de invitación de un solo uso que tú apruebas.
• Plan Premium: \$$precioPremium MXN al mes por hijo, con $diasPrueba días de prueba gratis (una vez por hijo). Se paga con tarjeta en nuestro sitio web; puedes cancelar cuando quieras.
• Puedes borrar todos tus datos en cualquier momento desde Familia › Borrar mis datos.''';

class Terminos extends StatefulWidget {
  const Terminos({super.key});
  @override
  State<Terminos> createState() => _TerminosState();
}

class _TerminosState extends State<Terminos> {
  bool acepto = false, datos = false, novedades = false, ejemplo = true;
  @override
  Widget build(BuildContext context) {
    final s = EstadoScope.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const SizedBox(height: 12),
          Row(children: [
            Container(width: 52, height: 52, alignment: Alignment.center, decoration: BoxDecoration(color: cFam, borderRadius: BorderRadius.circular(14)), child: const Text('FF', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20))),
            const SizedBox(width: 12),
            const Expanded(child: Text('Bienvenido a\nFutData Familia', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, height: 1.1))),
          ]),
          const SizedBox(height: 18),
          Tarjeta(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Términos y aviso de privacidad', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 4),
            const Text('Versión $versionLegal', style: TextStyle(color: cMu, fontSize: 12)),
            const SizedBox(height: 10),
            const Text(textoTerminos, style: TextStyle(height: 1.45)),
          ])),
          const SizedBox(height: 12),
          CheckboxListTile(value: acepto, onChanged: (v) => setState(() => acepto = v!), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, title: const Text('Acepto los Términos y Condiciones')),
          CheckboxListTile(value: datos, onChanged: (v) => setState(() => datos = v!), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, title: const Text('Doy mi consentimiento para registrar datos deportivos de mis hijos menores de edad')),
          CheckboxListTile(value: novedades, onChanged: (v) => setState(() => novedades = v!), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, title: const Text('Quiero recibir novedades (opcional)')),
          const Divider(height: 24),
          SwitchListTile(value: ejemplo, onChanged: (v) => setState(() => ejemplo = v), contentPadding: EdgeInsets.zero, title: const Text('Empezar con una familia de ejemplo'), subtitle: const Text('3 hijos con partidos y entrenos para probar todo. La puedes borrar después.')),
          const SizedBox(height: 12),
          FilledButton(
            key: const Key('aceptar'),
            onPressed: acepto && datos ? () => s.aceptar(ejemplo: ejemplo, novedades: novedades) : null,
            child: const Text('Aceptar y continuar'),
          ),
        ]),
      ),
    );
  }
}
