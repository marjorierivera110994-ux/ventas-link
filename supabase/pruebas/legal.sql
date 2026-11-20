-- Prueba de la CAPA LEGAL (consentimiento, borrado de cuenta, enlace retirado, retención). No deja datos: termina con
-- un error a propósito ("RESULTADOS {...}"). Todo debe ser true o empezar con "ok". Última corrida: 2026-11-20, 18 de 18.
do $t$
declare r jsonb := '{}'::jsonb; v uuid := gen_random_uuid(); w uuid := gen_random_uuid(); tv uuid; res jsonb; k int;
begin
  insert into auth.users (id, instance_id, aud, role, email, email_confirmed_at) values
    (v, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'legal-prueba@ejemplo.test', now()),
    (w, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'legal-otra@ejemplo.test', now());
  insert into public.admin_acciones (accion, detalle) values ('vendedora_creada', jsonb_build_object('correo', 'legal-prueba@ejemplo.test', 'nombre', 'Prueba'));
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', v, 'role', 'authenticated')::text, true);
  insert into public.tiendas (slug, nombre, whatsapp) values ('legal-prueba-x', 'Legal Prueba', '593990000002') returning id into tv;
  perform public.registrar_consentimiento('2026-11-20', 'recorrido'); perform public.registrar_consentimiento('2026-11-20', 'recorrido');
  select count(*) into k from public.consentimientos; r := r || jsonb_build_object('consentimiento_uno_y_visible', k = 1);
  begin perform public.registrar_consentimiento('2099-01-01', ''); r := r || '{"version_futura":"FALLO"}'; exception when others then r := r || jsonb_build_object('version_futura', 'ok ' || sqlerrm); end;
  begin insert into public.consentimientos (user_id, documento, version, mayor_edad) values (v, 'terminos_privacidad', '2026-11-19', true); r := r || '{"escribe_directo":"FALLO"}'; exception when others then r := r || jsonb_build_object('escribe_directo', 'ok ' || sqlstate); end;
  begin res := public.cuenta_para_borrar(v); r := r || '{"vendedora_usa_funcion_servidor":"FALLO"}'; exception when others then r := r || jsonb_build_object('vendedora_usa_funcion_servidor', 'ok ' || sqlstate); end;
  perform set_config('request.jwt.claims', json_build_object('sub', w, 'role', 'authenticated')::text, true);
  select count(*) into k from public.consentimientos; r := r || jsonb_build_object('no_ve_ajenos', k = 0);
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  begin perform public.registrar_consentimiento('2026-11-20', ''); r := r || '{"visitante_consiente":"FALLO"}'; exception when others then r := r || jsonb_build_object('visitante_consiente', 'ok ' || sqlstate); end;
  perform set_config('role', 'postgres', true);
  res := public.cuenta_para_borrar(v);
  r := r || jsonb_build_object('info_borrado', (res->>'tienda')::uuid = tv and (res->>'es_duena')::boolean = false and jsonb_typeof(res->'archivos') = 'array');
  r := r || jsonb_build_object('duena_marcada', (public.cuenta_para_borrar((select user_id from private.admins limit 1))->>'es_duena')::boolean);
  insert into public.pedidos (tienda_id, numero, clave_cliente, comprador_nombre, comprador_tel, entrega_modo, direccion, pago_preferido, nota, moneda, subtotal, created_at)
  values (tv, 1, gen_random_uuid(), 'Ana Compradora', '0991234567', 'domicilio', 'Calle 1', 'efectivo', 'timbre', 'USD', 10, now() - interval '13 months'),
         (tv, 2, gen_random_uuid(), 'Luis Reciente', '0997654321', 'retiro', '', 'efectivo', '', 'USD', 5, now() - interval '2 months');
  res := private.aplicar_retencion();
  select count(*) into k from public.pedidos where tienda_id = tv and comprador_nombre = 'Cliente' and comprador_tel is null and direccion = '' and nota = '' and numero = 1;
  r := r || jsonb_build_object('retencion_anonimiza_viejo', k = 1);
  select count(*) into k from public.pedidos where tienda_id = tv and comprador_nombre = 'Luis Reciente';
  r := r || jsonb_build_object('retencion_respeta_reciente', k = 1);
  delete from auth.users where id = v;
  select count(*) into k from public.tiendas where id = tv; r := r || jsonb_build_object('tienda_borrada', k = 0);
  select count(*) into k from public.pedidos where tienda_id = tv; r := r || jsonb_build_object('pedidos_borrados', k = 0);
  select count(*) into k from public.consentimientos where user_id = v; r := r || jsonb_build_object('consentimiento_borrado', k = 0);
  r := r || jsonb_build_object('enlace_retirado', not public.slug_disponible('legal-prueba-x'));
  select count(*) into k from public.admin_acciones where detalle->>'correo' = 'legal-prueba@ejemplo.test'; r := r || jsonb_build_object('bitacora_sin_correo', k = 0);
  select count(*) into k from public.event_log where tipo = 'cuenta_eliminada' and user_id is null and created_at > now() - interval '1 minute'; r := r || jsonb_build_object('evento_baja', k >= 1);
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', w, 'role', 'authenticated')::text, true);
  begin insert into public.tiendas (slug, nombre, whatsapp) values ('legal-prueba-x', 'Otra', '593990000003'); r := r || '{"toma_enlace_retirado":"FALLO"}'; exception when others then r := r || jsonb_build_object('toma_enlace_retirado', 'ok ' || sqlstate); end;
  perform set_config('role', 'postgres', true);
  r := r || jsonb_build_object('cron_programado', exists (select 1 from cron.job where jobname = 'ventaslink-retencion'));
  raise exception 'RESULTADOS %', r::text;
end $t$;
