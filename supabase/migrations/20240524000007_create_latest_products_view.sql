create or replace view latest_products as
with variant_prices as (
  select
    pv.product_id,
    min(pv.price) as min_price,
    max(pv.price) as max_price
  from product_variants pv
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
    pi.created_at desc,
    pi.id desc
)
select
  p.id,
  p.name,
  p.description,
  coalesce(vp.min_price, 0) as min_price,
  coalesce(vp.max_price, 0) as max_price,
  coalesce(b.name, '') as brand_name,
  coalesce(c.name, '') as category_name,
  p.created_at,
  coalesce(i.image_url, '') as image_url
from products p
left join brands b on b.id = p.brand_id
left join categories c on c.id = p.category_id
left join variant_prices vp on vp.product_id = p.id
left join best_image i on i.product_id = p.id
where coalesce(p.is_archived, false) = false
order by p.created_at desc, p.id desc
;

create index if not exists idx_products_created_at_latest on products (created_at desc);
create index if not exists idx_product_images_product_id on product_images (product_id);

