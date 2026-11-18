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
  insert into eventos(partido_id,equipo_id,tipo,minuto,jugador_id) values ('${ID.pA}','${ID.A}','LESION',40,'${ID.rivas}'), ('${ID.pA}','${ID.A}','LESION',55,'${ID.kevin}');
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
await caso(S2, 'Ve solo a su hijo en el plantel', U.padre, `select * from jugadores`, 1);
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

const SL = '4b · Lesiones (dato de salud)';
await caso(SL, 'El padre solo ve la lesión de su hijo', U.padre, `select * from eventos where tipo='LESION'`, 1);
await caso(SL, 'El jugador no ve lesiones de compañeros', U.jug, `select * from eventos where tipo='LESION'`, 0);
await caso(SL, 'El cuerpo técnico ve todas las lesiones', U.staff, `select * from eventos where tipo='LESION'`, 2);
await caso(SL, 'Todos siguen viendo los goles', U.padre, `select * from eventos where tipo='GOL'`, 2);
const S5 = '5 · Después de publicar la alineación';
await caso(S5, 'El padre ya ve la alineación', U.padre, `select * from alineaciones`, 2);
await caso(S5, 'El jugador ya ve la alineación', U.jug, `select * from alineaciones`, 2);

const S6 = '6 · Entrenador';
await caso(S6, 'Ve la suscripción de su equipo', U.ent, `select * from suscripciones`, 1);
await caso(S6, 'No puede activarse Premium por su cuenta (solo el servidor)', U.ent, `update suscripciones set plan='CLUB'`, 'error');
await caso(S6, 'Invita a un nuevo miembro del cuerpo técnico', U.ent, `insert into miembros_equipo(equipo_id,usuario_id,rol) values ('${ID.A}','${U.extra}','staff')`, 1);
await caso(S6, 'Puede borrar un partido (y sus eventos)', U.ent, `delete from partidos where id='${ID.pA}'`, 1);

const S7 = '7 · Inyección SQL y validación';
await caso(S7, 'Un nombre malicioso se guarda como texto, no se ejecuta', U.staff, `insert into jugadores(equipo_id,nombre,dorsal) values ($1,$2,22)`, 1, [ID.A, "x'); drop table partidos; --"]);
await caso(S7, 'La tabla partidos sigue existiendo', U.ent, `select count(*) from partidos`, 1);
await caso(S7, 'Rechaza minutos imposibles', U.staff, `insert into eventos(partido_id,equipo_id,tipo,minuto) values ('${ID.pA}','${ID.A}','GOL',500)`, 'error');
await caso(S7, 'Rechaza goles negativos', U.staff, `insert into partidos(equipo_id,rival,fecha_hora,goles_favor) values ('${ID.A}','X',now(),-3)`, 'error');
await caso(S7, 'Rechaza roles inventados', U.ent, `insert into miembros_equipo(equipo_id,usuario_id,rol) values ('${ID.A}','${U.entB}','admin')`, 'error');

// ---------- reporte ----------
let sec = '';
for (const r of resultados){ if (r.seccion!==sec){ sec = r.seccion; console.log(`\n${sec}`); }
  console.log(`  ${r.pasa ? '✓' : '✗'} ${r.desc}  [esperado: ${r.espera} · obtenido: ${r.obtenido}]`); }
console.log(`\n${resultados.length - fallos}/${resultados.length} pruebas pasaron.`);
process.exit(fallos ? 1 : 0);
