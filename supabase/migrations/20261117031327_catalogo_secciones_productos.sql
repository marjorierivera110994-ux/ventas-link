-- 0002_catalogo · secciones y productos, con los límites del plan vigilados dentro de la base.

create table public.secciones (
  id         uuid primary key default gen_random_uuid(),
  tienda_id  uuid not null references public.tiendas(id) on delete cascade,
  nombre     text not null check (char_length(btrim(nombre)) between 1 and 40),
  orden      integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (tienda_id, id)
);
create unique index secciones_nombre_unico on public.secciones (tienda_id, lower(btrim(nombre)));

create table public.productos (
  id            uuid primary key default gen_random_uuid(),
  tienda_id     uuid not null references public.tiendas(id) on delete cascade,
  seccion_id    uuid,
  nombre        text not null check (char_length(btrim(nombre)) between 1 and 80),
  descripcion   text not null default '' check (char_length(descripcion) <= 300),
  precio        numeric(12,2) not null check (precio > 0 and precio <= 99999999),
  precio_desde  timestamptz not null default now(),          -- desde cuándo rige este precio (ofertas honestas)
  oferta_pct    smallint check (oferta_pct between 5 and 90),
  oferta_hasta  timestamptz,
  variante_tipo text not null default '' check (char_length(variante_tipo) <= 20),
  variantes     text[] not null default '{}' check (cardinality(variantes) <= 20 and octet_length(array_to_string(variantes, ',')) <= 600),
  stock         integer check (stock is null or stock between 0 and 999999),   -- null = no controla stock
  activo        boolean not null default true,
  foto_path     text check (foto_path is null or (foto_path like tienda_id::text || '/%' and foto_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._/-]{1,120}$' and foto_path !~ '\.\.')),
  orden         integer not null default 0,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  check ((oferta_pct is null) = (oferta_hasta is null)),
  -- La sección debe ser de la MISMA tienda. Si se borra la sección, el producto queda sin sección (no se pierde).
  foreign key (tienda_id, seccion_id) references public.secciones (tienda_id, id) on delete set null (seccion_id)
);
create index productos_tienda_idx  on public.productos (tienda_id, activo, orden);
create index productos_seccion_idx on public.productos (tienda_id, seccion_id);

-- Límite de secciones del plan: se cuenta y se inserta sin dejar hueco para dos altas a la vez.
create or replace function private.seccion_antes() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_max integer; v_n integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('sec:' || new.tienda_id::text, 0));
  select p.max_secciones into v_max from public.planes p where p.id = private.plan_efectivo(new.tienda_id);
  select count(*) into v_n from public.secciones s where s.tienda_id = new.tienda_id;
  if v_n >= v_max then raise exception 'LIMITE_SECCIONES' using errcode = 'P0001', detail = v_max::text; end if;
  new.nombre := btrim(new.nombre);
  return new;
end $$;
create trigger secciones_limite before insert on public.secciones for each row execute function private.seccion_antes();
create trigger secciones_updated_at before update on public.secciones for each row execute function private.set_updated_at();

-- Límite de productos del plan + ofertas solo en planes de pago + fecha desde la que rige el precio.
create or replace function private.producto_antes() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_plan text; v_max integer; v_n integer; v_oferta_nueva boolean;
begin
  if tg_op = 'INSERT' then
    perform pg_advisory_xact_lock(hashtextextended('prod:' || new.tienda_id::text, 0));
    v_plan := private.plan_efectivo(new.tienda_id);
    select p.max_productos into v_max from public.planes p where p.id = v_plan;
    select count(*) into v_n from public.productos x where x.tienda_id = new.tienda_id;
    if v_n >= v_max then raise exception 'LIMITE_PRODUCTOS' using errcode = 'P0001', detail = v_max::text; end if;
    new.precio_desde := now();
    v_oferta_nueva := new.oferta_pct is not null;
  else
    if new.tienda_id is distinct from old.tienda_id then raise exception 'NO_PERMITIDO' using errcode = 'P0001'; end if;
    new.precio_desde := case when new.precio is distinct from old.precio then now() else old.precio_desde end;
    v_oferta_nueva := new.oferta_pct is not null
      and (new.oferta_pct is distinct from old.oferta_pct or new.oferta_hasta is distinct from old.oferta_hasta);
  end if;
  if v_oferta_nueva then
    if new.oferta_hasta <= now() then raise exception 'OFERTA_FECHA_INVALIDA' using errcode = 'P0001'; end if;
    if coalesce(v_plan, private.plan_efectivo(new.tienda_id)) = 'gratis' then raise exception 'FUNCION_DE_PAGO' using errcode = 'P0001', detail = 'ofertas'; end if;
  end if;
  new.nombre := btrim(new.nombre);
  return new;
end $$;
create trigger productos_antes before insert or update on public.productos for each row execute function private.producto_antes();
create trigger productos_updated_at before update on public.productos for each row execute function private.set_updated_at();

-- Precio que paga el cliente HOY (una sola fórmula para la tienda y para el pedido).
create or replace function private.precio_vigente(p_precio numeric, p_pct smallint, p_hasta timestamptz) returns numeric
language sql stable set search_path = '' as $$
  select case when p_pct is not null and p_hasta > now() then round(p_precio * (100 - p_pct) / 100.0, 2) else p_precio end;
$$;

-- ---------- seguridad ----------
alter table public.secciones enable row level security;
alter table public.productos enable row level security;
revoke all on public.secciones, public.productos from anon, authenticated;
grant all on public.secciones, public.productos to service_role;

grant select, delete on public.secciones to authenticated;
grant insert (tienda_id, nombre, orden) on public.secciones to authenticated;
grant update (nombre, orden) on public.secciones to authenticated;
create policy secciones_ver    on public.secciones for select to authenticated using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));
create policy secciones_crear  on public.secciones for insert to authenticated with check (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));
create policy secciones_editar on public.secciones for update to authenticated
  using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())))
  with check (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));
create policy secciones_borrar on public.secciones for delete to authenticated using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));

grant select, delete on public.productos to authenticated;
grant insert (tienda_id, seccion_id, nombre, descripcion, precio, oferta_pct, oferta_hasta, variante_tipo, variantes, stock, activo, foto_path, orden) on public.productos to authenticated;
grant update (seccion_id, nombre, descripcion, precio, oferta_pct, oferta_hasta, variante_tipo, variantes, stock, activo, foto_path, orden) on public.productos to authenticated;
create policy productos_ver    on public.productos for select to authenticated using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));
create policy productos_crear  on public.productos for insert to authenticated with check (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));
create policy productos_editar on public.productos for update to authenticated
  using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())))
  with check (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));
create policy productos_borrar on public.productos for delete to authenticated using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));

revoke execute on all functions in schema private from public, anon, authenticated;
