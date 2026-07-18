-- ============================================================
-- Supabase Storage: ที่เก็บรูปภาพ (แทน Cloudinary / Google Drive)
-- รันใน Supabase Dashboard → SQL Editor → New query → Run
-- ============================================================

-- สร้าง bucket สาธารณะชื่อ risk-images (ทุกคนเปิดดูรูปได้ผ่าน URL)
insert into storage.buckets (id, name, public)
values ('risk-images', 'risk-images', true)
on conflict (id) do nothing;

-- อนุญาตให้หน้าเว็บ (anon) อัปโหลดรูปเข้า bucket นี้ได้
create policy "public upload risk images"
on storage.objects for insert
to anon
with check (bucket_id = 'risk-images');
