-- ============================================================
-- เก็บตกข้อมูลการดำเนินการที่ซ้ำ: คู่ที่เนื้อหาเหมือนกันแต่รูปคนละลิงก์
-- (ชุดหนึ่งลิงก์ Google เดิม อีกชุดลิงก์ Storage ใหม่) — เก็บฉบับ Storage ไว้
-- รันหลัง sql/actions_cleanup.sql
-- ============================================================

-- 1) ลบฉบับที่รูปยังเป็นลิงก์ Google เมื่อมีฉบับ Storage ของรายการเดียวกันอยู่แล้ว
delete from risk_actions a
 using risk_actions b
 where a.id <> b.id
   and coalesce(a.action_date, 'epoch'::timestamptz) = coalesce(b.action_date, 'epoch'::timestamptz)
   and coalesce(a.location,'') = coalesce(b.location,'')
   and coalesce(a.road,'')     = coalesce(b.road,'')
   and coalesce(a.detail,'')   = coalesce(b.detail,'')
   and (coalesce(a.image1_url,'') like '%googleusercontent%' or coalesce(a.image2_url,'') like '%googleusercontent%')
   and coalesce(b.image1_url,'') not like '%googleusercontent%'
   and coalesce(b.image2_url,'') not like '%googleusercontent%';

-- 2) กลุ่มที่ยังเหลือซ้ำ (เช่น ไม่มีรูปทั้งคู่) เก็บ id ต่ำสุดไว้
delete from risk_actions a
 using risk_actions b
 where a.id > b.id
   and coalesce(a.action_date, 'epoch'::timestamptz) = coalesce(b.action_date, 'epoch'::timestamptz)
   and coalesce(a.location,'') = coalesce(b.location,'')
   and coalesce(a.road,'')     = coalesce(b.road,'')
   and coalesce(a.detail,'')   = coalesce(b.detail,'');
