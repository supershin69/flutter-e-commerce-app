-- Add foreign key constraint to order_items table
-- referencing product_variants table

DO $$ 
BEGIN 
    IF NOT EXISTS (
        SELECT 1 
        FROM information_schema.table_constraints 
        WHERE constraint_name = 'order_items_product_variant_id_fkey' 
        AND table_name = 'order_items'
    ) THEN 
        ALTER TABLE "public"."order_items" 
        ADD CONSTRAINT "order_items_product_variant_id_fkey" 
        FOREIGN KEY ("product_variant_id") 
        REFERENCES "public"."product_variants" ("id");
    END IF; 
END $$;
