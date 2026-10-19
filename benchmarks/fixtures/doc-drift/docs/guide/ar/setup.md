# البدء

تنقلك هذه الصفحة من نسخة جديدة من المستودع إلى واجهة تعمل على `http://localhost:3000`.

## المتطلبات

- Node 22.12 أو أحدث، و pnpm 10
- Docker لتشغيل Postgres 16 و Redis 7

## التثبيت

```bash
pnpm install
cp apps/api/.env.example apps/api/.env
docker compose up -d postgres redis
pnpm db:migrate
pnpm dev:all
```

الأمر الأول يثبّت مساحة العمل، والثاني يعطي الواجهة إعداداتها المحلية، والثالث يشغّل قواعد
البيانات، والرابع ينشئ الجداول، والأخير يشغّل الواجهة في وضع المراقبة.

## الخطوات التالية

اقرأ كيف ترقّم [الفوترة](billing.md) الفواتير وترسلها، ثم اربط [حزمة SDK](sdk.md).
