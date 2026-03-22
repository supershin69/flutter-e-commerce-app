-- Migration to update process_order function with stock management and row-level locking

CREATE OR REPLACE FUNCTION process_order(
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
  p_transaction_id text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
  v_item jsonb;
  v_variant_id uuid;
  v_quantity integer;
  v_price integer;
  v_product_name text;
  v_attributes jsonb;
  v_current_stock integer;
  v_variant_active boolean;
BEGIN
  -- 1. Insert Order
  INSERT INTO orders (
    id, user_id, total_amount, status, payment_status,
    shipping_address, payment_method, shipping_method,
    customer_name, transaction_id, created_at
  ) VALUES (
    p_order_id, p_user_id, p_total_amount, p_status, p_payment_status,
    p_shipping_address, p_payment_method, p_shipping_method,
    p_customer_name, p_transaction_id, now()
  );

  -- 2. Process Items
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items)
  LOOP
    -- Extract values from JSON
    v_variant_id := (v_item->>'variant_id')::uuid;
    v_quantity := (v_item->>'quantity')::integer;
    v_price := (v_item->>'price')::integer;
    v_product_name := v_item->>'product_name';
    v_attributes := COALESCE(v_item->'attributes', '{}'::jsonb);

    -- Lock and Check Stock
    SELECT quantity, is_active INTO v_current_stock, v_variant_active
    FROM product_variants
    WHERE id = v_variant_id
    FOR UPDATE; -- Row-level lock

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Product variant % not found', v_variant_id;
    END IF;

    IF v_variant_active IS FALSE THEN
      RAISE EXCEPTION 'Product "%" is currently unavailable', v_product_name;
    END IF;

    IF v_current_stock < v_quantity THEN
      RAISE EXCEPTION 'Insufficient stock for "%". Available: %, Requested: %', v_product_name, v_current_stock, v_quantity;
    END IF;

    -- Update Stock
    UPDATE product_variants
    SET quantity = quantity - v_quantity
    WHERE id = v_variant_id;

    -- Insert Order Item
    -- Using gen_random_uuid() for ID if not provided by default
    INSERT INTO order_items (
      id,
      order_id, 
      product_variant_id, 
      product_name, 
      product_attributes, 
      quantity, 
      price_at_purchase
    ) VALUES (
      gen_random_uuid(),
      p_order_id, 
      v_variant_id, 
      v_product_name, 
      v_attributes, 
      v_quantity, 
      v_price
    );

  END LOOP;

  RETURN jsonb_build_object('success', true, 'order_id', p_order_id);
EXCEPTION
  WHEN OTHERS THEN
    -- Transaction rolls back automatically on exception
    RAISE;
END;
$$;
