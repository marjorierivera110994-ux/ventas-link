-- Plan único "Ventas Link": $4.99 al mes o $59.88 al año (Hotmart), con todas las funciones.
-- Prueba gratis de 7 días una sola vez. Sin plan gratis: al vencer, la tienda queda en solo lectura
-- (ve y comparte sus productos, pero no puede crear ni cambiar productos, secciones ni videos).

-- 1) El único plan que existe es 'profesional' (con todas las funciones y límites altos).
update public.planes
   set nombre = 'Ventas Link', precio_mensual = 4.99, dias_prueba = 7,
       max_productos = 5000, max_secciones = 300, max_videos = 1000, video_segundos = 20
 where id = 'profesional';

-- 2) Cualquier plan con prueba, pago o regalo activo cuenta como 'profesional'. Si no hay nada activo: 'sin_plan'.
create or replace function private.plan_efectivo(p_tienda uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case
      when s.plan_pagado is not null and s.pagado_hasta > now() then 'profesional'
      when s.prueba_plan is not null and s.prueba_hasta > now() then 'profesional'
      when s.regalo_plan is not null and s.regalo_hasta > now() then 'profesional'
      else 'sin_plan' end
    from public.suscripciones s where s.tienda_id = p_tienda), 'sin_plan');
$$;

-- 3) Cuentas que nunca usaron la prueba reciben sus 7 días ahora (antes eran "gratis").
update public.suscripciones
   set prueba_plan = 'profesional', prueba_hasta = now() + interval '7 days', updated_at = now()
 where prueba_hasta is null and plan_pagado is null;

-- 4) Lo que ve la vendedora de su plan. Con plan vencido se muestran los límites del plan único.
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
  select p.* into v_l from public.planes p where p.id = 'profesional';
  return jsonb_build_object(
    'plan', v_plan,
    'origen', case when v_pagado then 'pagado' when v_prueba then 'prueba' else 'vencido' end,
    'vence', case when v_pagado then v_s.pagado_hasta when v_prueba then v_s.prueba_hasta end,
    'prueba_disponible', v_s.prueba_hasta is null,
    'prueba_plan', v_s.prueba_plan, 'prueba_hasta', v_s.prueba_hasta,
    'limites', jsonb_build_object('productos', v_l.max_productos, 'secciones', v_l.max_secciones, 'videos', v_l.max_videos, 'video_segundos', v_l.video_segundos),
    'uso', jsonb_build_object(
      'productos', (select count(*) from public.productos p where p.tienda_id = v_t),
      'secciones', (select count(*) from public.secciones s where s.tienda_id = v_t)));
end $$;

-- 5) Solo lectura al vencer: bloquea crear o cambiar productos, secciones y videos.
create or replace function private.exigir_plan() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  -- Los clientes siguen comprando: bajar el stock al hacer un pedido no se bloquea.
  if tg_op = 'UPDATE' and (to_jsonb(NEW) - 'stock' - 'updated_at') = (to_jsonb(OLD) - 'stock' - 'updated_at') then
    return NEW;
  end if;
  if private.plan_efectivo(NEW.tienda_id) = 'sin_plan' then
    raise exception 'PLAN_VENCIDO' using errcode = 'P0001';
  end if;
  return NEW;
end $$;

create trigger productos_exigir_plan before insert or update on public.productos
  for each row execute function private.exigir_plan();
create trigger secciones_exigir_plan before insert or update on public.secciones
  for each row execute function private.exigir_plan();

revoke execute on function private.exigir_plan() from public, anon, authenticated;
