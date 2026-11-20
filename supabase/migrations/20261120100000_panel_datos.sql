-- Panel de la dueña · 1/2: de dónde salen los números.
-- Registro de actividad (event_log), errores (error_log), origen de cada vendedora, pagos (para cuando exista el cobro),
-- costos que anota la dueña, configuración del negocio y bitácora de lo que hace la dueña en el panel.
-- Nada de esto lo puede leer una vendedora ni un visitante: solo se escribe por funciones y solo lo lee el panel.

-- ---------- Quién es dueña (administradora) ----------
create table private.admins (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  creado     timestamptz not null default now()
);
create or replace function private.es_admin(p_uid uuid) returns boolean
language sql stable security definer set search_path = '' as $$
  select p_uid is not null and exists (select 1 from private.admins a where a.user_id = p_uid);
$$;
create or replace function private.exigir_admin() returns uuid
language plpgsql stable security definer set search_path = '' as $$
declare v uuid := (select auth.uid());
begin
  if not private.es_admin(v) then raise exception 'NO_AUTORIZADO' using errcode = '42501'; end if;
  return v;
end $$;
create or replace function public.soy_admin() returns boolean
language sql stable security definer set search_path = '' as $$ select private.es_admin((select auth.uid())); $$;

-- ---------- Origen de cada vendedora (de qué enlace llegó) ----------
alter table public.tiendas add column fuente text not null default 'directo' check (fuente ~ '^[a-z0-9_:.-]{1,40}$');
grant insert (fuente) on public.tiendas to authenticated;
create index tiendas_fuente_idx on public.tiendas (fuente);
create index tiendas_creada_idx on public.tiendas (created_at);

-- ---------- Registro de actividad ----------
create table public.event_log (
  id         bigint generated always as identity primary key,
  tipo       text not null check (tipo ~ '^[a-z_]{3,40}$'),
  user_id    uuid references auth.users(id) on delete set null,
  tienda_id  uuid references public.tiendas(id) on delete set null,
  anon_id    text check (anon_id is null or anon_id ~ '^[a-z0-9-]{8,40}$'),
  dia        date not null default (now() at time zone 'America/Guayaquil')::date,
  props      jsonb not null default '{}'::jsonb check (jsonb_typeof(props) = 'object' and octet_length(props::text) <= 1024),
  created_at timestamptz not null default now()
);
create index event_log_tipo_idx on public.event_log (tipo, created_at);
create index event_log_user_idx on public.event_log (user_id, created_at) where user_id is not null;
create index event_log_tienda_idx on public.event_log (tienda_id) where tienda_id is not null;
create index event_log_anon_idx on public.event_log (anon_id, created_at) where anon_id is not null;
create unique index event_log_sesion_dia on public.event_log (user_id, dia) where tipo = 'sesion_iniciada' and user_id is not null;

-- Eventos que manda la app (los del servidor se escriben solos con disparadores, más abajo).
create or replace function public.registrar_evento(p_tipo text, p_anon text default null, p_props jsonb default '{}'::jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_t uuid; v_n int; v_anon text := nullif(lower(btrim(coalesce(p_anon, ''))), '');
begin
  if p_tipo is null or p_tipo not in ('landing_vista', 'onboarding_iniciado', 'onboarding_paso_completado', 'onboarding_planes_visto', 'sesion_iniciada', 'frase_compartida') then return; end if;
  if v_anon is not null and v_anon !~ '^[a-z0-9-]{8,40}$' then v_anon := null; end if;
  if v_uid is null and v_anon is null then return; end if;
  if p_props is null or jsonb_typeof(p_props) <> 'object' or octet_length(p_props::text) > 512 then p_props := '{}'::jsonb; end if;
  -- freno anti-abuso: nadie llena la tabla
  select count(*) into v_n from public.event_log e
   where e.created_at > now() - interval '10 minutes' and ((v_uid is not null and e.user_id = v_uid) or (v_uid is null and e.anon_id = v_anon));
  if v_n >= 60 then return; end if;
  if v_uid is not null then select t.id into v_t from public.tiendas t where t.owner_id = v_uid; end if;
  insert into public.event_log (tipo, user_id, tienda_id, anon_id, props) values (p_tipo, v_uid, v_t, v_anon, p_props)
  on conflict do nothing;                                     -- sesion_iniciada: una sola por día y persona
end $$;

-- ---------- Errores que ven las vendedoras ----------
create table public.error_log (
  id         bigint generated always as identity primary key,
  mensaje    text not null check (char_length(mensaje) between 1 and 300),
  pagina     text not null default '' check (char_length(pagina) <= 80),
  user_id    uuid references auth.users(id) on delete set null,
  anon_id    text check (anon_id is null or anon_id ~ '^[a-z0-9-]{8,40}$'),
  created_at timestamptz not null default now()
);
create index error_log_fecha_idx on public.error_log (created_at);
create index error_log_user_idx on public.error_log (user_id) where user_id is not null;
create or replace function public.registrar_error(p_mensaje text, p_pagina text default '', p_anon text default null) returns void
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_n int; v_anon text := nullif(lower(btrim(coalesce(p_anon, ''))), '');
        v_msg text := left(regexp_replace(btrim(coalesce(p_mensaje, '')), '\s+', ' ', 'g'), 300);
begin
  if v_msg = '' then return; end if;
  if v_anon is not null and v_anon !~ '^[a-z0-9-]{8,40}$' then v_anon := null; end if;
  if v_uid is null and v_anon is null then return; end if;
  select count(*) into v_n from public.error_log e
   where e.created_at > now() - interval '10 minutes' and ((v_uid is not null and e.user_id = v_uid) or (v_uid is null and e.anon_id = v_anon));
  if v_n >= 20 then return; end if;
  insert into public.error_log (mensaje, pagina, user_id, anon_id) values (v_msg, left(coalesce(p_pagina, ''), 80), v_uid, v_anon);
end $$;

-- ---------- Pagos de planes (lo llenará el aviso automático del proveedor de cobro, cuando exista) ----------
create table public.pagos (
  id             uuid primary key default gen_random_uuid(),
  tienda_id      uuid references public.tiendas(id) on delete set null,
  proveedor      text not null check (char_length(proveedor) between 2 and 30),
  proveedor_ref  text not null check (char_length(proveedor_ref) between 1 and 120),
  evento         text not null check (evento in ('compra', 'renovacion', 'cancelacion', 'reembolso', 'pago_fallido')),
  motivo         text check (motivo is null or motivo in ('voluntario', 'involuntario')),
  plan           text references public.planes(id),
  monto_minor    bigint not null default 0 check (monto_minor >= 0),     -- en centavos
  comision_minor bigint check (comision_minor is null or comision_minor >= 0),
  impuesto_minor bigint check (impuesto_minor is null or impuesto_minor >= 0),
  afiliado_minor bigint check (afiliado_minor is null or afiliado_minor >= 0),
  moneda         text not null default 'USD' check (moneda ~ '^[A-Z]{3}$'),
  ocurrio_at     timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  unique (proveedor, proveedor_ref)
);
create index pagos_fecha_idx on public.pagos (ocurrio_at);
create index pagos_tienda_idx on public.pagos (tienda_id);
create index pagos_plan_idx on public.pagos (plan);

-- ---------- Costos que anota la dueña y configuración del negocio ----------
create table public.costos (
  id         uuid primary key default gen_random_uuid(),
  mes        date not null check (extract(day from mes) = 1),
  concepto   text not null check (concepto in ('servidor', 'correo', 'dominio', 'ia', 'afiliados', 'anuncios', 'otros')),
  canal      text not null default '' check (canal ~ '^[a-z0-9_:.-]{0,40}$'),
  monto      numeric(12,2) not null check (monto >= 0 and monto <= 9999999),
  moneda     text not null default 'USD' check (moneda = 'USD'),
  nota       text not null default '' check (char_length(nota) <= 120),
  creado_por uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  check ((concepto = 'anuncios') = (canal <> ''))
);
create index costos_mes_idx on public.costos (mes);
create index costos_creado_por_idx on public.costos (creado_por);
create table public.config_negocio (
  id            smallint primary key default 1 check (id = 1),
  impuesto_pct  numeric(5,2) check (impuesto_pct is null or impuesto_pct between 0 and 60),
  comision_pct  numeric(5,2) check (comision_pct is null or comision_pct between 0 and 30),
  comision_fija numeric(8,2) check (comision_fija is null or comision_fija between 0 and 50),
  actualizado   timestamptz not null default now()
);
insert into public.config_negocio (id) values (1);

-- ---------- Bitácora del panel ----------
create table public.admin_acciones (
  id         bigint generated always as identity primary key,
  admin_id   uuid references auth.users(id) on delete set null,
  accion     text not null check (char_length(accion) between 2 and 40),
  detalle    jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
create index admin_acciones_fecha_idx on public.admin_acciones (created_at);
create index admin_acciones_admin_idx on public.admin_acciones (admin_id);

-- ---------- Eventos del servidor (no dependen de que el navegador avise) ----------
create or replace function private.ev_tienda() returns trigger language plpgsql security definer set search_path = '' as $$
begin insert into public.event_log (tipo, user_id, tienda_id, props) values ('tienda_creada', new.owner_id, new.id, jsonb_build_object('fuente', new.fuente)); return null; end $$;
create trigger tiendas_ev after insert on public.tiendas for each row execute function private.ev_tienda();

create or replace function private.ev_producto() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_owner uuid; v_primero boolean;
begin
  select t.owner_id into v_owner from public.tiendas t where t.id = new.tienda_id;
  select not exists (select 1 from public.event_log e where e.tienda_id = new.tienda_id and e.tipo = 'producto_publicado') into v_primero;
  insert into public.event_log (tipo, user_id, tienda_id, props) values ('producto_publicado', v_owner, new.tienda_id, jsonb_build_object('primero', v_primero, 'con_foto', new.foto_path is not null));
  return null;
end $$;
create trigger productos_ev after insert on public.productos for each row execute function private.ev_producto();

create or replace function private.ev_pedido() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  select t.owner_id into v_owner from public.tiendas t where t.id = new.tienda_id;
  if tg_op = 'INSERT' then
    insert into public.event_log (tipo, user_id, tienda_id, props) values ('pedido_recibido', v_owner, new.tienda_id, jsonb_build_object('subtotal', new.subtotal, 'moneda', new.moneda, 'primero', new.numero = 1));
  elsif new.estado is distinct from old.estado then
    insert into public.event_log (tipo, user_id, tienda_id, props) values ('pedido_' || new.estado, v_owner, new.tienda_id, jsonb_build_object('subtotal', new.subtotal, 'moneda', new.moneda));
  end if;
  return null;
end $$;
create trigger pedidos_ev after insert or update of estado on public.pedidos for each row execute function private.ev_pedido();

create or replace function private.ev_prueba() returns trigger language plpgsql security definer set search_path = '' as $$
declare v_owner uuid;
begin
  if old.prueba_hasta is null and new.prueba_hasta is not null then
    select t.owner_id into v_owner from public.tiendas t where t.id = new.tienda_id;
    insert into public.event_log (tipo, user_id, tienda_id, props) values ('prueba_iniciada', v_owner, new.tienda_id, jsonb_build_object('plan', new.prueba_plan));
  end if;
  return null;
end $$;
create trigger suscripciones_ev after update on public.suscripciones for each row execute function private.ev_prueba();

-- ---------- Seguridad: nadie lee ni escribe directo; solo funciones ----------
alter table public.event_log      enable row level security;
alter table public.error_log      enable row level security;
alter table public.pagos          enable row level security;
alter table public.costos         enable row level security;
alter table public.config_negocio enable row level security;
alter table public.admin_acciones enable row level security;
revoke all on public.event_log, public.error_log, public.pagos, public.costos, public.config_negocio, public.admin_acciones from anon, authenticated;
grant all on public.event_log, public.error_log, public.pagos, public.costos, public.config_negocio, public.admin_acciones to service_role;
revoke all on private.admins from public, anon, authenticated;

revoke execute on all functions in schema private from public, anon, authenticated;
grant execute on function private.cupo_media() to authenticated;   -- lo usa el permiso de subir fotos (se mantiene)
revoke execute on function public.registrar_evento(text, text, jsonb), public.registrar_error(text, text, text), public.soy_admin() from public, anon, authenticated;
grant execute on function public.registrar_evento(text, text, jsonb), public.registrar_error(text, text, text) to anon, authenticated, service_role;
grant execute on function public.soy_admin() to authenticated, service_role;
