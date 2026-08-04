-- ============================================================
-- คุณภาพข้อมูลสาเหตุ - แยกสาเหตุสันนิษฐาน ออกจาก ข้อหาที่แจ้งจริง
-- ============================================================
-- ต้องรัน officer.sql และ deaths_admin.sql มาก่อน
-- ควรรัน checkpoint_1_tables.sql ก่อนด้วย จะได้ใช้รายการข้อหาชุดเดียวกัน (cp_charges)
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
-- ถ้าบรรทัดแรกเป็นข้อความไทยลอย ๆ แปลว่า paste ขาดหัว ให้วางใหม่
--
-- ทำไมต้องมีตารางนี้
--   ช่อง cause ในตาราง accidents เป็นการ "สันนิษฐานที่เกิดเหตุ" ซึ่งกรอกง่าย
--   และไม่มีอะไรตรวจสอบ ผลคือสาเหตุยอดฮิตถูกเลือกจนเฝือ ทั้งที่แทบไม่เคย
--   ถูกแจ้งเป็นข้อหาจริง สถิติสาเหตุจึงใช้อ้างอิงไม่ได้
--
--   ตารางนี้เก็บสองอย่างที่ไม่เคยแยกกันมาก่อน
--     1) สาเหตุที่สันนิษฐาน + มีหลักฐานอะไรรองรับบ้าง
--     2) ข้อหาที่แจ้งจริง
--   ช่องว่างระหว่างสองอันนี้คือตัวชี้วัดคุณภาพข้อมูล ไม่ใช่ความเห็นใคร
--
-- ทำเป็นตารางแยก ไม่แก้ officer_save_accident เพราะฟังก์ชันนั้นแตกข้อมูล
-- ผู้เสียชีวิต/ผู้บาดเจ็บออกเป็นตารางอื่นด้วย แก้พลาดแล้วกระทบสถิติทั้งระบบ
-- ============================================================

create table if not exists acc_cause_detail (
  accident_code  text primary key,               -- ผูกกับ accidents.accident_code ที่ RPC คืนกลับมา
  cause_primary  text,                           -- สาเหตุหลัก หนึ่งเดียว จากรายการมาตรฐาน
  causes         jsonb not null default '[]'::jsonb,  -- สาเหตุร่วมทั้งหมด อุบัติเหตุจริงมักมีหลายปัจจัย
  confidence     text not null default 'สันนิษฐาน',   -- สันนิษฐาน | มีหลักฐาน | ยืนยันจากการสอบสวน
  evidence       jsonb not null default '[]'::jsonb,  -- รอยเบรก / กล้องวงจรปิด / พยาน / สภาพรถ / ตรวจวัดความเร็ว
  charges        jsonb not null default '[]'::jsonb,  -- ข้อหาที่แจ้งจริง ใช้ชื่อเดียวกับ cp_charges
  no_charge      boolean not null default false,      -- ไม่ได้แจ้งข้อหา (เปรียบเทียบปรับ/ยอมความ/ไม่มีคู่กรณี)
  note           text,
  updated_by     text,
  updated_at     timestamptz not null default now()
);
create index if not exists acc_cause_conf_idx on acc_cause_detail (confidence);

-- ============================================================
-- RLS: ปิดการอ่านจาก anon ทั้งหมด เป็นข้อมูลรูปคดี
-- ============================================================
alter table acc_cause_detail enable row level security;
-- ไม่สร้าง policy = anon อ่านไม่ได้เลย เจ้าหน้าที่เข้าผ่าน RPC เท่านั้น

-- ============================================================
-- บันทึก/แก้ไข รายละเอียดสาเหตุของเคสหนึ่ง
--   เจ้าหน้าที่ทุกคนบันทึกได้ ไม่ต้องเป็น admin เพราะเป็นส่วนหนึ่งของงานบันทึกเคส
-- ============================================================
create or replace function acc_cause_save(p_token text, p_code text, p_row jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb; v_conf text;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;
  if coalesce(p_code,'') = '' then
    return jsonb_build_object('success', false, 'message', 'ไม่พบรหัสอุบัติเหตุ');
  end if;

  -- ถ้าระบุหลักฐานมาแล้ว ให้ยกระดับความน่าเชื่อถือเอง ผู้ใช้ไม่ต้องมาเลือกซ้ำ
  v_conf := coalesce(nullif(p_row->>'confidence',''), 'สันนิษฐาน');
  if v_conf = 'สันนิษฐาน' and jsonb_array_length(coalesce(p_row->'evidence','[]'::jsonb)) > 0 then
    v_conf := 'มีหลักฐาน';
  end if;

  insert into acc_cause_detail(accident_code, cause_primary, causes, confidence, evidence, charges, no_charge, note, updated_by)
  values (p_code, nullif(p_row->>'cause_primary',''),
    coalesce(p_row->'causes','[]'::jsonb), v_conf,
    coalesce(p_row->'evidence','[]'::jsonb), coalesce(p_row->'charges','[]'::jsonb),
    coalesce((p_row->>'no_charge')::boolean, false), nullif(p_row->>'note',''),
    (v_user->>'rank') || ' ' || (v_user->>'firstName') || ' ' || (v_user->>'lastName'))
  on conflict (accident_code) do update set
    cause_primary = excluded.cause_primary, causes = excluded.causes,
    confidence = excluded.confidence, evidence = excluded.evidence,
    charges = excluded.charges, no_charge = excluded.no_charge,
    note = excluded.note, updated_by = excluded.updated_by, updated_at = now();

  return jsonb_build_object('success', true, 'confidence', v_conf, 'message', 'บันทึกรายละเอียดสาเหตุแล้ว');
end $$;

-- ============================================================
-- อ่านรายละเอียดสาเหตุตามช่วงวันที่ ใช้เติมกลับในฟอร์มตอนแก้ไข
-- ============================================================
create or replace function acc_cause_list(p_token text, p_codes jsonb) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  return jsonb_build_object('success', true,
    'rows', coalesce((select jsonb_object_agg(d.accident_code, to_jsonb(d))
      from acc_cause_detail d
      where p_codes is null
         or d.accident_code in (select jsonb_array_elements_text(p_codes))), '{}'::jsonb));
end $$;

-- ============================================================
-- ตัวชี้วัดคุณภาพข้อมูลสาเหตุ - หัวใจของเรื่องนี้
--   เทียบ "สันนิษฐานว่าเป็นสาเหตุ" กับ "แจ้งข้อหานั้นจริง" รายสาเหตุ
--   ตัวเลขที่ห่างกันมากคือสัญญาณว่าการบันทึกสาเหตุนั้นเชื่อไม่ได้
-- ============================================================
create or replace function acc_cause_quality(p_token text, p_from date, p_to date) returns jsonb
language plpgsql security definer set search_path = public as $$
declare v_user jsonb; v_total int;
begin
  v_user := officer_session_user(p_token);
  if v_user is null then
    return jsonb_build_object('success', false, 'code', 'AUTH_REQUIRED', 'message', 'กรุณาเข้าสู่ระบบใหม่');
  end if;

  select count(*) into v_total from accidents a
   where (p_from is null or a.incident_datetime >= p_from)
     and (p_to   is null or a.incident_datetime < (p_to + 1));

  return jsonb_build_object('success', true, 'total', v_total,
    -- สัดส่วนเคสที่กรอกรายละเอียดสาเหตุแล้ว เทียบกับเคสทั้งหมด
    'detailed', (select count(*) from accidents a join acc_cause_detail d on d.accident_code = a.accident_code
       where (p_from is null or a.incident_datetime >= p_from)
         and (p_to is null or a.incident_datetime < (p_to + 1))),
    'byConfidence', coalesce((select jsonb_object_agg(confidence, n) from (
        select d.confidence, count(*) n
          from accidents a join acc_cause_detail d on d.accident_code = a.accident_code
         where (p_from is null or a.incident_datetime >= p_from)
           and (p_to is null or a.incident_datetime < (p_to + 1))
         group by d.confidence) t), '{}'::jsonb),
    -- ตารางเปรียบเทียบ: สาเหตุนี้ถูกสันนิษฐานกี่ครั้ง vs แจ้งข้อหาตรงกันกี่ครั้ง
    'gap', coalesce((select jsonb_agg(to_jsonb(t) order by t.presumed desc) from (
        select a.cause,
               count(*) as presumed,
               count(*) filter (where d.charges @> to_jsonb(a.cause)) as charged,
               count(*) filter (where d.confidence <> 'สันนิษฐาน') as evidenced
          from accidents a
          left join acc_cause_detail d on d.accident_code = a.accident_code
         where coalesce(a.cause,'') <> ''
           and (p_from is null or a.incident_datetime >= p_from)
           and (p_to is null or a.incident_datetime < (p_to + 1))
         group by a.cause) t), '[]'::jsonb));
end $$;

-- ============================================================
-- ปิดการเรียกตรงจากคนทั่วไป
-- ============================================================
revoke execute on function acc_cause_save(text, text, jsonb) from public;

grant execute on function acc_cause_save(text, text, jsonb) to anon, authenticated;
grant execute on function acc_cause_list(text, jsonb) to anon, authenticated;
grant execute on function acc_cause_quality(text, date, date) to anon, authenticated;
