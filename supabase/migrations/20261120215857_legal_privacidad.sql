-- Capa legal y de privacidad (auditoría legal 2026-11-20)
-- 1) consentimientos: prueba de que cada vendedora aceptó Términos + Privacidad (con versión y fecha).
-- 2) enlaces retirados: al borrar una cuenta, su enlace /t/... no lo puede tomar otra persona
--    (evita que alguien reciba pedidos de clientes ajenos). Se guarda solo una huella (sha256), no el texto.
-- 3) borrado de cuenta: datos que necesita la función de servidor "borrar-cuenta" y limpieza de rastros.
-- 4) retención: los datos de contacto de compradores se borran a los 12 meses; registros técnicos con plazo.

-- ---------- 1) Consentimientos ----------
create table public.consentimientos (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  documento   text not null check (documento in ('terminos_privacidad')),
  version     text not null check (version ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'),
  mayor_edad  boolean not null,
  origen      text not null default '' check (char_length(origen) <= 40),
  aceptado_at timestamptz not null default now(),
  unique (user_id, documento, version)
);
alter table public.consentimientos enable row level security;
revoke all on public.consentimientos from anon, authenticated;
grant all on public.consentimientos to service_role;
grant select on public.consentimientos to authenticated;
create policy consentimientos_propios on public.consentimientos for select to authenticated
  using (user_id = (select auth.uid()));

-- La vendedora marca la casilla (no viene marcada) → se registra al tener sesión. Solo la propia cuenta.
create or replace function public.registrar_consentimiento(p_version text, p_origen text default '') returns void
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  if p_version is null or p_version !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' or p_version::date > (now() at time zone 'America/Guayaquil')::date then
    raise exception 'VERSION_INVALIDA' using errcode = 'P0001';
  end if;
  insert into public.consentimientos (user_id, documento, version, mayor_edad, origen)
  values (v_uid, 'terminos_privacidad', p_version, true, left(regexp_replace(coalesce(p_origen, ''), '[^a-z0-9_-]', '', 'g'), 40))
  on conflict (user_id, documento, version) do nothing;
end $$;
revoke execute on function public.registrar_consentimiento(text, text) from public, anon;
grant execute on function public.registrar_consentimiento(text, text) to authenticated, service_role;

-- ---------- 2) Enlaces retirados ----------
create table private.slugs_retirados (
  huella      text primary key,                      -- sha256 del enlace, no el enlace
  retirado_at timestamptz not null default now()
);
create or replace function private.huella_slug(p text) returns text
language sql immutable set search_path = '' as $$ select encode(sha256(convert_to(lower(btrim(coalesce(p, ''))), 'UTF8')), 'hex') $$;

create or replace function public.slug_disponible(p_slug text) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.slug_valido(lower(btrim(coalesce(p_slug, ''))))
     and not exists (select 1 from public.tiendas t where t.slug = lower(btrim(coalesce(p_slug, ''))))
     and not exists (select 1 from private.slugs_retirados r where r.huella = private.huella_slug(p_slug));
$$;

create or replace function private.tienda_antes() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.slug := lower(btrim(new.slug));
  if not private.slug_valido(new.slug) then raise exception 'SLUG_INVALIDO' using errcode = 'P0001'; end if;
  -- enlace de una cuenta borrada: se trata como "ocupado" (el navegador prueba el siguiente)
  if exists (select 1 from private.slugs_retirados r where r.huella = private.huella_slug(new.slug)) then
    raise exception 'duplicate key value violates unique constraint "tiendas_slug_retirado"' using errcode = '23505';
  end if;
  new.nombre := btrim(new.nombre);
  return new;
end $$;

create or replace function private.tienda_retirar_slug() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into private.slugs_retirados (huella) values (private.huella_slug(old.slug)) on conflict do nothing;
  return null;
end $$;
create trigger tiendas_retirar_slug after delete on public.tiendas for each row execute function private.tienda_retirar_slug();

-- ---------- 3) Borrado de cuenta ----------
-- Lo usa SOLO la función de servidor (service_role): qué tienda tiene, qué fotos borrar y si es la dueña.
create or replace function public.cuenta_para_borrar(p_uid uuid) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'es_duena', exists (select 1 from private.admins a where a.user_id = p_uid),
    'tienda',   t.id,
    'archivos', coalesce((select jsonb_agg(o.name) from storage.objects o
                           where t.id is not null and o.bucket_id = 'media' and o.name like t.id::text || '/%'), '[]'::jsonb))
  from (select (select x.id from public.tiendas x where x.owner_id = p_uid) as id) t;
$$;
revoke execute on function public.cuenta_para_borrar(uuid) from public, anon, authenticated;
grant execute on function public.cuenta_para_borrar(uuid) to service_role;

-- Al borrarse una cuenta (por la app o desde el panel de Supabase): se quita su correo de la bitácora del
-- panel y queda solo un evento anónimo para contar bajas. Todo lo demás cae en cascada (tienda, productos,
-- pedidos, consentimientos); los registros de uso quedan sin vínculo con la persona.
create or replace function private.cuenta_borrada() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if old.email is not null then
    update public.admin_acciones
       set detalle = (detalle - 'nombre') || jsonb_build_object('correo', 'cuenta eliminada')
     where lower(detalle->>'correo') = lower(old.email);
  end if;
  insert into public.event_log (tipo, props) values ('cuenta_eliminada', '{}'::jsonb);
  return null;
end $$;
create trigger auth_usuario_borrado after delete on auth.users for each row execute function private.cuenta_borrada();

-- ---------- 4) Retención ----------
-- Compradores: nombre, teléfono, dirección y nota se borran 12 meses después del pedido
-- (quedan productos y montos para las estadísticas de la vendedora). Registros técnicos con plazo fijo.
create or replace function private.aplicar_retencion() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_p int; v_e int; v_r int; v_a int;
begin
  update public.pedidos set comprador_nombre = 'Cliente', comprador_tel = null, direccion = '', nota = ''
   where created_at < now() - interval '12 months'
     and (comprador_nombre <> 'Cliente' or comprador_tel is not null or direccion <> '' or nota <> '');
  get diagnostics v_p = row_count;
  delete from public.event_log where created_at < now() - interval '25 months';
  get diagnostics v_e = row_count;
  delete from public.error_log where created_at < now() - interval '90 days';
  get diagnostics v_r = row_count;
  delete from public.admin_acciones where created_at < now() - interval '25 months';
  get diagnostics v_a = row_count;
  return jsonb_build_object('pedidos_anonimizados', v_p, 'eventos', v_e, 'errores', v_r, 'bitacora', v_a);
end $$;
revoke execute on function private.aplicar_retencion() from public, anon, authenticated;

create extension if not exists pg_cron with schema pg_catalog;
grant usage on schema cron to postgres;
grant all privileges on all tables in schema cron to postgres;
select cron.schedule('ventaslink-retencion', '17 8 * * *', 'select private.aplicar_retencion()');  -- 03:17 en Ecuador
