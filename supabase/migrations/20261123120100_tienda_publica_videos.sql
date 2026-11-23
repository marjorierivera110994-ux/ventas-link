-- La tienda pública ahora también entrega el videoclip de cada producto (video_path y segundos).
-- Resto de la función igual que en 20261117031556_publico_y_plan.sql.
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
              'video_path', p.video_path,
              'video_segundos', p.video_segundos,
              'nuevo', p.created_at > now() - interval '14 days') as j
            from public.productos p where p.tienda_id = v_t.id and p.activo
            order by p.orden, p.created_at desc limit 300) x), '[]'::jsonb),
    'total_productos', (select count(*) from public.productos p where p.tienda_id = v_t.id and p.activo));
end $$;
