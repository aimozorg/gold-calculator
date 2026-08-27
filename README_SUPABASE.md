# راه‌اندازی Supabase برای Gold Calculator MVP v0.3

این نسخه Supabase را برای سه کار وارد می‌کند: احراز هویت، پروفایل مغازه و خواندن وضعیت اشتراک. محاسبات همچنان کاملاً محلی/آفلاین هستند.

## 1) ساخت پروژه
در Supabase یک پروژه جدید بسازید.

## 2) اجرای SQL
فایل `supabase/migrations/0001_profiles_subscriptions.sql` را در SQL Editor اجرا کنید.

RLS روی هر دو جدول فعال است و دسترسی کلاینت محدود به رکورد کاربر است. وضعیت اشتراک از سمت کلاینت فقط خوانده می‌شود؛ **فعال‌سازی پرداختی باید در Edge Function/سرور انجام شود و نباید service_role key داخل اپ قرار گیرد.**

## 3) نصب وابستگی
در ریشه پروژه:

```bash
flutter pub get
```

## 4) گرفتن URL و Publishable Key
از Connect panel پروژه Supabase مقدار Project URL و Publishable Key را بردارید.

## 5) اجرای اپ با dart-define
Windows PowerShell:

```powershell
flutter run --dart-define=SUPABASE_URL="https://YOUR-PROJECT.supabase.co" --dart-define=SUPABASE_PUBLISHABLE_KEY="YOUR_PUBLISHABLE_KEY"
```

یا برای ساخت release:

```powershell
flutter build apk --release --dart-define=SUPABASE_URL="https://YOUR-PROJECT.supabase.co" --dart-define=SUPABASE_PUBLISHABLE_KEY="YOUR_PUBLISHABLE_KEY"
```

کلید service_role را هرگز داخل Flutter، GitHub یا APK قرار ندهید.

## 6) تست
ابتدا:

```bash
flutter analyze
flutter test
flutter run --dart-define=SUPABASE_URL="..." --dart-define=SUPABASE_PUBLISHABLE_KEY="..."
```

### نکته
کلاس `SubscriptionGate` فعلاً فقط وضعیت اشتراک را از Supabase می‌خواند. اتصال درگاه/پرداخت و فعال‌سازی امن اشتراک مرحله بعد است.

## وضعیت نسخه 0.3
این نسخه UI کامل v0.2 را نگه می‌دارد و Supabase Auth + subscription read gate را به آن اضافه می‌کند. اگر `SUPABASE_URL` و `SUPABASE_PUBLISHABLE_KEY` ارسال نشوند، برنامه در حالت پیش‌نمایش محلی اجرا می‌شود.
