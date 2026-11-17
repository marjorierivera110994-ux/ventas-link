-- 0005_fotos · espacio para fotos de productos, logo y portada.
-- Público para VER por enlace (un catálogo es público); solo el dueño sube/cambia/borra, y solo en SU carpeta.
-- Carpeta = id de la tienda. Solo JPG/PNG/WebP (SVG prohibido), máximo 4 MB por archivo.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('media', 'media', true, 4194304, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

-- Tope de archivos por tienda según su plan (2 por producto + 20 de margen): nadie puede llenar el espacio de todos.
create or replace function private.cupo_media() returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select (select count(*) from storage.objects o where o.bucket_id = 'media' and o.name like t.id::text || '/%')
         < (select 2 * p.max_productos + 20 from public.planes p where p.id = private.plan_efectivo(t.id))
    from public.tiendas t where t.owner_id = (select auth.uid())), false);
$$;
revoke execute on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.cupo_media() to authenticated;

create policy media_subir on storage.objects for insert to authenticated
  with check (bucket_id = 'media'
    and (storage.foldername(name))[1] = (select t.id::text from public.tiendas t where t.owner_id = (select auth.uid()))
    and (select private.cupo_media()));
create policy media_ver_propio on storage.objects for select to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select t.id::text from public.tiendas t where t.owner_id = (select auth.uid())));
create policy media_cambiar on storage.objects for update to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select t.id::text from public.tiendas t where t.owner_id = (select auth.uid())))
  with check (bucket_id = 'media' and (storage.foldername(name))[1] = (select t.id::text from public.tiendas t where t.owner_id = (select auth.uid())));
create policy media_borrar on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (storage.foldername(name))[1] = (select t.id::text from public.tiendas t where t.owner_id = (select auth.uid())));
