-- Enable Realtime on product_variants table
-- Run this in your Supabase SQL Editor

-- 1. Enable publication for the table
alter publication supabase_realtime add table public.product_variants;

-- 2. Ensure your client has access to read these changes (RLS)
-- If you haven't already, make sure RLS allows SELECT for authenticated/anon users
create policy "Enable read access for all users"
on public.product_variants
for select
using (true);

-- Optional: If you want to listen to INSERT/UPDATE/DELETE explicitly, 
-- usually enabling publication is enough for the client to subscribe.
