-- Prueba de seguridad de la base (50 comprobaciones). NO deja datos: termina con un error a propósito
-- ("RESULTADOS {...}") y todo se deshace. Correr tras CADA cambio de tablas, permisos o funciones.
-- Lectura: todo valor debe ser true, un número esperado o empezar con "ok". Cualquier "FALLO" = hay un hueco.

do $t$
declare
  a uuid := gen_random_uuid(); b uuid := gen_random_uuid();
  ta uuid; tb uuid; r jsonb := '{}'::jsonb; v jsonb; n int; p1 uuid; p2 uuid; p3 uuid; pb uuid; ped uuid; clave uuid := gen_random_uuid(); i int;
begin
  insert into auth.users (id, instance_id, aud, role, email) values
    (a, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'prueba-a@ejemplo.test'),
    (b, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'prueba-b@ejemplo.test');

  ---------------- VENDEDORA A ----------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  insert into public.tiendas (slug, nombre, whatsapp) values ('Prueba-Tienda-A', '  Tienda A ', '593990000001') returning id into ta;
  select count(*) into n from public.tienda_privado; r := r || jsonb_build_object('01_privado_y_suscripcion_creados', n = 1 and (select count(*) from public.suscripciones) = 1);
  r := r || jsonb_build_object('02_slug_en_minusculas', (select slug = 'prueba-tienda-a' and nombre = 'Tienda A' from public.tiendas));
  begin insert into public.tiendas (slug, nombre, whatsapp) values ('otra-tienda-a', 'Otra', '593990000009'); r := r || '{"03_una_tienda_por_vendedor":"FALLO"}';
  exception when others then r := r || jsonb_build_object('03_una_tienda_por_vendedor', 'ok ' || sqlstate); end;

  for i in 1..3 loop insert into public.secciones (tienda_id, nombre) values (ta, 'Seccion ' || i); end loop;
  begin insert into public.secciones (tienda_id, nombre) values (ta, 'Seccion 4'); r := r || '{"04_limite_secciones_gratis":"FALLO"}';
  exception when others then r := r || jsonb_build_object('04_limite_secciones_gratis', 'ok ' || sqlerrm); end;

  insert into public.productos (tienda_id, nombre, precio, stock, seccion_id) values (ta, 'Blusa', 10, 5, (select id from public.secciones limit 1)) returning id into p1;
  insert into public.productos (tienda_id, nombre, precio, variante_tipo, variantes) values (ta, 'Camisa', 20, 'talla', '{S,M,L}') returning id into p2;
  insert into public.productos (tienda_id, nombre, precio, activo) values (ta, 'Oculto', 5, false) returning id into p3;
  for i in 4..10 loop insert into public.productos (tienda_id, nombre, precio) values (ta, 'Producto ' || i, i); end loop;
  begin insert into public.productos (tienda_id, nombre, precio) values (ta, 'Producto 11', 11); r := r || '{"05_limite_10_productos_gratis":"FALLO"}';
  exception when others then r := r || jsonb_build_object('05_limite_10_productos_gratis', 'ok ' || sqlerrm); end;
  begin update public.productos set oferta_pct = 20, oferta_hasta = now() + interval '7 days' where id = p2; r := r || '{"06_oferta_bloqueada_en_gratis":"FALLO"}';
  exception when others then r := r || jsonb_build_object('06_oferta_bloqueada_en_gratis', 'ok ' || sqlerrm); end;

  v := public.iniciar_prueba('emprendedor');
  r := r || jsonb_build_object('07_prueba_7_dias', v->>'plan' = 'emprendedor' and v->>'origen' = 'prueba' and (v->'limites'->>'productos')::int = 300 and (v->'uso'->>'productos')::int = 10);
  insert into public.productos (tienda_id, nombre, precio) values (ta, 'Producto 11', 11);
  update public.productos set oferta_pct = 20, oferta_hasta = now() + interval '7 days' where id = p2;
  r := r || jsonb_build_object('08_con_prueba_si_deja_producto_11_y_oferta', (select count(*) = 11 from public.productos));
  begin perform public.iniciar_prueba('profesional'); r := r || '{"09_prueba_solo_una_vez":"FALLO"}';
  exception when others then r := r || jsonb_build_object('09_prueba_solo_una_vez', 'ok ' || sqlerrm); end;

  begin update public.tiendas set slug = 'robado' where id = ta; r := r || '{"10_no_cambia_enlace":"FALLO"}';
  exception when others then r := r || jsonb_build_object('10_no_cambia_enlace', 'ok ' || sqlstate); end;
  begin update public.suscripciones set plan_pagado = 'profesional', pagado_hasta = now() + interval '10 years'; r := r || '{"11_no_se_regala_plan_pagado":"FALLO"}';
  exception when others then r := r || jsonb_build_object('11_no_se_regala_plan_pagado', 'ok ' || sqlstate); end;
  begin update public.tienda_privado set contador_pedidos = 999; r := r || '{"12_no_toca_contador":"FALLO"}';
  exception when others then r := r || jsonb_build_object('12_no_toca_contador', 'ok ' || sqlstate); end;
  update public.tienda_privado set cobro_titular = 'Titular de prueba', meta_semanal = 200; get diagnostics n = row_count;
  r := r || jsonb_build_object('13_edita_sus_datos_de_cobro', n = 1);
  begin insert into storage.objects (bucket_id, name) values ('media', ta::text || '/productos/foto1.webp'); r := r || '{"14_sube_foto_a_su_carpeta":true}';
  exception when others then r := r || jsonb_build_object('14_sube_foto_a_su_carpeta', 'FALLO ' || sqlerrm); end;

  ---------------- VENDEDORA B ----------------
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  begin insert into public.tiendas (slug, nombre, whatsapp) values ('admin', 'Tienda B', '593990000002'); r := r || '{"15_enlace_reservado":"FALLO"}';
  exception when others then r := r || jsonb_build_object('15_enlace_reservado', 'ok ' || sqlerrm); end;
  begin insert into public.tiendas (slug, nombre, whatsapp) values ('prueba-tienda-a', 'Copia', '593990000002'); r := r || '{"16_enlace_repetido":"FALLO"}';
  exception when others then r := r || jsonb_build_object('16_enlace_repetido', 'ok ' || sqlstate); end;
  insert into public.tiendas (slug, nombre, whatsapp) values ('prueba-tienda-b', 'Tienda B', '593990000002') returning id into tb;
  insert into public.productos (tienda_id, nombre, precio) values (tb, 'Producto de B', 7) returning id into pb;
  r := r || jsonb_build_object('17_B_solo_ve_lo_suyo', (select count(*) from public.tiendas) = 1 and (select count(*) from public.productos) = 1
        and (select count(*) from public.tienda_privado) = 1 and (select count(*) from public.suscripciones) = 1 and (select count(*) from public.secciones) = 0);
  update public.productos set nombre = 'hackeado' where tienda_id = ta; get diagnostics n = row_count;
  delete from public.productos where tienda_id = ta; get diagnostics i = row_count;
  r := r || jsonb_build_object('18_B_no_edita_ni_borra_productos_de_A', n = 0 and i = 0);
  update public.tienda_privado set cobro_titular = 'robo' where tienda_id = ta; get diagnostics n = row_count;
  r := r || jsonb_build_object('19_B_no_toca_cobro_de_A', n = 0);
  begin insert into public.productos (tienda_id, nombre, precio) values (ta, 'Intruso', 1); r := r || '{"20_B_no_mete_productos_en_A":"FALLO"}';
  exception when others then r := r || jsonb_build_object('20_B_no_mete_productos_en_A', 'ok ' || sqlstate); end;
  begin insert into public.productos (tienda_id, nombre, precio, seccion_id) values (tb, 'Cruce', 1, (select s.id from public.secciones s limit 1)); r := r || '{"21_seccion_ajena":"sin seccion visible (ok)"}';
  exception when others then r := r || jsonb_build_object('21_seccion_ajena', 'ok ' || sqlstate); end;
  begin insert into storage.objects (bucket_id, name) values ('media', ta::text || '/productos/intruso.webp'); r := r || '{"22_B_no_sube_a_carpeta_de_A":"FALLO"}';
  exception when others then r := r || jsonb_build_object('22_B_no_sube_a_carpeta_de_A', 'ok ' || sqlstate); end;

  ---------------- PÚBLICO (sin cuenta) ----------------
  perform set_config('role', 'anon', true);
  perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  begin select count(*) into n from public.tiendas; r := r || '{"23_publico_no_lista_tiendas":"FALLO"}';
  exception when others then r := r || jsonb_build_object('23_publico_no_lista_tiendas', 'ok ' || sqlstate); end;
  begin select count(*) into n from public.pedidos; r := r || '{"24_publico_no_lee_pedidos":"FALLO"}';
  exception when others then r := r || jsonb_build_object('24_publico_no_lee_pedidos', 'ok ' || sqlstate); end;
  begin select count(*) into n from public.tienda_privado; r := r || '{"25_publico_no_lee_cobro":"FALLO"}';
  exception when others then r := r || jsonb_build_object('25_publico_no_lee_cobro', 'ok ' || sqlstate); end;
  r := r || jsonb_build_object('26_publico_ve_planes', (select count(*) = 3 from public.planes));
  v := public.tienda_publica('prueba-tienda-a');
  r := r || jsonb_build_object('27_tienda_publica', jsonb_build_object(
     'productos_visibles', jsonb_array_length(v->'productos'), 'oculto_no_sale', not (v->'productos') @> jsonb_build_array(jsonb_build_object('id', p3)),
     'secciones_con_productos', jsonb_array_length(v->'secciones'), 'plan', v->'tienda'->>'plan',
     'sin_datos_privados', not (v::text ~ 'owner_id|cobro|Titular|meta_semanal'),
     'precio_oferta_camisa', (select x->>'precio_final' from jsonb_array_elements(v->'productos') x where x->>'id' = p2::text)));
  v := public.crear_pedido('prueba-tienda-a', clave, jsonb_build_array(jsonb_build_object('producto_id', p1, 'cantidad', 2), jsonb_build_object('producto_id', p2, 'variante', 'M', 'cantidad', 1)),
        'Cliente de prueba', 'domicilio', 'transferencia', 'Av. Ejemplo 123', '0990000000', 'Sin nota', 'es');
  ped := (v->>'id')::uuid;
  r := r || jsonb_build_object('28_pedido_total_calculado_en_la_base', v - 'id');
  v := public.crear_pedido('prueba-tienda-a', clave, jsonb_build_array(jsonb_build_object('producto_id', p1, 'cantidad', 1)), 'Cliente de prueba', 'retiro', 'efectivo');
  r := r || jsonb_build_object('29_doble_envio_no_duplica', (v->>'repetido')::boolean and (v->>'id')::uuid = ped);
  begin perform public.crear_pedido('prueba-tienda-a', gen_random_uuid(), jsonb_build_array(jsonb_build_object('producto_id', pb, 'cantidad', 1)), 'X', 'retiro', 'efectivo'); r := r || '{"30_producto_de_otra_tienda":"FALLO"}';
  exception when others then r := r || jsonb_build_object('30_producto_de_otra_tienda', 'ok ' || sqlerrm); end;
  begin perform public.crear_pedido('prueba-tienda-a', gen_random_uuid(), jsonb_build_array(jsonb_build_object('producto_id', p3, 'cantidad', 1)), 'X', 'retiro', 'efectivo'); r := r || '{"31_producto_oculto":"FALLO"}';
  exception when others then r := r || jsonb_build_object('31_producto_oculto', 'ok ' || sqlerrm); end;
  begin perform public.crear_pedido('prueba-tienda-a', gen_random_uuid(), jsonb_build_array(jsonb_build_object('producto_id', p1, 'cantidad', 6)), 'X', 'retiro', 'efectivo'); r := r || '{"32_mas_que_el_stock":"FALLO"}';
  exception when others then r := r || jsonb_build_object('32_mas_que_el_stock', 'ok ' || sqlerrm); end;
  begin perform public.crear_pedido('prueba-tienda-a', gen_random_uuid(), jsonb_build_array(jsonb_build_object('producto_id', p2, 'variante', 'XXL', 'cantidad', 1)), 'X', 'retiro', 'efectivo'); r := r || '{"33_variante_inexistente":"FALLO"}';
  exception when others then r := r || jsonb_build_object('33_variante_inexistente', 'ok ' || sqlerrm); end;
  begin perform public.crear_pedido('prueba-tienda-a', gen_random_uuid(), '[{"producto_id":"no-es-id","cantidad":1,"precio":0.01}]'::jsonb, 'X', 'retiro', 'efectivo'); r := r || '{"34_carrito_basura":"FALLO"}';
  exception when others then r := r || jsonb_build_object('34_carrito_basura', 'ok ' || sqlerrm); end;
  begin perform public.crear_pedido('prueba-tienda-a', gen_random_uuid(), jsonb_build_array(jsonb_build_object('producto_id', p1, 'cantidad', 1)), 'X', 'domicilio', 'efectivo', ''); r := r || '{"35_domicilio_sin_direccion":"FALLO"}';
  exception when others then r := r || jsonb_build_object('35_domicilio_sin_direccion', 'ok ' || sqlerrm); end;
  begin perform public.actualizar_estado_pedido(ped, 'entregado'); r := r || '{"36_publico_no_cambia_pedidos":"FALLO"}';
  exception when others then r := r || jsonb_build_object('36_publico_no_cambia_pedidos', 'ok ' || sqlstate); end;
  begin perform public.mi_plan(); r := r || '{"37_publico_no_ve_planes_ajenos":"FALLO"}';
  exception when others then r := r || jsonb_build_object('37_publico_no_ve_planes_ajenos', 'ok ' || sqlstate); end;
  begin insert into storage.objects (bucket_id, name) values ('media', ta::text || '/x.webp'); r := r || '{"38_publico_no_sube_fotos":"FALLO"}';
  exception when others then r := r || jsonb_build_object('38_publico_no_sube_fotos', 'ok ' || sqlstate); end;
  perform public.registrar_visita('prueba-tienda-a'); perform public.registrar_visita('prueba-tienda-a');
  r := r || jsonb_build_object('39_enlace_libre_u_ocupado', jsonb_build_array(public.slug_disponible('prueba-tienda-a'), public.slug_disponible('tienda-nueva-libre'), public.slug_disponible('admin')));

  ---------------- B intenta tocar el pedido de A ----------------
  perform set_config('role', 'authenticated', true);
  perform set_config('request.jwt.claims', json_build_object('sub', b, 'role', 'authenticated')::text, true);
  r := r || jsonb_build_object('40_B_no_ve_pedidos_de_A', (select count(*) from public.pedidos) = 0 and (select count(*) from public.pedido_items) = 0);
  begin perform public.actualizar_estado_pedido(ped, 'confirmado'); r := r || '{"41_B_no_cambia_pedido_de_A":"FALLO"}';
  exception when others then r := r || jsonb_build_object('41_B_no_cambia_pedido_de_A', 'ok ' || sqlerrm); end;

  ---------------- A atiende su pedido ----------------
  perform set_config('request.jwt.claims', json_build_object('sub', a, 'role', 'authenticated')::text, true);
  r := r || jsonb_build_object('42_A_ve_su_pedido', (select jsonb_build_object('pedidos', count(*), 'numero', max(numero), 'subtotal', max(subtotal), 'lineas', (select count(*) from public.pedido_items)) from public.pedidos));
  begin insert into public.pedidos (tienda_id, numero, clave_cliente, comprador_nombre, entrega_modo, pago_preferido, moneda, subtotal) values (ta, 99, gen_random_uuid(), 'Falso', 'retiro', 'efectivo', 'USD', 1000); r := r || '{"43_A_no_inventa_pedidos":"FALLO"}';
  exception when others then r := r || jsonb_build_object('43_A_no_inventa_pedidos', 'ok ' || sqlstate); end;
  begin perform public.actualizar_estado_pedido(ped, 'entregado'); r := r || '{"44_no_salta_pasos":"FALLO"}';
  exception when others then r := r || jsonb_build_object('44_no_salta_pasos', 'ok ' || sqlerrm); end;
  perform public.actualizar_estado_pedido(ped, 'confirmado'); perform public.actualizar_estado_pedido(ped, 'pagado');
  r := r || jsonb_build_object('45_stock_intacto_antes_de_entregar', (select stock = 5 from public.productos where id = p1));
  v := public.actualizar_estado_pedido(ped, 'entregado');
  r := r || jsonb_build_object('46_al_entregar_baja_stock', (select stock from public.productos where id = p1), '47_estado_final', v->>'estado',
        '48_visitas_contadas', (select sum(visitas) from public.visitas_dia));
  begin perform public.actualizar_estado_pedido(ped, 'cancelado'); r := r || '{"49_entregado_ya_no_cambia":"FALLO"}';
  exception when others then r := r || jsonb_build_object('49_entregado_ya_no_cambia', 'ok ' || sqlerrm); end;
  update public.tiendas set publicada = false where id = ta;
  perform set_config('role', 'anon', true); perform set_config('request.jwt.claims', '{"role":"anon"}', true);
  r := r || jsonb_build_object('50_tienda_despublicada_no_se_ve', public.tienda_publica('prueba-tienda-a') is null);

  raise exception 'RESULTADOS %', jsonb_pretty(r);
end $t$;
