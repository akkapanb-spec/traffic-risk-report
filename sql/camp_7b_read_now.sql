-- ขั้นที่ 2 จาก 2  เก็บคำตอบแล้วดูผล
-- รันหลัง camp_7a_fire_now.sql ไปแล้วสักสิบวินาที
-- ถ้าผลยังเป็น ยังไม่ตรวจ ให้รอแล้วรันไฟล์นี้ซ้ำ
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run

select camp_check_collect();

select m.ref_code                                as รหัส,
       coalesce(m.display_name, 'ยังไม่มีชื่อ')   as ชื่อ,
       coalesce(i.ref_code, 'มาเอง')             as ถูกชวนโดย,
       case when m.is_friend is null then 'ยังไม่ตรวจ'
            when m.is_friend then 'ใช่' else 'ไม่ใช่' end  as เป็นเพื่อน,
       case when m.in_group is null then 'ยังไม่ตรวจ'
            when m.in_group then 'ใช่' else 'ไม่ใช่' end   as อยู่ในกลุ่ม,
       camp_friend_count(m.line_user_id)         as ชวนสำเร็จแล้ว,
       to_char(m.checked_at at time zone 'Asia/Bangkok', 'HH24:MI:SS') as ตรวจล่าสุด
from camp_members m
left join camp_members i on i.line_user_id = m.referred_by
order by m.created_at;
