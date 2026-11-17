-- 0003_pedidos · pedidos y sus líneas. Nadie escribe directo en estas tablas:
--   el comprador registra el pedido con crear_pedido() y el vendedor cambia el estado con actualizar_estado_pedido().

create table public.pedidos (
  id               uuid primary key default gen_random_uuid(),
  tienda_id        uuid not null references public.tiendas(id) on delete cascade,
  numero           integer not null check (numero > 0),          -- número corto por tienda (#1, #2…)
  clave_cliente    uuid not null unique,                          -- evita pedidos duplicados por doble toque o reintento
  estado           text not null default 'solicitado' check (estado in ('solicitado','confirmado','pagado','entregado','cancelado')),
  comprador_nombre text not null check (char_length(comprador_nombre) between 1 and 80),
  comprador_tel    text check (comprador_tel is null or comprador_tel ~ '^[0-9]{7,15}$'),
  entrega_modo     text not null check (entrega_modo in ('retiro','domicilio')),
  direccion        text not null default '' check (char_length(direccion) <= 200),
  pago_preferido   text not null check (pago_preferido in ('transferencia','efectivo','tarjeta','billetera')),
  nota             text not null default '' check (char_length(nota) <= 300),
  idioma           text not null default 'es' check (idioma in ('es','en','pt')),
  moneda           text not null check (moneda ~ '^[A-Z]{3}$'),
  subtotal         numeric(12,2) not null check (subtotal >= 0),
  confirmado_at    timestamptz,
  pagado_at        timestamptz,
  entregado_at     timestamptz,
  cancelado_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (tienda_id, numero)
);
create index pedidos_tienda_fecha_idx on public.pedidos (tienda_id, created_at desc);
create index pedidos_entregados_idx   on public.pedidos (tienda_id, entregado_at) where estado = 'entregado';

create table public.pedido_items (
  id              uuid primary key default gen_random_uuid(),
  pedido_id       uuid not null references public.pedidos(id) on delete cascade,
  tienda_id       uuid not null references public.tiendas(id) on delete cascade,   -- repetido a propósito: permiso directo por tienda
  producto_id     uuid references public.productos(id) on delete set null,
  nombre          text not null check (char_length(nombre) between 1 and 80),      -- copia del nombre al momento del pedido
  variante        text not null default '' check (char_length(variante) <= 40),
  cantidad        integer not null check (cantidad between 1 and 99),
  precio_unitario numeric(12,2) not null check (precio_unitario >= 0),             -- copia del precio al momento del pedido
  total           numeric(12,2) not null check (total >= 0),
  created_at      timestamptz not null default now()
);
create index pedido_items_pedido_idx   on public.pedido_items (pedido_id);
create index pedido_items_tienda_idx   on public.pedido_items (tienda_id);
create index pedido_items_producto_idx on public.pedido_items (producto_id);
create trigger pedidos_updated_at before update on public.pedidos for each row execute function private.set_updated_at();

-- ---------- El comprador registra su pedido (sin cuenta). Los precios SIEMPRE salen de la base, nunca del navegador. ----------
create or replace function public.crear_pedido(
  p_slug text, p_clave uuid, p_items jsonb, p_nombre text, p_entrega text, p_pago text,
  p_direccion text default '', p_tel text default null, p_nota text default '', p_idioma text default 'es')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_t public.tiendas; v_prev public.pedidos;
  v_id uuid := gen_random_uuid(); v_num integer; v_sub numeric(12,2) := 0; v_n integer;
  v_nombre text := btrim(coalesce(p_nombre, ''));
  v_tel text := nullif(regexp_replace(coalesce(p_tel, ''), '\D', '', 'g'), '');
  v_dir text := btrim(coalesce(p_direccion, ''));
  v_nota text := btrim(coalesce(p_nota, ''));
  v_idioma text := case when p_idioma in ('es','en','pt') then p_idioma else 'es' end;
  v_lineas jsonb := '[]'::jsonb; v_precio numeric(12,2); v_var text; r record;
begin
  if p_clave is null then raise exception 'PEDIDO_INVALIDO' using errcode = 'P0001'; end if;
  if char_length(v_nombre) not between 1 and 80 then raise exception 'NOMBRE_INVALIDO' using errcode = 'P0001'; end if;
  if p_entrega is null or p_entrega not in ('retiro','domicilio') then raise exception 'ENTREGA_INVALIDA' using errcode = 'P0001'; end if;
  if char_length(v_dir) > 200 or (p_entrega = 'domicilio' and char_length(v_dir) < 5) then raise exception 'DIRECCION_INVALIDA' using errcode = 'P0001'; end if;
  if p_pago is null or p_pago not in ('transferencia','efectivo','tarjeta','billetera') then raise exception 'PAGO_INVALIDO' using errcode = 'P0001'; end if;
  if v_tel is not null and v_tel !~ '^[0-9]{7,15}$' then raise exception 'TELEFONO_INVALIDO' using errcode = 'P0001'; end if;
  if char_length(v_nota) > 300 then raise exception 'NOTA_INVALIDA' using errcode = 'P0001'; end if;
  if p_items is null or jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) not between 1 and 50 or octet_length(p_items::text) > 8000 then
    raise exception 'CARRITO_INVALIDO' using errcode = 'P0001';
  end if;

  select t.* into v_t from public.tiendas t where t.slug = lower(btrim(coalesce(p_slug, ''))) and t.publicada;
  if not found then raise exception 'TIENDA_NO_ENCONTRADA' using errcode = 'P0001'; end if;

  -- Mismo pedido enviado dos veces: se devuelve el que ya existe, sin crear otro.
  select p.* into v_prev from public.pedidos p where p.clave_cliente = p_clave;
  if found then
    if v_prev.tienda_id <> v_t.id then raise exception 'PEDIDO_INVALIDO' using errcode = 'P0001'; end if;
    return jsonb_build_object('id', v_prev.id, 'numero', v_prev.numero, 'subtotal', v_prev.subtotal, 'moneda', v_prev.moneda, 'repetido', true);
  end if;

  -- Freno de abuso: nadie puede inundar una tienda con pedidos falsos.
  select count(*) into v_n from public.pedidos p where p.tienda_id = v_t.id and p.created_at > now() - interval '10 minutes';
  if v_n >= 30 then raise exception 'DEMASIADOS_PEDIDOS' using errcode = 'P0001'; end if;
  select count(*) into v_n from public.pedidos p where p.tienda_id = v_t.id and p.created_at > now() - interval '1 day';
  if v_n >= 500 then raise exception 'DEMASIADOS_PEDIDOS' using errcode = 'P0001'; end if;

  begin
    for r in
      select x.producto_id, btrim(coalesce(x.variante, '')) as variante, x.cantidad,
             pr.id as pid, pr.nombre, pr.precio, pr.oferta_pct, pr.oferta_hasta, pr.variantes, pr.activo
      from jsonb_to_recordset(p_items) as x(producto_id uuid, variante text, cantidad integer)
      left join public.productos pr on pr.id = x.producto_id and pr.tienda_id = v_t.id
    loop
      if r.pid is null or not r.activo then raise exception 'PRODUCTO_NO_DISPONIBLE' using errcode = 'P0001', detail = coalesce(r.producto_id::text, ''); end if;
      if r.cantidad is null or r.cantidad not between 1 and 20 then raise exception 'CANTIDAD_INVALIDA' using errcode = 'P0001'; end if;
      v_var := r.variante;
      if cardinality(r.variantes) = 0 then v_var := '';
      elsif not (v_var = any (r.variantes)) then raise exception 'VARIANTE_INVALIDA' using errcode = 'P0001', detail = r.pid::text; end if;
      v_precio := private.precio_vigente(r.precio, r.oferta_pct, r.oferta_hasta);
      v_sub := v_sub + v_precio * r.cantidad;
      v_lineas := v_lineas || jsonb_build_object('producto_id', r.pid, 'nombre', r.nombre, 'variante', v_var, 'cantidad', r.cantidad, 'precio', v_precio);
    end loop;
  exception when invalid_text_representation or numeric_value_out_of_range or datatype_mismatch or invalid_parameter_value then
    raise exception 'CARRITO_INVALIDO' using errcode = 'P0001';
  end;

  -- No se puede pedir más de lo que hay (si el vendedor controla el stock de ese producto).
  if exists (
    select 1 from (select (l->>'producto_id')::uuid as pid, sum((l->>'cantidad')::integer) as q from jsonb_array_elements(v_lineas) l group by 1) a
    join public.productos pr on pr.id = a.pid where pr.stock is not null and a.q > pr.stock) then
    raise exception 'SIN_STOCK' using errcode = 'P0001';
  end if;

  begin
    update public.tienda_privado tp set contador_pedidos = tp.contador_pedidos + 1 where tp.tienda_id = v_t.id returning tp.contador_pedidos into v_num;
    insert into public.pedidos (id, tienda_id, numero, clave_cliente, comprador_nombre, comprador_tel, entrega_modo, direccion, pago_preferido, nota, idioma, moneda, subtotal)
    values (v_id, v_t.id, v_num, p_clave, v_nombre, v_tel, p_entrega, case when p_entrega = 'domicilio' then v_dir else '' end, p_pago, v_nota, v_idioma, v_t.moneda, v_sub);
    insert into public.pedido_items (pedido_id, tienda_id, producto_id, nombre, variante, cantidad, precio_unitario, total)
    select v_id, v_t.id, l.producto_id, l.nombre, l.variante, l.cantidad, l.precio, l.precio * l.cantidad
    from jsonb_to_recordset(v_lineas) as l(producto_id uuid, nombre text, variante text, cantidad integer, precio numeric);
  exception when unique_violation then
    select p.* into v_prev from public.pedidos p where p.clave_cliente = p_clave;
    if found and v_prev.tienda_id = v_t.id then
      return jsonb_build_object('id', v_prev.id, 'numero', v_prev.numero, 'subtotal', v_prev.subtotal, 'moneda', v_prev.moneda, 'repetido', true);
    end if;
    raise;
  end;
  return jsonb_build_object('id', v_id, 'numero', v_num, 'subtotal', v_sub, 'moneda', v_t.moneda, 'repetido', false);
end $$;

-- ---------- El vendedor avanza su pedido: solicitado → confirmado → pagado → entregado (o cancelado). ----------
-- Al ENTREGAR se descuenta el stock (no antes: el pedido aún no estaba confirmado).
create or replace function public.actualizar_estado_pedido(p_pedido uuid, p_estado text)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_p public.pedidos; v_agotados jsonb := '[]'::jsonb;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  select p.* into v_p from public.pedidos p join public.tiendas t on t.id = p.tienda_id
   where p.id = p_pedido and t.owner_id = v_uid for update of p;
  if not found then raise exception 'PEDIDO_NO_ENCONTRADO' using errcode = 'P0001'; end if;
  if p_estado is null or not ((v_p.estado = 'solicitado' and p_estado in ('confirmado','cancelado'))
       or (v_p.estado = 'confirmado' and p_estado in ('pagado','cancelado'))
       or (v_p.estado = 'pagado' and p_estado in ('entregado','cancelado'))) then
    raise exception 'CAMBIO_NO_PERMITIDO' using errcode = 'P0001', detail = v_p.estado || ' -> ' || coalesce(p_estado, '');
  end if;
  update public.pedidos p set estado = p_estado,
    confirmado_at = case when p_estado = 'confirmado' then now() else p.confirmado_at end,
    pagado_at     = case when p_estado = 'pagado'     then now() else p.pagado_at end,
    entregado_at  = case when p_estado = 'entregado'  then now() else p.entregado_at end,
    cancelado_at  = case when p_estado = 'cancelado'  then now() else p.cancelado_at end
  where p.id = v_p.id returning p.* into v_p;
  if p_estado = 'entregado' then
    with baja as (
      update public.productos pr set stock = greatest(pr.stock - i.q, 0)
      from (select it.producto_id, sum(it.cantidad)::integer as q from public.pedido_items it
            where it.pedido_id = v_p.id and it.producto_id is not null group by 1) i
      where pr.id = i.producto_id and pr.stock is not null
      returning pr.id, pr.nombre, pr.stock)
    select coalesce(jsonb_agg(jsonb_build_object('id', b.id, 'nombre', b.nombre)) filter (where b.stock = 0), '[]'::jsonb) into v_agotados from baja b;
  end if;
  return jsonb_build_object('id', v_p.id, 'numero', v_p.numero, 'estado', v_p.estado, 'agotados', v_agotados);
end $$;

-- ---------- seguridad: el vendedor solo LEE sus pedidos; el público no ve ninguno ----------
alter table public.pedidos      enable row level security;
alter table public.pedido_items enable row level security;
revoke all on public.pedidos, public.pedido_items from anon, authenticated;
grant all on public.pedidos, public.pedido_items to service_role;
grant select on public.pedidos, public.pedido_items to authenticated;
create policy pedidos_ver      on public.pedidos      for select to authenticated using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));
create policy pedido_items_ver on public.pedido_items for select to authenticated using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));

revoke execute on function public.crear_pedido(text, uuid, jsonb, text, text, text, text, text, text, text) from public, anon, authenticated;
grant  execute on function public.crear_pedido(text, uuid, jsonb, text, text, text, text, text, text, text) to anon, authenticated, service_role;
revoke execute on function public.actualizar_estado_pedido(uuid, text) from public, anon, authenticated;
grant  execute on function public.actualizar_estado_pedido(uuid, text) to authenticated, service_role;
