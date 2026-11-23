-- Reporte mensual (plan Profesional). Lo calcula el servidor: la app solo muestra lo que devuelve.
-- Ventas = pedidos pagados o entregados, contados en el mes de su pago (o de su entrega si no hay fecha de pago).
-- Mes por zona horaria de Ecuador (America/Guayaquil), igual que el resto de la app.

create or replace function private.reporte_rango(p_tienda uuid, p_ini timestamptz, p_fin timestamptz) returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object(
    'ventas', (select count(*) from public.pedidos p
               where p.tienda_id = p_tienda and p.estado in ('pagado', 'entregado')
                 and coalesce(p.pagado_at, p.created_at) >= p_ini and coalesce(p.pagado_at, p.created_at) < p_fin),
    'ingresos', coalesce((select sum(p.subtotal) from public.pedidos p
               where p.tienda_id = p_tienda and p.estado in ('pagado', 'entregado')
                 and coalesce(p.pagado_at, p.created_at) >= p_ini and coalesce(p.pagado_at, p.created_at) < p_fin), 0),
    'pedidos', (select count(*) from public.pedidos p where p.tienda_id = p_tienda and p.created_at >= p_ini and p.created_at < p_fin),
    'canceladas', (select count(*) from public.pedidos p where p.tienda_id = p_tienda and p.cancelado_at >= p_ini and p.cancelado_at < p_fin),
    'visitas', coalesce((select sum(v.visitas) from public.visitas_dia v
               where v.tienda_id = p_tienda
                 and v.dia >= (p_ini at time zone 'America/Guayaquil')::date and v.dia < (p_fin at time zone 'America/Guayaquil')::date), 0)
  );
$$;
revoke execute on function private.reporte_rango(uuid, timestamptz, timestamptz) from public, anon, authenticated;

create or replace function public.reporte_mensual(p_mes text default null) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid());
  v_t public.tiendas;
  v_m date;
  v_ini timestamptz; v_fin timestamptz; v_pini timestamptz;
  v_top jsonb; v_dias jsonb;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  select t.* into v_t from public.tiendas t where t.owner_id = v_uid;
  if not found then raise exception 'SIN_TIENDA' using errcode = 'P0001'; end if;
  if private.plan_efectivo(v_t.id) <> 'profesional' then raise exception 'PLAN_REQUERIDO' using errcode = 'P0001'; end if;

  if p_mes is null or p_mes = '' then
    v_m := date_trunc('month', now() at time zone 'America/Guayaquil')::date;
  elsif p_mes ~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then
    v_m := to_date(p_mes || '-01', 'YYYY-MM-DD');
  else
    raise exception 'MES_INVALIDO' using errcode = 'P0001';
  end if;
  if v_m > date_trunc('month', now() at time zone 'America/Guayaquil')::date then raise exception 'MES_FUTURO' using errcode = 'P0001'; end if;

  v_ini := (v_m::timestamp) at time zone 'America/Guayaquil';
  v_fin := ((v_m + interval '1 month')::timestamp) at time zone 'America/Guayaquil';
  v_pini := ((v_m - interval '1 month')::timestamp) at time zone 'America/Guayaquil';

  select coalesce(jsonb_agg(x order by (x->>'unidades')::int desc), '[]'::jsonb) into v_top from (
    select jsonb_build_object('nombre', i.nombre, 'unidades', sum(i.cantidad), 'ingresos', sum(i.total)) x
    from public.pedido_items i join public.pedidos p on p.id = i.pedido_id
    where i.tienda_id = v_t.id and p.estado in ('pagado', 'entregado')
      and coalesce(p.pagado_at, p.created_at) >= v_ini and coalesce(p.pagado_at, p.created_at) < v_fin
    group by i.nombre order by sum(i.cantidad) desc limit 5
  ) s;

  select coalesce(jsonb_agg(jsonb_build_object('dia', d::date, 'ventas', coalesce(s.n, 0), 'ingresos', coalesce(s.ing, 0)) order by d), '[]'::jsonb) into v_dias
  from generate_series(v_m::timestamp, (v_m + interval '1 month' - interval '1 day')::timestamp, interval '1 day') d
  left join (
    select (coalesce(p.pagado_at, p.created_at) at time zone 'America/Guayaquil')::date as dd, count(*) as n, sum(p.subtotal) as ing
    from public.pedidos p
    where p.tienda_id = v_t.id and p.estado in ('pagado', 'entregado')
      and coalesce(p.pagado_at, p.created_at) >= v_ini and coalesce(p.pagado_at, p.created_at) < v_fin
    group by 1
  ) s on s.dd = d::date;

  return jsonb_build_object(
    'mes', to_char(v_m, 'YYYY-MM'),
    'moneda', v_t.moneda,
    'primer_mes', to_char((v_t.created_at at time zone 'America/Guayaquil')::date, 'YYYY-MM'),
    'actual', private.reporte_rango(v_t.id, v_ini, v_fin),
    'anterior', private.reporte_rango(v_t.id, v_pini, v_ini),
    'top_productos', v_top,
    'por_dia', v_dias
  );
end;
$$;

do $$
declare f text;
begin
  foreach f in array array['public.reporte_mensual(text)'] loop
    execute format('revoke execute on function %s from public, anon', f);
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $$;
