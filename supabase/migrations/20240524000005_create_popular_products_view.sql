-- View: popular_products - ranks products by total quantity sold
-- Assumptions:
-- - products has columns: id, name, description, brand_id, category_id, created_at, is_archived
-- - brands(name), categories(name)
-- - product_variants(product_id, price, quantity)
-- - order_items(product_variant_id, quantity, order_id)
-- - product_images(product_id, url, is_primary)
-- Only include products with sales (>0) and currently in stock (any variant qty > 0)

create or replace view popular_products as
with variant_prices as (
  select
    pv.product_id,
    min(pv.price) as min_price,
    max(pv.price) as max_price,
    bool_or(pv.quantity > 0) as in_stock
  from product_variants pv
  group by pv.product_id
),
sales as (
  select
    pv.product_id,
    coalesce(sum(oi.quantity), 0) as total_sold,
    count(distinct oi.order_id) as order_count
  from product_variants pv
  left join order_items oi
    on oi.product_variant_id = pv.id
  group by pv.product_id
),
primary_images as (
  select distinct on (pi.product_id)
    pi.product_id,
    pi.url as image_url
  from product_images pi
  where coalesce(pi.is_primary, false) = true
  order by pi.product_id, pi.id desc
)
select
  p.id,
  p.name,
  p.description,
  vp.min_price,
  vp.max_price,
  b.name as brand_name,
  c.name as category_name,
  s.total_sold,
  s.order_count,
  i.image_url
from products p
join brands b on b.id = p.brand_id
join categories c on c.id = p.category_id
left join variant_prices vp on vp.product_id = p.id
left join sales s on s.product_id = p.id
left join primary_images i on i.product_id = p.id
where coalesce(p.is_archived, false) = false
  and coalesce(s.total_sold, 0) > 0
  and coalesce(vp.in_stock, false) = true
order by s.total_sold desc, s.order_count desc, p.created_at desc
limit 20;

-- Performance: helpful indexes
create index if not exists idx_order_items_variant_id on order_items (product_variant_id);
create index if not exists idx_order_items_order_id on order_items (order_id);
create index if not exists idx_product_variants_product_id on product_variants (product_id);
create index if not exists idx_products_created_at on products (created_at desc);

