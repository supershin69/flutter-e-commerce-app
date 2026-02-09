# Database Migrations

This folder contains SQL migration scripts for your Supabase database.

## How to Run Migrations

### Option 1: Using Supabase Dashboard (Recommended)

1. Go to your Supabase project dashboard
2. Navigate to **SQL Editor**
3. Click **New Query**
4. Copy and paste the SQL from the migration file
5. Click **Run** to execute

### Option 2: Using Supabase CLI

If you have Supabase CLI installed:

```bash
supabase db push
```

## Migration Files

### `add_user_profile_fields.sql`
Adds `phone` and `address` columns to the `profiles` table for checkout voucher functionality.

**What it does:**
- Adds `phone` column (TEXT, nullable)
- Adds `address` column (TEXT, nullable)
- Adds helpful comments to the columns
- Creates an index on `user_id` for faster lookups

**Run this migration if:**
- You need to store user phone numbers and addresses
- You're using the checkout voucher screen
- Your `profiles` table doesn't have `phone` and `address` columns yet

## Verifying the Migration

After running the migration, verify it worked by running this query in Supabase SQL Editor:

```sql
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'profiles'
ORDER BY ordinal_position;
```

You should see `phone` and `address` in the results.
