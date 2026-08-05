-- ============================================================
-- รหัสการปกครอง จังหวัดนครสวรรค์ (ส่วนที่ 2 ของ 2)
-- ============================================================
-- ต้องรัน geocode_1_tables.sql ก่อน
--
-- ตรวจก่อนกด Run: บรรทัดแรกของช่อง editor ต้องเป็นเส้น ==== ชุดนี้
--
-- ที่มา: ตารางรหัสการปกครอง จังหวัดนครสวรรค์ 130 ตำบล 15 อำเภอ
-- ใส่เฉพาะนครสวรรค์ ทั้งประเทศ 7,436 ตำบลให้นำเข้าผ่าน geo_codes_import แทน
-- รันซ้ำได้ ไม่เพิ่มแถวซ้ำ
-- ============================================================

set search_path = public, extensions;

insert into geo_codes (sub_code, sub_name, sub_name_en, dist_code, dist_name, dist_name_en, prov_code, prov_name, prov_name_en) values
  (600101, 'ปากน้ำโพ', 'Pak Nam Pho', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600102, 'กลางแดด', 'Klang Daet', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600103, 'เกรียงไกร', 'Kriangkrai', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600104, 'แควใหญ่', 'Khwae Yai', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600105, 'ตะเคียนเลื่อน', 'Takhian Luean', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600106, 'นครสวรรค์ตก', 'Nakhon Sawan Tok', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600107, 'นครสวรรค์ออก', 'Nakhon Sawan Ok', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600108, 'บางพระหลวง', 'Bang Phra Luang', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600109, 'บางม่วง', 'Bang Muang', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600110, 'บ้านมะเกลือ', 'Ban Makluea', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600111, 'บ้านแก่ง', 'Ban Kaeng', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600112, 'พระนอน', 'Phra Non', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600113, 'วัดไทร', 'Wat Sai', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600114, 'หนองกรด', 'Nong Krot', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600115, 'หนองกระโดน', 'Nong Kradon', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600116, 'หนองปลิง', 'Nong Pling', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600117, 'บึงเสนาท', 'Bueng Senat', 6001, 'เมืองนครสวรรค์', 'Mueang Nakhon Sawan', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600201, 'โกรกพระ', 'Krok Phra', 6002, 'โกรกพระ', 'Krok Phra', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600202, 'ยางตาล', 'Yang Tan', 6002, 'โกรกพระ', 'Krok Phra', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600203, 'บางมะฝ่อ', 'Bang Mafo', 6002, 'โกรกพระ', 'Krok Phra', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600204, 'บางประมุง', 'Bang Pramung', 6002, 'โกรกพระ', 'Krok Phra', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600205, 'นากลาง', 'Na Klang', 6002, 'โกรกพระ', 'Krok Phra', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600206, 'ศาลาแดง', 'Sala Daeng', 6002, 'โกรกพระ', 'Krok Phra', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600207, 'เนินกว้าว', 'Noen Kwao', 6002, 'โกรกพระ', 'Krok Phra', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600208, 'เนินศาลา', 'Noen Sala', 6002, 'โกรกพระ', 'Krok Phra', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600209, 'หาดสูง', 'Hat Sung', 6002, 'โกรกพระ', 'Krok Phra', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600301, 'ชุมแสง', 'Chum Saeng', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600302, 'ทับกฤช', 'Thap Krit', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600303, 'พิกุล', 'Phikun', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600304, 'เกยไชย', 'Koei Chai', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600305, 'ท่าไม้', 'Tha Mai', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600306, 'บางเคียน', 'Bang Khian', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600307, 'หนองกระเจา', 'Nong Krachao', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600308, 'พันลาน', 'Phan Lan', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600309, 'โคกหม้อ', 'Khok Mo', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600310, 'ไผ่สิงห์', 'Phai Sing', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600311, 'ฆะมัง', 'Kha Mang', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600312, 'ทับกฤชใต้', 'Thap Krit Tai', 6003, 'ชุมแสง', 'Chum Saeng', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600401, 'หนองบัว', 'Nong Bua', 6004, 'หนองบัว', 'Nong Bua', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600402, 'หนองกลับ', 'Nong Klap', 6004, 'หนองบัว', 'Nong Bua', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600403, 'ธารทหาร', 'Than Thahan', 6004, 'หนองบัว', 'Nong Bua', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600404, 'ห้วยร่วม', 'Huai Ruam', 6004, 'หนองบัว', 'Nong Bua', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600405, 'ห้วยถั่วใต้', 'Huai Thua Tai', 6004, 'หนองบัว', 'Nong Bua', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600406, 'ห้วยถั่วเหนือ', 'Huai Thua Nuea', 6004, 'หนองบัว', 'Nong Bua', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600407, 'ห้วยใหญ่', 'Huai Yai', 6004, 'หนองบัว', 'Nong Bua', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600408, 'ทุ่งทอง', 'Thung Thong', 6004, 'หนองบัว', 'Nong Bua', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600409, 'วังบ่อ', 'Wang Bo', 6004, 'หนองบัว', 'Nong Bua', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600501, 'ท่างิ้ว', 'Tha Ngio', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600502, 'บางตาหงาย', 'Bang Ta Ngai', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600503, 'หูกวาง', 'Hu Kwang', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600504, 'อ่างทอง', 'Ang Thong', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600505, 'บ้านแดน', 'Ban Daen', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600506, 'บางแก้ว', 'Bang Kaeo', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600507, 'ตาขีด', 'Ta Khit', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600508, 'ตาสัง', 'Ta Sang', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600509, 'ด่านช้าง', 'Dan Chang', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600510, 'หนองกรด', 'Nong Krot', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600511, 'หนองตางู', 'Nong Ta Ngu', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600512, 'บึงปลาทู', 'Bueng Pla Thu', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600513, 'เจริญผล', 'Charoen Phon', 6005, 'บรรพตพิสัย', 'Banphot Phisai', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600601, 'มหาโพธิ', 'Mahapho', 6006, 'เก้าเลี้ยว', 'Kao Liao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600602, 'เก้าเลี้ยว', 'Kao Liao', 6006, 'เก้าเลี้ยว', 'Kao Liao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600603, 'หนองเต่า', 'Nong Tao', 6006, 'เก้าเลี้ยว', 'Kao Liao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600604, 'เขาดิน', 'Khao Din', 6006, 'เก้าเลี้ยว', 'Kao Liao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600605, 'หัวดง', 'Hua Dong', 6006, 'เก้าเลี้ยว', 'Kao Liao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600701, 'ตาคลี', 'Takhli', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600702, 'ช่องแค', 'Chong Khae', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600703, 'จันเสน', 'Chan Sen', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600704, 'ห้วยหอม', 'Huai Hom', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600705, 'หัวหวาย', 'Hua Wai', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600706, 'หนองโพ', 'Nong Pho', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600707, 'หนองหม้อ', 'Nong Mo', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600708, 'สร้อยทอง', 'Soi Thong', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600709, 'ลาดทิพรส', 'Lat Thippharot', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600710, 'พรหมนิมิต', 'Phrom Nimit', 6007, 'ตาคลี', 'Takhli', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600801, 'ท่าตะโก', 'Tha Tako', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600802, 'พนมรอก', 'Phanom Rok', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600803, 'หัวถนน', 'Hua Thanon', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600804, 'สายลำโพง', 'Sai Lamphong', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600805, 'วังมหากร', 'Wang Mahakon', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600806, 'ดอนคา', 'Don Kha', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600807, 'ทำนบ', 'Thamnop', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600808, 'วังใหญ่', 'Wang Yai', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600809, 'พนมเศษ', 'Phanom Set', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600810, 'หนองหลวง', 'Nong Luang', 6008, 'ท่าตะโก', 'Tha Tako', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600901, 'โคกเดื่อ', 'Khok Duea', 6009, 'ไพศาลี', 'Phaisali', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600902, 'สำโรงชัย', 'Samrong Chai', 6009, 'ไพศาลี', 'Phaisali', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600903, 'วังน้ำลัด', 'Wang Nam Lat', 6009, 'ไพศาลี', 'Phaisali', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600904, 'ตะคร้อ', 'Takhro', 6009, 'ไพศาลี', 'Phaisali', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600905, 'โพธิ์ประสาท', 'Pho Prasat', 6009, 'ไพศาลี', 'Phaisali', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600906, 'วังข่อย', 'Wang Khoi', 6009, 'ไพศาลี', 'Phaisali', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600907, 'นาขอม', 'Na Khom', 6009, 'ไพศาลี', 'Phaisali', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (600908, 'ไพศาลี', 'Phaisali', 6009, 'ไพศาลี', 'Phaisali', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601001, 'พยุหะ', 'Phayuha', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601002, 'เนินมะกอก', 'Noen Makok', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601003, 'นิคมเขาบ่อแก้ว', 'Nikhom Khao Bo Kaeo', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601004, 'ม่วงหัก', 'Muang Hak', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601005, 'ยางขาว', 'Yang Khao', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601006, 'ย่านมัทรี', 'Yan Matsi', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601007, 'เขาทอง', 'Khao Thong', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601008, 'ท่าน้ำอ้อย', 'Tha Nam Oi', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601009, 'น้ำทรง', 'Nam Song', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601010, 'เขากะลา', 'Khao Kala', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601011, 'สระทะเล', 'Sa Thale', 6010, 'พยุหะคีรี', 'Phayuha Khiri', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601101, 'ลาดยาว', 'Lat Yao', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601102, 'ห้วยน้ำหอม', 'Huai Nam Hom', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601103, 'วังม้า', 'Wang Ma', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601104, 'วังเมือง', 'Wang Mueang', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601105, 'สร้อยละคร', 'Soi Lakhon', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601106, 'มาบแก', 'Map Kae', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601107, 'หนองยาว', 'Nong Yao', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601108, 'หนองนมวัว', 'Nong Nom Wua', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601109, 'บ้านไร่', 'Ban Rai', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601110, 'เนินขี้เหล็ก', 'Noen Khi Lek', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601116, 'ศาลเจ้าไก่ต่อ', 'San Chao Kai To', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601117, 'สระแก้ว', 'Sa Kaeo', 6011, 'ลาดยาว', 'Lat Yao', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601201, 'ตากฟ้า', 'Tak Fa', 6012, 'ตากฟ้า', 'Tak Fa', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601202, 'ลำพยนต์', 'Lam Phayon', 6012, 'ตากฟ้า', 'Tak Fa', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601203, 'สุขสำราญ', 'Suk Samran', 6012, 'ตากฟ้า', 'Tak Fa', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601204, 'หนองพิกุล', 'Nong Phikun', 6012, 'ตากฟ้า', 'Tak Fa', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601205, 'พุนกยูง', 'Phu Nok Yung', 6012, 'ตากฟ้า', 'Tak Fa', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601206, 'อุดมธัญญา', 'Udom Thanya', 6012, 'ตากฟ้า', 'Tak Fa', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601207, 'เขาชายธง', 'Khao Chai Thong', 6012, 'ตากฟ้า', 'Tak Fa', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601301, 'แม่วงก์', 'Mae Wong', 6013, 'แม่วงก์', 'Mae Wong', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601303, 'แม่เล่ย์', 'Mae Le', 6013, 'แม่วงก์', 'Mae Wong', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601304, 'วังซ่าน', 'Wang San', 6013, 'แม่วงก์', 'Mae Wong', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601305, 'เขาชนกัน', 'Khao Chon Kan', 6013, 'แม่วงก์', 'Mae Wong', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601401, 'แม่เปิน', 'Mae Poen', 6014, 'แม่เปิน', 'Mae Poen', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601501, 'ชุมตาบง', 'Chum Ta Bong', 6015, 'ชุมตาบง', 'Chum Ta Bong', 60, 'นครสวรรค์', 'Nakhon Sawan'),
  (601502, 'ปางสวรรค์', 'Pang Sawan', 6015, 'ชุมตาบง', 'Chum Ta Bong', 60, 'นครสวรรค์', 'Nakhon Sawan')
on conflict (sub_code) do update set
  sub_name = excluded.sub_name, sub_name_en = excluded.sub_name_en,
  dist_code = excluded.dist_code, dist_name = excluded.dist_name, dist_name_en = excluded.dist_name_en,
  prov_code = excluded.prov_code, prov_name = excluded.prov_name, prov_name_en = excluded.prov_name_en;

-- ============================================================
-- ชื่อพ้อง - ชื่อที่ใช้จริงในระบบ ผูกกลับเข้ารหัสทางการ
-- ============================================================
-- ระบบเราและไฟล์ขอบเขตตำบลที่ใช้วาดแผนที่ เขียน 'วัดไทรย์'
-- ทะเบียนกลางเขียน 'วัดไทร' ทั้งสองใช้กันจริง จึงไม่แก้ชื่อฝั่งใดฝั่งหนึ่ง
-- แต่ผูกให้ชี้รหัสเดียวกัน เพื่อให้เทียบข้อมูลข้ามแหล่งได้
insert into geo_aliases (alias, sub_code, note) values
  ('วัดไทรย์', 600113, 'ชื่อที่ใช้ในพื้นที่และในระบบนี้ ทะเบียนกลางเขียน วัดไทร')
on conflict (alias) do update set sub_code = excluded.sub_code, note = excluded.note;

-- ============================================================
-- ตรวจผลหลังรัน
-- ============================================================
-- select count(*) as ตำบลนครสวรรค์ from geo_codes where prov_code = 60;
-- select geo_resolve_sub('วัดไทรย์')   as ควรได้_600113;
-- select geo_resolve_sub('ต.หนองกรด', 'เมืองนครสวรรค์') as ควรได้_600114;
