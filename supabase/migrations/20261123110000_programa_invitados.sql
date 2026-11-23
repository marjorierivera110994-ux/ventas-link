-- Programa de invitados: tú invitas a otra vendedora; cuando ella publica su PRIMER producto,
-- las dos reciben 30 días de plan Emprendedor. Cada vendedora puede ganar hasta 12 premios.
-- Todo lo decide el servidor. Un código vale una sola vez por tienda invitada.

alter table public.suscripciones
  add column if not exists regalo_plan text references public.planes(id),
  add column if not exists regalo_hasta timestamptz,
  add constraint suscripciones_regalo_pareja check ((regalo_plan is null) = (regalo_hasta is null)),
  add constraint suscripciones_regalo_no_gratis check (regalo_plan is distinct from 'gratis');

-- El plan que cuenta: pagado > prueba > regalo de invitados > gratis.
create or replace function private.plan_efectivo(p_tienda uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce((
    select case
      when s.plan_pagado is not null and s.pagado_hasta > now() then s.plan_pagado
      when s.prueba_plan is not null and s.prueba_hasta > now() then s.prueba_plan
      when s.regalo_plan is not null and s.regalo_hasta > now() then s.regalo_plan
      else 'gratis' end
    from public.suscripciones s where s.tienda_id = p_tienda), 'gratis');
$$;

create table public.invitaciones (
  tienda_id  uuid primary key references public.tiendas(id) on delete cascade,
  codigo     text not null unique check (codigo ~ '^[a-hj-np-z2-9]{8}$'),
  created_at timestamptz not null default now()
);
create table public.invitados (
  invitado_id  uuid primary key references public.tiendas(id) on delete cascade,
  invitador_id uuid not null references public.tiendas(id) on delete cascade,
  created_at   timestamptz not null default now(),
  premiado_at  timestamptz,
  check (invitador_id <> invitado_id)
);
create index invitados_invitador_idx on public.invitados (invitador_id) where premiado_at is not null;

alter table public.invitaciones enable row level security;
alter table public.invitados     enable row level security;
revoke all on public.invitaciones, public.invitados from anon, authenticated;
grant all on public.invitaciones, public.invitados to service_role;

create or replace function private.codigo_nuevo() returns text
language sql volatile set search_path = '' as $$
  select string_agg(substr('abcdefghjkmnpqrstuvwxyz23456789', 1 + floor(random() * 30)::int, 1), '') from generate_series(1, 8);
$$;

create or replace function private.dar_regalo(p_tienda uuid) returns void
language sql security definer set search_path = '' as $$
  update public.suscripciones
     set regalo_plan = 'emprendedor',
         regalo_hasta = greatest(coalesce(regalo_hasta, now()), now()) + interval '30 days',
         updated_at = now()
   where tienda_id = p_tienda;
$$;

create or replace function public.mi_invitacion() returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_t uuid; v_c text; v_n int; v_p int;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  select t.id into v_t from public.tiendas t where t.owner_id = v_uid;
  if not found then raise exception 'SIN_TIENDA' using errcode = 'P0001'; end if;
  select i.codigo into v_c from public.invitaciones i where i.tienda_id = v_t;
  if v_c is null then
    loop
      begin
        insert into public.invitaciones (tienda_id, codigo) values (v_t, private.codigo_nuevo()) returning codigo into v_c;
        exit;
      exception when unique_violation then
        select i.codigo into v_c from public.invitaciones i where i.tienda_id = v_t;
        if v_c is not null then exit; end if;
      end;
    end loop;
  end if;
  select count(*), count(*) filter (where premiado_at is not null) into v_n, v_p from public.invitados where invitador_id = v_t;
  return jsonb_build_object('codigo', v_c, 'invitados', v_n, 'premiados', v_p, 'premios_max', 12, 'premios_restantes', greatest(0, 12 - v_p));
end;
$$;

create or replace function public.canjear_invitacion(p_codigo text) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare v_uid uuid := (select auth.uid()); v_yo uuid; v_quien uuid;
begin
  if v_uid is null then raise exception 'NO_AUTENTICADO' using errcode = 'P0001'; end if;
  select t.id into v_yo from public.tiendas t where t.owner_id = v_uid;
  if not found then raise exception 'SIN_TIENDA' using errcode = 'P0001'; end if;
  select i.tienda_id into v_quien from public.invitaciones i where i.codigo = lower(btrim(coalesce(p_codigo, '')));
  if v_quien is null then return jsonb_build_object('ok', false, 'motivo', 'codigo_no_existe'); end if;
  if v_quien = v_yo then return jsonb_build_object('ok', false, 'motivo', 'es_tu_codigo'); end if;
  if exists (select 1 from public.invitados x where x.invitado_id = v_yo) then return jsonb_build_object('ok', false, 'motivo', 'ya_tenias_invitacion'); end if;
  insert into public.invitados (invitado_id, invitador_id) values (v_yo, v_quien);
  return jsonb_build_object('ok', true);
end;
$$;

-- Premio: cuando la invitada publica su primer producto activo.
create or replace function private.invitacion_premiar() returns trigger
language plpgsql security definer set search_path = '' as $$
declare v_inv public.invitados; v_p int;
begin
  if not NEW.activo then return NEW; end if;
  select x.* into v_inv from public.invitados x where x.invitado_id = NEW.tienda_id and x.premiado_at is null;
  if not found then return NEW; end if;
  select count(*) into v_p from public.invitados x where x.invitador_id = v_inv.invitador_id and x.premiado_at is not null;
  update public.invitados set premiado_at = now() where invitado_id = NEW.tienda_id;
  perform private.dar_regalo(NEW.tienda_id);                       -- la invitada: 30 días siempre
  if v_p < 12 then perform private.dar_regalo(v_inv.invitador_id); end if;  -- quien invitó: hasta 12 premios
  return NEW;
end;
$$;

create trigger productos_invitacion after insert or update of activo on public.productos
  for each row execute function private.invitacion_premiar();

revoke execute on function private.codigo_nuevo(), private.dar_regalo(uuid), private.invitacion_premiar() from public, anon, authenticated;
revoke execute on function public.mi_invitacion(), public.canjear_invitacion(text) from public, anon;
grant execute on function public.mi_invitacion(), public.canjear_invitacion(text) to authenticated;
