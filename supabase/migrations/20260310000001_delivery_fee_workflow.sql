create extension if not exists pgcrypto;

alter table public.orders
add column if not exists delivery_fee integer,
add column if not exists delivery_fee_status text not null default 'pending_fee',
add column if not exists fee_set_at timestamptz,
add column if not exists customer_responded_at timestamptz;

alter table public.orders
drop constraint if exists orders_delivery_fee_status_check;

alter table public.orders
add constraint orders_delivery_fee_status_check
check (delivery_fee_status in (
  'pending_fee',
  'fee_set',
  'customer_accepted',
  'customer_rejected'
));

alter table public.orders
drop constraint if exists orders_delivery_fee_required_check;

alter table public.orders
add constraint orders_delivery_fee_required_check
check (
  delivery_fee_status not in ('fee_set', 'customer_accepted')
  or delivery_fee is not null
);

create or replace function public.is_admin(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select (p.role::text = 'admin') from public.profiles p where p.user_id = p_user_id),
    false
  );
$$;

create or replace function public.is_moderator(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select (p.role::text = 'moderator') from public.profiles p where p.user_id = p_user_id),
    false
  );
$$;

create or replace function public.is_staff(p_user_id uuid default auth.uid())
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.is_admin(p_user_id) or public.is_moderator(p_user_id);
$$;

create or replace function public.create_order_pending_fee(
  p_order_id uuid,
  p_user_id uuid,
  p_total_amount integer,
  p_shipping_address jsonb,
  p_payment_method public.payment_methods,
  p_shipping_method public.shipping_methods,
  p_customer_name text,
  p_items jsonb,
  p_payment_status text default 'pending',
  p_transaction_id text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_variant_id_text text;
  v_variant_id uuid;
  v_quantity integer;
  v_price integer;
  v_product_name text;
  v_attributes jsonb;
  v_variant_active boolean;
  v_available_quantity integer;
  v_payment_status public.payment_status;
  v_order_json jsonb;
begin
  if p_user_id is null then
    raise exception 'user_id is required' using errcode = '22004';
  end if;

  if auth.uid() is null or auth.uid() <> p_user_id then
    raise exception 'Not allowed' using errcode = '42501';
  end if;

  if p_payment_status is null or not exists (
    select 1
    from unnest(enum_range(null::public.payment_status)) s
    where s::text = p_payment_status
  ) then
    raise exception 'Invalid payment status: "%"', p_payment_status using errcode = '22023';
  end if;
  v_payment_status := p_payment_status::public.payment_status;

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_variant_id_text := nullif(trim(v_item->>'variant_id'), '');
    if v_variant_id_text is null then
      raise exception 'Missing variant_id for item "%"', coalesce(v_item->>'product_name', '')
        using errcode = '22023';
    end if;
    begin
      v_variant_id := v_variant_id_text::uuid;
    exception
      when invalid_text_representation then
        raise exception 'Invalid variant_id "%": item "%"', v_variant_id_text, coalesce(v_item->>'product_name', '')
          using errcode = '22023';
    end;
    v_quantity := (v_item->>'quantity')::integer;
    v_product_name := v_item->>'product_name';

    select quantity, is_active
    into v_available_quantity, v_variant_active
    from public.product_variants
    where id = v_variant_id;

    if not found then
      raise exception 'Product variant % not found', v_variant_id using errcode = 'P0002';
    end if;

    if v_variant_active is false then
      raise exception 'Product "%" is currently unavailable', v_product_name using errcode = '22023';
    end if;

    if v_available_quantity < v_quantity then
      raise exception 'Insufficient stock for "%". Available: %, Requested: %', v_product_name, v_available_quantity, v_quantity
        using errcode = '23514';
    end if;
  end loop;

  insert into public.orders (
    id,
    user_id,
    total_amount,
    status,
    payment_status,
    shipping_address,
    payment_method,
    shipping_method,
    customer_name,
    transaction_id,
    created_at,
    delivery_fee_status
  ) values (
    p_order_id,
    p_user_id,
    p_total_amount,
    'pending'::public.order_status,
    v_payment_status,
    p_shipping_address,
    p_payment_method,
    p_shipping_method,
    p_customer_name,
    p_transaction_id,
    now(),
    'pending_fee'
  );

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_variant_id_text := nullif(trim(v_item->>'variant_id'), '');
    if v_variant_id_text is null then
      raise exception 'Missing variant_id for item "%"', coalesce(v_item->>'product_name', '')
        using errcode = '22023';
    end if;
    begin
      v_variant_id := v_variant_id_text::uuid;
    exception
      when invalid_text_representation then
        raise exception 'Invalid variant_id "%": item "%"', v_variant_id_text, coalesce(v_item->>'product_name', '')
          using errcode = '22023';
    end;
    v_quantity := (v_item->>'quantity')::integer;
    v_price := (v_item->>'price')::integer;
    v_product_name := v_item->>'product_name';
    v_attributes := coalesce(v_item->'attributes', '{}'::jsonb);

    insert into public.order_items (
      id,
      order_id,
      product_variant_id,
      product_name,
      product_attributes,
      quantity,
      price_at_purchase
    ) values (
      gen_random_uuid(),
      p_order_id,
      v_variant_id,
      v_product_name,
      v_attributes,
      v_quantity,
      v_price
    );
  end loop;

  select to_jsonb(o.*)
  into v_order_json
  from public.orders o
  where o.id = p_order_id;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'order', v_order_json
  );
end;
$$;

grant execute on function public.create_order_pending_fee(
  uuid,
  uuid,
  integer,
  jsonb,
  public.payment_methods,
  public.shipping_methods,
  text,
  jsonb,
  text,
  text
) to authenticated;

create or replace function public.admin_list_orders_pending_fee()
returns setof public.orders
language sql
security definer
set search_path = public
as $$
  select *
  from public.orders
  where public.is_staff(auth.uid())
    and delivery_fee_status in ('pending_fee', 'fee_set')
  order by created_at desc;
$$;

create or replace function public.admin_set_delivery_fee(
  p_order_id uuid,
  p_delivery_fee integer,
  p_force boolean default false
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
begin
  if not public.is_staff(auth.uid()) then
    raise exception 'Admin access required' using errcode = '42501';
  end if;

  if p_delivery_fee is null or p_delivery_fee < 0 then
    raise exception 'Invalid delivery_fee' using errcode = '22023';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order % not found', p_order_id using errcode = 'P0002';
  end if;

  if not p_force and v_order.delivery_fee_status not in ('pending_fee', 'fee_set') then
    raise exception 'Fee cannot be set in current state: %', v_order.delivery_fee_status using errcode = '22023';
  end if;

  update public.orders
  set
    delivery_fee = p_delivery_fee,
    delivery_fee_status = 'fee_set',
    fee_set_at = now()
  where id = p_order_id;

  insert into public.notifications (user_id, type, title, body, data, created_at, read)
  values (
    v_order.user_id,
    'delivery_fee_set',
    'Delivery fee confirmed',
    format('Delivery fee is %s MMK. Tap to approve or cancel.', p_delivery_fee),
    jsonb_build_object(
      'type', 'delivery_fee_set',
      'order_id', p_order_id::text,
      'delivery_fee', p_delivery_fee
    ),
    now(),
    false
  );

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'user_id', v_order.user_id,
    'delivery_fee', p_delivery_fee
  );
end;
$$;

create or replace function public.customer_accept_delivery_fee(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_item record;
  v_available_quantity integer;
  v_variant_active boolean;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order % not found', p_order_id using errcode = 'P0002';
  end if;

  if v_order.user_id <> auth.uid() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;

  if v_order.customer_responded_at is not null then
    raise exception 'Customer already responded' using errcode = '22023';
  end if;

  if v_order.delivery_fee_status <> 'fee_set' then
    raise exception 'Delivery fee is not ready for approval' using errcode = '22023';
  end if;

  if v_order.delivery_fee is null then
    raise exception 'Delivery fee not set' using errcode = '22023';
  end if;

  for v_item in
    select product_variant_id, quantity, product_name
    from public.order_items
    where order_id = p_order_id
  loop
    select quantity, is_active
    into v_available_quantity, v_variant_active
    from public.product_variants
    where id = v_item.product_variant_id
    for update;

    if not found then
      raise exception 'Product variant % not found', v_item.product_variant_id using errcode = 'P0002';
    end if;

    if v_variant_active is false then
      raise exception 'Product "%" is currently unavailable', v_item.product_name using errcode = '22023';
    end if;

    if v_available_quantity < v_item.quantity then
      raise exception 'Insufficient stock for "%". Available: %, Requested: %', v_item.product_name, v_available_quantity, v_item.quantity
        using errcode = '23514';
    end if;
  end loop;

  update public.product_variants pv
  set quantity = pv.quantity - oi.quantity
  from public.order_items oi
  where oi.order_id = p_order_id
    and oi.product_variant_id = pv.id;

  update public.orders
  set
    delivery_fee_status = 'customer_accepted',
    customer_responded_at = now(),
    status = 'processing'::public.order_status,
    total_amount = total_amount + v_order.delivery_fee
  where id = p_order_id;

  return jsonb_build_object('success', true, 'order_id', p_order_id);
end;
$$;

create or replace function public.customer_reject_delivery_fee(p_order_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_cancel_status public.order_status;
begin
  if auth.uid() is null then
    raise exception 'Authentication required' using errcode = '42501';
  end if;

  select *
  into v_order
  from public.orders
  where id = p_order_id
  for update;

  if not found then
    raise exception 'Order % not found', p_order_id using errcode = 'P0002';
  end if;

  if v_order.user_id <> auth.uid() then
    raise exception 'Not allowed' using errcode = '42501';
  end if;

  if v_order.customer_responded_at is not null then
    raise exception 'Customer already responded' using errcode = '22023';
  end if;

  if v_order.delivery_fee_status <> 'fee_set' then
    raise exception 'Delivery fee is not ready for approval' using errcode = '22023';
  end if;

  v_cancel_status := case
    when exists (
      select 1
      from unnest(enum_range(null::public.order_status)) s
      where s::text = 'cancelled'
    ) then 'cancelled'::public.order_status
    else 'canceled'::public.order_status
  end;

  update public.orders
  set
    delivery_fee_status = 'customer_rejected',
    customer_responded_at = now(),
    status = v_cancel_status
  where id = p_order_id;

  return jsonb_build_object('success', true, 'order_id', p_order_id);
end;
$$;

create or replace function public.auto_cancel_unresponsive_fee_orders()
returns integer
language sql
security definer
set search_path = public
as $$
  with cancelled as (
    update public.orders
    set
      delivery_fee_status = 'customer_rejected',
      customer_responded_at = now(),
      status = case
        when exists (
          select 1
          from unnest(enum_range(null::public.order_status)) s
          where s::text = 'cancelled'
        ) then 'cancelled'::public.order_status
        else 'canceled'::public.order_status
      end
    where delivery_fee_status = 'fee_set'
      and customer_responded_at is null
      and fee_set_at is not null
      and fee_set_at <= now() - interval '24 hours'
    returning id, user_id
  ),
  notif as (
    insert into public.notifications (user_id, type, title, body, data, created_at, read)
    select
      c.user_id,
      'delivery_fee_timeout',
      'Order cancelled',
      'Delivery fee was not approved within 24 hours. The order has been cancelled.',
      jsonb_build_object('type', 'delivery_fee_timeout', 'order_id', c.id::text),
      now(),
      false
    from cancelled c
    returning 1
  )
  select count(*)::integer from cancelled;
$$;

do $$
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then null;
  end;

  begin
    perform cron.schedule(
      'auto_cancel_unresponsive_fee_orders',
      '*/15 * * * *',
      $$select public.auto_cancel_unresponsive_fee_orders();$$
    );
  exception
    when others then null;
  end;
end $$;
