# FutData · Credenciales: cómo se crean y se entregan los accesos

**Regla principal:** el entrenador **no crea ni conoce contraseñas**. Entrega **invitaciones**. Cada persona crea su propia
cuenta y el entrenador aprueba que sea quien debe ser. Así, si el mensaje llega a quien no debe, esa persona no entra.

## Flujo

```mermaid
sequenceDiagram
  participant E as Entrenador
  participant S as Servidor (Supabase)
  participant P as Persona invitada
  E->>S: crear_invitacion(rol, jugador, vigencia)
  S-->>E: Código FUT-XXXXX-XXXXX (se muestra una sola vez; se guarda solo su hash)
  E->>P: Mensaje privado (WhatsApp/SMS) con código o QR
  P->>S: Crea su cuenta (correo o teléfono + código de verificación)
  P->>S: canjear_invitacion(código)
  S-->>P: Queda "por aprobar" (sin acceso todavía)
  S-->>E: Aviso: "Laura Soto canjeó la invitación de tutor de Kevin"
  E->>S: resolver_miembro(aprobar)
  S-->>P: Acceso activo con el rol y jugador de la invitación
```

## Reglas (implementadas y probadas en `db/supabase/esquema_rls.sql`)

| Regla | Por qué |
|---|---|
| Solo el entrenador crea invitaciones, aprueba, rechaza y quita accesos | Son las llaves del equipo y de datos de menores |
| Nadie puede invitar como “entrenador”; ni el entrenador puede dar acceso directo sin invitación | Evita escalar privilegios y atajos inseguros |
| La invitación fija el **rol** y, para jugador o padre, el **jugador**; quien canjea no puede cambiarlos | Un código de “padre de Kevin” no sirve para ver a otro niño ni para ser cuerpo técnico |
| Un solo uso; vence en 24 h, 3 días o 7 días (máximo 7) | Un código viejo o reenviado no sirve |
| Al canjear queda **por aprobar** y no ve nada hasta que el entrenador aprueba | Si el código se filtró a un grupo, el intruso queda en espera y se rechaza |
| Se guarda solo el **hash SHA-256** del código, nunca el código | Ni con acceso a la base se pueden reutilizar códigos |
| 5 intentos fallidos por hora → bloqueo; la respuesta es la misma para inexistente, usado, revocado o vencido | Impide adivinar códigos y no da pistas |
| Códigos de 10 caracteres sin letras confusas (sin O/0, I/1/L): `FUT-K7Q2M-X9PTA` | Fácil de dictar; ~50 bits de azar más el bloqueo |
| Máximo 1 cuenta de jugador por jugador y 2 tutores por jugador | Evita cuentas duplicadas o de terceros |
| Quitar a alguien corta su acceso de inmediato | Las reglas se evalúan en cada consulta |
| Todo queda en el **registro de accesos** (crear, canjear, aprobar, rechazar, quitar) | Saber quién hizo qué y cuándo |

## Recomendaciones para la app real

1. **Cuenta de cada persona:** inicio sin contraseña (código por correo o SMS), o *Iniciar sesión con Apple / Google*. Sin contraseñas que se olviden o se compartan.
2. **Entrenador con doble verificación:** además del correo, una llave de acceso (*passkey*) o app autenticadora. Es la cuenta más valiosa.
3. **Enviar por privado:** la app muestra el aviso “nunca en el grupo del equipo” y comparte con el menú del teléfono (WhatsApp, SMS) o QR en persona.
4. **Invitación ligada al contacto (opcional):** si el entrenador escribe el correo o teléfono del invitado, el código solo funciona con una cuenta verificada con ese contacto.
5. **Menores de 13 años:** no tienen cuenta; los representa su tutor. De 13 a 17, el tutor confirma la cuenta.
6. **Sesiones:** tokens cortos (1 h) con renovación; al quitar a alguien se revocan sus sesiones. Pantalla “Dispositivos conectados” para el entrenador.
7. **Cambio de dueño:** “Transferir equipo” a otro entrenador, con confirmación de ambos y aviso al cuerpo técnico; sin esto el entrenador no puede borrar su cuenta.
8. **Avisos:** notificar al entrenador cada canje y cada intento bloqueado.
9. **Revisión periódica:** cada temporada, la app sugiere quitar accesos de quien ya no está en el equipo.
