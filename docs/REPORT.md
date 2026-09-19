# GST Billing System — Short Project Report

**Institution:** Darshan University, Department of Computer Engineering  
**Project:** GST Billing System (Mobile / Web Application)  
**Stack:** Flutter + Firebase Firestore + `pdf` / `printing`

---

## 1. Objective

Build an application that lets a shopkeeper manage customers (parties), maintain a reusable product catalogue, create GST-compliant itemized invoices with automatic CGST/SGST or IGST calculation, store immutable bill history, and export/share each bill as a PDF.

---

## 2. Modules implemented

| Module | Implementation summary |
|---|---|
| Party management | CRUD, search, per-party bill history |
| Product management | CRUD, HSN, price, GST % slabs |
| Bill creation | Party + items + qty; auto tax; sequential invoice no.; read-only after save |
| PDF invoice | Shop header, bill-to, item table, totals; preview & share |
| History & dashboard | Sorted list, text search, date-range filter; today/month sales & tax |
| Shop settings | Editable shop details used for PDF header and GST state logic |

---

## 3. GST calculation (as implemented)

1. Taxable amount = rate × quantity  
2. Same state → CGST = SGST = (GST% ÷ 2) of taxable  
3. Different state → IGST = GST% of taxable  
4. Line total = taxable + tax  
5. Grand total = sum of line totals (money rounded to 2 decimals)

Logic lives in `lib/services/gst_service.dart` and is covered by `test/gst_service_test.dart`.

---

## 4. Sample invoices included

| Invoice | Tax type | Notes |
|---|---|---|
| INV-0001 | CGST + SGST | Intra-state, registered party |
| INV-0002 | IGST | Inter-state (MH → GJ) |
| INV-0003 | CGST + SGST | Mixed rates 5/12/18%, unregistered |

Files: `docs/sample_invoices/INV-0001.pdf` … `INV-0003.pdf`

---

## 5. How to run

```bash
flutter pub get
flutter run
flutter analyze
flutter test
```

---

## 6. Screenshots

Insert screenshots of: Dashboard, Parties, Party History, Products, Create Invoice, Invoice Details (PDF actions), Bill History (date filter), Shop Settings. Capture from `flutter run` on Android or Chrome.

---

## 7. Conclusion

The application meets the core functional requirements of the GST Billing System task: party/product management, correct GST split, immutable saved bills, PDF export/share, searchable history with date filter, and a simple sales/tax dashboard. Firebase provides cloud persistence suitable for a clean clone-and-run demo when project Firebase credentials are present.
