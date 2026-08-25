-- ปิดสวิตช์แจ้งเตือนฝนกลับ
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run

update bs_settings set val = to_jsonb(false) where key = 'rainAlertEnabled';

select 'สวิตช์แจ้งเตือนฝน' as รายการ,
       coalesce((select val #>> array[]::text[] from bs_settings where key = 'rainAlertEnabled'), '-') as ผล;
