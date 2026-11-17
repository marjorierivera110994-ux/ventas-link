-- Por defecto la tienda ofrece retiro Y entrega a domicilio (la mayoría de pequeños negocios hace ambas).
-- La vendedora podrá cambiarlo cuando exista su pantalla de ajustes.
alter table public.tiendas alter column entregas set default '{retiro,domicilio}';
update public.tiendas set entregas = '{retiro,domicilio}' where entregas = '{retiro}';
