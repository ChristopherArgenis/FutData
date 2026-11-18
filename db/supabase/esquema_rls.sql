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
  select rol from miembros_equipo where equipo_id = eq and usuario_id = auth.uid()
  order by case rol when 'entrenador' then 1 when 'staff' then 2 when 'jugador' then 3 else 4 end limit 1 $$;
create function fn_es_miembro(eq uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from miembros_equipo where equipo_id = eq and usuario_id = auth.uid()) $$;
create function fn_es_staff(eq uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(fn_rol(eq) in ('entrenador','staff'), false) $$;
create function fn_es_entrenador(eq uuid) returns boolean language sql stable security definer set search_path = public as $$
  select coalesce(fn_rol(eq) = 'entrenador', false) $$;
create function fn_ve_plantel(eq uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from miembros_equipo where equipo_id = eq and usuario_id = auth.uid() and rol in ('entrenador','staff','jugador')) $$;
create function fn_es_mio(jug uuid) returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from miembros_equipo where jugador_id = jug and usuario_id = auth.uid() and rol in ('jugador','padre')) $$;

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
create policy mi_ins on miembros_equipo for insert to authenticated with check (fn_es_entrenador(equipo_id));
create policy mi_upd on miembros_equipo for update to authenticated using (fn_es_entrenador(equipo_id)) with check (fn_es_entrenador(equipo_id));
create policy mi_del on miembros_equipo for delete to authenticated using (fn_es_entrenador(equipo_id));

-- plantel: entrenador, staff y jugadores ven a todos; el padre solo a su hijo.
create policy ju_sel on jugadores for select to authenticated using (fn_ve_plantel(equipo_id) or fn_es_mio(id));
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
-- Las lesiones son datos de salud (sensibles): solo cuerpo técnico, el jugador y su tutor.
create policy ev_sel on eventos for select to authenticated using (fn_es_miembro(equipo_id)
  and (tipo <> 'LESION' or fn_es_staff(equipo_id) or fn_es_mio(jugador_id)));
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

grant usage on schema public to authenticated;
grant select, insert, update, delete on equipos, miembros_equipo, jugadores, jugadores_privado, partidos, eventos, convocatorias, alineaciones to authenticated;
grant select on suscripciones to authenticated;
revoke all on all tables in schema public from anon;
