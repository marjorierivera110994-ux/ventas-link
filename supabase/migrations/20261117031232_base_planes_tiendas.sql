-- 0001_base · planes, tiendas, datos privados del vendedor y suscripciones.
-- Regla: el público (anon) NO tiene permisos sobre ninguna tabla; solo entra por funciones (ver 0004).

create schema if not exists private;
revoke all on schema private from public;

create or replace function private.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at := now(); return new; end $$;

-- ---------- planes (catálogo de límites; lo edita solo el dueño de la app) ----------
create table public.planes (
  id             text primary key check (id ~ '^[a-z]{3,20}$'),
  nombre         text not null,
  precio_mensual numeric(8,2) not null check (precio_mensual >= 0),
  moneda         text not null default 'USD' check (moneda ~ '^[A-Z]{3}$'),
  max_productos  integer not null check (max_productos > 0),
  max_secciones  integer not null check (max_secciones > 0),
  max_videos     integer not null check (max_videos >= 0),
  video_segundos integer not null check (video_segundos between 1 and 60),
  dias_prueba    integer not null default 0 check (dias_prueba between 0 and 60),
  orden          smallint not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);
insert into public.planes (id, nombre, precio_mensual, max_productos, max_secciones, max_videos, video_segundos, dias_prueba, orden) values
  ('gratis',      'Gratis',      0,    10,   3,   1,    15, 0, 1),
  ('emprendedor', 'Emprendedor', 4.99, 300,  30,  300,  15, 7, 2),
  ('profesional', 'Profesional', 9.99, 5000, 300, 1000, 20, 7, 3);
create trigger planes_updated_at before update on public.planes for each row execute function private.set_updated_at();

-- ---------- tiendas (una por vendedor; aquí SOLO va lo que el cliente puede ver) ----------
create table public.tiendas (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null default auth.uid() unique references auth.users(id) on delete cascade,
  slug         text not null unique check (slug ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$'),
  nombre       text not null check (char_length(btrim(nombre)) between 2 and 60),
  descripcion  text not null default '' check (char_length(descripcion) <= 200),
  tipo         text not null default '' check (char_length(tipo) <= 40),
  whatsapp     text not null check (whatsapp ~ '^[1-9][0-9]{7,14}$'),
  pais         text not null default 'EC' check (pais ~ '^[A-Z]{2}$'),
  moneda       text not null default 'USD' check (moneda ~ '^[A-Z]{3}$'),
  idioma       text not null default 'es' check (idioma in ('es','en','pt')),
  horario      text not null default '' check (char_length(horario) <= 80),
  pagos        text[] not null default '{transferencia,efectivo}'
               check (pagos <@ array['transferencia','efectivo','tarjeta','billetera'] and cardinality(pagos) between 1 and 4),
  entregas     text[] not null default '{retiro}'
               check (entregas <@ array['retiro','domicilio'] and cardinality(entregas) between 1 and 2),
  estilo       jsonb not null default '{}'::jsonb check (jsonb_typeof(estilo) = 'object' and octet_length(estilo::text) <= 4000),
  logo_path    text check (logo_path is null or (logo_path like id::text || '/%' and logo_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._/-]{1,120}$' and logo_path !~ '\.\.')),
  portada_path text check (portada_path is null or (portada_path like id::text || '/%' and portada_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._/-]{1,120}$' and portada_path !~ '\.\.')),
  publicada    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- ---------- datos privados del vendedor (cobro, metas): jamás salen a la tienda pública ----------
create table public.tienda_privado (
  tienda_id        uuid primary key references public.tiendas(id) on delete cascade,
  cobro_titular    text not null default '' check (char_length(cobro_titular) <= 60),
  banco            text not null default '' check (char_length(banco) <= 60),
  cuenta_tipo      text not null default '' check (char_length(cuenta_tipo) <= 20),
  cuenta_numero    text not null default '' check (char_length(cuenta_numero) <= 34),
  billetera_numero text not null default '' check (char_length(billetera_numero) <= 20),
  retiro_direccion text not null default '' check (char_length(retiro_direccion) <= 200),
  envio_detalle    text not null default '' check (char_length(envio_detalle) <= 120),
  meta_semanal     numeric(12,2) check (meta_semanal is null or meta_semanal between 0 and 9999999),
  meta_mensual     numeric(12,2) check (meta_mensual is null or meta_mensual between 0 and 99999999),
  contador_pedidos integer not null default 0 check (contador_pedidos >= 0),
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ---------- suscripciones (el vendedor la LEE; solo el servidor la cambia) ----------
create table public.suscripciones (
  tienda_id    uuid primary key references public.tiendas(id) on delete cascade,
  plan_pagado  text references public.planes(id),
  pagado_hasta timestamptz,
  prueba_plan  text references public.planes(id),
  prueba_hasta timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  check ((plan_pagado is null) = (pagado_hasta is null)),
  check ((prueba_plan is null) = (prueba_hasta is null)),
  check (plan_pagado is distinct from 'gratis' and prueba_plan is distinct from 'gratis')
);
create index suscripciones_plan_pagado_idx on public.suscripciones (plan_pagado);
create index suscripciones_prueba_plan_idx on public.suscripciones (prueba_plan);

-- ---------- reglas ----------
create or replace function private.slug_valido(p text) returns boolean
language sql immutable set search_path = '' as $$
  select p is not null and p ~ '^[a-z0-9][a-z0-9-]{1,38}[a-z0-9]$' and p !~ '--'
     and p <> all (array['admin','api','app','ayuda','soporte','login','registro','planes','precios','tienda','tiendas','demo',
                         'ventaslink','ventas-link','www','panel','pago','pagos','legal','terminos','privacidad','blog','static',
                         'assets','logo','mi-tienda','inicio','onboarding','null','undefined']);
$$;

create or replace function private.tienda_antes() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.slug := lower(btrim(new.slug));
  if not private.slug_valido(new.slug) then raise exception 'SLUG_INVALIDO' using errcode = 'P0001'; end if;
  new.nombre := btrim(new.nombre);
  return new;
end $$;
create trigger tiendas_antes before insert on public.tiendas for each row execute function private.tienda_antes();
create trigger tiendas_updated_at before update on public.tiendas for each row execute function private.set_updated_at();

-- Al crear la tienda nacen sus datos privados y su suscripción (plan gratis, prueba sin usar).
create or replace function private.tienda_creada() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.tienda_privado (tienda_id) values (new.id);
  insert into public.suscripciones (tienda_id) values (new.id);
  return null;
end $$;
create trigger tiendas_creada after insert on public.tiendas for each row execute function private.tienda_creada();
create trigger tienda_privado_updated_at before update on public.tienda_privado for each row execute function private.set_updated_at();
create trigger suscripciones_updated_at before update on public.suscripciones for each row execute function private.set_updated_at();

-- Plan vigente HOY: pagado > prueba > gratis. La prueba vence sola (sin cobro y sin tarea programada).
create or replace function private.plan_efectivo(p_tienda uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case
      when s.plan_pagado is not null and s.pagado_hasta > now() then s.plan_pagado
      when s.prueba_plan is not null and s.prueba_hasta > now() then s.prueba_plan
      else 'gratis' end
    from public.suscripciones s where s.tienda_id = p_tienda), 'gratis');
$$;

-- ---------- seguridad: RLS + permisos mínimos por columna ----------
alter table public.planes         enable row level security;
alter table public.tiendas        enable row level security;
alter table public.tienda_privado enable row level security;
alter table public.suscripciones  enable row level security;

revoke all on public.planes, public.tiendas, public.tienda_privado, public.suscripciones from anon, authenticated;
grant all on public.planes, public.tiendas, public.tienda_privado, public.suscripciones to service_role;

grant select on public.planes to anon, authenticated;
create policy planes_ver on public.planes for select to anon, authenticated using (true);

grant select on public.tiendas to authenticated;
grant insert (slug, nombre, descripcion, tipo, whatsapp, pais, moneda, idioma, horario, pagos, entregas, estilo, logo_path, portada_path, publicada) on public.tiendas to authenticated;
grant update (nombre, descripcion, tipo, whatsapp, pais, moneda, idioma, horario, pagos, entregas, estilo, logo_path, portada_path, publicada) on public.tiendas to authenticated;
create policy tiendas_ver    on public.tiendas for select to authenticated using (owner_id = (select auth.uid()));
create policy tiendas_crear  on public.tiendas for insert to authenticated with check (owner_id = (select auth.uid()));
create policy tiendas_editar on public.tiendas for update to authenticated using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));

grant select on public.tienda_privado to authenticated;
grant update (cobro_titular, banco, cuenta_tipo, cuenta_numero, billetera_numero, retiro_direccion, envio_detalle, meta_semanal, meta_mensual) on public.tienda_privado to authenticated;
create policy privado_ver    on public.tienda_privado for select to authenticated
  using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));
create policy privado_editar on public.tienda_privado for update to authenticated
  using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())))
  with check (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));

grant select on public.suscripciones to authenticated;
create policy suscripciones_ver on public.suscripciones for select to authenticated
  using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));

revoke execute on all functions in schema private from public, anon, authenticated;
