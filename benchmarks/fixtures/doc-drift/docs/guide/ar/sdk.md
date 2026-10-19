# حزمة SDK

يغلّف عميل TypeScript الواجهة البرمجية: المصادقة، وإعادة المحاولة للطلبات المتكررة الآمنة،
والاستجابات ذات الأنواع.

## الاستدعاء الأول

```ts
import { createClient } from '@tallyhook/sdk';

const client = createClient({ apiKey: process.env.TALLYHOOK_API_KEY ?? '' });
// ...
const first = await client.orders.list({ limit: 50 });
```

تحمل كل صفحة `nextCursor`؛ مرّره مرة أخرى في `cursor` لقراءة الصفحة التالية.

العودة إلى [الصفحة الرئيسية](index.md).
