# GST Billing System

Flutter mobile/web app for small shopkeepers to manage parties (customers), reusable products, create GST-compliant invoices (CGST+SGST / IGST), save read-only bill history, and share/download PDF invoices. Data syncs via Firebase Firestore.

**Darshan University — Department of Computer Engineering**  
Project task: GST Billing System

---

## Tech stack

| Layer | Choice |
|---|---|
| UI | Flutter (Material 3), Android + Web |
| Backend | Firebase Firestore (cloud sync) |
| PDF | `pdf` + `printing` (preview / share / save) |
| GST math | Pure Dart `GstService` (unit-tested) |

---

## Modules covered

### 1. Party (customer) management
- Add / edit / delete party (name, mobile, address, state, GSTIN, email)
- Searchable party list
- **Party bill history** — tap a party to see all their invoices and totals

### 2. Product management
- Add / edit / delete products (name, HSN/SAC, price, GST %)
- GST slab picker: 0%, 5%, 12%, 18%, 28%
- Reusable catalogue for invoice lines

### 3. GST bill creation
- Select party + add products with quantity
- Auto taxable amount = rate × qty
- Same shop/party state → CGST + SGST (half each); different state → IGST
- Subtotal, total tax, grand total (rounded to 2 decimals)
- Sequential invoice numbers (`INV-0001` …) via Firestore transaction
- Saved bills are **read-only** (no edit after generation)

### 4. PDF invoice
- Shop header (name, address, state, GSTIN, mobile)
- Invoice no., date, bill-to party
- Itemized table with taxable amount and CGST/SGST/IGST
- Preview, share, and save/download

### 5. Bill history & dashboard
- Bill list sorted newest-first; search by party / invoice no.
- **Date-range filter** on bill history
- Dashboard: today’s sales & bills & tax; monthly sales & bills & tax; all-time tax; recent bills

### 6. Shop settings
- Editable shop name, address, state, GSTIN, mobile, email  
  (used on every PDF and for intra/inter-state GST)

---

## Sample invoices (submission)

Three generated PDFs (same layout as the live app):

| File | Scenario |
|---|---|
| [`docs/sample_invoices/INV-0001.pdf`](docs/sample_invoices/INV-0001.pdf) | Intra-state (Maharashtra → Maharashtra), CGST+SGST |
| [`docs/sample_invoices/INV-0002.pdf`](docs/sample_invoices/INV-0002.pdf) | Inter-state (Maharashtra → Gujarat), IGST |
| [`docs/sample_invoices/INV-0003.pdf`](docs/sample_invoices/INV-0003.pdf) | Intra-state, mixed GST slabs (5% / 12% / 18%), unregistered party |

Regenerate:

```bash
flutter test tool/generate_sample_invoices.dart
```

---

## Run locally

1. Install Flutter SDK and enable a device (Android emulator / Chrome).
2. Clone this repo and open the project folder.
3. Ensure Firebase is configured (`lib/firebase_options.dart`, `google-services.json` / `GoogleService-Info.plist`).
4. Install deps and run:

```bash
flutter pub get
flutter run
```

Useful checks:

```bash
flutter analyze
flutter test
```

---

## Screenshots (for the report)

Capture these from a running build and paste into your university report PDF if needed:

1. **Dashboard** — sales / tax cards + recent bills  
2. **Parties** — searchable list  
3. **Party bill history** — one party’s invoices  
4. **Products** — product list  
5. **Create invoice** — party selected, CGST/SGST or IGST chip, line items + totals  
6. **Invoice details** — read-only bill + Share PDF  
7. **Bill history** — search + date range filter  
8. **Shop settings** — shop header fields  

---

## Project structure (high level)

```
lib/
  models/          Party, Product, Bill, BillItem, ShopConfig
  services/        Firestore CRUD, GstService, PdfService, BillService
  screens/         Dashboard, Parties, Products, History, Invoice, Shop Settings
  widgets/         Invoice summary table / totals
docs/sample_invoices/   Sample PDF deliverables
tool/                   Sample PDF generator
test/                   GST + bill filter + dashboard unit tests
```

---

## Bonus features implemented

- Multiple GST rate slabs (0 / 5 / 12 / 18 / 28)
- Firebase cloud sync for parties, products, and bills

## Out of scope (optional stretch, not required)

- Discount fields, payment status, Excel/CSV export, barcode entry, multi-user staff login, amount-in-words on PDF
