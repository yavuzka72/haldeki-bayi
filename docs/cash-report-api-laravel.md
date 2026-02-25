# DailyCashDashboard Laravel API (Frontend Uyumlu)

Bu dokuman, `DailyCashDashboard` ekraninin bekledigi endpoint ve response seklini birebir verir.

## 1) Endpoint

- Method: `GET`
- Path: `/api/v1/cash`
- Query:
  - `from` (zorunlu, `Y-m-d`)
  - `to` (zorunlu, `Y-m-d`)
  - `dealer_id` (opsiyonel)
  - `courier_id` (opsiyonel)

## 2) Frontend'in Bekledigi Response

```json
{
  "date_from": "2026-02-01",
  "date_to": "2026-02-19",
  "dealer_id": 24,
  "courier_id": null,
  "daily": [],
  "customers": [],
  "suppliers": [],
  "couriers": [],
  "vendors": []
}
```

Not: Frontend `data` wrapper'ini da okuyabiliyor ama en temiz sekil yukaridaki gibi root response donmek.

## 3) Route

`routes/api.php`:

```php
use App\Http\Controllers\Api\V1\CashReportController;

Route::prefix('v1')->middleware('auth:sanctum')->group(function () {
    Route::get('cash', [CashReportController::class, 'index']);
});
```

## 4) Controller

`app/Http/Controllers/Api/V1/CashReportController.php`:

```php
<?php

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

class CashReportController extends Controller
{
    public function index(Request $request)
    {
        $validated = $request->validate([
            'from' => ['required', 'date_format:Y-m-d'],
            'to' => ['required', 'date_format:Y-m-d', 'after_or_equal:from'],
            'dealer_id' => ['nullable', 'integer'],
            'courier_id' => ['nullable', 'integer'],
        ]);

        $from = Carbon::createFromFormat('Y-m-d', $validated['from'])->startOfDay();
        $to = Carbon::createFromFormat('Y-m-d', $validated['to'])->endOfDay();

        // Frontend dealer_id gondermezse token'dan dealer id kullan
        $dealerId = $validated['dealer_id'] ?? optional($request->user())->dealer_id;
        $courierId = $validated['courier_id'] ?? null;

        // Guvenlik: isteyen herkes farkli dealer goremesin
        // Admin degilsen sadece kendi dealer'ini gorebilirsin
        if (!$request->user()?->hasRole('admin')) {
            $dealerId = optional($request->user())->dealer_id;
        }

        // 1) Gunluk ozet (vw_gunluk_kasa_ozet)
        $daily = DB::table('vw_gunluk_kasa_ozet')
            ->when($dealerId, fn ($q) => $q->where('dealer_id', $dealerId))
            ->when($courierId, fn ($q) => $q->where('courier_id', $courierId))
            ->whereDate('tarih', '>=', $from->toDateString())
            ->whereDate('tarih', '<=', $to->toDateString())
            ->orderBy('tarih')
            ->get([
                'tarih',
                'dealer_id',
                'bayi_adi',
                'musteri_tahsilat',
                'tedarikci_odeme',
                'kurye_odeme',
                'bayi_komisyonu',
                // Opsiyonel: varsa dursun, frontend hesabi kendisi de yapiyor
                DB::raw('COALESCE(gunluk_net_kasa, 0) as gunluk_net_kasa'),
            ]);

        // 2) Musteri tahsilat detay (vw_musteri_tahsilat_detay)
        $customers = DB::table('vw_musteri_tahsilat_detay')
            ->when($dealerId, fn ($q) => $q->where('dealer_id', $dealerId))
            ->when($courierId, fn ($q) => $q->where('courier_id', $courierId))
            ->whereBetween('islem_tarihi', [$from, $to])
            ->orderByDesc('islem_tarihi')
            ->get([
                'islem_tarihi',
                'dealer_id',
                'bayi_adi',
                'delivery_order_id',
                'kaynak_order_id',
                'teslimat_kodu',
                'musteri_adi',
                'siparis_tutari',
                'tahsil_edilen_tutar',
                'odeme_durumu',
                'siparis_durumu',
            ]);

        // 3) Tedarikci odeme detay (vw_tedarikci_odeme_detay)
        $suppliers = DB::table('vw_tedarikci_odeme_detay')
            ->when($dealerId, fn ($q) => $q->where('dealer_id', $dealerId))
            ->whereBetween('islem_tarihi', [$from, $to])
            ->orderByDesc('islem_tarihi')
            ->get([
                'islem_tarihi',
                'dealer_id',
                'bayi_adi',
                'order_id',
                'siparis_kodu',
                'tedarikci_adi',
                'siparis_tutari',
                'tedarikci_odeme_tutari',
                'siparis_durumu',
                'odeme_durumu',
            ]);

        // 4) Kurye odeme detay (vw_kurye_odeme_detay)
        $couriers = DB::table('vw_kurye_odeme_detay')
            ->when($dealerId, fn ($q) => $q->where('dealer_id', $dealerId))
            ->when($courierId, fn ($q) => $q->where('courier_id', $courierId))
            ->whereBetween('islem_tarihi', [$from, $to])
            ->orderByDesc('islem_tarihi')
            ->get([
                'islem_tarihi',
                'dealer_id',
                'bayi_adi',
                'delivery_order_id',
                'kaynak_order_id',
                'teslimat_kodu',
                'kurye_adi',
                'siparis_tutari',
                'kurye_odeme_tutari',
                'teslimat_durumu',
                'odeme_durumu',
            ]);

        // 5) Bayi komisyon detay (vw_bayi_komisyon_detay)
        $vendors = DB::table('vw_bayi_komisyon_detay')
            ->when($dealerId, fn ($q) => $q->where('dealer_id', $dealerId))
            ->whereBetween('islem_tarihi', [$from, $to])
            ->orderByDesc('islem_tarihi')
            ->get([
                'islem_tarihi',
                'dealer_id',
                'bayi_adi',
                'order_id',
                'siparis_kodu',
                'siparis_tutari',
                'bayi_komisyon_tutari',
                'siparis_durumu',
                'odeme_durumu',
            ]);

        return response()->json([
            'date_from' => $from->toDateString(),
            'date_to' => $to->toDateString(),
            'dealer_id' => $dealerId,
            'courier_id' => $courierId,
            'daily' => $daily,
            'customers' => $customers,
            'suppliers' => $suppliers,
            'couriers' => $couriers,
            'vendors' => $vendors,
        ]);
    }
}
```

## 5) Frontend Alan Eslesmesi (Kontrol Listesi)

Ekran/model tarafinda beklenen alan adlari:

- `daily`:
  - `tarih`, `dealer_id`, `bayi_adi`, `musteri_tahsilat`, `tedarikci_odeme`, `kurye_odeme`, `bayi_komisyonu`
- `customers`:
  - `islem_tarihi`, `dealer_id`, `bayi_adi`, `delivery_order_id`, `kaynak_order_id`, `teslimat_kodu`, `musteri_adi`, `siparis_tutari`, `tahsil_edilen_tutar`, `odeme_durumu`, `siparis_durumu`
- `suppliers`:
  - `islem_tarihi`, `dealer_id`, `bayi_adi`, `order_id`, `siparis_kodu`, `tedarikci_adi`, `siparis_tutari`, `tedarikci_odeme_tutari`, `siparis_durumu`, `odeme_durumu`
- `couriers`:
  - `islem_tarihi`, `dealer_id`, `bayi_adi`, `delivery_order_id`, `kaynak_order_id`, `teslimat_kodu`, `kurye_adi`, `siparis_tutari`, `kurye_odeme_tutari`, `teslimat_durumu`, `odeme_durumu`
- `vendors`:
  - `islem_tarihi`, `dealer_id`, `bayi_adi`, `order_id`, `siparis_kodu`, `siparis_tutari`, `bayi_komisyon_tutari`, `siparis_durumu`, `odeme_durumu`

## 6) Hata Donusleri

- Validation: `422` (Laravel default)
- Auth yoksa: `401`
- Beklenmeyen hata: `500`

Opsiyonel olarak tum cevaplari sizin mevcut `json_custom_response(...)` helper'inizla da donebilirsiniz, fakat frontend'in yukaridaki anahtarlarin en az bir formatini gormesi yeterli.
