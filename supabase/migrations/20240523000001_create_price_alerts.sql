-- Create price_alerts table 
CREATE TABLE public.price_alerts ( 
  id uuid NOT NULL DEFAULT gen_random_uuid(), 
  user_id uuid NOT NULL REFERENCES auth.users(id), 
  product_id uuid NOT NULL REFERENCES public.products(id), 
  target_price integer NOT NULL CHECK (target_price >= 0), 
  is_active boolean DEFAULT true, 
  created_at timestamp with time zone DEFAULT now(), 
  updated_at timestamp with time zone DEFAULT now(), 
  notified_at timestamp with time zone, -- When we last notified 
  CONSTRAINT price_alerts_pkey PRIMARY KEY (id), 
  CONSTRAINT unique_user_product_alert UNIQUE (user_id, product_id) 
); 

-- Add RLS policies 
ALTER TABLE public.price_alerts ENABLE ROW LEVEL SECURITY; 

CREATE POLICY "Users can view their own alerts" 
  ON public.price_alerts FOR SELECT 
  USING (auth.uid() = user_id); 

CREATE POLICY "Users can create their own alerts" 
  ON public.price_alerts FOR INSERT 
  WITH CHECK (auth.uid() = user_id); 

CREATE POLICY "Users can update their own alerts" 
  ON public.price_alerts FOR UPDATE 
  USING (auth.uid() = user_id); 

CREATE POLICY "Users can delete their own alerts" 
  ON public.price_alerts FOR DELETE 
  USING (auth.uid() = user_id); 

-- Index for performance 
CREATE INDEX idx_price_alerts_user_id ON public.price_alerts(user_id); 
CREATE INDEX idx_price_alerts_product_id ON public.price_alerts(product_id); 
CREATE INDEX idx_price_alerts_active ON public.price_alerts(is_active) WHERE is_active = true;
