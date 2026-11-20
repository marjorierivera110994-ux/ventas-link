-- Montos en los avisos con el formato de Ecuador: $1.234,56
create or replace function private.dinero(p numeric) returns text
language sql immutable set search_path = '' as $f$
  select '$' || translate(to_char(round(coalesce(p, 0), 2), 'FM999G999G990D00'), ',.', '.,');
$f$;
revoke execute on function private.dinero(numeric) from public, anon, authenticated;

create or replace function public.admin_resumen(p_mes date default null) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  v_admin uuid := private.exigir_admin();
  v_hoy   date := (now() at time zone 'America/Guayaquil')::date;
  v_ini   date := date_trunc('month', coalesce(p_mes, (now() at time zone 'America/Guayaquil')::date))::date;
  v_fin   date; v_ant date;
  v_t     uuid[];                         -- tiendas de vendedoras (sin las de la dueña)
  v_cfg   public.config_negocio;
  vend jsonb; uso jsonb; ventas jsonb; dinero jsonb; canales jsonb; errores jsonb; avisos jsonb := '[]'::jsonb;
  v_cobro boolean; v_pagando int; v_prueba int; v_mrr numeric; v_compras int; v_cancel_vol int; v_cancel_inv int; v_reemb int; v_fallidos int;
  v_ing numeric := 0; v_reemb_m numeric := 0; v_com numeric := 0; v_imp numeric := 0; v_afi numeric := 0; v_com_est boolean := false; v_imp_est boolean := false;
  v_serv numeric; v_correo numeric; v_dom numeric; v_ia numeric; v_afi_c numeric; v_anun numeric; v_otros numeric; v_ncostos int;
  v_gan numeric; v_otras_monedas jsonb;
  v_sin_atender int; v_creadas3 int; v_creadas3_prod int; v_err_alza jsonb;
begin
  v_fin := (v_ini + interval '1 month')::date; v_ant := (v_ini - interval '1 month')::date;
  select coalesce(array_agg(t.id), '{}') into v_t from public.tiendas t where not private.es_admin(t.owner_id);
  select * into v_cfg from public.config_negocio where id = 1;

  -- ===== VENDEDORAS =====
  select jsonb_build_object(
    'cuentas',        (select count(*) from auth.users u where not private.es_admin(u.id)),
    'tiendas',        cardinality(v_t),
    'nuevas_mes',     (select count(*) from public.tiendas t where t.id = any(v_t) and (t.created_at at time zone 'America/Guayaquil')::date >= v_ini and (t.created_at at time zone 'America/Guayaquil')::date < v_fin),
    'nuevas_mes_ant', (select count(*) from public.tiendas t where t.id = any(v_t) and (t.created_at at time zone 'America/Guayaquil')::date >= v_ant and (t.created_at at time zone 'America/Guayaquil')::date < v_ini),
    'activas_hoy',    (select count(distinct e.user_id) from public.event_log e where e.tipo = 'sesion_iniciada' and e.dia = v_hoy and e.tienda_id = any(v_t)),
    'activas_7d',     (select count(distinct e.user_id) from public.event_log e where e.tipo = 'sesion_iniciada' and e.dia > v_hoy - 7 and e.tienda_id = any(v_t)),
    'activas_30d',    (select count(distinct e.user_id) from public.event_log e where e.tipo = 'sesion_iniciada' and e.dia > v_hoy - 30 and e.tienda_id = any(v_t)),
    'con_producto',   (select count(*) from public.tiendas t where t.id = any(v_t) and exists (select 1 from public.productos p where p.tienda_id = t.id)),
    'con_pedido',     (select count(*) from public.tiendas t where t.id = any(v_t) and exists (select 1 from public.pedidos p where p.tienda_id = t.id)),
    'retencion', jsonb_build_object(
      'd1',  (select jsonb_build_object('n', count(*), 'volvieron', count(*) filter (where exists (select 1 from public.event_log e where e.tienda_id = t.id and e.tipo in ('sesion_iniciada', 'producto_publicado', 'pedido_confirmado', 'pedido_pagado', 'pedido_entregado', 'pedido_cancelado') and e.dia = (t.created_at at time zone 'America/Guayaquil')::date + 1)))
              from public.tiendas t where t.id = any(v_t) and (t.created_at at time zone 'America/Guayaquil')::date <= v_hoy - 2),
      'd7',  (select jsonb_build_object('n', count(*), 'volvieron', count(*) filter (where exists (select 1 from public.event_log e where e.tienda_id = t.id and e.tipo in ('sesion_iniciada', 'producto_publicado', 'pedido_confirmado', 'pedido_pagado', 'pedido_entregado', 'pedido_cancelado') and e.dia between (t.created_at at time zone 'America/Guayaquil')::date + 7 and (t.created_at at time zone 'America/Guayaquil')::date + 13)))
              from public.tiendas t where t.id = any(v_t) and (t.created_at at time zone 'America/Guayaquil')::date <= v_hoy - 14),
      'd30', (select jsonb_build_object('n', count(*), 'volvieron', count(*) filter (where exists (select 1 from public.event_log e where e.tienda_id = t.id and e.tipo in ('sesion_iniciada', 'producto_publicado', 'pedido_confirmado', 'pedido_pagado', 'pedido_entregado', 'pedido_cancelado') and e.dia between (t.created_at at time zone 'America/Guayaquil')::date + 30 and (t.created_at at time zone 'America/Guayaquil')::date + 59)))
              from public.tiendas t where t.id = any(v_t) and (t.created_at at time zone 'America/Guayaquil')::date <= v_hoy - 60)),
    'serie', (select jsonb_agg(jsonb_build_object('d', d::date,
                'tiendas', (select count(*) from public.tiendas t where t.id = any(v_t) and (t.created_at at time zone 'America/Guayaquil')::date = d::date),
                'pedidos', (select count(*) from public.pedidos p where p.tienda_id = any(v_t) and (p.created_at at time zone 'America/Guayaquil')::date = d::date),
                'activas', (select count(distinct e.user_id) from public.event_log e where e.tipo = 'sesion_iniciada' and e.dia = d::date and e.tienda_id = any(v_t))) order by d)
              from generate_series(v_hoy - 29, v_hoy, interval '1 day') d)
  ) into vend;

  -- ===== USO DE LA APP (mes elegido) =====
  select count(*) into v_sin_atender from public.pedidos p where p.tienda_id = any(v_t) and p.estado = 'solicitado' and p.created_at < now() - interval '48 hours';
  select jsonb_build_object(
    'landing',         (select count(distinct e.anon_id) from public.event_log e where e.tipo = 'landing_vista' and e.dia >= v_ini and e.dia < v_fin),
    'inicio',          (select count(distinct e.anon_id) from public.event_log e where e.tipo = 'onboarding_iniciado' and e.dia >= v_ini and e.dia < v_fin),
    'pasos',           coalesce((select jsonb_object_agg(x.paso, x.n) from (select e.props->>'paso' as paso, count(distinct e.anon_id) as n from public.event_log e where e.tipo = 'onboarding_paso_completado' and e.dia >= v_ini and e.dia < v_fin and e.props ? 'paso' group by 1) x), '{}'::jsonb),
    'planes_visto',    (select count(distinct e.anon_id) from public.event_log e where e.tipo = 'onboarding_planes_visto' and e.dia >= v_ini and e.dia < v_fin),
    'tiendas_creadas', (select count(*) from public.event_log e where e.tipo = 'tienda_creada' and e.dia >= v_ini and e.dia < v_fin and e.tienda_id = any(v_t)),
    'primer_producto', (select count(*) from public.event_log e where e.tipo = 'producto_publicado' and (e.props->>'primero')::boolean and e.dia >= v_ini and e.dia < v_fin and e.tienda_id = any(v_t)),
    'primer_pedido',   (select count(*) from public.event_log e where e.tipo = 'pedido_recibido' and (e.props->>'primero')::boolean and e.dia >= v_ini and e.dia < v_fin and e.tienda_id = any(v_t)),
    'productos_mes',   (select count(*) from public.event_log e where e.tipo = 'producto_publicado' and e.dia >= v_ini and e.dia < v_fin and e.tienda_id = any(v_t)),
    'productos_total', (select count(*) from public.productos p where p.tienda_id = any(v_t)),
    'con_foto_pct',    (select round(100.0 * count(*) filter (where p.foto_path is not null) / nullif(count(*), 0)) from public.productos p where p.tienda_id = any(v_t)),
    'visitas_mes',     (select coalesce(sum(v.visitas), 0) from public.visitas_dia v where v.tienda_id = any(v_t) and v.dia >= v_ini and v.dia < v_fin),
    'pedidos_mes',     (select count(*) from public.pedidos p where p.tienda_id = any(v_t) and (p.created_at at time zone 'America/Guayaquil')::date >= v_ini and (p.created_at at time zone 'America/Guayaquil')::date < v_fin),
    'pedidos_mes_ant', (select count(*) from public.pedidos p where p.tienda_id = any(v_t) and (p.created_at at time zone 'America/Guayaquil')::date >= v_ant and (p.created_at at time zone 'America/Guayaquil')::date < v_ini),
    'entregados_mes',  (select count(*) from public.pedidos p where p.tienda_id = any(v_t) and p.estado = 'entregado' and (p.entregado_at at time zone 'America/Guayaquil')::date >= v_ini and (p.entregado_at at time zone 'America/Guayaquil')::date < v_fin),
    'cancelados_mes',  (select count(*) from public.pedidos p where p.tienda_id = any(v_t) and p.estado = 'cancelado' and (p.cancelado_at at time zone 'America/Guayaquil')::date >= v_ini and (p.cancelado_at at time zone 'America/Guayaquil')::date < v_fin),
    'vendido_mes',     coalesce((select jsonb_agg(jsonb_build_object('moneda', x.moneda, 'total', x.total, 'pedidos', x.n) order by x.total desc) from (select p.moneda, sum(p.subtotal) as total, count(*) as n from public.pedidos p where p.tienda_id = any(v_t) and p.estado = 'entregado' and (p.entregado_at at time zone 'America/Guayaquil')::date >= v_ini and (p.entregado_at at time zone 'America/Guayaquil')::date < v_fin group by p.moneda) x), '[]'::jsonb),
    'pedidos_valor_mes', coalesce((select jsonb_agg(jsonb_build_object('moneda', x.moneda, 'total', x.total) order by x.total desc) from (select p.moneda, sum(p.subtotal) as total from public.pedidos p where p.tienda_id = any(v_t) and (p.created_at at time zone 'America/Guayaquil')::date >= v_ini and (p.created_at at time zone 'America/Guayaquil')::date < v_fin group by p.moneda) x), '[]'::jsonb),
    'sin_atender',     v_sin_atender,
    'frases_compartidas', (select count(*) from public.event_log e where e.tipo = 'frase_compartida' and e.dia >= v_ini and e.dia < v_fin and (e.tienda_id is null or e.tienda_id = any(v_t))),
    'top_tiendas',     coalesce((select jsonb_agg(x order by x.pedidos desc, x.visitas desc) from (
                          select t.nombre, t.slug, (select count(*) from public.pedidos p where p.tienda_id = t.id and (p.created_at at time zone 'America/Guayaquil')::date >= v_ini and (p.created_at at time zone 'America/Guayaquil')::date < v_fin) as pedidos,
                                 (select coalesce(sum(v.visitas), 0) from public.visitas_dia v where v.tienda_id = t.id and v.dia >= v_ini and v.dia < v_fin) as visitas,
                                 (select count(*) from public.productos p where p.tienda_id = t.id) as productos
                          from public.tiendas t where t.id = any(v_t)) x where x.pedidos > 0 or x.visitas > 0 limit 5), '[]'::jsonb)
  ) into uso;

  -- ===== VENTAS DE PLANES =====
  v_cobro := exists (select 1 from public.pagos);
  select count(*) filter (where s.plan_pagado is not null and s.pagado_hasta > now()),
         count(*) filter (where not (s.plan_pagado is not null and s.pagado_hasta > now()) and s.prueba_plan is not null and s.prueba_hasta > now()),
         coalesce(sum(pl.precio_mensual) filter (where s.plan_pagado is not null and s.pagado_hasta > now()), 0)
    into v_pagando, v_prueba, v_mrr
    from public.suscripciones s left join public.planes pl on pl.id = s.plan_pagado where s.tienda_id = any(v_t);
  select count(*) filter (where g.evento = 'compra'), count(*) filter (where g.evento = 'cancelacion' and coalesce(g.motivo, 'voluntario') = 'voluntario'),
         count(*) filter (where g.evento = 'cancelacion' and g.motivo = 'involuntario'), count(*) filter (where g.evento = 'reembolso'), count(*) filter (where g.evento = 'pago_fallido')
    into v_compras, v_cancel_vol, v_cancel_inv, v_reemb, v_fallidos
    from public.pagos g where (g.ocurrio_at at time zone 'America/Guayaquil')::date >= v_ini and (g.ocurrio_at at time zone 'America/Guayaquil')::date < v_fin;
  ventas := jsonb_build_object('cobro_conectado', v_cobro, 'pagando', v_pagando, 'en_prueba', v_prueba, 'mrr', v_mrr, 'compras', v_compras,
    'cancel_voluntarias', v_cancel_vol, 'cancel_involuntarias', v_cancel_inv, 'reembolsos', v_reemb, 'pagos_fallidos', v_fallidos,
    'churn_pct', case when v_cobro and (v_pagando + v_cancel_vol + v_cancel_inv - v_compras) > 0 then round(100.0 * (v_cancel_vol + v_cancel_inv) / (v_pagando + v_cancel_vol + v_cancel_inv - v_compras), 1) end,
    'pruebas_terminadas', (select count(*) from public.suscripciones s where s.tienda_id = any(v_t) and s.prueba_hasta < now() and (s.prueba_hasta at time zone 'America/Guayaquil')::date >= v_ini and (s.prueba_hasta at time zone 'America/Guayaquil')::date < v_fin),
    'pruebas_a_pago',     (select count(*) from public.suscripciones s where s.tienda_id = any(v_t) and s.prueba_hasta < now() and (s.prueba_hasta at time zone 'America/Guayaquil')::date >= v_ini and (s.prueba_hasta at time zone 'America/Guayaquil')::date < v_fin and exists (select 1 from public.pagos g where g.tienda_id = s.tienda_id and g.evento = 'compra')),
    'ingresos_serie', coalesce((select jsonb_agg(jsonb_build_object('mes', m.mes, 'total', m.total) order by m.mes) from (
        select to_char(date_trunc('month', g.ocurrio_at at time zone 'America/Guayaquil'), 'YYYY-MM') as mes,
               sum(case when g.evento in ('compra', 'renovacion') then g.monto_minor when g.evento = 'reembolso' then -g.monto_minor else 0 end) / 100.0 as total
        from public.pagos g where g.moneda = 'USD' and g.ocurrio_at >= (v_ini - interval '5 months') and (g.ocurrio_at at time zone 'America/Guayaquil')::date < v_fin group by 1) m), '[]'::jsonb));

  -- ===== GANANCIA DEL MES (en dólares) =====
  select coalesce(sum(g.monto_minor) filter (where g.evento in ('compra', 'renovacion')), 0) / 100.0,
         coalesce(sum(g.monto_minor) filter (where g.evento = 'reembolso'), 0) / 100.0,
         coalesce(sum(g.comision_minor) filter (where g.evento in ('compra', 'renovacion')), 0) / 100.0,
         bool_or(g.comision_minor is null) filter (where g.evento in ('compra', 'renovacion')),
         coalesce(sum(g.impuesto_minor) filter (where g.evento in ('compra', 'renovacion')), 0) / 100.0,
         bool_or(g.impuesto_minor is null) filter (where g.evento in ('compra', 'renovacion')),
         coalesce(sum(g.afiliado_minor) filter (where g.evento in ('compra', 'renovacion')), 0) / 100.0
    into v_ing, v_reemb_m, v_com, v_com_est, v_imp, v_imp_est, v_afi
    from public.pagos g where g.moneda = 'USD' and (g.ocurrio_at at time zone 'America/Guayaquil')::date >= v_ini and (g.ocurrio_at at time zone 'America/Guayaquil')::date < v_fin;
  v_com_est := coalesce(v_com_est, false); v_imp_est := coalesce(v_imp_est, false);
  -- Lo que el proveedor no informó se ESTIMA con la configuración (y la tarjeta dirá "Estimación")
  if v_com_est then
    v_com := v_com + coalesce((select sum(g.monto_minor / 100.0 * coalesce(v_cfg.comision_pct, 0) / 100 + coalesce(v_cfg.comision_fija, 0)) from public.pagos g
                               where g.moneda = 'USD' and g.comision_minor is null and g.evento in ('compra', 'renovacion') and (g.ocurrio_at at time zone 'America/Guayaquil')::date >= v_ini and (g.ocurrio_at at time zone 'America/Guayaquil')::date < v_fin), 0);
  end if;
  if v_imp_est then
    v_imp := v_imp + coalesce((select sum(g.monto_minor / 100.0 * coalesce(v_cfg.impuesto_pct, 0) / 100) from public.pagos g
                               where g.moneda = 'USD' and g.impuesto_minor is null and g.evento in ('compra', 'renovacion') and (g.ocurrio_at at time zone 'America/Guayaquil')::date >= v_ini and (g.ocurrio_at at time zone 'America/Guayaquil')::date < v_fin), 0);
  end if;
  select coalesce(sum(c.monto) filter (where c.concepto = 'servidor'), 0), coalesce(sum(c.monto) filter (where c.concepto = 'correo'), 0), coalesce(sum(c.monto) filter (where c.concepto = 'dominio'), 0),
         coalesce(sum(c.monto) filter (where c.concepto = 'ia'), 0), coalesce(sum(c.monto) filter (where c.concepto = 'afiliados'), 0), coalesce(sum(c.monto) filter (where c.concepto = 'anuncios'), 0),
         coalesce(sum(c.monto) filter (where c.concepto = 'otros'), 0), count(*)
    into v_serv, v_correo, v_dom, v_ia, v_afi_c, v_anun, v_otros, v_ncostos
    from public.costos c where c.mes = v_ini;
  v_ing := v_ing - v_reemb_m;
  v_gan := v_ing - v_com - v_imp - v_afi - v_afi_c - v_serv - v_correo - v_dom - v_ia - v_otros;
  select coalesce(jsonb_agg(jsonb_build_object('moneda', x.moneda, 'total', x.total)), '[]'::jsonb) into v_otras_monedas from (
    select g.moneda, sum(case when g.evento in ('compra', 'renovacion') then g.monto_minor when g.evento = 'reembolso' then -g.monto_minor else 0 end) / 100.0 as total
    from public.pagos g where g.moneda <> 'USD' and (g.ocurrio_at at time zone 'America/Guayaquil')::date >= v_ini and (g.ocurrio_at at time zone 'America/Guayaquil')::date < v_fin group by g.moneda) x;
  dinero := jsonb_build_object('moneda', 'USD', 'ingresos', v_ing, 'comision', round(v_com, 2), 'impuestos', round(v_imp, 2), 'afiliados', v_afi + v_afi_c,
    'servidor', v_serv, 'correo', v_correo, 'dominio', v_dom, 'ia', v_ia, 'otros', v_otros, 'anuncios', v_anun,
    'ganancia', round(v_gan, 2), 'tras_anuncios', round(v_gan - v_anun, 2), 'margen_pct', case when v_ing > 0 then round(100 * v_gan / v_ing, 1) end,
    'costos_anotados', v_ncostos,
    'faltan', to_jsonb(array_remove(array[
        case when v_ncostos = 0 then 'costos_del_mes' end,
        case when v_cfg.impuesto_pct is null then 'impuesto' end,
        case when v_cfg.comision_pct is null and v_cfg.comision_fija is null then 'comision' end], null)),
    'estimacion', (v_ncostos = 0 or v_com_est or v_imp_est or v_cfg.impuesto_pct is null),
    'otras_monedas', v_otras_monedas,
    'config', jsonb_build_object('impuesto_pct', v_cfg.impuesto_pct, 'comision_pct', v_cfg.comision_pct, 'comision_fija', v_cfg.comision_fija));

  -- ===== POR CANAL (de dónde llegó cada vendedora) =====
  select coalesce(jsonb_agg(jsonb_build_object('canal', x.canal, 'altas', x.altas, 'con_producto', x.con_producto, 'pagadores', x.pagadores, 'ingresos', x.ingresos, 'gasto', x.gasto) order by x.altas desc, x.gasto desc), '[]'::jsonb) into canales
  from (
    select c.canal,
           (select count(*) from public.tiendas t where t.id = any(v_t) and t.fuente = c.canal) as altas,
           (select count(*) from public.tiendas t where t.id = any(v_t) and t.fuente = c.canal and exists (select 1 from public.productos p where p.tienda_id = t.id)) as con_producto,
           (select count(distinct g.tienda_id) from public.pagos g join public.tiendas t on t.id = g.tienda_id where t.id = any(v_t) and t.fuente = c.canal and g.evento = 'compra') as pagadores,
           (select coalesce(sum(case when g.evento in ('compra', 'renovacion') then g.monto_minor when g.evento = 'reembolso' then -g.monto_minor else 0 end), 0) / 100.0 from public.pagos g join public.tiendas t on t.id = g.tienda_id where t.id = any(v_t) and t.fuente = c.canal and g.moneda = 'USD') as ingresos,
           (select coalesce(sum(k.monto), 0) from public.costos k where k.concepto = 'anuncios' and k.canal = c.canal) as gasto
    from (select distinct t.fuente as canal from public.tiendas t where t.id = any(v_t) union select distinct k.canal from public.costos k where k.concepto = 'anuncios') c
  ) x;

  -- ===== ERRORES =====
  select jsonb_build_object(
    'ult_24h', (select count(*) from public.error_log e where e.created_at > now() - interval '24 hours' and not private.es_admin(e.user_id)),
    'ult_7d',  (select count(*) from public.error_log e where e.created_at > now() - interval '7 days' and not private.es_admin(e.user_id)),
    'grupos',  coalesce((select jsonb_agg(x order by x.veces desc) from (
                  select e.mensaje, max(e.pagina) as pagina, count(*) as veces, count(distinct coalesce(e.user_id::text, e.anon_id)) as personas, max(e.created_at) as ultima
                  from public.error_log e where e.created_at > now() - interval '7 days' and not private.es_admin(e.user_id) group by e.mensaje order by count(*) desc limit 8) x), '[]'::jsonb)
  ) into errores;

  -- ===== AVISOS (qué pasó → por qué importa → qué hacer) =====
  if (v_ing > 0 or v_ncostos > 0) and v_gan < 0 then
    avisos := avisos || jsonb_build_array(case when v_ing <= 0 then
      jsonb_build_object('nivel', 'medio', 'id', 'sin_ingresos', 'titulo', 'Este mes llevas ' || private.dinero(-v_gan) || ' en gastos y todavía no cobras',
        'porque', 'Mientras no cobres los planes, cada mes es pérdida.', 'hacer', 'Conecta el cobro de planes y revisa que tus gastos sean los mínimos.')
    else jsonb_build_object('nivel', 'alto', 'id', 'margen_negativo', 'titulo', 'Este mes vas en pérdida: −' || private.dinero(-v_gan),
        'porque', 'Gastas más de lo que te queda de lo cobrado. Si vendes más así, pierdes más.', 'hacer', 'Revisa tus costos en Dinero o sube el precio antes de buscar más clientes.') end);
  end if;
  if v_ing > 0 and v_ia > 0.2 * v_ing then
    avisos := avisos || jsonb_build_object('nivel', 'alto', 'id', 'ia_cara', 'titulo', 'La IA se come el ' || round(100 * v_ia / v_ing) || '% de lo que cobras',
      'porque', 'Por encima del 20% la IA deja poco margen.', 'hacer', 'Pon límites de uso a la IA o sube el precio.');
  end if;
  if v_cobro and v_pagando > 0 and not exists (select 1 from public.pagos g where g.ocurrio_at > now() - interval '35 days') then
    avisos := avisos || jsonb_build_object('nivel', 'alto', 'id', 'cobro_sin_avisos', 'titulo', 'No llegan avisos de cobro hace más de un mes',
      'porque', 'Puede que la conexión con tu proveedor de cobro esté fallando: alguien podría tener el plan sin pagar, o pagar sin recibirlo.', 'hacer', 'Revisa la conexión con tu proveedor de cobro.');
  end if;
  if v_cancel_inv >= 3 and v_cancel_inv * 3 > (v_cancel_vol + v_cancel_inv) then
    avisos := avisos || jsonb_build_object('nivel', 'alto', 'id', 'churn_involuntario', 'titulo', v_cancel_inv || ' vendedoras se fueron porque falló su pago',
      'porque', 'Querían seguir pagando: es la pérdida más fácil de recuperar.', 'hacer', 'Activa recordatorios de pago y reintentos con tu proveedor de cobro.');
  end if;
  if exists (select 1 from jsonb_array_elements(canales) c where (c->>'gasto')::numeric > 0 and (c->>'gasto')::numeric > (c->>'ingresos')::numeric) then
    avisos := avisos || (select jsonb_agg(jsonb_build_object('nivel', 'medio', 'id', 'canal_' || (c->>'canal'), 'titulo', 'El canal "' || (c->>'canal') || '" te cuesta más de lo que te deja',
      'porque', 'Gastaste ' || private.dinero((c->>'gasto')::numeric) || ' y te dejó ' || private.dinero((c->>'ingresos')::numeric) || '.', 'hacer', 'Pausa o baja el gasto en ese canal hasta que sus vendedoras empiecen a pagar.'))
      from jsonb_array_elements(canales) c where (c->>'gasto')::numeric > 0 and (c->>'gasto')::numeric > (c->>'ingresos')::numeric);
  end if;
  if v_sin_atender > 0 then
    avisos := avisos || jsonb_build_object('nivel', 'medio', 'id', 'pedidos_sin_atender', 'titulo', v_sin_atender || case when v_sin_atender = 1 then ' pedido lleva' else ' pedidos llevan' end || ' más de 2 días sin respuesta',
      'porque', 'Un cliente que no recibe respuesta compra en otro lado, y la vendedora siente que la app no le sirve.', 'hacer', 'Mira en Vendedoras quiénes tienen pedidos pendientes y escríbeles.');
  end if;
  select count(*), count(*) filter (where exists (select 1 from public.productos p where p.tienda_id = t.id)) into v_creadas3, v_creadas3_prod
    from public.tiendas t where t.id = any(v_t) and t.created_at < now() - interval '3 days';
  if v_creadas3 >= 3 and v_creadas3_prod * 2 < v_creadas3 then
    avisos := avisos || jsonb_build_object('nivel', 'medio', 'id', 'activacion_baja', 'titulo', 'Solo ' || v_creadas3_prod || ' de ' || v_creadas3 || ' tiendas subieron su primer producto',
      'porque', 'Una tienda sin productos no vende y la vendedora se va.', 'hacer', 'Escríbeles para ayudarlas con su primer producto (mira la lista en Vendedoras).');
  end if;
  select jsonb_agg(jsonb_build_object('nivel', 'medio', 'id', 'error_' || md5(x.mensaje), 'titulo', x.veces || ' veces hoy: "' || left(x.mensaje, 80) || '"',
      'porque', 'Un mismo error repetido le está fallando a ' || x.personas || case when x.personas = 1 then ' persona.' else ' personas.' end, 'hacer', 'Revisa la sección Errores y pídeme que lo arregle.'))
    into v_err_alza from (select e.mensaje, count(*) as veces, count(distinct coalesce(e.user_id::text, e.anon_id)) as personas from public.error_log e where e.created_at > now() - interval '24 hours' and not private.es_admin(e.user_id) group by e.mensaje having count(*) >= 5) x;
  if v_err_alza is not null then avisos := avisos || v_err_alza; end if;

  return jsonb_build_object('mes', v_ini, 'hoy', v_hoy, 'generado', now(), 'vendedoras', vend, 'uso', uso, 'ventas', ventas, 'dinero', dinero, 'canales', canales, 'errores', errores, 'avisos', avisos,
    'ia', jsonb_build_object('costo_mes', v_ia, 'pct_ingresos', case when v_ing > 0 then round(100 * v_ia / v_ing, 1) end));
end $$;

-- ===== Lista de vendedoras (con buscador) =====
