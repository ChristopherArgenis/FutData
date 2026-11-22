// Pruebas de seguridad de las políticas RLS (Postgres real en WASM con PGlite).
// Uso:  cd db/supabase && npm install && node test_rls.mjs
import { PGlite } from '@electric-sql/pglite';
import { readFileSync } from 'node:fs';

const db = new PGlite();
// Sustituto de lo que Supabase ya trae: roles y auth.uid() leído del JWT.
await db.exec(`
  create role anon nologin; create role authenticated nologin;
  create schema auth; grant usage on schema auth to authenticated, anon;
  create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
`);
await db.exec(readFileSync(new URL('./esquema_rls.sql', import.meta.url), 'utf8'));

// ---------- datos de prueba (como superusuario) ----------
const U = { ent:'00000000-0000-0000-0000-0000000000a1', staff:'00000000-0000-0000-0000-0000000000a2', jug:'00000000-0000-0000-0000-0000000000a3',
            padre:'00000000-0000-0000-0000-0000000000a4', entB:'00000000-0000-0000-0000-0000000000b1', extra:'00000000-0000-0000-0000-0000000000c1' };
const ID = { A:'10000000-0000-0000-0000-00000000000a', B:'10000000-0000-0000-0000-00000000000b', mora:'20000000-0000-0000-0000-000000000001',
             kevin:'20000000-0000-0000-0000-000000000002', rivas:'20000000-0000-0000-0000-000000000003', jugB:'20000000-0000-0000-0000-0000000000b1',
             pA:'30000000-0000-0000-0000-00000000000a', pB:'30000000-0000-0000-0000-00000000000b' };
await db.exec(`
  insert into equipos(id,nombre,propietario) values ('${ID.A}','Halcones FC','${U.ent}'), ('${ID.B}','Real Arenal','${U.entB}');
  insert into jugadores(id,equipo_id,nombre,dorsal,posicion) values
    ('${ID.mora}','${ID.A}','Emilio Mora',10,'MED'), ('${ID.kevin}','${ID.A}','Kevin Soto',6,'MED'), ('${ID.rivas}','${ID.A}','Marco Rivas',9,'DEL'),
    ('${ID.jugB}','${ID.B}','Jugador Rival',7,'DEL');
  insert into jugadores_privado values ('${ID.mora}','${ID.A}','664-111-1111','2001-05-02','Mamá Mora'), ('${ID.kevin}','${ID.A}','664-222-2222','2012-03-10','Laura Soto'),
    ('${ID.rivas}','${ID.A}','664-333-3333','2000-01-01','Papá Rivas');
  insert into miembros_equipo(equipo_id,usuario_id,rol,jugador_id) values
    ('${ID.A}','${U.staff}','staff',null), ('${ID.A}','${U.jug}','jugador','${ID.mora}'), ('${ID.A}','${U.padre}','padre','${ID.kevin}');
  insert into partidos(id,equipo_id,rival,fecha_hora) values ('${ID.pA}','${ID.A}','Atlético Valle', now() + interval '4 days'), ('${ID.pB}','${ID.B}','Otro', now());
  insert into convocatorias(partido_id,jugador_id,equipo_id,respuesta) values
    ('${ID.pA}','${ID.mora}','${ID.A}','PENDIENTE'), ('${ID.pA}','${ID.kevin}','${ID.A}','VOY'), ('${ID.pA}','${ID.rivas}','${ID.A}','VOY');
  insert into alineaciones values ('${ID.pA}','${ID.kevin}','${ID.A}','MED'), ('${ID.pA}','${ID.rivas}','${ID.A}','DEL');
  insert into eventos(partido_id,equipo_id,tipo,minuto,jugador_id) values ('${ID.pA}','${ID.A}','GOL',12,'${ID.rivas}');
  insert into suscripciones values ('${ID.A}','PREMIUM','activa', now() + interval '30 days');
`);

// ---------- ejecutar como un usuario ----------
async function como(user, sql, params=[]){
  await db.exec('reset role');
  await db.query(`select set_config('request.jwt.claim.sub', $1, false)`, [user || '']);
  await db.exec(user ? 'set role authenticated' : 'set role anon');
  try { const r = await db.query(sql, params); const lectura = /^\s*select/i.test(sql); return { ok:true, rows:r.rows, n: lectura ? r.rows.length : (r.affectedRows ?? 0) }; }
  catch (e) { return { ok:false, err:e.message }; }
  finally { await db.exec('reset role'); }
}
const resultados = []; let fallos = 0;
function caso_manual(seccion, desc, pasa, det){ if (!pasa) fallos++; resultados.push({seccion, desc, pasa, espera:'sí', obtenido: pasa ? 'sí' : `no ${det||''}`}); }
async function caso(seccion, desc, user, sql, espera, params){
  const r = await como(user, sql, params);
  let pasa, obtenido;
  if (espera === 'error'){ pasa = !r.ok; obtenido = r.ok ? `permitido (${r.n})` : 'bloqueado'; }
  else { pasa = r.ok && r.n === espera; obtenido = r.ok ? `${r.n} fila(s)` : `error: ${r.err}`; }
  if (!pasa) fallos++;
  resultados.push({ seccion, desc, pasa, espera: espera==='error' ? 'bloqueado' : `${espera} fila(s)`, obtenido });
}

const S1 = '1 · Aislamiento entre equipos y anónimos';
await caso(S1, 'Entrenador de otro equipo no ve nuestros partidos', U.entB, `select * from partidos where equipo_id='${ID.A}'`, 0);
await caso(S1, 'Entrenador de otro equipo no ve nuestro plantel', U.entB, `select * from jugadores where equipo_id='${ID.A}'`, 0);
await caso(S1, 'Entrenador de otro equipo no ve teléfonos de nuestros jugadores', U.entB, `select * from jugadores_privado`, 0);
await caso(S1, 'Entrenador de otro equipo no puede registrar eventos en nuestro partido', U.entB, `insert into eventos(partido_id,equipo_id,tipo,minuto) values ('${ID.pA}','${ID.A}','GOL',5)`, 'error');
await caso(S1, 'Entrenador de otro equipo no puede cambiar nuestro marcador', U.entB, `update partidos set goles_favor=0, goles_contra=9 where id='${ID.pA}'`, 0);
await caso(S1, 'Usuario registrado sin equipo no ve nada', U.extra, `select * from partidos`, 0);
await caso(S1, 'Usuario sin equipo no puede agregarse como entrenador', U.extra, `insert into miembros_equipo(equipo_id,usuario_id,rol) values ('${ID.A}','${U.extra}','entrenador',null)`, 'error');
await caso(S1, 'Visitante sin sesión no puede leer partidos', null, `select * from partidos`, 'error');
await caso(S1, 'Visitante sin sesión no puede leer jugadores', null, `select * from jugadores`, 'error');

const S2 = '2 · Padre / tutor';
await caso(S2, 'Ve el plantel del equipo (decisión: se conocen en persona)', U.padre, `select id,nombre,dorsal from jugadores`, 3);
await caso(S2, 'Ve solo los datos privados de su hijo', U.padre, `select * from jugadores_privado`, 1);
await caso(S2, 'Ve solo la convocatoria de su hijo', U.padre, `select * from convocatorias`, 1);
await caso(S2, 'Puede responder por su hijo', U.padre, `update convocatorias set respuesta='NO_VOY' where jugador_id='${ID.kevin}'`, 1);
await caso(S2, 'No puede responder por otro jugador', U.padre, `update convocatorias set respuesta='NO_VOY' where jugador_id='${ID.rivas}'`, 0);
await caso(S2, 'No puede marcar asistencia real', U.padre, `update convocatorias set asistio=true where jugador_id='${ID.kevin}'`, 'error');
await caso(S2, 'No puede mover la convocatoria a otro jugador', U.padre, `update convocatorias set jugador_id='${ID.rivas}' where jugador_id='${ID.kevin}'`, 'error');
await caso(S2, 'No ve la alineación mientras no se publica', U.padre, `select * from alineaciones`, 0);
await caso(S2, 'No ve la suscripción ni el pago', U.padre, `select * from suscripciones`, 0);
await caso(S2, 'No puede cambiar el marcador', U.padre, `update partidos set goles_favor=5`, 0);
await caso(S2, 'No puede borrar partidos', U.padre, `delete from partidos`, 0);
await caso(S2, 'No puede registrar goles', U.padre, `insert into eventos(partido_id,equipo_id,tipo,minuto) values ('${ID.pA}','${ID.A}','GOL',5)`, 'error');
await caso(S2, 'No puede ascenderse a entrenador', U.padre, `update miembros_equipo set rol='entrenador', jugador_id=null where usuario_id='${U.padre}'`, 0);
await caso(S2, 'Solo ve su propia membresía, no la de otros', U.padre, `select * from miembros_equipo`, 1);

const S3 = '3 · Jugador';
await caso(S3, 'Ve el plantel completo (nombre, dorsal, posición)', U.jug, `select id,nombre,dorsal from jugadores`, 3);
await caso(S3, 'Solo ve sus propios datos privados', U.jug, `select * from jugadores_privado`, 1);
await caso(S3, 'Ve quién va, duda o no va', U.jug, `select * from convocatorias`, 3);
await caso(S3, 'Puede responder su asistencia', U.jug, `update convocatorias set respuesta='VOY' where jugador_id='${ID.mora}'`, 1);
await caso(S3, 'No puede responder por un compañero', U.jug, `update convocatorias set respuesta='NO_VOY' where jugador_id='${ID.rivas}'`, 0);
await caso(S3, 'No puede crear convocatoria a nombre de otro', U.jug, `insert into convocatorias(partido_id,jugador_id,equipo_id,respuesta) values ('${ID.pA}','${ID.rivas}','${ID.A}','NO_VOY') on conflict do nothing`, 'error');
await caso(S3, 'No puede registrar goles', U.jug, `insert into eventos(partido_id,equipo_id,tipo,minuto,jugador_id) values ('${ID.pA}','${ID.A}','GOL',90,'${ID.mora}')`, 'error');
await caso(S3, 'No puede publicar la alineación', U.jug, `update partidos set alineacion_publicada=true`, 0);
await caso(S3, 'No ve la suscripción', U.jug, `select * from suscripciones`, 0);

const S4 = '4 · Cuerpo técnico';
await caso(S4, 'Registra goles', U.staff, `insert into eventos(partido_id,equipo_id,tipo,minuto,jugador_id) values ('${ID.pA}','${ID.A}','GOL',30,'${ID.mora}')`, 1);
await caso(S4, 'Corrige el marcador', U.staff, `update partidos set goles_favor=2, goles_contra=0 where id='${ID.pA}'`, 1);
await caso(S4, 'Marca asistencia real', U.staff, `update convocatorias set asistio=true where jugador_id='${ID.kevin}'`, 1);
await caso(S4, 'Ve los datos de contacto del plantel', U.staff, `select * from jugadores_privado`, 3);
await caso(S4, 'Publica la alineación', U.staff, `update partidos set alineacion_publicada=true where id='${ID.pA}'`, 1);
await caso(S4, 'No puede borrar partidos', U.staff, `delete from partidos where id='${ID.pA}'`, 0);
await caso(S4, 'No puede borrar jugadores', U.staff, `delete from jugadores where id='${ID.rivas}'`, 0);
await caso(S4, 'No ve la suscripción', U.staff, `select * from suscripciones`, 0);
await caso(S4, 'No puede invitar miembros ni cambiar roles', U.staff, `insert into miembros_equipo(equipo_id,usuario_id,rol) values ('${ID.A}','${U.extra}','staff')`, 'error');
await caso(S4, 'No puede colgar un evento de un partido de otro equipo', U.staff, `insert into eventos(partido_id,equipo_id,tipo,minuto) values ('${ID.pB}','${ID.A}','GOL',5)`, 'error');
await caso(S4, 'No puede escribir con el equipo_id de otro equipo', U.staff, `insert into eventos(partido_id,equipo_id,tipo,minuto) values ('${ID.pB}','${ID.B}','GOL',5)`, 'error');

const S5 = '5 · Después de publicar la alineación';
await caso(S5, 'El padre ya ve la alineación', U.padre, `select * from alineaciones`, 2);
await caso(S5, 'El jugador ya ve la alineación', U.jug, `select * from alineaciones`, 2);

const S6 = '6 · Entrenador';
await caso(S6, 'Ve la suscripción de su equipo', U.ent, `select * from suscripciones`, 1);
await caso(S6, 'No puede activarse Premium por su cuenta (solo el servidor)', U.ent, `update suscripciones set plan='CLUB'`, 'error');
await caso(S6, 'Ni el entrenador puede dar acceso directo: solo por invitación', U.ent, `insert into miembros_equipo(equipo_id,usuario_id,rol) values ('${ID.A}','${U.extra}','staff')`, 'error');
await caso(S6, 'Puede borrar un partido (y sus eventos)', U.ent, `delete from partidos where id='${ID.pA}'`, 1);

const S7 = '7 · Inyección SQL y validación';
await caso(S7, 'Un nombre malicioso se guarda como texto, no se ejecuta', U.staff, `insert into jugadores(equipo_id,nombre,dorsal) values ($1,$2,22)`, 1, [ID.A, "x'); drop table partidos; --"]);
await caso(S7, 'La tabla partidos sigue existiendo', U.ent, `select count(*) from partidos`, 1);
await caso(S7, 'Rechaza minutos imposibles', U.staff, `insert into eventos(partido_id,equipo_id,tipo,minuto) values ('${ID.pA}','${ID.A}','GOL',500)`, 'error');
await caso(S7, 'Rechaza goles negativos', U.staff, `insert into partidos(equipo_id,rival,fecha_hora,goles_favor) values ('${ID.A}','X',now(),-3)`, 'error');
await caso(S7, 'Rechaza eventos de lesión (ya no se registran)', U.staff, `insert into eventos(partido_id,equipo_id,tipo,minuto) values ('${ID.pB}','${ID.B}','LESION',5)`, 'error');
await caso(S7, 'Rechaza roles inventados', U.ent, `insert into miembros_equipo(equipo_id,usuario_id,rol) values ('${ID.A}','${U.entB}','admin')`, 'error');

const S8 = '8 · Credenciales: invitaciones, canje y aprobación';
const NUEVO = '00000000-0000-0000-0000-0000000000d1', OTRO = '00000000-0000-0000-0000-0000000000d2', ATAC = '00000000-0000-0000-0000-0000000000d3';
const inv = async (user, rol, jug, horas=72) => como(user, `select crear_invitacion($1,$2,$3,'prueba',$4) as c`, [ID.A, rol, jug, horas]);
await caso(S8, 'El cuerpo técnico no puede crear invitaciones', U.staff, `select crear_invitacion('${ID.A}','staff',null,'x',72)`, 'error');
await caso(S8, 'Un jugador no puede crear invitaciones', U.jug, `select crear_invitacion('${ID.A}','staff',null,'x',72)`, 'error');
await caso(S8, 'Un padre no puede crear invitaciones', U.padre, `select crear_invitacion('${ID.A}','padre','${ID.kevin}','x',72)`, 'error');
await caso(S8, 'Nadie puede invitar a alguien como entrenador', U.ent, `select crear_invitacion('${ID.A}','entrenador',null,'x',72)`, 'error');
await caso(S8, 'No se permiten vigencias de más de 7 días', U.ent, `select crear_invitacion('${ID.A}','staff',null,'x',720)`, 'error');
await caso(S8, 'El entrenador de otro equipo no puede invitar al nuestro', U.entB, `select crear_invitacion('${ID.A}','staff',null,'x',72)`, 'error');
await caso(S8, 'No se puede invitar como jugador a quien ya tiene cuenta', U.ent, `select crear_invitacion('${ID.A}','jugador','${ID.mora}','x',72)`, 'error');
const r1 = await inv(U.ent, 'padre', ID.rivas); const code = r1.rows?.[0]?.c;
caso_manual(S8, 'El entrenador crea una invitación con formato FUT-XXXXX-XXXXX', /^FUT-[A-HJ-NP-Z2-9]{5}-[A-HJ-NP-Z2-9]{5}$/.test(code||''), code);
const guardado = (await como(U.ent, `select * from invitaciones where para='prueba'`)).rows?.[0] || {};
caso_manual(S8, 'La base guarda solo el hash, nunca el código', !JSON.stringify(guardado).includes(code) && /^[0-9a-f]{64}$/.test(guardado.codigo_hash||''));
await caso(S8, 'Un jugador no puede leer las invitaciones ni sus hashes', U.jug, `select * from invitaciones`, 0);
await inv(U.ent, 'padre', ID.rivas);
await caso(S8, 'Máximo 2 tutores por jugador', U.ent, `select crear_invitacion('${ID.A}','padre','${ID.rivas}','x',72)`, 'error');
await caso(S8, 'Sin sesión no se puede canjear', null, `select canjear_invitacion('${code}')`, 'error');
for (let k=0; k<5; k++) await como(ATAC, `select canjear_invitacion($1)`, ['FUT-AAAAA-AAAA' + 'BCDEF'[k]]);
await caso(S8, 'Tras 5 intentos fallidos se bloquea, aun con el código correcto', ATAC, `select canjear_invitacion('${code}')`, 'error');
await caso(S8, 'Un código con espacios o minúsculas se reconoce igual', NUEVO, `select canjear_invitacion($1) as m`, 1, ['  ' + code.toLowerCase() + ' ']);
await caso(S8, 'Quien canjea queda “por aprobar”, con el rol y jugador de la invitación', U.ent, `select * from miembros_equipo where usuario_id='${NUEVO}' and estado='por_aprobar' and rol='padre' and jugador_id='${ID.rivas}'`, 1);
await caso(S8, 'Mientras no lo aprueben, no ve nada del equipo', NUEVO, `select * from jugadores`, 0);
const reuso = await como(OTRO, `select canjear_invitacion($1) as m`, [code]);
caso_manual(S8, 'Un código no sirve dos veces', reuso.ok && reuso.rows[0].m === null);
await caso(S8, 'Quien canjeó no puede aprobarse a sí mismo', NUEVO, `select resolver_miembro((select id from miembros_equipo where usuario_id='${NUEVO}'), true)`, 'error');
await caso(S8, 'Quien canjeó no puede cambiarse el rol', NUEVO, `update miembros_equipo set rol='staff', jugador_id=null where usuario_id='${NUEVO}'`, 0);
await caso(S8, 'El cuerpo técnico no puede aprobar', U.staff, `select resolver_miembro((select id from miembros_equipo where usuario_id='${NUEVO}'), true)`, 'error');
await caso(S8, 'El entrenador de otro equipo no puede aprobar', U.entB, `select resolver_miembro('${'00000000-0000-0000-0000-000000000000'}', true)`, 'error');
await caso(S8, 'El entrenador aprueba', U.ent, `select resolver_miembro((select id from miembros_equipo where usuario_id='${NUEVO}'), true)`, 1);
await caso(S8, 'Ya aprobado, ve el equipo y su plantel', NUEVO, `select * from equipos e join jugadores j on j.equipo_id = e.id where e.id='${ID.A}' limit 1`, 1);
await db.exec(`update invitaciones set expira_en = now() - interval '1 minute', creada_en = now() - interval '2 days' where para='prueba' and usada_en is null`);
const vencido = (await como(U.ent, `select crear_invitacion($1,'staff',null,'vence',24) as c`, [ID.A])).rows[0].c;
await db.exec(`update invitaciones set expira_en = now() - interval '1 minute', creada_en = now() - interval '2 days' where para='vence'`);
const rv = await como(OTRO, `select canjear_invitacion($1) as m`, [vencido]);
caso_manual(S8, 'Un código vencido no sirve', rv.ok && rv.rows[0].m === null);
const revocado = (await como(U.ent, `select crear_invitacion($1,'staff',null,'revocar',24) as c`, [ID.A])).rows[0].c;
await caso(S8, 'El entrenador revoca una invitación', U.ent, `update invitaciones set revocada_en = now() where para='revocar'`, 1);
const rr = await como(OTRO, `select canjear_invitacion($1) as m`, [revocado]);
caso_manual(S8, 'Un código revocado no sirve', rr.ok && rr.rows[0].m === null);
await caso(S8, 'Quitar a un miembro le corta el acceso de inmediato', U.ent, `update miembros_equipo set estado='quitado' where usuario_id='${NUEVO}'`, 1);
await caso(S8, 'Ya quitado, no ve nada', NUEVO, `select * from jugadores`, 0);
await caso(S8, 'Cada aceptación de términos queda registrada', U.padre, `insert into consentimientos(usuario_id,tipo,version) values ('${U.padre}','tutor','1.0')`, 1);
await caso(S8, 'Nadie puede registrar consentimientos a nombre de otro', U.ent, `insert into consentimientos(usuario_id,tipo,version) values ('${U.padre}','tutor','1.0')`, 'error');
await caso(S8, 'Solo el entrenador ve el registro de accesos', U.staff, `select * from auditoria`, 0);
await caso(S8, 'El entrenador ve el registro de accesos', U.ent, `select * from auditoria where accion='miembro_aprobado'`, 1);

// ---------- reporte ----------
let sec = '';
for (const r of resultados){ if (r.seccion!==sec){ sec = r.seccion; console.log(`\n${sec}`); }
  console.log(`  ${r.pasa ? '✓' : '✗'} ${r.desc}  [esperado: ${r.espera} · obtenido: ${r.obtenido}]`); }
console.log(`\n${resultados.length - fallos}/${resultados.length} pruebas pasaron.`);
process.exit(fallos ? 1 : 0);
