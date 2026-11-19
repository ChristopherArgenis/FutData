-- =====================================================================
-- FutData · Esquema en la nube (Postgres / Supabase) con Row Level Security
--
-- Aplica en el servidor la matriz de permisos de docs/ARQUITECTURA.md (4b).
-- La app oculta pantallas según el rol, pero la protección real está aquí:
-- aunque alguien modifique la app o llame a la API directo, la base de datos
-- solo le devuelve y le deja cambiar lo que su rol permite.
--
-- Requiere auth.uid() (lo da Supabase). Las pruebas usan un sustituto.
-- =====================================================================

-- ---------- tablas ----------
create table equipos (
  id            uuid primary key default gen_random_uuid(),
  nombre        text not null check (length(nombre) between 1 and 80),
  propietario   uuid not null,
  creado_en     timestamptz not null default now()
);

create table miembros_equipo (
  id            uuid primary key default gen_random_uuid(),
  equipo_id     uuid not null references equipos(id) on delete cascade,
  usuario_id    uuid not null,
  rol           text not null check (rol in ('entrenador','staff','jugador','padre')),
  jugador_id    uuid,                         -- jugador: él mismo · padre: su hijo
  estado        text not null default 'activo' check (estado in ('por_aprobar','activo','rechazado','quitado')),
  invitacion_id uuid,
  desde         timestamptz not null default now(),
  unique (equipo_id, usuario_id, jugador_id),
  check ((rol in ('jugador','padre')) = (jugador_id is not null))
);

create table jugadores (
  id            uuid primary key default gen_random_uuid(),
  equipo_id     uuid not null references equipos(id) on delete cascade,
  nombre        text not null check (length(nombre) between 1 and 80),
  dorsal        int check (dorsal between 0 and 99),
  posicion      text check (posicion in ('POR','DEF','MED','DEL')),
  unique (id, equipo_id)
);
alter table miembros_equipo add foreign key (jugador_id, equipo_id) references jugadores(id, equipo_id);

-- Datos sensibles separados: solo cuerpo técnico, el propio jugador y su tutor.
create table jugadores_privado (
  jugador_id    uuid primary key,
  equipo_id     uuid not null,
  telefono      text,
  fecha_nacimiento date,
  contacto_emergencia text,
  foreign key (jugador_id, equipo_id) references jugadores(id, equipo_id) on delete cascade
);

create table partidos (
  id            uuid primary key default gen_random_uuid(),
  equipo_id     uuid not null references equipos(id) on delete cascade,
  rival         text not null,
  fecha_hora    timestamptz not null,
  estado        text not null default 'PROGRAMADO' check (estado in ('PROGRAMADO','EN_JUEGO','FINALIZADO','CANCELADO')),
  goles_favor   int check (goles_favor >= 0),
  goles_contra  int check (goles_contra >= 0),
  alineacion_publicada boolean not null default false,
  unique (id, equipo_id)
);

-- equipo_id repetido + FK compuesta: impide colgar un evento de un partido de otro equipo.
create table eventos (
  id            uuid primary key default gen_random_uuid(),
  partido_id    uuid not null,
  equipo_id     uuid not null,
  tipo          text not null check (tipo in ('GOL','AUTOGOL','TARJETA_AMARILLA','TARJETA_ROJA','CAMBIO','LESION','TIRO')),
  minuto        int not null check (minuto between 0 and 130),
  jugador_id    uuid,
  foreign key (partido_id, equipo_id) references partidos(id, equipo_id) on delete cascade
);

create table convocatorias (
  partido_id    uuid not null,
  jugador_id    uuid not null,
  equipo_id     uuid not null,
  respuesta     text not null default 'PENDIENTE' check (respuesta in ('PENDIENTE','VOY','NO_VOY','DUDA')),
  asistio       boolean,                      -- lo marca el cuerpo técnico
  primary key (partido_id, jugador_id),
  foreign key (partido_id, equipo_id) references partidos(id, equipo_id) on delete cascade,
  foreign key (jugador_id, equipo_id) references jugadores(id, equipo_id) on delete cascade
);

create table alineaciones (
  partido_id    uuid not null,
  jugador_id    uuid not null,
  equipo_id     uuid not null,
  posicion      text,
  primary key (partido_id, jugador_id),
  foreign key (partido_id, equipo_id) references partidos(id, equipo_id) on delete cascade,
  foreign key (jugador_id, equipo_id) references jugadores(id, equipo_id) on delete cascade
);

create table suscripciones (
  equipo_id     uuid primary key references equipos(id) on delete cascade,
  plan          text not null check (plan in ('GRATIS','PREMIUM','CLUB')),
  estado        text not null,
  renueva_en    timestamptz
);

-- ---------- funciones de apoyo (security definer: leen membresías sin abrir la tabla) ----------
create function fn_rol(eq uuid) returns text language sql stable security definer set search_path = public as $$
  select rol from miembros_equipo where equipo_id = eq and usuario_id = auth.uid() and estado = 'activo'
  order by case rol when 'entrenador' then 1 when 'staff' then 2 when 'jugador' then 3 else 4 end limit 1 $$;
create function fn_es_miembro(eq uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from miembros_equipo where equipo_id = eq and usuario_id = auth.uid() and estado = 'activo') $$;
create function fn_es_staff(eq uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(fn_rol(eq) in ('entrenador','staff'), false) $$;
create function fn_es_entrenador(eq uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(fn_rol(eq) = 'entrenador', false) $$;
create function fn_ve_plantel(eq uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from miembros_equipo where equipo_id = eq and usuario_id = auth.uid() and estado = 'activo' and rol in ('entrenador','staff','jugador')) $$;
create function fn_es_mio(jug uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from miembros_equipo where jugador_id = jug and usuario_id = auth.uid() and estado = 'activo' and rol in ('jugador','padre')) $$;

-- Quien crea el equipo queda como entrenador.
create function fn_equipo_nuevo() returns trigger language plpgsql security definer set search_path = public as $$
begin insert into miembros_equipo(equipo_id, usuario_id, rol) values (new.id, new.propietario, 'entrenador'); return new; end $$;
create trigger tr_equipo_nuevo after insert on equipos for each row execute function fn_equipo_nuevo();

-- Jugador/padre solo cambian su respuesta, no si asistió ni de qué partido es.
create function fn_convocatoria_guardia() returns trigger language plpgsql as $$
begin
  if not fn_es_staff(old.equipo_id) and (new.asistio is distinct from old.asistio
     or new.partido_id <> old.partido_id or new.jugador_id <> old.jugador_id or new.equipo_id <> old.equipo_id) then
    raise exception 'Solo el cuerpo técnico puede cambiar asistencia o datos de la convocatoria';
  end if; return new; end $$;
create trigger tr_convocatoria_guardia before update on convocatorias for each row execute function fn_convocatoria_guardia();

-- ---------- RLS ----------
alter table equipos           enable row level security;
alter table miembros_equipo   enable row level security;
alter table jugadores         enable row level security;
alter table jugadores_privado enable row level security;
alter table partidos          enable row level security;
alter table eventos           enable row level security;
alter table convocatorias     enable row level security;
alter table alineaciones      enable row level security;
alter table suscripciones     enable row level security;

-- equipos
create policy eq_sel on equipos for select to authenticated using (fn_es_miembro(id));
create policy eq_ins on equipos for insert to authenticated with check (propietario = auth.uid());
create policy eq_upd on equipos for update to authenticated using (fn_es_entrenador(id)) with check (fn_es_entrenador(id));
create policy eq_del on equipos for delete to authenticated using (fn_es_entrenador(id));

-- membresías: el cuerpo técnico ve a todos; los demás solo su propia membresía. Solo el entrenador invita o cambia roles.
create policy mi_sel on miembros_equipo for select to authenticated using (fn_es_staff(equipo_id) or usuario_id = auth.uid());
-- Nadie inserta membresías directo: se entra por invitación (fn_canjear_invitacion) y aprobación del entrenador.
create policy mi_ins on miembros_equipo for insert to authenticated with check (false);
create policy mi_upd on miembros_equipo for update to authenticated using (fn_es_entrenador(equipo_id)) with check (fn_es_entrenador(equipo_id));
create policy mi_del on miembros_equipo for delete to authenticated using (fn_es_entrenador(equipo_id));

-- plantel (nombre, dorsal, posición): todos los miembros activos. Los datos de contacto van aparte.
create policy ju_sel on jugadores for select to authenticated using (fn_es_miembro(equipo_id));
create policy ju_ins on jugadores for insert to authenticated with check (fn_es_staff(equipo_id));
create policy ju_upd on jugadores for update to authenticated using (fn_es_staff(equipo_id)) with check (fn_es_staff(equipo_id));
create policy ju_del on jugadores for delete to authenticated using (fn_es_entrenador(equipo_id));

-- datos privados: cuerpo técnico, y cada jugador/tutor solo los suyos.
create policy jp_sel on jugadores_privado for select to authenticated using (fn_es_staff(equipo_id) or fn_es_mio(jugador_id));
create policy jp_ins on jugadores_privado for insert to authenticated with check (fn_es_staff(equipo_id));
create policy jp_upd on jugadores_privado for update to authenticated using (fn_es_staff(equipo_id) or fn_es_mio(jugador_id)) with check (fn_es_staff(equipo_id) or fn_es_mio(jugador_id));
create policy jp_del on jugadores_privado for delete to authenticated using (fn_es_entrenador(equipo_id));

-- partidos: todos los miembros ven; staff programa y registra; solo entrenador borra.
create policy pa_sel on partidos for select to authenticated using (fn_es_miembro(equipo_id));
create policy pa_ins on partidos for insert to authenticated with check (fn_es_staff(equipo_id));
create policy pa_upd on partidos for update to authenticated using (fn_es_staff(equipo_id)) with check (fn_es_staff(equipo_id));
create policy pa_del on partidos for delete to authenticated using (fn_es_entrenador(equipo_id));

-- eventos (goles, tarjetas, cambios, lesiones): públicos para el equipo; staff los registra y corrige.
-- Eventos, incluidas lesiones, visibles para el equipo: así todos saben de ausencias.
-- Requiere consentimiento expreso de datos de salud (tabla consentimientos, tipo 'salud').
create policy ev_sel on eventos for select to authenticated using (fn_es_miembro(equipo_id));
create policy ev_ins on eventos for insert to authenticated with check (fn_es_staff(equipo_id));
create policy ev_upd on eventos for update to authenticated using (fn_es_staff(equipo_id)) with check (fn_es_staff(equipo_id));
create policy ev_del on eventos for delete to authenticated using (fn_es_staff(equipo_id));

-- convocatorias: staff y jugadores ven todas; el padre solo la de su hijo. Cada quien responde la suya.
create policy co_sel on convocatorias for select to authenticated
  using (fn_es_staff(equipo_id) or fn_rol(equipo_id) = 'jugador' or fn_es_mio(jugador_id));
create policy co_ins on convocatorias for insert to authenticated with check (fn_es_staff(equipo_id) or fn_es_mio(jugador_id));
create policy co_upd on convocatorias for update to authenticated
  using (fn_es_staff(equipo_id) or fn_es_mio(jugador_id)) with check (fn_es_staff(equipo_id) or fn_es_mio(jugador_id));
create policy co_del on convocatorias for delete to authenticated using (fn_es_staff(equipo_id));

-- alineaciones: staff siempre; jugadores y padres solo cuando el partido la tiene publicada.
create policy al_sel on alineaciones for select to authenticated using (fn_es_staff(equipo_id)
  or (fn_es_miembro(equipo_id) and exists (select 1 from partidos p where p.id = partido_id and p.alineacion_publicada)));
create policy al_ins on alineaciones for insert to authenticated with check (fn_es_staff(equipo_id));
create policy al_upd on alineaciones for update to authenticated using (fn_es_staff(equipo_id)) with check (fn_es_staff(equipo_id));
create policy al_del on alineaciones for delete to authenticated using (fn_es_staff(equipo_id));

-- suscripción: solo el entrenador la ve. Se escribe únicamente desde el servidor (webhook de RevenueCat con service_role).
create policy su_sel on suscripciones for select to authenticated using (fn_es_entrenador(equipo_id));

-- ---------- invitaciones (credenciales) ----------
-- Solo se guarda el hash SHA-256 del código; el código se muestra una vez al entrenador.
create table invitaciones (
  id            uuid primary key default gen_random_uuid(),
  equipo_id     uuid not null references equipos(id) on delete cascade,
  rol           text not null check (rol in ('staff','jugador','padre')),       -- nunca 'entrenador'
  jugador_id    uuid,
  para          text check (length(para) <= 60),
  codigo_hash   text not null unique,
  creada_por    uuid not null,
  creada_en     timestamptz not null default now(),
  expira_en     timestamptz not null check (expira_en <= creada_en + interval '7 days'),
  usada_en      timestamptz,
  usada_por     uuid,
  revocada_en   timestamptz,
  foreign key (jugador_id, equipo_id) references jugadores(id, equipo_id) on delete cascade,
  check ((rol in ('jugador','padre')) = (jugador_id is not null))
);
create table intentos_canje (usuario_id uuid not null, en timestamptz not null default now(), ok boolean not null);
create table consentimientos (
  usuario_id    uuid not null,
  tipo          text not null check (tipo in ('terminos','privacidad','salud','tutor','responsable','confidencial','edad','novedades')),
  version       text not null,
  aceptado_en   timestamptz not null default now(),
  revocado_en   timestamptz,
  primary key (usuario_id, tipo, version)
);
create table auditoria (id bigint generated always as identity primary key, equipo_id uuid, usuario_id uuid, accion text not null, detalle jsonb, en timestamptz not null default now());

alter table invitaciones enable row level security;
alter table intentos_canje enable row level security;
alter table consentimientos enable row level security;
alter table auditoria enable row level security;
create policy in_sel on invitaciones for select to authenticated using (fn_es_entrenador(equipo_id));       -- solo ve hashes y estados
create policy in_upd on invitaciones for update to authenticated using (fn_es_entrenador(equipo_id)) with check (fn_es_entrenador(equipo_id));  -- revocar
create policy co2_sel on consentimientos for select to authenticated using (usuario_id = auth.uid());
create policy co2_ins on consentimientos for insert to authenticated with check (usuario_id = auth.uid());
create policy co2_upd on consentimientos for update to authenticated using (usuario_id = auth.uid()) with check (usuario_id = auth.uid());
create policy au_sel on auditoria for select to authenticated using (fn_es_entrenador(equipo_id));

create function fn_hash(c text) returns text language sql immutable as $$ select encode(sha256(convert_to(upper(trim(c)), 'UTF8')), 'hex') $$;
create function fn_codigo() returns text language plpgsql volatile as $$
declare alfa text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; b bytea := uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid()); s text := ''; i int;
begin
  foreach i in array array[0,1,2,3,4,5,9,10,11,12] loop s := s || substr(alfa, 1 + (get_byte(b, i) % 32), 1); end loop;   -- evita bytes de versión del UUID
  return 'FUT-' || substr(s,1,5) || '-' || substr(s,6,5);
end $$;

-- Crea una invitación. Solo el entrenador. Devuelve el código una sola vez.
create function crear_invitacion(eq uuid, p_rol text, p_jugador uuid, p_para text, p_horas int) returns text
language plpgsql security definer set search_path = public as $$
declare c text; n int;
begin
  if not fn_es_entrenador(eq) then raise exception 'Solo el entrenador puede invitar'; end if;
  if p_horas not in (24, 72, 168) then raise exception 'Vigencia no permitida'; end if;
  if p_rol = 'jugador' and (exists (select 1 from miembros_equipo where equipo_id = eq and rol = 'jugador' and jugador_id = p_jugador and estado in ('activo','por_aprobar'))
       or exists (select 1 from invitaciones where equipo_id = eq and rol = 'jugador' and jugador_id = p_jugador and usada_en is null and revocada_en is null and expira_en > now())) then
    raise exception 'Ese jugador ya tiene cuenta o una invitación pendiente'; end if;
  if p_rol = 'padre' then
    select (select count(*) from miembros_equipo where equipo_id = eq and rol = 'padre' and jugador_id = p_jugador and estado in ('activo','por_aprobar'))
         + (select count(*) from invitaciones where equipo_id = eq and rol = 'padre' and jugador_id = p_jugador and usada_en is null and revocada_en is null and expira_en > now()) into n;
    if n >= 2 then raise exception 'Máximo 2 tutores por jugador'; end if; end if;
  c := fn_codigo();
  insert into invitaciones(equipo_id, rol, jugador_id, para, codigo_hash, creada_por, expira_en)
    values (eq, p_rol, case when p_rol = 'staff' then null else p_jugador end, left(p_para, 60), fn_hash(c), auth.uid(), now() + make_interval(hours => p_horas));
  insert into auditoria(equipo_id, usuario_id, accion, detalle) values (eq, auth.uid(), 'invitacion_creada', jsonb_build_object('rol', p_rol, 'jugador', p_jugador));
  return c;
end $$;

-- Canjea un código. Cualquier usuario con sesión. Límite: 5 fallos por hora. Queda 'por_aprobar'.
create function canjear_invitacion(p_codigo text) returns uuid
language plpgsql security definer set search_path = public as $$
declare inv invitaciones; m uuid;
begin
  if auth.uid() is null then raise exception 'Inicia sesión primero'; end if;
  if (select count(*) from intentos_canje where usuario_id = auth.uid() and not ok and en > now() - interval '1 hour') >= 5 then
    raise exception 'Demasiados intentos. Espera e inténtalo más tarde'; end if;
  select * into inv from invitaciones where codigo_hash = fn_hash(p_codigo) for update;
  if inv.id is null or inv.usada_en is not null or inv.revocada_en is not null or inv.expira_en <= now() then
    insert into intentos_canje(usuario_id, ok) values (auth.uid(), false);
    return null;                         -- mismo resultado para inexistente, usado, revocado o vencido: no da pistas
  end if;
  update invitaciones set usada_en = now(), usada_por = auth.uid() where id = inv.id;
  insert into miembros_equipo(equipo_id, usuario_id, rol, jugador_id, estado, invitacion_id)
    values (inv.equipo_id, auth.uid(), inv.rol, inv.jugador_id, 'por_aprobar', inv.id) returning id into m;
  insert into intentos_canje(usuario_id, ok) values (auth.uid(), true);
  insert into auditoria(equipo_id, usuario_id, accion, detalle) values (inv.equipo_id, auth.uid(), 'invitacion_canjeada', jsonb_build_object('rol', inv.rol));
  return m;
end $$;

-- Aprueba o rechaza a quien canjeó. Solo el entrenador del equipo.
create function resolver_miembro(p_miembro uuid, p_aprobar boolean) returns void
language plpgsql security definer set search_path = public as $$
declare eq uuid;
begin
  select equipo_id into eq from miembros_equipo where id = p_miembro and estado = 'por_aprobar';
  if eq is null or not fn_es_entrenador(eq) then raise exception 'No autorizado'; end if;
  update miembros_equipo set estado = case when p_aprobar then 'activo' else 'rechazado' end, desde = now() where id = p_miembro;
  insert into auditoria(equipo_id, usuario_id, accion, detalle) values (eq, auth.uid(), case when p_aprobar then 'miembro_aprobado' else 'miembro_rechazado' end, jsonb_build_object('miembro', p_miembro));
end $$;

revoke all on function crear_invitacion, canjear_invitacion, resolver_miembro, fn_codigo, fn_hash from public;
grant execute on function crear_invitacion, canjear_invitacion, resolver_miembro to authenticated;

grant usage on schema public to authenticated;
grant select, insert, update, delete on equipos, miembros_equipo, jugadores, jugadores_privado, partidos, eventos, convocatorias, alineaciones to authenticated;
grant select on suscripciones to authenticated;
grant select, update on invitaciones to authenticated;
grant select, insert, update on consentimientos to authenticated;
grant select on auditoria to authenticated;
revoke all on all tables in schema public from anon;
