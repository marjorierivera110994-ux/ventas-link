-- Prueba de seguridad del PANEL DE LA DUEÑA. No deja datos: termina con un error a propósito ("RESULTADOS {...}").
-- Lectura: todo debe ser true o empezar con "ok". Cualquier "FALLO" = hay un hueco. Correr tras cada cambio del panel.
do $t$
declare r jsonb := '{}'::jsonb; a uuid := gen_random_uuid(); v uuid := gen_random_uuid(); tv uuid; res jsonb; k int;
begin
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at) values
    (a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'duena-prueba@ejemplo.test', now()),
    (v, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'vendedora-prueba@ejemplo.test', now());
  insert into private.admins (user_id) values (a);
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  insert into public.tiendas (slug, nombre, whatsapp, fuente) values ('vendedora-prueba-x', 'Vendedora Prueba', '593990000001', 'tiktok') returning id into tv;
  insert into public.productos (tienda_id, nombre, precio) values (tv, 'Producto 1', 10);
  perform public.registrar_evento('sesion_iniciada', 'anon-prueba-123', '{}'); perform public.registrar_evento('sesion_iniciada', 'anon-prueba-123', '{}');
  perform public.registrar_evento('evento_inventado', 'anon-prueba-123', '{}');
  perform public.registrar_error('Algo falló', 'productos.html', 'anon-prueba-123');
  begin res := public.admin_resumen(); r := r || '{"vendedora_lee_panel":"FALLO"}'; exception when others then r := r || jsonb_build_object('vendedora_lee_panel', 'ok ' || sqlerrm); end;
  begin res := public.admin_vendedoras(); r := r || '{"vendedora_lee_lista":"FALLO"}'; exception when others then r := r || jsonb_build_object('vendedora_lee_lista', 'ok ' || sqlerrm); end;
  begin perform public.admin_costo_guardar(current_date, 'servidor', 25); r := r || '{"vendedora_escribe_costos":"FALLO"}'; exception when others then r := r || jsonb_build_object('vendedora_escribe_costos', 'ok ' || sqlerrm); end;
  begin perform public.admin_registrar('vendedora_creada', '{}'); r := r || '{"vendedora_escribe_bitacora":"FALLO"}'; exception when others then r := r || jsonb_build_object('vendedora_escribe_bitacora', 'ok ' || sqlerrm); end;
  begin select count(*) into k from public.event_log; r := r || '{"vendedora_lee_eventos":"FALLO"}'; exception when others then r := r || jsonb_build_object('vendedora_lee_eventos', 'ok ' || sqlstate); end;
  begin select count(*) into k from public.costos; r := r || '{"vendedora_lee_costos":"FALLO"}'; exception when others then r := r || jsonb_build_object('vendedora_lee_costos', 'ok ' || sqlstate); end;
  begin insert into public.event_log (tipo) values ('landing_vista'); r := r || '{"vendedora_escribe_eventos_directo":"FALLO"}'; exception when others then r := r || jsonb_build_object('vendedora_escribe_eventos_directo', 'ok ' || sqlstate); end;
  r := r || jsonb_build_object('vendedora_no_es_duena', not public.soy_admin());
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  begin res := public.admin_resumen(); r := r || '{"visitante_lee_panel":"FALLO"}'; exception when others then r := r || jsonb_build_object('visitante_lee_panel', 'ok ' || sqlstate); end;
  begin select count(*) into k from public.pagos; r := r || '{"visitante_lee_pagos":"FALLO"}'; exception when others then r := r || jsonb_build_object('visitante_lee_pagos', 'ok ' || sqlstate); end;
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  r := r || jsonb_build_object('duena_es_duena', public.soy_admin());
  perform public.admin_costo_guardar(current_date, 'servidor', 25, '', 'Supabase Pro');
  perform public.admin_costo_guardar(current_date, 'anuncios', 40, 'TikTok', '');
  res := public.admin_resumen();
  r := r || jsonb_build_object('duena_ve_numeros', (res->'vendedoras'->>'tiendas')::int = 1 and (res->'vendedoras'->>'activas_hoy')::int = 1 and (res->'dinero'->>'ganancia')::numeric = -25
                                 and jsonb_array_length(res->'avisos') = 2 and (res->'errores'->>'ult_24h')::int = 1);
  r := r || jsonb_build_object('sesion_una_por_dia', (res->'vendedoras'->>'activas_hoy')::int = 1);
  r := r || jsonb_build_object('busqueda_sin_comodines', (public.admin_vendedoras('%')->>'total')::int = 0);
  raise exception 'RESULTADOS %', r::text;
end $t$;
