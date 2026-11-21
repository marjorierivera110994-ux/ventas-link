-- Prueba de MI CAMINO AL ÉXITO + AVISOS. No deja datos: termina con un error a propósito ("RESULTADOS {...}").
-- Todo debe ser true o empezar con "ok".
do $t$
declare
  r jsonb := '{}'::jsonb; v uuid := gen_random_uuid(); w uuid := gen_random_uuid(); tv uuid; p1 uuid; p2 uuid;
  res jsonb; ped jsonb; ped2 jsonb; k int; txt text; pts int; pts2 int;
begin
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at) values
    (v, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'camino-prueba@ejemplo.test', now()),
    (w, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'camino-otra@ejemplo.test', now());

  -- ===== Vendedor: tienda, productos y celular suscrito =====
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  insert into public.tiendas (slug, nombre, whatsapp) values ('camino-prueba-x', 'Camino Prueba', '593990000004') returning id into tv;
  insert into public.productos (tienda_id, nombre, precio) values (tv, 'Blusa de seda', 14) returning id into p1;
  insert into public.productos (tienda_id, nombre, precio) values (tv, 'Collar artesanal', 9) returning id into p2;
  begin perform public.push_guardar('https://evil.example.com/robar', 'B' || repeat('A', 86), repeat('A', 22), 'x'); r := r || '{"endpoint_ajeno":"FALLO"}';
  exception when others then r := r || jsonb_build_object('endpoint_ajeno', 'ok ' || sqlerrm); end;
  perform public.push_guardar('https://fcm.googleapis.com/fcm/send/prueba-' || v, 'B' || repeat('A', 86), repeat('A', 22), 'Android de prueba');
  res := public.avisos_mias();
  r := r || jsonb_build_object('suscrito', (res->>'dispositivos')::int = 1 and (res->>'estados')::boolean = false and res->>'hora' = '19:00');

  res := public.mi_camino();
  r := r || jsonb_build_object('arranque_puntos', (res->>'puntos')::int);   -- 10 tienda + 20 primer producto + 5 producto hoy = 35
  r := r || jsonb_build_object('medalla_tienda', exists (select 1 from jsonb_array_elements(res->'medallas') m where m->>'codigo' = 'tienda_creada' and (m->>'ganada')::boolean));
  r := r || jsonb_build_object('nivel_inicial', res->'nivel'->>'nombre' = 'Emprendedor principiante' and (res->>'faltan')::int = 100 - (res->>'puntos')::int);
  r := r || jsonb_build_object('retos_listados', jsonb_array_length(res->'retos') = 13 and jsonb_array_length(res->'medallas') = 8);
  r := r || jsonb_build_object('reto_10_en_progreso', exists (select 1 from jsonb_array_elements(res->'retos') x where x->>'codigo' = 'diez_productos' and x->>'estado' = 'en_progreso' and (x->>'avance')::int = 2));
  pts := (res->>'puntos')::int;
  res := public.mi_camino();
  r := r || jsonb_build_object('sin_puntos_dobles', (res->>'puntos')::int = pts);

  -- ===== Comprador (anónimo) pide =====
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  ped := public.crear_pedido('camino-prueba-x', gen_random_uuid(),
           jsonb_build_array(jsonb_build_object('producto_id', p1, 'cantidad', 2), jsonb_build_object('producto_id', p2, 'cantidad', 1)),
           'Ana Compradora', 'retiro', 'efectivo', '', '0991234567', 'timbre azul', 'es');
  perform public.registrar_consulta('camino-prueba-x', p1);
  perform public.registrar_consulta('camino-prueba-x', p1);   -- misma hora: no se repite
  begin perform public.avisos_tomar(5); r := r || '{"anon_toma_avisos":"FALLO"}'; exception when others then r := r || jsonb_build_object('anon_toma_avisos', 'ok ' || sqlstate); end;
  set constraints all immediate;                               -- dispara el aviso del pedido (normalmente sale al final de la transacción)
  perform set_config('role', 'postgres', true);

  select count(*), max(a.cuerpo) into k, txt from private.avisos a where a.user_id = v and a.categoria = 'pedidos';
  r := r || jsonb_build_object('aviso_pedido', k = 1, 'aviso_pedido_texto', txt);
  r := r || jsonb_build_object('aviso_sin_datos_comprador', txt not like '%Ana%' and txt not like '%099%' and txt not like '%timbre%');
  r := r || jsonb_build_object('aviso_primera_solicitud', txt like '%primera solicitud%');
  select count(*) into k from private.avisos a where a.user_id = v and a.categoria = 'consultas';
  r := r || jsonb_build_object('consulta_una_vez', k = 1);
  select count(*) into k from public.camino_logros where tienda_id = tv and tipo = 'venta';
  r := r || jsonb_build_object('solicitud_no_es_venta', k = 0);

  -- ===== El vendedor confirma (no es venta) y luego marca pagado (sí es venta) =====
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  perform public.actualizar_estado_pedido((ped->>'id')::uuid, 'confirmado');
  select coalesce(sum(puntos), 0) into pts from public.camino_puntos where tienda_id = tv;
  select count(*) into k from public.camino_logros where tienda_id = tv and tipo = 'venta';
  r := r || jsonb_build_object('confirmado_no_es_venta', k = 0);
  perform public.actualizar_estado_pedido((ped->>'id')::uuid, 'pagado');
  select coalesce(sum(puntos), 0) into pts2 from public.camino_puntos where tienda_id = tv;
  r := r || jsonb_build_object('venta_suma_puntos', pts2 - pts);   -- 10 venta + 50 primera venta + 30 venta de la semana = 90
  res := public.camino_nuevos();
  r := r || jsonb_build_object('celebraciones_pendientes', jsonb_array_length(res->'nuevos') > 0);
  perform public.camino_visto(array(select (x->>'id')::bigint from jsonb_array_elements(res->'nuevos') x));
  res := public.camino_nuevos();
  r := r || jsonb_build_object('celebradas_no_repiten', jsonb_array_length(res->'nuevos') = 0);
  perform set_config('role', 'postgres', true);
  select count(*), max(a.titulo) into k, txt from private.avisos a where a.user_id = v and a.categoria = 'felicitaciones' and a.titulo like '%primera venta%';
  r := r || jsonb_build_object('felicitacion_primera_venta', k = 1);
  select count(*) into k from private.avisos a where a.user_id = v and a.categoria = 'estados';
  r := r || jsonb_build_object('estados_apagado_por_defecto', k = 0);
  r := r || jsonb_build_object('nivel_2_alcanzado', exists (select 1 from public.camino_logros where tienda_id = tv and tipo = 'nivel' and codigo = 'nivel_2'));

  -- ===== Venta cancelada después de pagada: se descuentan sus 10 puntos =====
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  perform public.actualizar_estado_pedido((ped->>'id')::uuid, 'cancelado');
  select coalesce(sum(puntos), 0) into pts from public.camino_puntos where tienda_id = tv;
  r := r || jsonb_build_object('cancelada_descuenta', pts2 - pts = 10);
  begin perform public.actualizar_estado_pedido((ped->>'id')::uuid, 'cancelado'); r := r || '{"doble_cancelacion":"FALLO"}';
  exception when others then r := r || jsonb_build_object('doble_cancelacion', 'ok ' || sqlerrm); end;
  -- ===== Preferencias: con "pedidos" apagado no llega aviso =====
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  res := public.avisos_guardar(false, true, false, true, true, to_char(now() at time zone 'America/Guayaquil' - interval '1 minute', 'HH24:MI'), 'America/Guayaquil');
  r := r || jsonb_build_object('preferencias_guardadas', (res->>'pedidos')::boolean = false);
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  ped2 := public.crear_pedido('camino-prueba-x', gen_random_uuid(), jsonb_build_array(jsonb_build_object('producto_id', p2, 'cantidad', 1)),
            'Luis Comprador', 'domicilio', 'transferencia', 'Calle 10 y Av. 5', '0997654321', '', 'es');
  set constraints all immediate;
  perform set_config('role', 'postgres', true);
  select count(*) into k from private.avisos a where a.user_id = v and a.categoria = 'pedidos';
  r := r || jsonb_build_object('pedidos_apagado_respetado', k = 1);

  -- ===== Recordatorio diario: no se manda si ya entró hoy; sí si no entró; nunca dos el mismo día =====
  select private.avisos_programar() into k;
  r := r || jsonb_build_object('recordatorio_no_si_entro_hoy', k = 0);
  delete from private.actividad where user_id = v;
  select private.avisos_programar() into k;
  r := r || jsonb_build_object('recordatorio_si_no_entro', k = 1);
  select private.avisos_programar() into k;
  r := r || jsonb_build_object('recordatorio_una_vez', k = 0);
  select a.titulo || ' | ' || a.cuerpo into txt from private.avisos a where a.user_id = v and a.categoria = 'recordatorio';
  r := r || jsonb_build_object('recordatorio_texto', txt);

  -- ===== Aislamiento: otra cuenta no ve nada ajeno =====
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', w, 'role', 'authenticated')::text, true);
  select count(*) into k from public.camino_logros; r := r || jsonb_build_object('no_ve_logros_ajenos', k = 0);
  select count(*) into k from public.camino_puntos; r := r || jsonb_build_object('no_ve_puntos_ajenos', k = 0);
  select count(*) into k from public.push_suscripciones; r := r || jsonb_build_object('no_ve_celulares_ajenos', k = 0);
  begin select count(*) into k from private.avisos; r := r || '{"lee_bandeja":"FALLO"}'; exception when others then r := r || jsonb_build_object('lee_bandeja', 'ok ' || sqlstate); end;
  begin perform public.push_config_servidor(); r := r || '{"lee_llaves":"FALLO"}'; exception when others then r := r || jsonb_build_object('lee_llaves', 'ok ' || sqlstate); end;
  begin perform public.camino_visto(array[1::bigint]); r := r || jsonb_build_object('visto_ajeno_inofensivo', 'ok'); exception when others then r := r || jsonb_build_object('visto_ajeno_inofensivo', 'ok ' || sqlstate); end;
  begin perform public.mi_camino(); r := r || '{"sin_tienda":"FALLO"}'; exception when others then r := r || jsonb_build_object('sin_tienda', 'ok ' || sqlerrm); end;
  perform set_config('role', 'postgres', true);
  r := r || jsonb_build_object('cron_avisos', exists (select 1 from cron.job where jobname = 'ventaslink-avisos'));
  raise exception 'RESULTADOS %', r::text;
end $t$;
