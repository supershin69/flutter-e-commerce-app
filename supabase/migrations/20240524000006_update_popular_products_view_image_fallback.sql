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
best_image as (
  select distinct on (pi.product_id)
    pi.product_id,
    pi.url as image_url
  from product_images pi
  order by
    pi.product_id,
    coalesce(pi.is_primary, false) desc,
    pi.id desc
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
left join best_image i on i.product_id = p.id
where coalesce(p.is_archived, false) = false
  and coalesce(s.total_sold, 0) > 0
  and coalesce(vp.in_stock, false) = true
order by s.total_sold desc, s.order_count desc, p.created_at desc
limit 20;

