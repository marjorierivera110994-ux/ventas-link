-- MI CAMINO AL ÉXITO (puntos, niveles, retos, medallas, historial) + AVISOS (notificaciones push reales).
-- Todo se calcula en el servidor con hechos comprobables; el navegador solo LEE lo suyo y pide acciones por RPC.
-- Venta = pedido marcado "pagado" (o luego "entregado"). Una solicitud NO es venta. Si una venta se cancela, se descuentan sus puntos.
-- 2026-11-21

-- ---------- 0. Capa extra: tablas internas con protección aunque no se vean desde la app ----------
alter table private.admins enable row level security;
alter table private.slugs_retirados enable row level security;

create extension if not exists pg_net with schema extensions;

-- =====================================================================================
-- 1. AVISOS
-- =====================================================================================
create table public.avisos_preferencias (
  user_id           uuid primary key references auth.users(id) on delete cascade,
  pedidos           boolean not null default true,    -- nuevo pedido (solicitud)
  consultas         boolean not null default true,    -- un cliente abre WhatsApp para preguntar por un producto
  estados           boolean not null default false,   -- cambios de estado (los hace el vendedor: apagado por defecto)
  felicitaciones    boolean not null default true,    -- ventas, retos, metas, niveles, medallas
  recordatorio      boolean not null default true,    -- 1 recordatorio diario como máximo
  hora_recordatorio time not null default '19:00',
  zona              text not null default 'America/Guayaquil' check (char_length(zona) <= 60),
  updated_at        timestamptz not null default now()
);
alter table public.avisos_preferencias enable row level security;
revoke all on public.avisos_preferencias from anon, authenticated;
grant select on public.avisos_preferencias to authenticated;
grant all on public.avisos_preferencias to service_role;
create policy avisos_pref_ver on public.avisos_preferencias for select to authenticated using (user_id = (select auth.uid()));

create table public.push_suscripciones (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null references auth.users(id) on delete cascade,
  endpoint    text not null unique,
  p256dh      text not null,
  auth        text not null,
  dispositivo text not null default '',
  fallos      smallint not null default 0,
  ultimo_ok   timestamptz,
  created_at  timestamptz not null default now(),
  -- solo servicios de notificación reales (Google/Android, Apple, Mozilla, Microsoft): nadie puede usar el envío para llamar otras direcciones
  constraint push_endpoint_valido check (char_length(endpoint) <= 1000 and endpoint ~ '^https://(fcm\.googleapis\.com|[a-z0-9.-]+\.push\.services\.mozilla\.com|[a-z0-9.-]+\.notify\.windows\.com|web\.push\.apple\.com|[a-z0-9.-]+\.push\.apple\.com)/'),
  constraint push_p256dh_valido check (p256dh ~ '^[A-Za-z0-9_-]{80,100}={0,2}$'),
  constraint push_auth_valido check (auth ~ '^[A-Za-z0-9_-]{16,32}={0,2}$'),
  constraint push_dispositivo_valido check (char_length(dispositivo) <= 80)
);
create index push_suscripciones_user on public.push_suscripciones (user_id);
alter table public.push_suscripciones enable row level security;
revoke all on public.push_suscripciones from anon, authenticated;
grant select on public.push_suscripciones to authenticated;
grant all on public.push_suscripciones to service_role;
create policy push_ver on public.push_suscripciones for select to authenticated using (user_id = (select auth.uid()));

-- Configuración del envío: llaves de firma (se crean solas en el servidor la primera vez) y la contraseña interna
-- con la que la base despierta a la función de envío. Nada de esto pasa por el navegador ni por el chat.
create table private.push_config (
  id            boolean primary key default true check (id),
  vapid_publica text,
  vapid_privada jsonb,
  token         text not null default encode(extensions.gen_random_bytes(32), 'hex'),
  funcion_url   text not null,
  contacto      text not null
);
alter table private.push_config enable row level security;
revoke all on private.push_config from public, anon, authenticated;
insert into private.push_config (funcion_url, contacto)
values ('https://vqhkbijlnpjtklnlvvuf.supabase.co/functions/v1/enviar-avisos', 'https://grand-halva-1b3001.netlify.app');

-- Bandeja de salida: cada aviso una sola vez (clave única = sin duplicados).
create table private.avisos (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references auth.users(id) on delete cascade,
  categoria  text not null check (categoria in ('pedidos','consultas','estados','felicitaciones','recordatorio','prueba')),
  clave      text not null unique check (char_length(clave) <= 160),
  titulo     text not null check (char_length(titulo) <= 80),
  cuerpo     text not null check (char_length(cuerpo) <= 240),
  url        text not null check (url ~ '^[a-z0-9-]+\.html(#[a-z]+)?$'),
  etiqueta   text not null default '' check (char_length(etiqueta) <= 40),
  estado     text not null default 'pendiente' check (estado in ('pendiente','enviando','enviado','sin_destino','error')),
  intentos   smallint not null default 0,
  detalle    text not null default '',
  creado_at  timestamptz not null default now(),
  tomado_at  timestamptz,
  enviado_at timestamptz
);
create index avisos_por_enviar on private.avisos (id) where estado in ('pendiente','enviando','error');
create index avisos_por_usuario on private.avisos (user_id, creado_at);
alter table private.avisos enable row level security;
revoke all on private.avisos from public, anon, authenticated;

-- Último día en que el vendedor usó la app (para no mandar recordatorio a quien ya entró hoy).
create table private.actividad (
  user_id uuid primary key references auth.users(id) on delete cascade,
  dia     date not null
);
alter table private.actividad enable row level security;
revoke all on private.actividad from public, anon, authenticated;

create or replace function private.zona_de(p_uid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((select p.zona from public.avisos_preferencias p where p.user_id = p_uid), 'America/Guayaquil')
$$;

create or replace function private.marcar_actividad(p_uid uuid) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_uid is null then return; end if;
  insert into private.actividad (user_id, dia) values (p_uid, (now() at time zone private.zona_de(p_uid))::date)
  on conflict (user_id) do update set dia = excluded.dia where private.actividad.dia <> excluded.dia;
end $$;

-- Pone un aviso en la bandeja SOLO si el vendedor tiene esa categoría activada y al menos un celular suscrito.
create or replace function private.encolar_aviso(p_uid uuid, p_cat text, p_clave text, p_titulo text, p_cuerpo text, p_url text, p_etiqueta text default '')
returns boolean
language plpgsql security definer set search_path = '' as $$
declare v public.avisos_preferencias; v_ok boolean; v_id bigint;
begin
  if p_uid is null then return false; end if;
  select * into v from public.avisos_preferencias where user_id = p_uid;
  if found then
    v_ok := case p_cat when 'pedidos' then v.pedidos when 'consultas' then v.consultas when 'estados' then v.estados
                       when 'felicitaciones' then v.felicitaciones when 'recordatorio' then v.recordatorio else true end;
  else
    v_ok := p_cat <> 'estados';
  end if;
  if not v_ok then return false; end if;
  if not exists (select 1 from public.push_suscripciones s where s.user_id = p_uid) then return false; end if;
  insert into private.avisos (user_id, categoria, clave, titulo, cuerpo, url, etiqueta)
  values (p_uid, p_cat, left(p_clave, 160), left(p_titulo, 80), left(p_cuerpo, 240), p_url, left(coalesce(p_etiqueta, ''), 40))
  on conflict (clave) do nothing
  returning id into v_id;
  return v_id is not null;
end $$;

-- Despierta a la función de envío (llamada web asíncrona: no frena el pedido ni la venta).
create or replace function private.avisos_despertar() returns void
language plpgsql security definer set search_path = '' as $$
declare c private.push_config;
begin
  select * into c from private.push_config where id;
  if not found then return; end if;
  perform net.http_post(url := c.funcion_url, body := '{"accion":"enviar"}'::jsonb,
                        headers := jsonb_build_object('Content-Type', 'application/json', 'x-vl-token', c.token),
                        timeout_milliseconds := 8000);
end $$;

create or replace function private.avisos_tras_insertar() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  begin perform private.avisos_despertar(); exception when others then raise warning 'avisos_despertar: %', sqlerrm; end;
  return null;
end $$;
create trigger avisos_nuevos after insert on private.avisos for each statement execute function private.avisos_tras_insertar();

-- ---------- RPC del vendedor ----------
create or replace function public.push_clave_publica() returns text
language sql stable security definer set search_path = '' as $$
  select c.vapid_publica from private.push_config c where c.id
$$;

create or replace function public.push_guardar(p_endpoint text, p_p256dh text, p_auth text, p_dispositivo text default '')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  insert into public.push_suscripciones (user_id, endpoint, p256dh, auth, dispositivo)
  values (v_uid, btrim(p_endpoint), btrim(p_p256dh), btrim(p_auth), left(btrim(coalesce(p_dispositivo, '')), 80))
  on conflict (endpoint) do update set user_id = excluded.user_id, p256dh = excluded.p256dh, auth = excluded.auth,
                                     dispositivo = excluded.dispositivo, fallos = 0;
  -- máximo 10 celulares por cuenta: se quitan los más antiguos
  delete from public.push_suscripciones s where s.user_id = v_uid and s.id in (
    select x.id from public.push_suscripciones x where x.user_id = v_uid order by x.created_at desc offset 10);
  insert into public.avisos_preferencias (user_id) values (v_uid) on conflict (user_id) do nothing;
  return jsonb_build_object('ok', true);
exception when check_violation then
  raise exception 'SUSCRIPCION_INVALIDA' using errcode = 'P0001';
end $$;

create or replace function public.push_borrar(p_endpoint text) returns void
language sql security definer set search_path = '' as $$
  delete from public.push_suscripciones s where s.endpoint = btrim(p_endpoint) and s.user_id = (select auth.uid())
$$;

create or replace function public.avisos_mias() returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v public.avisos_preferencias; v_n int;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  select * into v from public.avisos_preferencias where user_id = v_uid;
  select count(*) into v_n from public.push_suscripciones where user_id = v_uid;
  return jsonb_build_object(
    'pedidos', coalesce(v.pedidos, true), 'consultas', coalesce(v.consultas, true), 'estados', coalesce(v.estados, false),
    'felicitaciones', coalesce(v.felicitaciones, true), 'recordatorio', coalesce(v.recordatorio, true),
    'hora', to_char(coalesce(v.hora_recordatorio, '19:00'::time), 'HH24:MI'), 'zona', coalesce(v.zona, 'America/Guayaquil'),
    'dispositivos', v_n);
end $$;

create or replace function public.avisos_guardar(p_pedidos boolean, p_consultas boolean, p_estados boolean, p_felicitaciones boolean,
                                                 p_recordatorio boolean, p_hora text, p_zona text default 'America/Guayaquil')
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_hora time; v_zona text := btrim(coalesce(p_zona, ''));
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  if p_hora is null or p_hora !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' then raise exception 'HORA_INVALIDA' using errcode = 'P0001'; end if;
  v_hora := p_hora::time;
  if not exists (select 1 from pg_catalog.pg_timezone_names z where z.name = v_zona) then v_zona := 'America/Guayaquil'; end if;
  insert into public.avisos_preferencias as a (user_id, pedidos, consultas, estados, felicitaciones, recordatorio, hora_recordatorio, zona, updated_at)
  values (v_uid, coalesce(p_pedidos, true), coalesce(p_consultas, true), coalesce(p_estados, false), coalesce(p_felicitaciones, true),
          coalesce(p_recordatorio, true), v_hora, v_zona, now())
  on conflict (user_id) do update set pedidos = excluded.pedidos, consultas = excluded.consultas, estados = excluded.estados,
    felicitaciones = excluded.felicitaciones, recordatorio = excluded.recordatorio, hora_recordatorio = excluded.hora_recordatorio,
    zona = excluded.zona, updated_at = now();
  return public.avisos_mias();
end $$;

-- Aviso de prueba (para que el vendedor compruebe que le llegan): máximo 1 por minuto.
create or replace function public.avisos_probar() returns boolean
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid());
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  return private.encolar_aviso(v_uid, 'prueba', 'prueba:' || v_uid || ':' || to_char(now(), 'YYYYMMDDHH24MI'),
    '🔔 ¡Tus avisos ya funcionan!', 'Así te avisaremos de cada pedido nuevo. Toca para abrir tu app.', 'app-vendedor.html#pedidos', 'prueba');
end $$;

-- ---------- RPC solo para la función de envío (service_role) ----------
create or replace function public.push_config_servidor() returns jsonb
language sql stable security definer set search_path = '' as $$
  select jsonb_build_object('publica', c.vapid_publica, 'privada', c.vapid_privada, 'token', c.token, 'contacto', c.contacto)
  from private.push_config c where c.id
$$;

create or replace function public.push_guardar_llaves(p_publica text, p_privada jsonb) returns text
language plpgsql security definer set search_path = '' as $$
begin
  if p_publica !~ '^[A-Za-z0-9_-]{86,88}$' or jsonb_typeof(p_privada) <> 'object' or (p_privada->>'d') is null then
    raise exception 'LLAVES_INVALIDAS' using errcode = 'P0001';
  end if;
  update private.push_config set vapid_publica = p_publica, vapid_privada = p_privada where id and vapid_publica is null;
  return (select c.vapid_publica from private.push_config c where c.id);
end $$;

create or replace function public.avisos_tomar(p_limite integer default 50) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare r jsonb;
begin
  with sel as (
    select a.id from private.avisos a
    where a.creado_at > now() - interval '1 day'
      and a.intentos < 3
      and (a.estado = 'pendiente' or a.estado = 'error' or (a.estado = 'enviando' and a.tomado_at < now() - interval '3 minutes'))
    order by a.id
    limit greatest(1, least(coalesce(p_limite, 50), 200))
    for update skip locked),
  upd as (
    update private.avisos a set estado = 'enviando', intentos = a.intentos + 1, tomado_at = now()
    from sel where a.id = sel.id
    returning a.id, a.user_id, a.categoria, a.titulo, a.cuerpo, a.url, a.etiqueta)
  select coalesce(jsonb_agg(jsonb_build_object(
           'id', u.id, 'categoria', u.categoria, 'titulo', u.titulo, 'cuerpo', u.cuerpo, 'url', u.url, 'etiqueta', u.etiqueta,
           'subs', coalesce((select jsonb_agg(jsonb_build_object('endpoint', s.endpoint, 'p256dh', s.p256dh, 'auth', s.auth))
                             from public.push_suscripciones s where s.user_id = u.user_id), '[]'::jsonb))), '[]'::jsonb)
  into r from upd u;
  return r;
end $$;

create or replace function public.avisos_resultado(p_id bigint, p_estado text, p_detalle text default '',
                                                   p_ok text[] default '{}', p_borrar text[] default '{}', p_fallo text[] default '{}')
returns void
language plpgsql security definer set search_path = '' as $$
begin
  update private.avisos set
    estado = case when p_estado in ('enviado','sin_destino','error') then p_estado else 'error' end,
    detalle = left(coalesce(p_detalle, ''), 300),
    enviado_at = case when p_estado = 'enviado' then now() else enviado_at end
  where id = p_id;
  update public.push_suscripciones set ultimo_ok = now(), fallos = 0 where endpoint = any (coalesce(p_ok, '{}'));
  delete from public.push_suscripciones where endpoint = any (coalesce(p_borrar, '{}'));
  update public.push_suscripciones set fallos = least(fallos + 1, 1000) where endpoint = any (coalesce(p_fallo, '{}'));
  delete from public.push_suscripciones where fallos >= 20;  -- un celular que lleva 20 fallos seguidos ya no existe
end $$;

-- =====================================================================================
-- 2. MI CAMINO AL ÉXITO
-- =====================================================================================
create table public.camino_logros (
  id         bigint generated always as identity primary key,
  tienda_id  uuid not null references public.tiendas(id) on delete cascade,
  tipo       text not null check (tipo in ('reto','medalla','meta','nivel','venta')),
  codigo     text not null check (codigo ~ '^[a-z0-9_]{2,40}$'),
  periodo    text not null default '' check (char_length(periodo) <= 40),   -- '' único · '2026-11-21' diario · '2026-S47' semanal · id del pedido en ventas
  titulo     text not null check (char_length(titulo) <= 80),
  puntos     integer not null default 0,
  visto      boolean not null default false,
  created_at timestamptz not null default now(),
  unique (tienda_id, tipo, codigo, periodo)
);
create index camino_logros_tienda on public.camino_logros (tienda_id, created_at desc);
create index camino_logros_no_vistos on public.camino_logros (tienda_id) where not visto;

create table public.camino_puntos (
  id         bigint generated always as identity primary key,
  tienda_id  uuid not null references public.tiendas(id) on delete cascade,
  clave      text not null check (char_length(clave) <= 120),
  motivo     text not null check (char_length(motivo) <= 80),
  puntos     integer not null check (puntos between -1000 and 1000),
  created_at timestamptz not null default now(),
  unique (tienda_id, clave)
);
create index camino_puntos_tienda on public.camino_puntos (tienda_id);

alter table public.camino_logros enable row level security;
alter table public.camino_puntos enable row level security;
revoke all on public.camino_logros, public.camino_puntos from anon, authenticated;
grant select on public.camino_logros, public.camino_puntos to authenticated;
grant all on public.camino_logros, public.camino_puntos to service_role;
create policy camino_logros_ver on public.camino_logros for select to authenticated
  using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));
create policy camino_puntos_ver on public.camino_puntos for select to authenticated
  using (tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid())));

-- Catálogo: UNA sola fuente para retos, metas y medallas. "hecho" = qué dato comprobable se mide; "meta" = cuánto se necesita.
create or replace function private.camino_catalogo() returns jsonb
language sql immutable set search_path = '' as $$
  select '[
    {"grupo":"mision","tipo":"reto","codigo":"completar_perfil","titulo":"Completa el perfil de tu tienda","descripcion":"Escribe una descripción corta y tu horario de atención.","puntos":30,"hecho":"perfil","meta":1},
    {"grupo":"mision","tipo":"reto","codigo":"primer_producto","titulo":"Sube tu primer producto","descripcion":"Con tu primer producto, tu tienda ya puede recibir pedidos.","puntos":20,"hecho":"productos","meta":1},
    {"grupo":"mision","tipo":"reto","codigo":"diez_productos","titulo":"Publica 10 productos","descripcion":"Un catálogo variado vende más.","puntos":40,"hecho":"productos","meta":10},
    {"grupo":"mision","tipo":"reto","codigo":"compartir_catalogo","titulo":"Comparte tu catálogo","descripcion":"Envía el enlace de tu tienda a tus clientes o súbelo a tus estados.","puntos":15,"hecho":"compartidas","meta":1},
    {"grupo":"mision","tipo":"reto","codigo":"primer_pedido","titulo":"Recibe tu primer pedido","descripcion":"Cuando un cliente te pida desde tu tienda.","puntos":25,"hecho":"pedidos","meta":1},
    {"grupo":"mision","tipo":"reto","codigo":"primera_venta","titulo":"Haz tu primera venta","descripcion":"Marca como pagado un pedido que ya cobraste.","puntos":50,"hecho":"ventas","meta":1},
    {"grupo":"mision","tipo":"reto","codigo":"nuevos_clientes","titulo":"Consigue 3 clientes","descripcion":"Recibe pedidos de 3 clientes distintos.","puntos":40,"hecho":"clientes","meta":3},
    {"grupo":"diario","tipo":"reto","codigo":"comparte_hoy","titulo":"Comparte tu tienda hoy","descripcion":"Un estado de WhatsApp con tu enlace basta.","puntos":5,"hecho":"comp_hoy","meta":1},
    {"grupo":"diario","tipo":"reto","codigo":"mejora_hoy","titulo":"Agrega o mejora un producto hoy","descripcion":"Una mejor foto o descripción también cuenta.","puntos":5,"hecho":"prod_hoy","meta":1},
    {"grupo":"semanal","tipo":"reto","codigo":"sube_3","titulo":"Sube 3 productos nuevos","descripcion":"Esta semana, de lunes a domingo.","puntos":20,"hecho":"prod_sem","meta":3},
    {"grupo":"semanal","tipo":"reto","codigo":"pedidos_3","titulo":"Recibe 3 pedidos","descripcion":"Esta semana, sin contar los cancelados.","puntos":25,"hecho":"ped_sem","meta":3},
    {"grupo":"semanal","tipo":"reto","codigo":"venta_semana","titulo":"Consigue una venta","descripcion":"Un pedido pagado esta semana.","puntos":30,"hecho":"ventas_sem","meta":1},
    {"grupo":"meta","tipo":"meta","codigo":"meta_semanal","titulo":"Alcanza tu meta de la semana","descripcion":"Tus ventas pagadas de la semana llegan a tu meta.","puntos":50,"hecho":"meta_ok","meta":1},
    {"grupo":"medalla","tipo":"medalla","codigo":"tienda_creada","titulo":"Primera tienda creada","descripcion":"Diste el primer paso.","puntos":10,"hecho":"tienda","meta":1},
    {"grupo":"medalla","tipo":"medalla","codigo":"primer_producto","titulo":"Primer producto publicado","descripcion":"Tu vitrina ya tiene algo que mostrar.","puntos":0,"hecho":"productos","meta":1},
    {"grupo":"medalla","tipo":"medalla","codigo":"catalogo_completo","titulo":"Catálogo completo","descripcion":"10 productos con foto.","puntos":0,"hecho":"productos_foto","meta":10},
    {"grupo":"medalla","tipo":"medalla","codigo":"primera_solicitud","titulo":"Primera solicitud de pedido","descripcion":"Alguien quiso lo que vendes.","puntos":0,"hecho":"pedidos","meta":1},
    {"grupo":"medalla","tipo":"medalla","codigo":"primera_venta","titulo":"Primera venta realizada","descripcion":"El comienzo de grandes cosas.","puntos":0,"hecho":"ventas","meta":1},
    {"grupo":"medalla","tipo":"medalla","codigo":"cinco_ventas","titulo":"Cinco ventas","descripcion":"Tu negocio ya está en marcha.","puntos":60,"hecho":"ventas","meta":5},
    {"grupo":"medalla","tipo":"medalla","codigo":"diez_ventas","titulo":"Diez ventas","descripcion":"Diez clientes confiaron en ti.","puntos":100,"hecho":"ventas","meta":10},
    {"grupo":"medalla","tipo":"medalla","codigo":"vendedor_constante","titulo":"Vendedor constante","descripcion":"Ventas en 4 semanas distintas.","puntos":80,"hecho":"semanas_venta","meta":4}
  ]'::jsonb
$$;

create or replace function private.camino_niveles() returns jsonb
language sql immutable set search_path = '' as $$
  select '[{"n":1,"nombre":"Emprendedor principiante","desde":0},{"n":2,"nombre":"Emprendedor activo","desde":100},
           {"n":3,"nombre":"Emprendedor destacado","desde":300},{"n":4,"nombre":"Emprendedor avanzado","desde":700},
           {"n":5,"nombre":"Experto en ventas","desde":1500}]'::jsonb
$$;

create or replace function private.camino_nivel(p_puntos integer) returns integer
language sql immutable set search_path = '' as $$
  select coalesce(max((x->>'n')::int), 1) from jsonb_array_elements(private.camino_niveles()) x where (x->>'desde')::int <= greatest(p_puntos, 0)
$$;

-- Hechos comprobables de una tienda (todo sale de la base, nada lo manda el navegador).
create or replace function private.camino_hechos(p_tienda uuid) returns jsonb
language plpgsql stable security definer set search_path = '' as $$
declare
  t public.tiendas; tz text; hoy date; ini_hoy timestamptz; ini_sem timestamptz; fin_sem timestamptz; ini_mes timestamptz;
  v_meta numeric; v_monto_sem numeric; r jsonb;
begin
  select * into t from public.tiendas where id = p_tienda;
  if not found then return null; end if;
  tz := private.zona_de(t.owner_id);
  hoy := (now() at time zone tz)::date;
  ini_hoy := hoy::timestamp at time zone tz;
  ini_sem := date_trunc('week', hoy::timestamp) at time zone tz;
  fin_sem := ini_sem + interval '7 days';
  ini_mes := date_trunc('month', hoy::timestamp) at time zone tz;
  select coalesce(tp.meta_semanal, 0) into v_meta from public.tienda_privado tp where tp.tienda_id = p_tienda;
  v_meta := coalesce(v_meta, 0);
  select coalesce(sum(p.subtotal), 0) into v_monto_sem from public.pedidos p
   where p.tienda_id = p_tienda and p.estado in ('pagado','entregado') and p.pagado_at >= ini_sem and p.pagado_at < fin_sem;
  select jsonb_build_object(
    'tienda', 1,
    'perfil', case when char_length(btrim(coalesce(t.descripcion, ''))) >= 10 and char_length(btrim(coalesce(t.horario, ''))) >= 3 then 1 else 0 end,
    'productos', (select count(*) from public.productos pr where pr.tienda_id = p_tienda and pr.activo),
    'productos_foto', (select count(*) from public.productos pr where pr.tienda_id = p_tienda and pr.activo and pr.foto_path is not null),
    'compartidas', (select count(*) from public.event_log e where e.tienda_id = p_tienda and e.tipo = 'tienda_compartida'),
    'pedidos', (select count(*) from public.pedidos p where p.tienda_id = p_tienda),
    'ventas', (select count(*) from public.pedidos p where p.tienda_id = p_tienda and p.estado in ('pagado','entregado')),
    'clientes', (select count(distinct coalesce(p.comprador_tel, lower(btrim(p.comprador_nombre)))) from public.pedidos p
                  where p.tienda_id = p_tienda and p.estado <> 'cancelado' and p.comprador_nombre <> 'Cliente'),
    'semanas_venta', (select count(distinct to_char(p.pagado_at at time zone tz, 'IYYY-IW')) from public.pedidos p
                       where p.tienda_id = p_tienda and p.estado in ('pagado','entregado') and p.pagado_at is not null),
    'comp_hoy', (select count(*) from public.event_log e where e.tienda_id = p_tienda and e.tipo = 'tienda_compartida' and e.created_at >= ini_hoy),
    'prod_hoy', (select count(*) from public.productos pr where pr.tienda_id = p_tienda and (pr.created_at >= ini_hoy or pr.updated_at >= ini_hoy)),
    'prod_sem', (select count(*) from public.productos pr where pr.tienda_id = p_tienda and pr.created_at >= ini_sem and pr.created_at < fin_sem),
    'ped_sem', (select count(*) from public.pedidos p where p.tienda_id = p_tienda and p.estado <> 'cancelado' and p.created_at >= ini_sem and p.created_at < fin_sem),
    'ventas_sem', (select count(*) from public.pedidos p where p.tienda_id = p_tienda and p.estado in ('pagado','entregado') and p.pagado_at >= ini_sem and p.pagado_at < fin_sem),
    'monto_sem', v_monto_sem,
    'meta_sem', v_meta,
    'meta_ok', case when v_meta > 0 and v_monto_sem >= v_meta then 1 else 0 end,
    'monto_mes', (select coalesce(sum(p.subtotal), 0) from public.pedidos p where p.tienda_id = p_tienda and p.estado in ('pagado','entregado') and p.pagado_at >= ini_mes),
    'ventas_mes', (select count(*) from public.pedidos p where p.tienda_id = p_tienda and p.estado in ('pagado','entregado') and p.pagado_at >= ini_mes),
    'monto_total', (select coalesce(sum(p.subtotal), 0) from public.pedidos p where p.tienda_id = p_tienda and p.estado in ('pagado','entregado')),
    'hoy', to_char(hoy, 'YYYY-MM-DD'),
    'semana', to_char(hoy, 'IYYY-"S"IW'),
    'moneda', t.moneda
  ) into r;
  return r;
end $$;

-- Da un logro una sola vez (y sus puntos una sola vez). Devuelve el logro nuevo o null si ya existía.
create or replace function private.camino_dar(p_tienda uuid, p_tipo text, p_codigo text, p_periodo text, p_titulo text, p_puntos integer, p_visto boolean default false)
returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v public.camino_logros;
begin
  insert into public.camino_logros (tienda_id, tipo, codigo, periodo, titulo, puntos, visto)
  values (p_tienda, p_tipo, p_codigo, coalesce(p_periodo, ''), left(p_titulo, 80), p_puntos, p_visto)
  on conflict (tienda_id, tipo, codigo, periodo) do nothing
  returning * into v;
  if v.id is null then return null; end if;
  if p_puntos <> 0 then
    insert into public.camino_puntos (tienda_id, clave, motivo, puntos)
    values (p_tienda, p_tipo || ':' || p_codigo || ':' || coalesce(p_periodo, ''), left(p_titulo, 80), p_puntos)
    on conflict (tienda_id, clave) do nothing;
  end if;
  return jsonb_build_object('id', v.id, 'tipo', v.tipo, 'codigo', v.codigo, 'periodo', v.periodo, 'titulo', v.titulo, 'puntos', v.puntos);
end $$;

-- Motor: revisa los hechos y entrega lo que corresponda. Idempotente (se puede llamar mil veces).
create or replace function private.camino_evaluar(p_tienda uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  h jsonb; c jsonb; nuevos jsonb := '[]'::jsonb; x jsonb; v_antes int; v_ahora int; v_periodo text; lvl jsonb; r record;
begin
  h := private.camino_hechos(p_tienda);
  if h is null then return '[]'::jsonb; end if;
  select coalesce(sum(puntos), 0) into v_antes from public.camino_puntos where tienda_id = p_tienda;

  for c in select * from jsonb_array_elements(private.camino_catalogo()) loop
    if coalesce((h->>(c->>'hecho'))::numeric, 0) >= (c->>'meta')::numeric then
      v_periodo := case c->>'grupo' when 'diario' then h->>'hoy' when 'semanal' then h->>'semana' when 'meta' then h->>'semana' else '' end;
      x := private.camino_dar(p_tienda, c->>'tipo', c->>'codigo', v_periodo, c->>'titulo', (c->>'puntos')::int);
      if x is not null then nuevos := nuevos || x; end if;
    end if;
  end loop;

  -- Cada venta pagada suma 10 puntos (una sola vez por pedido).
  for r in select p.id, p.numero from public.pedidos p
            where p.tienda_id = p_tienda and p.estado in ('pagado','entregado') and p.pagado_at is not null
              and not exists (select 1 from public.camino_logros l where l.tienda_id = p_tienda and l.tipo = 'venta' and l.codigo = 'venta' and l.periodo = p.id::text)
  loop
    x := private.camino_dar(p_tienda, 'venta', 'venta', r.id::text, 'Venta del pedido #' || r.numero, 10);
    if x is not null then nuevos := nuevos || x; end if;
  end loop;
  -- Venta cancelada después de pagada: se descuentan sus puntos (queda en el historial, sin celebración).
  for r in select p.id, p.numero from public.pedidos p
            where p.tienda_id = p_tienda and p.estado = 'cancelado'
              and exists (select 1 from public.camino_logros l where l.tienda_id = p_tienda and l.tipo = 'venta' and l.codigo = 'venta' and l.periodo = p.id::text)
              and not exists (select 1 from public.camino_logros l where l.tienda_id = p_tienda and l.tipo = 'venta' and l.codigo = 'anulada' and l.periodo = p.id::text)
  loop
    perform private.camino_dar(p_tienda, 'venta', 'anulada', r.id::text, 'Venta del pedido #' || r.numero || ' cancelada', -10, true);
  end loop;

  -- Niveles
  select coalesce(sum(puntos), 0) into v_ahora from public.camino_puntos where tienda_id = p_tienda;
  for lvl in select * from jsonb_array_elements(private.camino_niveles()) loop
    if (lvl->>'n')::int > 1 and (lvl->>'n')::int <= private.camino_nivel(v_ahora) then
      x := private.camino_dar(p_tienda, 'nivel', 'nivel_' || (lvl->>'n'), '', lvl->>'nombre', 0,
                              (lvl->>'n')::int <= private.camino_nivel(v_antes));  -- si ya tenía ese nivel, no se celebra de nuevo
      if x is not null and (lvl->>'n')::int > private.camino_nivel(v_antes) then nuevos := nuevos || x; end if;
    end if;
  end loop;
  return nuevos;
end $$;

create or replace function private.monto(p numeric, p_moneda text) returns text
language sql immutable set search_path = '' as $$
  select case when coalesce(p_moneda, 'USD') = 'USD' then private.dinero(p) else ltrim(private.dinero(p), '$') || ' ' || p_moneda end
$$;

-- Un solo aviso de felicitación por grupo de logros nuevos (no 3 avisos a la vez).
create or replace function private.camino_felicitar(p_tienda uuid, p_nuevos jsonb) returns boolean
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid; v_tit text; v_cuerpo text; v_pts int; v_min bigint; v_venta jsonb; v_nivel jsonb; v_medalla jsonb; v_meta jsonb; v_reto jsonb; v_primera boolean;
begin
  if p_nuevos is null or jsonb_array_length(p_nuevos) = 0 then return false; end if;
  select t.owner_id into v_uid from public.tiendas t where t.id = p_tienda;
  select coalesce(sum((x->>'puntos')::int), 0), min((x->>'id')::bigint) into v_pts, v_min from jsonb_array_elements(p_nuevos) x;
  select x into v_venta   from jsonb_array_elements(p_nuevos) x where x->>'tipo' = 'venta' limit 1;
  select x into v_nivel   from jsonb_array_elements(p_nuevos) x where x->>'tipo' = 'nivel' order by x->>'codigo' desc limit 1;
  select x into v_medalla from jsonb_array_elements(p_nuevos) x where x->>'tipo' = 'medalla' order by (x->>'puntos')::int desc limit 1;
  select x into v_meta    from jsonb_array_elements(p_nuevos) x where x->>'tipo' = 'meta' limit 1;
  select x into v_reto    from jsonb_array_elements(p_nuevos) x where x->>'tipo' = 'reto' order by (x->>'puntos')::int desc limit 1;
  v_primera := exists (select 1 from jsonb_array_elements(p_nuevos) x where x->>'codigo' = 'primera_venta');
  if v_venta is not null and v_primera then
    v_tit := '🎉 ¡Lo lograste! Tu primera venta';
    v_cuerpo := 'Este es el comienzo de grandes cosas. Ganaste ' || v_pts || ' puntos. ¡Sigue creciendo con Ventas Link!';
  elsif v_venta is not null then
    v_tit := '🎉 ¡Felicidades! Nueva venta';
    v_cuerpo := 'Cada paso te acerca más a tus sueños. +' || v_pts || ' puntos. ¡Sigue creciendo con Ventas Link!';
  elsif v_nivel is not null then
    v_tit := '🏆 ¡Subiste de nivel!';
    v_cuerpo := 'Ahora eres ' || (v_nivel->>'titulo') || '. Sigue construyendo tu camino al éxito.';
  elsif v_meta is not null then
    v_tit := '🎯 ¡Alcanzaste tu meta de la semana!';
    v_cuerpo := 'Excelente trabajo. +' || v_pts || ' puntos en tu camino al éxito.';
  elsif v_medalla is not null then
    v_tit := '🏅 ¡Nueva medalla!';
    v_cuerpo := (v_medalla->>'titulo') || case when v_pts > 0 then '. +' || v_pts || ' puntos.' else '. Mírala en tu camino al éxito.' end;
  elsif v_reto is not null then
    v_tit := '✅ ¡Reto cumplido!';
    v_cuerpo := (v_reto->>'titulo') || '. +' || v_pts || ' puntos. ¡Excelente trabajo!';
  else
    return false;
  end if;
  return private.encolar_aviso(v_uid, 'felicitaciones', 'felic:' || p_tienda || ':' || v_min, v_tit, v_cuerpo, 'app-vendedor.html#camino', 'camino');
end $$;

create or replace function private.camino_revisar(p_tienda uuid) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v jsonb;
begin
  v := private.camino_evaluar(p_tienda);
  perform private.camino_felicitar(p_tienda, v);
  return v;
exception when others then
  raise warning 'camino_revisar %: %', p_tienda, sqlerrm;   -- un error aquí JAMÁS frena un pedido, una venta ni un producto
  return '[]'::jsonb;
end $$;

-- ---------- Disparadores: pedidos, productos, tienda y "compartí mi tienda" ----------
create or replace function private.resumen_items(p_pedido uuid) returns text
language sql stable security definer set search_path = '' as $$
  select case when count(*) = 0 then 'Tu pedido'
              else (array_agg(i.nombre || case when i.cantidad > 1 then ' ×' || i.cantidad else '' end order by i.created_at, i.nombre))[1]
                   || case when count(*) > 1 then ' y ' || (count(*) - 1) || case when count(*) = 2 then ' producto más' else ' productos más' end else '' end
         end
  from public.pedido_items i where i.pedido_id = p_pedido
$$;

create or replace function private.pedido_nuevo_aviso() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid; v_nuevos jsonb; v_extra text := '';
begin
  begin
    select t.owner_id into v_uid from public.tiendas t where t.id = new.tienda_id;
    v_nuevos := private.camino_evaluar(new.tienda_id);
    if exists (select 1 from jsonb_array_elements(v_nuevos) x where x->>'codigo' in ('primer_pedido','primera_solicitud')) then
      v_extra := ' 🏅 ¡Tu primera solicitud de pedido!';
    end if;
    -- Sin datos del comprador: solo número, productos, total y forma de entrega.
    perform private.encolar_aviso(v_uid, 'pedidos', 'pedido:' || new.id || ':solicitado',
      '🛍️ Nuevo pedido #' || new.numero,
      private.resumen_items(new.id) || ' · ' || private.monto(new.subtotal, new.moneda) || ' · '
        || case new.entrega_modo when 'domicilio' then 'Envío a domicilio' else 'Retiro' end || '. Confírmalo por WhatsApp.' || v_extra,
      'app-vendedor.html#pedidos', 'pedido');
    -- Los logros del primer pedido van dentro de este mismo aviso; si hubo otros (raro), van aparte.
    if jsonb_array_length(v_nuevos) > 0 and v_extra = '' then perform private.camino_felicitar(new.tienda_id, v_nuevos); end if;
  exception when others then
    raise warning 'pedido_nuevo_aviso %: %', new.id, sqlerrm;
  end;
  return null;
end $$;
-- Al final de la transacción (cuando el pedido ya tiene sus productos).
create constraint trigger pedidos_aviso_nuevo after insert on public.pedidos
  deferrable initially deferred for each row execute function private.pedido_nuevo_aviso();

create or replace function private.pedido_estado_aviso() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid; v_nuevos jsonb; v_felic boolean := false; v_txt text;
begin
  begin
    select t.owner_id into v_uid from public.tiendas t where t.id = new.tienda_id;
    v_nuevos := private.camino_evaluar(new.tienda_id);
    v_felic := private.camino_felicitar(new.tienda_id, v_nuevos);
    v_txt := case new.estado when 'confirmado' then 'confirmado' when 'pagado' then 'pagado' when 'entregado' then 'entregado' when 'cancelado' then 'cancelado' else new.estado end;
    -- "Cambios de estado" (apagado por defecto): no se manda si ya salió la felicitación de esa venta.
    if not v_felic then
      perform private.encolar_aviso(v_uid, 'estados', 'pedido:' || new.id || ':' || new.estado,
        '📦 Pedido #' || new.numero || ': ' || v_txt,
        private.resumen_items(new.id) || ' · ' || private.monto(new.subtotal, new.moneda) || '.',
        'app-vendedor.html#pedidos', 'pedido');
    end if;
  exception when others then
    raise warning 'pedido_estado_aviso %: %', new.id, sqlerrm;
  end;
  return null;
end $$;
create trigger pedidos_aviso_estado after update of estado on public.pedidos
  for each row when (old.estado is distinct from new.estado) execute function private.pedido_estado_aviso();

create or replace function private.camino_por_productos() returns trigger
language plpgsql security definer set search_path = '' as $$
declare r record;
begin
  for r in select distinct n.tienda_id from nuevos n loop perform private.camino_revisar(r.tienda_id); end loop;
  return null;
end $$;
create trigger productos_camino_ins after insert on public.productos referencing new table as nuevos
  for each statement execute function private.camino_por_productos();
create trigger productos_camino_upd after update on public.productos referencing new table as nuevos
  for each statement execute function private.camino_por_productos();

create or replace function private.camino_por_tienda() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.camino_revisar(new.id);
  return null;
end $$;
create trigger tiendas_camino after insert or update of descripcion, horario on public.tiendas
  for each row execute function private.camino_por_tienda();

create or replace function private.camino_por_evento() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  perform private.camino_revisar(new.tienda_id);
  return null;
end $$;
create trigger event_log_camino after insert on public.event_log
  for each row when (new.tipo = 'tienda_compartida' and new.tienda_id is not null) execute function private.camino_por_evento();

-- "Compartí mi tienda" pasa a ser un evento válido (lo registra la app del vendedor con su sesión).
create or replace function public.registrar_evento(p_tipo text, p_anon text default null, p_props jsonb default '{}'::jsonb) returns void
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_t uuid; v_n int; v_anon text := nullif(lower(btrim(coalesce(p_anon, ''))), '');
begin
  if p_tipo is null or p_tipo not in ('landing_vista', 'onboarding_iniciado', 'onboarding_paso_completado', 'onboarding_planes_visto',
                                      'sesion_iniciada', 'frase_compartida', 'tienda_compartida') then return; end if;
  if p_tipo = 'tienda_compartida' and v_uid is null then return; end if;
  if v_anon is not null and v_anon !~ '^[a-z0-9-]{8,40}$' then v_anon := null; end if;
  if v_uid is null and v_anon is null then return; end if;
  if p_props is null or jsonb_typeof(p_props) <> 'object' or octet_length(p_props::text) > 512 then p_props := '{}'::jsonb; end if;
  select count(*) into v_n from public.event_log e
   where e.created_at > now() - interval '10 minutes' and ((v_uid is not null and e.user_id = v_uid) or (v_uid is null and e.anon_id = v_anon));
  if v_n >= 60 then return; end if;
  if v_uid is not null then select t.id into v_t from public.tiendas t where t.owner_id = v_uid; end if;
  insert into public.event_log (tipo, user_id, tienda_id, anon_id, props) values (p_tipo, v_uid, v_t, v_anon, p_props)
  on conflict do nothing;
end $$;

-- Un cliente abre WhatsApp para preguntar por un producto: se avisa al vendedor (máx. 1 por producto por hora y 10 al día).
create or replace function public.registrar_consulta(p_slug text, p_producto uuid) returns void
language plpgsql security definer set search_path = '' as $$
declare t public.tiendas; v_nombre text; v_n int;
begin
  select * into t from public.tiendas where slug = lower(btrim(coalesce(p_slug, ''))) and publicada;
  if not found or p_producto is null then return; end if;
  if t.owner_id = (select auth.uid()) then return; end if;   -- el propio vendedor probando su tienda no cuenta
  select pr.nombre into v_nombre from public.productos pr where pr.id = p_producto and pr.tienda_id = t.id and pr.activo;
  if v_nombre is null then return; end if;
  select count(*) into v_n from private.avisos a where a.user_id = t.owner_id and a.categoria = 'consultas' and a.creado_at > now() - interval '1 day';
  if v_n >= 10 then return; end if;
  perform private.encolar_aviso(t.owner_id, 'consultas', 'consulta:' || p_producto || ':' || to_char(now(), 'YYYYMMDDHH24'),
    '💬 Te están preguntando por un producto',
    'Un cliente abrió WhatsApp para preguntarte por «' || left(v_nombre, 60) || '». Respóndele pronto.',
    'app-vendedor.html#productos', 'consulta');
end $$;

-- ---------- RPC de la sección "Mi camino al éxito" ----------
create or replace function public.mi_camino() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := (select auth.uid()); t public.tiendas; h jsonb; v_pts int; v_n int; nv jsonb; sig jsonb; c jsonb;
  retos jsonb := '[]'::jsonb; medallas jsonb := '[]'::jsonb; v_hecho numeric; v_meta numeric; v_per text; l public.camino_logros;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  select * into t from public.tiendas where owner_id = v_uid;
  if not found then raise exception 'SIN_TIENDA' using errcode = 'P0001'; end if;
  perform private.marcar_actividad(v_uid);
  perform private.camino_revisar(t.id);          -- retos de hoy/semana que se cumplieron con el paso del tiempo
  h := private.camino_hechos(t.id);
  select coalesce(sum(puntos), 0) into v_pts from public.camino_puntos where tienda_id = t.id;
  v_n := private.camino_nivel(v_pts);
  select x into nv from jsonb_array_elements(private.camino_niveles()) x where (x->>'n')::int = v_n;
  select x into sig from jsonb_array_elements(private.camino_niveles()) x where (x->>'n')::int = v_n + 1;

  for c in select * from jsonb_array_elements(private.camino_catalogo()) loop
    v_hecho := coalesce((h->>(c->>'hecho'))::numeric, 0); v_meta := (c->>'meta')::numeric;
    v_per := case c->>'grupo' when 'diario' then h->>'hoy' when 'semanal' then h->>'semana' when 'meta' then h->>'semana' else '' end;
    select * into l from public.camino_logros where tienda_id = t.id and tipo = c->>'tipo' and codigo = c->>'codigo' and periodo = v_per;
    if c->>'grupo' = 'medalla' then
      medallas := medallas || jsonb_build_object('codigo', c->>'codigo', 'titulo', c->>'titulo', 'descripcion', c->>'descripcion',
                    'puntos', (c->>'puntos')::int, 'ganada', l.id is not null, 'fecha', l.created_at, 'avance', least(v_hecho, v_meta), 'meta', v_meta);
    else
      retos := retos || jsonb_build_object('grupo', c->>'grupo', 'codigo', c->>'codigo', 'titulo', c->>'titulo', 'descripcion', c->>'descripcion',
                 'puntos', (c->>'puntos')::int,
                 'estado', case when l.id is not null then 'completado' when v_hecho > 0 and c->>'codigo' <> 'meta_semanal' then 'en_progreso'
                                when c->>'codigo' = 'meta_semanal' and (h->>'monto_sem')::numeric > 0 then 'en_progreso' else 'pendiente' end,
                 'avance', case when c->>'codigo' = 'meta_semanal' then least((h->>'monto_sem')::numeric, greatest((h->>'meta_sem')::numeric, 0)) else least(v_hecho, v_meta) end,
                 'meta', case when c->>'codigo' = 'meta_semanal' then (h->>'meta_sem')::numeric else v_meta end,
                 'fecha', l.created_at);
    end if;
  end loop;

  return jsonb_build_object(
    'tienda', jsonb_build_object('nombre', t.nombre, 'slug', t.slug, 'moneda', t.moneda, 'descripcion', coalesce(t.descripcion, ''), 'horario', coalesce(t.horario, '')),
    'puntos', v_pts,
    'nivel', nv, 'siguiente', sig,
    'faltan', case when sig is null then 0 else (sig->>'desde')::int - v_pts end,
    'niveles', private.camino_niveles(),
    'retos', retos, 'medallas', medallas,
    'ventas', jsonb_build_object('semana', h->'ventas_sem', 'monto_semana', h->'monto_sem', 'meta_semana', h->'meta_sem',
                                 'mes', h->'ventas_mes', 'monto_mes', h->'monto_mes', 'total', h->'ventas', 'monto_total', h->'monto_total'),
    'historial', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tipo', x.tipo, 'codigo', x.codigo, 'titulo', x.titulo, 'puntos', x.puntos, 'fecha', x.created_at) order by x.created_at desc, x.id desc)
                           from (select * from public.camino_logros where tienda_id = t.id order by created_at desc, id desc limit 80) x), '[]'::jsonb),
    'nuevos', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tipo', x.tipo, 'codigo', x.codigo, 'titulo', x.titulo, 'puntos', x.puntos) order by x.id)
                        from public.camino_logros x where x.tienda_id = t.id and not x.visto), '[]'::jsonb));
end $$;

-- Logros que todavía no se celebraron en la app (para la pantalla de pedidos y el inicio).
create or replace function public.camino_nuevos() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_t uuid; v_pts int;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  select id into v_t from public.tiendas where owner_id = v_uid;
  if v_t is null then return jsonb_build_object('nuevos', '[]'::jsonb); end if;
  perform private.marcar_actividad(v_uid);
  select coalesce(sum(puntos), 0) into v_pts from public.camino_puntos where tienda_id = v_t;
  return jsonb_build_object('puntos', v_pts, 'nivel', (select x from jsonb_array_elements(private.camino_niveles()) x where (x->>'n')::int = private.camino_nivel(v_pts)),
    'nuevos', coalesce((select jsonb_agg(jsonb_build_object('id', x.id, 'tipo', x.tipo, 'codigo', x.codigo, 'titulo', x.titulo, 'puntos', x.puntos) order by x.id)
                        from public.camino_logros x where x.tienda_id = v_t and not x.visto), '[]'::jsonb));
end $$;

create or replace function public.camino_visto(p_ids bigint[]) returns void
language sql security definer set search_path = '' as $$
  update public.camino_logros l set visto = true
  where l.id = any (coalesce(p_ids, '{}')) and l.tienda_id = (select t.id from public.tiendas t where t.owner_id = (select auth.uid()))
$$;

create or replace function public.guardar_meta_semanal(p_meta numeric) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_t uuid;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  if p_meta is null or p_meta < 0 or p_meta > 99999999 then raise exception 'META_INVALIDA' using errcode = 'P0001'; end if;
  select id into v_t from public.tiendas where owner_id = v_uid;
  if v_t is null then raise exception 'SIN_TIENDA' using errcode = 'P0001'; end if;
  update public.tienda_privado set meta_semanal = round(p_meta, 2) where tienda_id = v_t;
  perform private.camino_revisar(v_t);
  return public.camino_nuevos();
end $$;

-- ---------- Recordatorio diario (1 al día como máximo, a la hora que elige el vendedor) ----------
create or replace function private.recordatorio_frases() returns text[]
language sql immutable set search_path = '' as $$
  select array[
    '☀️ Hoy es un buen día para vender', '💜 Tu tienda te está esperando', '🚀 Cada venta empieza con un paso',
    '✨ Lo que haces hoy suma para mañana', '🌱 Los negocios grandes empezaron pequeños', '🔥 Tu constancia es tu mejor publicidad',
    '💪 Vender es ayudar a alguien a decidir', '🎯 Un pequeño avance hoy cuenta', '🛍️ Alguien está buscando lo que vendes',
    '🌟 Tu esfuerzo de hoy es tu venta de mañana', '📣 Que hoy te vean: comparte tu enlace', '🤝 Atender bien también es vender',
    '⏰ Diez minutos hoy hacen la diferencia', '🙌 Sigue creciendo con Ventas Link', '💡 Una buena foto vende más',
    '🌈 Tus sueños se construyen pedido a pedido', '🏁 Hoy puedes acercarte a tu meta', '😊 Responder rápido enamora a tus clientes',
    '📦 Tu catálogo es tu vitrina: mantenla linda', '🧡 Lo estás haciendo bien, sigue así', '🪴 Constancia antes que perfección',
    '⚡ Tu próxima venta puede ser hoy', '🎉 Celebra cada paso, también los pequeños', '🔑 Tu enlace abre la puerta de tu tienda']
$$;

create or replace function private.avisos_programar() returns integer
language plpgsql security definer set search_path = '' as $$
declare
  r record; v_local timestamp; v_dia date; t public.tiendas; h jsonb; v_frases text[] := private.recordatorio_frases();
  v_tit text; v_cuerpo text; v_url text; v_pend int; v_n int := 0;
begin
  for r in select p.user_id, p.hora_recordatorio, p.zona from public.avisos_preferencias p
           where p.recordatorio and exists (select 1 from public.push_suscripciones s where s.user_id = p.user_id)
  loop
    begin
      v_local := now() at time zone r.zona;
      if v_local::time < r.hora_recordatorio or (v_local::time - r.hora_recordatorio) >= interval '3 hours' then continue; end if;
      v_dia := v_local::date;
      if exists (select 1 from private.actividad a where a.user_id = r.user_id and a.dia = v_dia) then continue; end if;   -- ya entró hoy
      if exists (select 1 from private.avisos a where a.clave = 'diario:' || r.user_id || ':' || v_dia) then continue; end if;
      select * into t from public.tiendas where owner_id = r.user_id;
      v_tit := v_frases[1 + ((extract(doy from v_dia)::int + abs(hashtext(r.user_id::text))) % array_length(v_frases, 1))];
      v_url := 'app-vendedor.html#camino';
      if t.id is null then
        v_cuerpo := 'Termina de crear tu tienda: en 2 minutos ya puedes empezar a vender.'; v_url := 'app-vendedor.html';
      else
        h := private.camino_hechos(t.id);
        select count(*) into v_pend from public.pedidos p where p.tienda_id = t.id and p.estado = 'solicitado';
        if v_pend > 0 then
          v_cuerpo := 'Tienes ' || v_pend || case when v_pend = 1 then ' pedido esperando tu respuesta. Atiéndelo hoy.' else ' pedidos esperando tu respuesta. Atiéndelos hoy.' end;
          v_url := 'app-vendedor.html#pedidos';
        elsif (h->>'productos')::int = 0 then
          v_cuerpo := 'Sube tu primer producto: con eso tu tienda empieza a vender.'; v_url := 'app-vendedor.html#productos';
        elsif (h->>'meta_sem')::numeric > 0 and (h->>'meta_ok')::int = 0 then
          v_cuerpo := 'Te faltan ' || private.monto((h->>'meta_sem')::numeric - (h->>'monto_sem')::numeric, t.moneda) || ' para tu meta de la semana. Comparte tu tienda hoy.';
        else
          v_cuerpo := 'Comparte tu tienda hoy en tus estados: cada visita es una oportunidad de venta.';
        end if;
      end if;
      if private.encolar_aviso(r.user_id, 'recordatorio', 'diario:' || r.user_id || ':' || v_dia, v_tit, v_cuerpo, v_url, 'recordatorio') then v_n := v_n + 1; end if;
    exception when others then
      raise warning 'avisos_programar %: %', r.user_id, sqlerrm;
    end;
  end loop;
  return v_n;
end $$;
create or replace function private.avisos_cron() returns void
language plpgsql security definer set search_path = '' as $$
begin
  perform private.avisos_programar();
  if exists (select 1 from private.avisos a where a.creado_at > now() - interval '1 day' and a.intentos < 3
             and (a.estado in ('pendiente','error') or (a.estado = 'enviando' and a.tomado_at < now() - interval '3 minutes'))) then
    perform private.avisos_despertar();
  end if;
end $$;

-- ---------- Retención: la bandeja de avisos se limpia a los 90 días ----------
create or replace function private.aplicar_retencion() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_p int; v_e int; v_r int; v_a int; v_v int;
begin
  update public.pedidos set comprador_nombre = 'Cliente', comprador_tel = null, direccion = '', nota = ''
   where created_at < now() - interval '12 months'
     and (comprador_nombre <> 'Cliente' or comprador_tel is not null or direccion <> '' or nota <> '');
  get diagnostics v_p = row_count;
  delete from public.event_log where created_at < now() - interval '25 months';
  get diagnostics v_e = row_count;
  delete from public.error_log where created_at < now() - interval '90 days';
  get diagnostics v_r = row_count;
  delete from public.admin_acciones where created_at < now() - interval '25 months';
  get diagnostics v_a = row_count;
  delete from private.avisos where creado_at < now() - interval '90 days';
  get diagnostics v_v = row_count;
  return jsonb_build_object('pedidos_anonimizados', v_p, 'eventos', v_e, 'errores', v_r, 'bitacora', v_a, 'avisos', v_v);
end $$;

-- ---------- Permisos ----------
do $$
declare f text;
begin
  foreach f in array array[
    'private.zona_de(uuid)', 'private.marcar_actividad(uuid)', 'private.encolar_aviso(uuid,text,text,text,text,text,text)',
    'private.avisos_despertar()', 'private.avisos_tras_insertar()', 'private.camino_catalogo()', 'private.camino_niveles()',
    'private.camino_nivel(integer)', 'private.camino_hechos(uuid)', 'private.camino_dar(uuid,text,text,text,text,integer,boolean)',
    'private.camino_evaluar(uuid)', 'private.camino_felicitar(uuid,jsonb)', 'private.camino_revisar(uuid)', 'private.resumen_items(uuid)',
    'private.pedido_nuevo_aviso()', 'private.pedido_estado_aviso()', 'private.camino_por_productos()', 'private.camino_por_tienda()',
    'private.camino_por_evento()', 'private.recordatorio_frases()', 'private.avisos_programar()', 'private.avisos_cron()', 'private.aplicar_retencion()']
  loop execute format('revoke execute on function %s from public, anon, authenticated', f); end loop;
end $$;

revoke execute on function public.push_clave_publica(), public.push_guardar(text,text,text,text), public.push_borrar(text),
  public.avisos_mias(), public.avisos_guardar(boolean,boolean,boolean,boolean,boolean,text,text), public.avisos_probar(),
  public.mi_camino(), public.camino_nuevos(), public.camino_visto(bigint[]), public.guardar_meta_semanal(numeric) from public, anon;
grant execute on function public.push_clave_publica(), public.push_guardar(text,text,text,text), public.push_borrar(text),
  public.avisos_mias(), public.avisos_guardar(boolean,boolean,boolean,boolean,boolean,text,text), public.avisos_probar(),
  public.mi_camino(), public.camino_nuevos(), public.camino_visto(bigint[]), public.guardar_meta_semanal(numeric) to authenticated, service_role;

revoke execute on function public.push_config_servidor(), public.push_guardar_llaves(text,jsonb), public.avisos_tomar(integer),
  public.avisos_resultado(bigint,text,text,text[],text[],text[]) from public, anon, authenticated;
grant execute on function public.push_config_servidor(), public.push_guardar_llaves(text,jsonb), public.avisos_tomar(integer),
  public.avisos_resultado(bigint,text,text,text[],text[],text[]) to service_role;

revoke execute on function public.registrar_consulta(text, uuid) from public;
grant execute on function public.registrar_consulta(text, uuid) to anon, authenticated, service_role;
revoke execute on function public.registrar_evento(text, text, jsonb) from public;
grant execute on function public.registrar_evento(text, text, jsonb) to anon, authenticated, service_role;

-- ---------- Tareas programadas ----------
select cron.schedule('ventaslink-avisos', '* * * * *', 'select private.avisos_cron()');   -- cada minuto: recordatorios + reintentos
