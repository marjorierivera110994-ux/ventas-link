-- 0004_publico_y_plan · lo único que ve el público (por funciones), visitas y funciones del plan del vendedor.

create table public.visitas_dia (
  tienda_id uuid not null references public.tiendas(id) on delete cascade,
  dia       date not null,
  visitas   integer not null default 0 check (visitas >= 0),
  primary key (tienda_id, dia)
);
alter table public.visitas_dia enable row level security;
revoke all on public.visitas_dia from anon, authenticated;
grant all on public.visitas_dia to service_role;
grant select on public.visitas_dia to authenticated;
create policy visitas_ver on public.visitas_dia for select to authenticated using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));

-- La tienda como la ve el cliente: una sola consulta, solo datos públicos, solo si está publicada.
-- No existe forma de listar todas las tiendas: hay que conocer el enlace.
create or replace function public.tienda_publica(p_slug text) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_t public.tiendas;
begin
  select t.* into v_t from public.tiendas t where t.slug = lower(btrim(coalesce(p_slug, ''))) and t.publicada;
  if not found then return null; end if;
  return jsonb_build_object(
    'tienda', jsonb_build_object('slug', v_t.slug, 'nombre', v_t.nombre, 'descripcion', v_t.descripcion, 'tipo', v_t.tipo, 'whatsapp', v_t.whatsapp,
      'pais', v_t.pais, 'moneda', v_t.moneda, 'idioma', v_t.idioma, 'horario', v_t.horario, 'pagos', v_t.pagos, 'entregas', v_t.entregas,
      'estilo', v_t.estilo, 'logo_path', v_t.logo_path, 'portada_path', v_t.portada_path, 'plan', private.plan_efectivo(v_t.id)),
    'secciones', coalesce((
      select jsonb_agg(jsonb_build_object('id', s.id, 'nombre', s.nombre) order by s.orden, s.created_at)
      from public.secciones s
      where s.tienda_id = v_t.id and exists (select 1 from public.productos p where p.tienda_id = v_t.id and p.seccion_id = s.id and p.activo)), '[]'::jsonb),
    'productos', coalesce((
      select jsonb_agg(x.j order by x.orden, x.created_at desc)
      from (select p.orden, p.created_at, jsonb_build_object(
              'id', p.id, 'seccion_id', p.seccion_id, 'nombre', p.nombre, 'descripcion', p.descripcion,
              'precio', p.precio,
              'precio_final', private.precio_vigente(p.precio, p.oferta_pct, p.oferta_hasta),
              'oferta_pct', case when p.oferta_pct is not null and p.oferta_hasta > now() then p.oferta_pct end,
              'oferta_hasta', case when p.oferta_pct is not null and p.oferta_hasta > now() then p.oferta_hasta end,
              'variante_tipo', p.variante_tipo, 'variantes', p.variantes,
              'stock', case when p.stock is null then null else least(p.stock, 20) end,   -- no se revela el inventario completo
              'foto_path', p.foto_path,
              'nuevo', p.created_at > now() - interval '14 days') as j
            from public.productos p where p.tienda_id = v_t.id and p.activo
            order by p.orden, p.created_at desc limit 300) x), '[]'::jsonb),
    'total_productos', (select count(*) from public.productos p where p.tienda_id = v_t.id and p.activo));
end $$;

create or replace function public.registrar_visita(p_slug text) returns void
language sql security definer set search_path = '' as $$
  insert into public.visitas_dia (tienda_id, dia, visitas)
  select t.id, (now() at time zone 'America/Guayaquil')::date, 1
  from public.tiendas t where t.slug = lower(btrim(coalesce(p_slug, ''))) and t.publicada
  on conflict (tienda_id, dia) do update set visitas = public.visitas_dia.visitas + 1;
$$;

create or replace function public.slug_disponible(p_slug text) returns boolean
language sql stable security definer set search_path = '' as $$
  select private.slug_valido(lower(btrim(coalesce(p_slug, ''))))
     and not exists (select 1 from public.tiendas t where t.slug = lower(btrim(coalesce(p_slug, ''))));
$$;

-- Plan del vendedor: cuál tiene hoy, de dónde viene, cuándo vence, sus límites y cuánto lleva usado.
create or replace function public.mi_plan() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_t uuid; v_s public.suscripciones; v_plan text; v_l public.planes;
        v_pagado boolean; v_prueba boolean;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  select t.id into v_t from public.tiendas t where t.owner_id = v_uid;
  if not found then raise exception 'SIN_TIENDA' using errcode = 'P0001'; end if;
  select s.* into v_s from public.suscripciones s where s.tienda_id = v_t;
  v_pagado := v_s.plan_pagado is not null and v_s.pagado_hasta > now();
  v_prueba := not v_pagado and v_s.prueba_plan is not null and v_s.prueba_hasta > now();
  v_plan := private.plan_efectivo(v_t);
  select p.* into v_l from public.planes p where p.id = v_plan;
  return jsonb_build_object(
    'plan', v_plan,
    'origen', case when v_pagado then 'pagado' when v_prueba then 'prueba' else 'gratis' end,
    'vence', case when v_pagado then v_s.pagado_hasta when v_prueba then v_s.prueba_hasta end,
    'prueba_disponible', v_s.prueba_hasta is null,
    'prueba_plan', v_s.prueba_plan, 'prueba_hasta', v_s.prueba_hasta,
    'limites', jsonb_build_object('productos', v_l.max_productos, 'secciones', v_l.max_secciones, 'videos', v_l.max_videos, 'video_segundos', v_l.video_segundos),
    'uso', jsonb_build_object(
      'productos', (select count(*) from public.productos p where p.tienda_id = v_t),
      'secciones', (select count(*) from public.secciones s where s.tienda_id = v_t)));
end $$;

-- Prueba gratis: una sola vez por tienda, sin tarjeta. Al vencer se vuelve sola al plan gratis.
create or replace function public.iniciar_prueba(p_plan text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_t uuid; v_dias integer;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  select t.id into v_t from public.tiendas t where t.owner_id = v_uid;
  if not found then raise exception 'SIN_TIENDA' using errcode = 'P0001'; end if;
  select p.dias_prueba into v_dias from public.planes p where p.id = p_plan and p.dias_prueba > 0;
  if not found then raise exception 'PLAN_INVALIDO' using errcode = 'P0001'; end if;
  update public.suscripciones s set prueba_plan = p_plan, prueba_hasta = now() + make_interval(days => v_dias)
   where s.tienda_id = v_t and s.prueba_hasta is null;
  if not found then raise exception 'PRUEBA_YA_USADA' using errcode = 'P0001'; end if;
  return public.mi_plan();
end $$;

revoke execute on function public.tienda_publica(text), public.registrar_visita(text), public.slug_disponible(text), public.mi_plan(), public.iniciar_prueba(text) from public, anon, authenticated;
grant execute on function public.tienda_publica(text), public.registrar_visita(text), public.slug_disponible(text) to anon, authenticated, service_role;
grant execute on function public.mi_plan(), public.iniciar_prueba(text) to authenticated, service_role;
