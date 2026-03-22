do $$
begin
  begin
    alter table public.notifications
    add column if not exists type text;
  exception
    when others then null;
  end;
end $$;

do $$
begin
  begin
    update public.notifications
    set type = coalesce(type, (data->>'type'))
    where type is null
      and data is not null;
  exception
    when others then null;
  end;
end $$;

create or replace function public.notifications_set_type_from_data()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.type is null and new.data is not null then
    new.type := new.data->>'type';
  end if;
  return new;
end;
$$;

do $$
begin
  begin
    drop trigger if exists trg_notifications_set_type on public.notifications;
  exception
    when others then null;
  end;

  begin
    create trigger trg_notifications_set_type
    before insert or update on public.notifications
    for each row
    execute function public.notifications_set_type_from_data();
  exception
    when others then null;
  end;
end $$;

create index if not exists idx_notifications_user_type_created_at
on public.notifications (user_id, type, created_at desc);

