-- Videoclips de producto. Cada plan tiene un máximo de videos (planes.max_videos) y de segundos por video (planes.video_segundos).
-- Bucket aparte "videos": público para VER (como las fotos), solo el dueño sube, cambia y borra en su propia carpeta.
-- La duración la declara la app al subir el video (el celular la mide); el servidor la compara con el límite del plan.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('videos', 'videos', true, 12582912, array['video/mp4', 'video/webm', 'video/quicktime'])
on conflict (id) do update set public = excluded.public, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;

create policy videos_subir on storage.objects for insert to authenticated
  with check (bucket_id = 'videos' and (storage.foldername(name))[1] = (select t.id::text from public.tiendas t where t.owner_id = (select auth.uid())));
create policy videos_cambiar on storage.objects for update to authenticated
  using (bucket_id = 'videos' and (storage.foldername(name))[1] = (select t.id::text from public.tiendas t where t.owner_id = (select auth.uid())))
  with check (bucket_id = 'videos' and (storage.foldername(name))[1] = (select t.id::text from public.tiendas t where t.owner_id = (select auth.uid())));
create policy videos_borrar on storage.objects for delete to authenticated
  using (bucket_id = 'videos' and (storage.foldername(name))[1] = (select t.id::text from public.tiendas t where t.owner_id = (select auth.uid())));

alter table public.productos
  add column if not exists video_path text,
  add column if not exists video_segundos integer,
  add constraint productos_video_ruta check (video_path is null or (video_path like tienda_id::text || '/%' and video_path ~ '^[0-9a-f-]{36}/[A-Za-z0-9._/-]{1,120}$' and video_path !~ '\.\.')),
  add constraint productos_video_pareja check ((video_path is null) = (video_segundos is null)),
  add constraint productos_video_segundos check (video_segundos is null or video_segundos between 1 and 60);

grant update (video_path, video_segundos) on public.productos to authenticated;
grant insert (video_path, video_segundos) on public.productos to authenticated;

create or replace function private.video_limite() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_plan text; v_max_videos int; v_max_seg int; v_usados int;
begin
  if NEW.video_path is null then return NEW; end if;
  if TG_OP = 'UPDATE' and OLD.video_path is not distinct from NEW.video_path and OLD.video_segundos is not distinct from NEW.video_segundos then return NEW; end if;
  v_plan := private.plan_efectivo(NEW.tienda_id);
  select p.max_videos, p.video_segundos into v_max_videos, v_max_seg from public.planes p where p.id = v_plan;
  if NEW.video_segundos > v_max_seg then raise exception 'VIDEO_MUY_LARGO' using errcode = 'P0001'; end if;
  select count(*) into v_usados from public.productos p
    where p.tienda_id = NEW.tienda_id and p.video_path is not null and p.id is distinct from NEW.id;
  if v_usados >= v_max_videos then raise exception 'VIDEO_LIMITE' using errcode = 'P0001'; end if;
  return NEW;
end;
$$;

create trigger productos_video_limite before insert or update of video_path, video_segundos on public.productos
  for each row execute function private.video_limite();

revoke execute on function private.video_limite() from public, anon, authenticated;
