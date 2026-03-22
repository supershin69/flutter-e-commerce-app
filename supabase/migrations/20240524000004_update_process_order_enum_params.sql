create extension if not exists pgcrypto;

drop function if exists process_order(uuid, uuid, integer, text, text, jsonb, text, text, text, jsonb, text);
drop function if exists process_order(uuid, uuid, integer, order_status, payment_status, jsonb, payment_methods, shipping_methods, text, jsonb, text);

create or replace function process_order(
  p_order_id uuid,
  p_user_id uuid,
  p_total_amount integer,
  p_status order_status,
  p_payment_status payment_status,
  p_shipping_address jsonb,
  p_payment_method payment_methods,
  p_shipping_method shipping_methods,
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
  v_available_quantity integer;
  v_variant_active boolean;
begin
  for v_item in select * from jsonb_array_elements(p_items)
  loop
    v_variant_id := (v_item->>'variant_id')::uuid;
    v_quantity := (v_item->>'quantity')::integer;

    select quantity, is_active
    into v_available_quantity, v_variant_active
    from product_variants
    where id = v_variant_id
    for update;

    if not found then
      raise exception 'Product variant % not found', v_variant_id using errcode = 'P0002';
    end if;

    if v_variant_active is false then
      raise exception 'Product variant % is inactive', v_variant_id using errcode = '22023';
    end if;

    if v_available_quantity < v_quantity then
      raise exception 'Insufficient stock for variant %', v_variant_id using errcode = '23514';
    end if;
  end loop;

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
    p_status,
    p_payment_status,
    p_shipping_address,
    p_payment_method,
    p_shipping_method,
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

    update product_variants
    set quantity = quantity - v_quantity
    where id = v_variant_id;
  end loop;

  return jsonb_build_object(
    'success', true,
    'order_id', p_order_id,
    'message', 'Order processed successfully'
  );
end;
$$;

