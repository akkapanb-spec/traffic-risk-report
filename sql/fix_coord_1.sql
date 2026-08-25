-- แก้พิกัดที่ขาดจุดทศนิยม
-- รันเมื่อไหร่ก็ได้ ไม่เกี่ยวกับกิจกรรมหรือการแจ้งเตือน
-- ถ้ามี $0 ต่อท้ายไฟล์ ให้ลบออกก่อนกด Run
--
-- อาการ
--   บางแถวเก็บลองจิจูดเป็น 100123875 ซึ่งควรเป็น 100.123875
--   ค่าแบบนี้อยู่นอกกรอบพิกัดที่ถูกต้อง แถวจึงหายไปจากแผนที่
--   และหายจากการวิเคราะห์จุดเสี่ยงทุกชนิดโดยไม่มีอะไรฟ้อง
--   ที่แย่กว่านั้นคือถ้าเอาไปแปลงระบบพิกัดตรง ๆ จะขึ้น Invalid coordinate แล้วทั้งคำสั่งพัง
--
-- วิธีแก้
--   หารด้วยหนึ่งล้าน แล้วรับเฉพาะค่าที่ตกกลับเข้ากรอบนครสวรรค์เท่านั้น
--   ค่าไหนหารแล้วยังอยู่นอกกรอบ แปลว่าเพี้ยนด้วยสาเหตุอื่น ปล่อยไว้ให้คนตรวจเอง
--   ไม่เดาแทน เพราะพิกัดผิดที่ถูกเดาให้ อันตรายกว่าพิกัดที่หายไปเฉย ๆ

update accidents
   set longitude = longitude / 1000000.0
 where longitude > 1000
   and longitude / 1000000.0 between 99.4 and 100.7
   and latitude between 15.0 and 16.6;

update accidents
   set latitude = latitude / 1000000.0
 where latitude > 1000
   and latitude / 1000000.0 between 15.0 and 16.6
   and longitude between 99.4 and 100.7;

-- ตรวจผล  คำสั่งสุดท้ายคำสั่งเดียวที่จะแสดงผล
select 'อุบัติเหตุที่มีพิกัด' as รายการ,
       (select count(*)::text from accidents where latitude is not null and longitude is not null) as จำนวน
union all
select 'พิกัดอยู่ในกรอบนครสวรรค์',
       (select count(*)::text from accidents
         where latitude between 15.0 and 16.6 and longitude between 99.4 and 100.7)
union all
select 'ยังเหลือพิกัดที่อยู่นอกกรอบ',
       (select count(*)::text from accidents
         where latitude is not null and longitude is not null
           and not (latitude between 15.0 and 16.6 and longitude between 99.4 and 100.7))
       || '  (ถ้าไม่เป็น 0 ให้ดูรายการข้างล่าง)'
union all
select 'พิกัดที่ยังเพี้ยนอยู่',
       coalesce((select string_agg(latitude::text || ', ' || longitude::text, '   ')
                 from accidents
                where latitude is not null and longitude is not null
                  and not (latitude between 15.0 and 16.6 and longitude between 99.4 and 100.7)),
                'ไม่เหลือแล้ว');
