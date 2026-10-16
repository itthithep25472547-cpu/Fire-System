# ตั้งค่าหน้าจัดการบัญชีผู้ใช้

หน้าจัดการบัญชีใช้ Supabase Edge Function เพื่อไม่เปิดเผย `service_role` key ในเว็บ

## ตั้งค่าแอดมิน

1. เพิ่มบัญชีแอดมินของคุณไว้ใน Supabase ที่ **Authentication → Users** ก่อน โดยอีเมลต้องตรงกับที่จะอนุญาตด้านล่าง
2. รัน `supabase-workflow-upgrade.sql` ใน **Supabase Dashboard → SQL Editor** ก่อน เพื่อสร้างตาราง role และประวัติส่งเมล พร้อมตั้ง RLS
3. ติดตั้ง Supabase CLI และเปิด PowerShell ที่โฟลเดอร์โปรเจกต์นี้
4. ล็อกอินและผูกโปรเจกต์:

```powershell
npx.cmd supabase@latest login
npx.cmd supabase@latest link --project-ref ovaceqrzhvzgugoclxyl
```

5. กำหนดอีเมลแอดมินที่อนุญาตให้จัดการบัญชีได้ หากมีหลายอีเมลให้คั่นด้วย comma:

```powershell
npx.cmd supabase@latest secrets set ADMIN_EMAILS="admin@example.com" --project-ref ovaceqrzhvzgugoclxyl
```

6. Deploy ฟังก์ชันจัดการผู้ใช้:

```powershell
npx.cmd supabase@latest functions deploy manage-users --project-ref ovaceqrzhvzgugoclxyl
```

หลัง deploy แล้ว แอดมินที่มีอีเมลตรงกับ `ADMIN_EMAILS` จะเห็นแท็บ **บัญชีผู้ใช้** ในเว็บ ผู้ใช้ทั่วไปจะไม่เห็นแท็บนี้

## เพิ่มผู้ใช้

ในเว็บเปิดแท็บ **บัญชีผู้ใช้** กรอกอีเมลกับรหัสผ่านเริ่มต้นอย่างน้อย 12 ตัวอักษร แล้วกด **สร้างบัญชี** จากนั้นส่งข้อมูลล็อกอินให้เจ้าหน้าที่ผ่านช่องทางที่ปลอดภัย

Edge Function ใช้ `SUPABASE_SERVICE_ROLE_KEY` ที่ Supabase จัดเตรียมให้ฝั่ง server เท่านั้น ห้ามนำคีย์นี้ไปใส่ใน `supabase-config.js` หรือ HTML

## ตั้งค่าส่งใบเตือนผ่าน Resend

1. สมัคร/เข้าสู่ระบบที่ Resend แล้วสร้าง API key ในหน้า **API Keys** คัดลอกเก็บไว้ส่วนตัว ห้ามใส่ใน HTML หรือส่งในแชต
2. สำหรับส่งถึงลูกค้าจริง ให้เพิ่มโดเมนผู้ส่งใน Resend แล้วตั้งค่า DNS ตามที่ Resend แสดง จนสถานะโดเมนเป็น **Verified** จากนั้นเลือกอีเมลผู้ส่งบนโดเมนนั้น เช่น `renewal@your-verified-domain.com`
3. เปิด PowerShell ที่โฟลเดอร์โปรเจกต์ แล้วตั้ง secrets ทีละรายการ โดยแทนค่าตัวอย่างด้วยค่าจริง พิมพ์ API key ใน Terminal เท่านั้น:

```powershell
npx.cmd supabase@latest secrets set RESEND_API_KEY="re_ใส่คีย์ของคุณ" --project-ref ovaceqrzhvzgugoclxyl
npx.cmd supabase@latest secrets set RESEND_FROM_ADDRESS="The Deves <renewal@your-verified-domain.com>" --project-ref ovaceqrzhvzgugoclxyl
```

4. Deploy ฟังก์ชันส่งอีเมล:

```powershell
npx.cmd supabase@latest functions deploy send-renewal-email --project-ref ovaceqrzhvzgugoclxyl
```

5. เปิดเว็บเวอร์ชันล่าสุด ล็อกอิน เลือกใบเตือน ตรวจอีเมลผู้รับ แล้วกด **ส่งอีเมลอัตโนมัติ (Resend)** เมื่อส่งสำเร็จ ระบบจะเปลี่ยนสถานะใบเตือนเป็น **ส่งแล้ว**

`onboarding@resend.dev` ใช้ได้เฉพาะทดสอบและส่งได้เฉพาะอีเมลเจ้าของบัญชี Resend เท่านั้น การส่งถึงลูกค้าต้องใช้ sender บนโดเมนที่ยืนยันแล้ว

## ตั้งค่า role และเปิดระบบเตือนอัตโนมัติ

- ผู้ใช้ใหม่เริ่มเป็น **เจ้าหน้าที่**; แอดมินเลือก role ตอนสร้างบัญชีหรือเปลี่ยน role ในตารางบัญชีได้
- เจ้าหน้าที่ดู เพิ่ม และแก้ไขได้ แต่ลบกรมธรรม์/ใบเตือนและจัดการบัญชีได้เฉพาะแอดมิน
- หากต้องเพิ่มแอดมิน ให้เพิ่มอีเมลใน secret `ADMIN_EMAILS`; ผู้ใช้ที่ไม่อยู่ในรายการจะเป็นเจ้าหน้าที่
- เปิดช่อง **ส่งอีเมลเตือนอัตโนมัติ** ในกรมธรรม์ที่ต้องการให้เตือน ระบบส่งภาษาไทยก่อนหมดอายุ 30 และ 7 วัน; ค่าเริ่มต้นปิดไว้
- ประวัติการส่งอยู่ในหน้า **ใบเตือนต่ออายุ**; การส่งตามกำหนดเป็นข้อความภาษาไทยและไม่มี PDF แนบ ส่วนการกดส่งเองจะแนบ PDF

### ตั้งเวลา Cron

1. สร้าง secret สำหรับ cron ใน PowerShell แล้วคัดลอกไว้ใน clipboard:

```powershell
$cronSecret = [guid]::NewGuid().ToString('N')
Set-Clipboard $cronSecret
npx.cmd supabase@latest secrets set CRON_SECRET="$cronSecret" --project-ref ovaceqrzhvzgugoclxyl
npx.cmd supabase@latest functions deploy send-scheduled-reminders --project-ref ovaceqrzhvzgugoclxyl
```

2. เปิด `supabase-schedule-reminders.sql` แทน `PASTE_CRON_SECRET_HERE` ด้วย secret ที่เพิ่งสร้าง แล้วรันทั้งไฟล์ใน **Supabase Dashboard → SQL Editor** ไฟล์นี้ตั้งให้ทำงานทุกวันเวลา 02:00 น. ไทย
3. ใน Supabase Dashboard → **Edge Functions** ตรวจว่า `send-scheduled-reminders` deploy แล้ว และตรวจ `email_send_logs` หลังรอบทำงาน

Cron จะส่งเฉพาะกรมธรรม์ที่เปิด opt-in และมีอีเมลผู้รับที่ถูกต้อง บันทึกผลลงประวัติ และไม่ส่งซ้ำสำหรับกรมธรรม์/วันหมดอายุ/ช่วงเตือนเดียวกัน
