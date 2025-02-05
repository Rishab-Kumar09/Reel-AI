-- Create videos table
create table if not exists public.videos (
    id uuid default gen_random_uuid() primary key,
    filename text not null,
    url text not null,
    username text not null,
    description text,
    category text default 'general',
    is_vertical boolean default true,
    created_at timestamp with time zone default timezone('utc'::text, now()),
    tags text[] default array[]::text[],
    likes integer default 0,
    comments integer default 0,
    shares integer default 0
);

-- Enable RLS
alter table public.videos enable row level security;

-- Create storage bucket for videos
insert into storage.buckets (id, name)
values ('videos', 'videos')
on conflict do nothing;

-- Create storage policy for public access to videos
create policy "Videos are publicly accessible"
on storage.objects for select
using ( bucket_id = 'videos' );

-- Create storage policy for authenticated uploads
create policy "Authenticated users can upload videos"
on storage.objects for insert
with check (
    bucket_id = 'videos'
    and auth.role() = 'authenticated'
);

-- Grant access to authenticated users
grant usage on schema public to authenticated;
grant all on public.videos to authenticated;
grant select on public.videos to anon; 