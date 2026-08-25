'use strict';
/* ============================================================
   ฉากประกอบสถานการณ์ วาดด้วย SVG ล้วน ไม่มีไฟล์ภาพภายนอก
   ============================================================
   มุมมองเป็นสายตาคนขับที่มองไปข้างหน้าตามถนน ไม่ใช่มองจากด้านข้าง
   เพราะสิ่งที่ต้องตัดสินใจล้วนอยู่ข้างหน้าทั้งนั้น
   ทั้งสี่แยกที่กำลังจะถึง รถที่จอดบังอยู่ และรถบรรทุกที่วิ่งคู่มา
   ถ้าวาดจากด้านข้างจะเล่าเรื่องพวกนี้ไม่ได้เลย

   ระบบพิกัด กว้าง 400 สูง 210
     เส้นขอบฟ้าอยู่ที่ y = 84
     จุดรวมสายตาอยู่ที่ x = 200
     ถนนบานออกจากขอบฟ้าจนเลยขอบจอด้านล่าง

   t คือความลึก 0 คือไกลสุดที่ขอบฟ้า 1 คือใกล้สุดที่ขอบล่าง
   ทุกอย่างวางด้วย t เสมอ ของไกลจึงเล็กและอยู่สูงโดยอัตโนมัติ
   และวัตถุทุกชิ้นวาดขึ้นจากเส้นพื้นที่ระดับ yAt(t) จึงไม่ลอย
   ============================================================ */

var W = 400, H = 210, HZ = 84, VX = 200, HW = 20, SPREAD = 230;
var UID = 0;

function yAt(t) { return HZ + t * (H - HZ); }
function halfAt(t) { return HW + t * SPREAD; }
function leftAt(t) { return VX - halfAt(t); }
function rightAt(t) { return VX + halfAt(t); }
function kAt(t) { return 0.16 + t * 1.05; }   // ตัวคูณขนาดวัตถุตามความลึก

var PAL = {
  day:   { sky:'#a6d2ee', far:'#dceaf6', ground:'#7ea564', road:'#4e555f', kerb:'#9aa2ab', line:'#f2f5f9' },
  night: { sky:'#070d1e', far:'#16244c', ground:'#131c10', road:'#20242b', kerb:'#39404a', line:'#c9d2de' },
  rain:  { sky:'#7f92a4', far:'#aebdc9', ground:'#5c7050', road:'#3b434e', kerb:'#6b727b', line:'#dbe4ee' }
};

/* ---------- ชิ้นส่วนที่ใช้ซ้ำ ทุกชิ้นยืนบนเส้นพื้น yAt(t) ---------- */

// รถเก๋งมองจากด้านหลัง สำหรับรถที่วิ่งไปทางเดียวกับเรา
function carBack(cx, t, col) {
  var k = kAt(t), g = yAt(t), w = 58 * k, h = 40 * k;
  return '<g>' +
    '<ellipse cx="' + cx + '" cy="' + g + '" rx="' + (w * 0.52) + '" ry="' + (h * 0.10) + '" fill="#000" opacity=".25"/>' +
    '<rect x="' + (cx - w / 2) + '" y="' + (g - h) + '" width="' + w + '" height="' + h + '" rx="' + (h * 0.20) + '" fill="' + col + '"/>' +
    '<rect x="' + (cx - w * 0.33) + '" y="' + (g - h * 0.95) + '" width="' + (w * 0.66) + '" height="' + (h * 0.40) + '" rx="' + (h * 0.10) + '" fill="#222a34" opacity=".85"/>' +
    '<rect x="' + (cx - w * 0.45) + '" y="' + (g - h * 0.40) + '" width="' + (w * 0.17) + '" height="' + (h * 0.16) + '" rx="2" fill="#e04a3c"/>' +
    '<rect x="' + (cx + w * 0.28) + '" y="' + (g - h * 0.40) + '" width="' + (w * 0.17) + '" height="' + (h * 0.16) + '" rx="2" fill="#e04a3c"/>' +
    '</g>';
}

// รถกระบะมองจากด้านข้าง สำหรับรถที่จอดริมทาง
function pickupSide(cx, t, col, flip) {
  var k = kAt(t), g = yAt(t), w = 96 * k, h = 34 * k, r = h * 0.34;
  var body =
    '<ellipse cx="' + cx + '" cy="' + g + '" rx="' + (w * 0.52) + '" ry="' + (h * 0.12) + '" fill="#000" opacity=".25"/>' +
    '<rect x="' + (cx - w / 2) + '" y="' + (g - h) + '" width="' + w + '" height="' + (h * 0.60) + '" rx="' + (h * 0.14) + '" fill="' + col + '"/>' +
    '<path d="M' + (cx - w * 0.36) + ' ' + (g - h) + ' l' + (w * 0.10) + ' ' + (-h * 0.52) + ' h' + (w * 0.30) + ' l' + (w * 0.08) + ' ' + (h * 0.52) + ' z" fill="' + col + '"/>' +
    '<path d="M' + (cx - w * 0.30) + ' ' + (g - h * 1.02) + ' l' + (w * 0.08) + ' ' + (-h * 0.40) + ' h' + (w * 0.22) + ' l' + (w * 0.06) + ' ' + (h * 0.40) + ' z" fill="#2a323d" opacity=".85"/>' +
    '<circle cx="' + (cx - w * 0.28) + '" cy="' + (g - r * 0.9) + '" r="' + r + '" fill="#151a21"/>' +
    '<circle cx="' + (cx + w * 0.30) + '" cy="' + (g - r * 0.9) + '" r="' + r + '" fill="#151a21"/>';
  return flip ? '<g transform="translate(' + (cx * 2) + ',0) scale(-1,1)">' + body + '</g>' : '<g>' + body + '</g>';
}

// จักรยานยนต์ที่วิ่งสวนมา เห็นเป็นไฟหน้ากับเงาคนขี่
function motoOncoming(cx, t) {
  var k = kAt(t), g = yAt(t), w = 30 * k, h = 52 * k;
  return '<g>' +
    '<ellipse cx="' + cx + '" cy="' + g + '" rx="' + (w * 0.5) + '" ry="' + (h * 0.06) + '" fill="#000" opacity=".3"/>' +
    '<rect x="' + (cx - w * 0.16) + '" y="' + (g - h * 0.52) + '" width="' + (w * 0.32) + '" height="' + (h * 0.52) + '" fill="#2b3340"/>' +
    '<ellipse cx="' + cx + '" cy="' + (g - h * 0.66) + '" rx="' + (w * 0.42) + '" ry="' + (h * 0.22) + '" fill="#39434f"/>' +
    '<circle cx="' + cx + '" cy="' + (g - h * 0.58) + '" r="' + (w * 0.24) + '" fill="#fff4c6"/>' +
    '<circle cx="' + cx + '" cy="' + (g - h * 0.92) + '" r="' + (w * 0.26) + '" fill="#4a5461"/>' +
    '</g>';
}

// แฮนด์รถจักรยานยนต์ที่ขอบล่าง บอกว่าเรานั่งขี่อยู่ วางให้เตี้ยไม่บังฉาก
function egoMoto(extra) {
  return '<g>' +
    '<path d="M118 210 q82 -20 164 0" fill="none" stroke="#232830" stroke-width="7" stroke-linecap="round"/>' +
    '<rect x="100" y="192" width="30" height="10" rx="5" fill="#171b22"/>' +
    '<rect x="270" y="192" width="30" height="10" rx="5" fill="#171b22"/>' +
    '<rect x="186" y="186" width="28" height="17" rx="5" fill="#12161c"/>' +
    '<circle cx="200" cy="195" r="5" fill="#39434f"/>' +
    (extra || '') + '</g>';
}

// ฝากระโปรงรถยนต์ที่ขอบล่าง
function egoCar() {
  return '<g><path d="M-10 210 q210 -34 420 0 z" fill="#c3c8ce"/>' +
         '<path d="M-10 210 q210 -34 420 0" fill="none" stroke="#969da5" stroke-width="2"/></g>';
}

/* ---------- ถนนพื้นฐาน ---------- */
function baseRoad(p, o) {
  o = o || {};
  var n = o.narrow ? 0.6 : 1;
  var lh = VX - HW * n, rh = VX + HW * n, lb = VX - (HW + SPREAD) * n, rb = VX + (HW + SPREAD) * n;

  var s = '<rect x="0" y="0" width="' + W + '" height="' + HZ + '" fill="url(#sky' + o.uid + ')"/>' +
          '<rect x="0" y="' + HZ + '" width="' + W + '" height="' + (H - HZ) + '" fill="' + p.ground + '"/>' +
          '<polygon points="' + lh + ',' + HZ + ' ' + rh + ',' + HZ + ' ' + rb + ',' + H + ' ' + lb + ',' + H + '" fill="' + p.road + '"/>' +
          '<polygon points="' + lh + ',' + HZ + ' ' + (lh - 2) + ',' + HZ + ' ' + (lb - 22) + ',' + H + ' ' + lb + ',' + H + '" fill="' + p.kerb + '" opacity=".5"/>' +
          '<polygon points="' + rh + ',' + HZ + ' ' + (rh + 2) + ',' + HZ + ' ' + (rb + 22) + ',' + H + ' ' + rb + ',' + H + '" fill="' + p.kerb + '" opacity=".5"/>';

  if (!o.noLine) {
    for (var i = 0; i < 5; i++) {
      s += '<rect class="dash' + (o.still ? ' still' : '') + '" x="197" y="' + HZ + '" width="6" height="5" rx="1" fill="' + p.line + '"' +
           ' style="animation-delay:' + (-i * 0.3) + 's"/>';
    }
  }
  return s;
}

// ถนนตัดขวางแบบมีระยะใกล้ไกล ไม่ใช่แถบตรงบาง ๆ ที่ดูเหมือนกำแพง
function crossRoad(p, t1, t2) {
  var y1 = yAt(t1), y2 = yAt(t2);
  return '<polygon points="0,' + y1 + ' ' + W + ',' + y1 + ' ' + W + ',' + y2 + ' 0,' + y2 + '" fill="' + p.road + '"/>' +
         '<rect x="0" y="' + (y1 - 2) + '" width="' + W + '" height="2" fill="' + p.kerb + '" opacity=".55"/>' +
         '<rect x="0" y="' + y2 + '" width="' + W + '" height="2" fill="' + p.kerb + '" opacity=".55"/>';
}

// เส้นหยุดขาวขวางเลนของเรา ครึ่งซ้ายของถนนเพราะไทยขับชิดซ้าย
function stopLine(p, t) {
  var y = yAt(t), l = leftAt(t) + 3, hgt = 3 + t * 5;
  return '<polygon points="' + l + ',' + y + ' ' + (VX - 2) + ',' + y + ' ' + (VX - 2) + ',' + (y + hgt) + ' ' + (l - 4) + ',' + (y + hgt) + '" fill="' + p.line + '" opacity=".92"/>';
}

function label(x, y, txt, anchor) {
  return '<text x="' + x + '" y="' + y + '" text-anchor="' + (anchor || 'middle') + '" font-size="11" font-weight="700"' +
         ' fill="#fff" stroke="#0a0f18" stroke-width="3" paint-order="stroke" opacity=".95">' + txt + '</text>';
}

/* ---------- แต่ละสถานการณ์ ---------- */
var ART = {

  // สี่แยกไม่มีสัญญาณไฟ มีรถกระบะจอดริมทางฝั่งขวาบังไม่ให้เห็นรถที่จะมาจากทางขวา
  // สี่แยกไม่มีสัญญาณไฟ มีรถกระบะเคลื่อนเข้าแยกจากทางขวา ชะลอเหมือนจะหยุด
  // เราถึงแยกก่อนเล็กน้อย จึงเป็นฝ่ายมีสิทธิ์ใช้ทางตามกฎ
  // แต่การมีสิทธิ์ไม่ได้แปลว่าอีกฝ่ายจะหยุดจริง นั่นคือสิ่งที่ฉากนี้ต้องเล่า
  junction: function (p, o) {
    var tC = 0.34, gC = yAt(tC);
    return baseRoad(p, o) +
      crossRoad(p, 0.16, 0.50) +
      stopLine(p, 0.56) +
      // รถกระบะอยู่บนถนนตัดขวางฝั่งขวา หันหน้าเข้าหาแยก และยังห่างแยกกว่าเรา
      pickupSide(322, tC, '#e8eaed', false) +
      // ไฟเบรกติด บอกว่ากำลังชะลอ
      '<rect x="' + (322 + 44 * kAt(tC)) + '" y="' + (gC - 22 * kAt(tC)) + '" width="' + (7 * kAt(tC)) + '" height="' + (7 * kAt(tC)) + '" rx="2" fill="#ff4433" class="blink"/>' +
      // ลูกศรบอกทิศทางที่เขากำลังมุ่งไป คือเข้าหาแยก
      '<path d="M300 ' + (gC + 8) + ' h-42 m0 0 l8 -5 m-8 5 l8 5" stroke="#ffd24a" stroke-width="2.5" fill="none" stroke-linecap="round"/>' +
      label(VX, HZ - 10, 'เราถึงแยกก่อนเล็กน้อย · เขาชะลอเหมือนจะหยุด') +
      egoMoto();
  },

  // ฝนเพิ่งเริ่มตก ผิวถนนเป็นฟิล์มลื่นและสะท้อนแสง
  rain: function (p, o) {
    var s = baseRoad(p, o);
    for (var i = 0; i < 6; i++) {
      var t = 0.20 + i * 0.14, cx = VX + (i % 2 ? 1 : -1) * halfAt(t) * 0.45;
      s += '<ellipse cx="' + cx + '" cy="' + yAt(t) + '" rx="' + (26 * kAt(t)) + '" ry="' + (5 * kAt(t)) + '" fill="#d5e6f4" opacity=".18"/>';
    }
    s += carBack(VX - halfAt(0.34) * 0.42, 0.34, '#78838f');
    s += '<g class="rainfall">';
    for (var j = 0; j < 30; j++) {
      var x = (j * 41) % 440 - 20;
      s += '<line x1="' + x + '" y1="-16" x2="' + (x - 10) + '" y2="18" stroke="#e2eef8" stroke-width="1.4" opacity=".5"/>';
    }
    s += '</g>' + label(VX, HZ - 12, 'ฝนเพิ่งเริ่มตก ถนนเริ่มลื่น');
    return s + egoMoto();
  },

  // ปากซอย ระยะทางสั้น หมวกยังแขวนอยู่ที่แฮนด์ ไม่ได้สวม
  helmet: function (p, o) {
    var s = baseRoad(p, { narrow:true, still:true, uid:o.uid });
    s += '<rect x="246" y="40" width="96" height="52" fill="#d9cdb4"/>' +
         '<rect x="246" y="40" width="96" height="11" fill="#b4553f"/>' +
         '<rect x="262" y="60" width="28" height="32" fill="#69737f"/>' +
         '<rect x="300" y="60" width="26" height="20" fill="#93a3b1"/>' +
         '<rect x="58" y="46" width="60" height="46" fill="#c6cfbd"/>' +
         '<rect x="126" y="58" width="34" height="34" fill="#bcc4b4"/>' +
         label(VX, HZ - 10, 'ไปแค่ปากซอย ไม่ถึงหนึ่งกิโลเมตร');
    return s + egoMoto(
      '<g><path d="M282 168 a24 24 0 0 1 48 0 v15 h-48 z" fill="#eef1f5"/>' +
      '<rect x="282" y="181" width="48" height="9" rx="4" fill="#333b45"/>' +
      '<path d="M306 190 v12" stroke="#333b45" stroke-width="3"/>' +
      label(306, 160, 'หมวกยังแขวนอยู่') + '</g>');
  },

  // จุดกลับรถ มีเกาะกลางเว้นช่อง และมีจักรยานยนต์สวนมาในเลนตรงข้าม
  uturn: function (p, o) {
    var s = baseRoad(p, o);
    var seg = function (t1, t2) {
      var w1 = 2 + t1 * 16, w2 = 2 + t2 * 16;
      return '<polygon points="' + (VX - w1) + ',' + yAt(t1) + ' ' + (VX + w1) + ',' + yAt(t1) +
             ' ' + (VX + w2) + ',' + yAt(t2) + ' ' + (VX - w2) + ',' + yAt(t2) + '" fill="#a8b0b9"/>'
    };
    s += seg(0, 0.26) + seg(0.54, 1);
    s += label(VX, HZ - 10, 'จะกลับรถ มีจักรยานยนต์สวนมา');
    s += motoOncoming(VX + halfAt(0.46) * 0.55, 0.46);
    s += '<path d="M' + (VX + halfAt(0.46) * 0.55) + ' ' + (yAt(0.46) + 4) + ' v18" stroke="#e04a3c" stroke-width="2" stroke-dasharray="4 3"/>';
    return s + egoCar();
  },

  // กลางคืน ทางตรงยาว เริ่มง่วง ขอบภาพหรี่ลงเหมือนหนังตาจะปิด
  drowsy: function (p, o) {
    var s = baseRoad(p, o);
    s += '<polygon points="' + (VX - 24) + ',' + (HZ + 4) + ' ' + (VX + 24) + ',' + (HZ + 4) + ' ' + (VX + 230) + ',' + H + ' ' + (VX - 230) + ',' + H + '" fill="#ffe9a8" opacity=".13"/>';
    for (var i = 0; i < 5; i++) {
      var t = 0.16 + i * 0.19;
      s += '<rect x="' + (rightAt(t) + 5) + '" y="' + (yAt(t) - 16 * kAt(t)) + '" width="' + (5 * kAt(t)) + '" height="' + (16 * kAt(t)) + '" fill="#f6c85a" opacity=".85"/>';
    }
    s += '<rect x="0" y="0" width="' + W + '" height="52" fill="#04060c" opacity=".82"/>' +
         '<rect x="0" y="' + (H - 34) + '" width="' + W + '" height="34" fill="#04060c" opacity=".82"/>' +
         label(VX, 32, 'ตาเริ่มหนัก · เหลืออีก 20 กม.');
    return s + egoCar();
  },

  // ขี่อยู่ข้างซ้ายของรถบรรทุก รถบรรทุกเปิดไฟเลี้ยวซ้าย เราอยู่ในจุดบอดพอดี
  truck: function (p, o) {
    var s = baseRoad(p, o);
    var g = yAt(0.86);
    s += '<g>' +
      '<ellipse cx="336" cy="' + g + '" rx="96" ry="9" fill="#000" opacity=".3"/>' +
      '<rect x="252" y="' + (g - 108) + '" width="176" height="88" rx="6" fill="#414c5b"/>' +      '<rect x="252" y="' + (g - 108) + '" width="176" height="13" fill="#5a6879"/>' +
      '<rect x="262" y="' + (g - 74) + '" width="158" height="28" fill="#2b3340" opacity=".55"/>' +
      '<circle cx="292" cy="' + (g - 12) + '" r="15" fill="#161b22"/>' +
      '<circle cx="372" cy="' + (g - 12) + '" r="15" fill="#161b22"/>' +
      '<rect x="242" y="' + (g - 66) + '" width="15" height="15" rx="3" fill="#ffb020" class="blink"/>' +
      label(VX, HZ - 10, 'รถบรรทุกเปิดไฟเลี้ยวซ้าย · เราอยู่จุดบอด') +
      '</g>';
    return s + egoMoto();
  },

  // ก่อนออกเดินทาง รถยังจอดอยู่ จึงไม่มีเส้นถนนวิ่ง
  drink: function (p, o) {
    var s = baseRoad(p, { still:true, uid:o.uid });
    s += '<rect x="30" y="34" width="150" height="58" fill="#243049"/>' +
         '<rect x="44" y="48" width="40" height="28" fill="#f0c869" opacity=".9"/>' +
         '<rect x="98" y="48" width="40" height="28" fill="#f0c869" opacity=".55"/>' +
         '<rect x="18" y="126" width="112" height="9" rx="3" fill="#7a5a3a"/>' +
         '<g><rect x="46" y="96" width="26" height="30" rx="3" fill="#f2c14e"/>' +
         '<rect x="46" y="91" width="26" height="9" rx="4" fill="#fff7e2"/>' +
         '<rect x="72" y="103" width="8" height="15" rx="4" fill="#f2c14e"/></g>' +
         carBack(286, 0.40, '#b23b3b') +
         label(VX, HZ - 10, 'ดื่มไปสองแก้ว กำลังจะขี่กลับ');
    return s + egoMoto();
  },

  // ทางแยกมีสัญญาณไฟ ไฟเปลี่ยนเป็นเหลืองขณะที่ยังห่างจากเส้นหยุด
  amber: function (p, o) {
    var s = baseRoad(p, o) + crossRoad(p, 0.14, 0.42) + stopLine(p, 0.46);
    s += '<rect x="330" y="30" width="7" height="86" fill="#5b636e"/>' +
         '<rect x="313" y="8" width="41" height="72" rx="7" fill="#1e232a"/>' +
         '<circle cx="333" cy="24" r="10" fill="#3b424b"/>' +
         '<circle cx="333" cy="44" r="10" fill="#ffc02e"/>' +
         '<circle cx="333" cy="64" r="10" fill="#3b424b"/>' +
         label(200, HZ - 12, 'ไฟเปลี่ยนเป็นเหลือง');
    return s + egoCar();
  }
};

/* ---------- ประกอบเป็น SVG ---------- */
function sceneSVG(art, mood) {
  var key = (mood === 'night' || art === 'drowsy' || art === 'drink') ? 'night'
          : (mood === 'rain' || art === 'rain') ? 'rain' : 'day';
  var p = PAL[key];
  var uid = 'g' + (++UID);                       // ไล่สีต้องมีชื่อไม่ซ้ำ ไม่งั้นทุกฉากจะใช้อันแรกร่วมกัน
  var draw = ART[art] || ART.junction;

  return '<svg class="scene-svg" viewBox="0 0 ' + W + ' ' + H + '" preserveAspectRatio="xMidYMid slice" ' +
         'xmlns="http://www.w3.org/2000/svg" aria-hidden="true">' +
         '<defs><linearGradient id="sky' + uid + '" x1="0" y1="0" x2="0" y2="1">' +
         '<stop offset="0" stop-color="' + p.sky + '"/><stop offset="1" stop-color="' + p.far + '"/>' +
         '</linearGradient></defs>' +
         draw(p, { uid: uid }) +
         '</svg>';
}

if (typeof window !== 'undefined') window.sceneSVG = sceneSVG;
