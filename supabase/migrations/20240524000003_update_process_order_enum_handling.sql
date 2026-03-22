-- Update process_order to validate enum inputs and cast safely
-- Fixes: "column 'status' is of type order_status but expression is of type text"

create extension if not exists pgcrypto;

create or replace function process_order(
  p_order_id uuid,
  p_user_id uuid,
  p_total_amount integer,
  p_status text,
  p_payment_status text,
  p_shipping_address jsonb,
  p_payment_method text,
  p_shipping_method text,
  p_customer_name text,
  p_items jsonb,
  p_transaction_id text default null
) returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item jsonb;
  v_variant_id uuid;
  v_quantity integer;
  v_price integer;
  v_product_name text;
  v_attributes jsonb;
  v_current_stock integer;
  v_variant_active boolean;

  v_status order_status;
  v_payment_status payment_status;
  v_payment_method payment_methods;
  v_shipping_method shipping_methods;
begin
  if p_status is null or not exists (
    select 1
    from unnest(enum_range(null::order_status)) s
    where s::text = p_status
  ) then
    raise exception 'Invalid order status: "%". Allowed: %', p_status, array(select s::text from unnest(enum_range(null::order_status)) s)
      using errcode = '22023';
  end if;
  v_status := p_status::order_status;

  if p_payment_status is null or not exists (
    select 1
    from unnest(enum_range(null::payment_status)) s
    where s::text = p_payment_status
  ) then
    raise exception 'Invalid payment status: "%". Allowed: %', p_payment_status, array(select s::text from unnest(enum_range(null::payment_status)) s)
      using errcode = '22023';
  end if;
  v_payment_status := p_payment_status::payment_status;

  if p_payment_method is null or not exists (
    select 1
    from unnest(enum_range(null::payment_methods)) s
    where s::text = p_payment_method
  ) then
    raise exception 'Invalid payment method: "%". Allowed: %', p_payment_method, array(select s::text from unnest(enum_range(null::payment_methods)) s)
      using errcode = '22023';
  end if;
  v_payment_method := p_payment_method::payment_methods;

  if p_shipping_method is null or not exists (
    select 1
    from unnest(enum_range(null::shipping_methods)) s
    where s::text = p_shipping_method
  ) then
    raise exception 'Invalid shipping method: "%". Allowed: %', p_shipping_method, array(select s::text from unnest(enum_range(null::shipping_methods)) s)
      using errcode = '22023';
  end if;
  v_shipping_method := p_shipping_method::shipping_methods;

  insert into orders (
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
    created_at
  ) values (
    p_order_id,
    p_user_id,
    p_total_amount,
    v_status,
    v_payment_status,
    p_shipping_address,
    v_payment_method,
    v_shipping_method,
    p_customer_name,
    p_transaction_id,
    now()
  );

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_variant_id := (v_item->>'variant_id')::uuid;
    v_quantity := (v_item->>'quantity')::integer;
    v_price := (v_item->>'price')::integer;
    v_product_name := v_item->>'product_name';
    v_attributes := coalesce(v_item->'attributes', '{}'::jsonb);

    select quantity, is_active
    into v_current_stock, v_variant_active
    from product_variants
    where id = v_variant_id
    for update;

    if not found then
      raise exception 'Product variant % not found', v_variant_id using errcode = 'P0002';
    end if;

    if v_variant_active is false then
      raise exception 'Product "%" is currently unavailable', v_product_name using errcode = '22023';
    end if;

    if v_current_stock < v_quantity then
      raise exception 'Insufficient stock for "%". Available: %, Requested: %', v_product_name, v_current_stock, v_quantity
        using errcode = '23514';
    end if;

    update product_variants
    set quantity = quantity - v_quantity
    where id = v_variant_id;

    insert into order_items (
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

  return jsonb_build_object('success', true, 'order_id', p_order_id);
end;
$$;

