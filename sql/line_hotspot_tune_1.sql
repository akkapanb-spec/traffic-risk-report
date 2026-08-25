-- ============================================================
-- พรีวิวเกณฑ์แจ้งจุดเสี่ยงซ้ำ ก่อนตัดสินใจตั้งตัวเลข
-- ============================================================
-- ไฟล์นี้ "อ่านอย่างเดียว" ไม่แก้ค่าอะไร ไม่ส่งอะไรเข้าไลน์
-- ใช้ตารางชั่วคราวที่หายไปเองเมื่อจบ ไม่ทิ้งอะไรไว้ในระบบ
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้ามี $0 ค้างอยู่บรรทัดสุดท้าย ให้ลบทิ้งก่อนกด Run
-- ไฟล์นี้ไม่มีวงเล็บปีกกาเลยแม้แต่ตัวเดียว
--
-- ทำไมต้องพรีวิวก่อน
--   เกณฑ์ที่ตั้งไว้ตอนนี้คือ 4 ครั้งต่อช่องต่อเดือน ซึ่งผมเลือกจากข้อมูลเดือน ส.ค. 69
--   แต่จำนวนอุบัติเหตุแต่ละเดือนไม่เท่ากัน เกณฑ์ที่พอดีเดือนหนึ่งอาจเงียบสนิทอีกเดือน
--   หรือเด้งรัวจนคนในกลุ่มปิดการแจ้งเตือนทิ้ง ซึ่งแย่กว่าไม่แจ้งเลย
--
--   ไฟล์นี้จึงคำนวณด้วยตรรกะเดียวกับตัวแจ้งเตือนจริงเป๊ะ ๆ
--   แล้วบอกว่าถ้าตั้งเกณฑ์ 2 3 4 5 หรือ 6 จะได้แจ้งกี่จุดในเดือนนี้
--   พร้อมรายชื่อจุดที่หนักที่สุด 10 อันดับ ให้เปิดแผนที่ดูของจริงได้
--
-- ช่องกว้าง 100 เมตรเท่าตัวแจ้งเตือนจริง ถ้าจะเปลี่ยนความกว้างค่อยบอกทีหลัง
-- ============================================================

create temporary table if not exists tmp_tune_pt (g geometry) on commit drop;
truncate tmp_tune_pt;

insert into tmp_tune_pt (g)
select st_transform(st_setsrid(st_makepoint(a.longitude, a.latitude), 4326), 32647)
  from accidents a
 where a.latitude is not null and a.longitude is not null
   and a.latitude between 14 and 17 and a.longitude between 99 and 101
   and a.incident_datetime >= date_trunc('month', timezone('Asia/Bangkok', now()))
   and a.incident_datetime < now();

create index if not exists tmp_tune_pt_gix on tmp_tune_pt using gist (g);
analyze tmp_tune_pt;

with bounds as (
  select st_setsrid(st_expand(st_extent(g)::geometry, 100.0 / sqrt(3.0) * 2), 32647) as b
    from tmp_tune_pt
),
cells as (
  select h.geom from st_hexagongrid(100.0 / sqrt(3.0), (select b from bounds)) h
),
agg as (
  select cl.geom, count(*)::int as n
    from cells cl join tmp_tune_pt p on st_intersects(cl.geom, p.g)
   group by cl.geom
),
thresholds as (
  select t.v as เกณฑ์, count(a.n)::int as จำนวนจุดที่จะแจ้ง
    from (values (2), (3), (4), (5), (6)) t(v)
    left join agg a on a.n >= t.v
   group by t.v
)
select '1 ภาพรวมเดือนนี้' as หมวด,
       'อุบัติเหตุ ' || (select count(*)::text from tmp_tune_pt) ||
       ' ครั้ง · ช่องที่หนาที่สุดได้ ' || coalesce((select max(n)::text from agg), '0') ||
       ' ครั้ง · เกณฑ์ที่ใช้อยู่ตอนนี้คือ ' ||
       coalesce((select (val #>> array[]::text[]) from bs_settings
                  where key = 'hotspotMinPerMonth'), '4') as รายละเอียด

union all
select '2 ถ้าตั้งเกณฑ์ ' || เกณฑ์::text,
       'จะแจ้ง ' || จำนวนจุดที่จะแจ้ง::text || ' จุดในเดือนนี้'
  from thresholds

union all
select '3 จุดที่หนักที่สุด อันดับ ' ||
       lpad(row_number() over (order by a.n desc)::text, 2, '0'),
       a.n::text || ' ครั้ง · https://www.google.com/maps?q=' ||
       round(st_y(st_transform(st_centroid(a.geom), 4326))::numeric, 6) || ',' ||
       round(st_x(st_transform(st_centroid(a.geom), 4326))::numeric, 6)
  from agg a
 where a.n >= 2
 order by 1, 2;

-- ============================================================
-- เลือกเกณฑ์แล้วตั้งค่าอย่างไร
-- ============================================================
-- ไม่ต้องรันไฟล์ใหม่ เปลี่ยนแค่ตัวเลขในตารางตั้งค่า มีผลรอบถัดไปทันที
-- เปลี่ยนเลข 3 เป็นเลขที่เลือก แล้วรันบรรทัดเดียวนี้
--
--   update bs_settings set val = '3'::jsonb, updated_at = now()
--    where key = 'hotspotMinPerMonth';
--
-- ข้อคิดในการเลือก
--   ตั้งต่ำไป กลุ่มจะเด้งบ่อยจนคนปิดการแจ้งเตือน ซึ่งแย่กว่าไม่แจ้งเลย
--   ตั้งสูงไป จะเงียบทั้งเดือนแล้วไม่มีใครรู้ว่าระบบยังทำงานอยู่
--   จุดที่พอดีคือราว 2 ถึง 5 จุดต่อเดือน มากพอให้รู้สึกว่ามีประโยชน์
--   และน้อยพอที่ทุกครั้งที่เด้งจะมีคนอ่านจริง
--
-- ความถี่ในการตรวจตอนนี้คือทุก 5 นาที ซึ่งไม่ได้แปลว่าส่งถี่
-- เพราะจุดเดิมในเดือนเดียวกันส่งได้ครั้งเดียว ถ้าจะเปลี่ยนเป็นวันละครั้งตอนเช้า
--
--   select cron.unschedule('line-hotspot');
--   select cron.schedule('line-hotspot', '0 1 * * *', 'select line_send_hotspots();');
--
-- เลข 1 คือตี 1 เวลามาตรฐานกลาง ซึ่งตรงกับ 8 โมงเช้าบ้านเรา
-- ============================================================
