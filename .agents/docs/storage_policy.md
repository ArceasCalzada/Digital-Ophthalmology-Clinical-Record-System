# Database Storage Optimization & Future Data Policy

## Overview
This document establishes strict storage guidelines for all future feature additions in the Digital Ophthalmology Clinical Record System (DOCRS). The objective is to continuously minimize database storage footprint per patient, eliminate redundant data caching, and prevent unbounded document growth.

---

## 1. Strict Data Schema Audits
- **Minimal Field Sets**: Store only essential clinical findings. Avoid caching computed or redundant UI states in primary database documents.
- **Strict Typing**: All payload fields must be strongly typed (`String`, `double`, `int`, `DateTime`) with explicit validation.
- **Document Bounds**: Individual Firestore documents must remain well below the 1 MB limit (target: < 50 KB per patient encounter document).

---

## 2. Efficient Data Formats
- **Vector Inking Engine**: All eye examination diagrams and paper chart drawings MUST use mathematical vector representations (`DrawingStroke` point arrays serialized via `perfect_freehand`) rather than raster images (PNG/JPEG/BMP).
  - *Storage Savings*: Vector representation uses ~2-10 KB per chart vs ~1.5 MB for high-res raster PNGs (**99.3% storage reduction**).
- **No Heavy Binary Blobs in Database**: Never store raw base64-encoded images, PDFs, DICOM scans, or audio recordings inside Firestore or database documents.
- **Bucket Storage Mandate**: Heavy files must be uploaded to dedicated Cloud Bucket Storage (e.g. Firebase Storage bucket `gs://` or `https://firebasestorage...`), with only the HTTP reference URL stored in the database record.

---

## 3. Archiving and Pruning Strategy
- **Historical Data Archiving**: Encounters older than 3 years not required for active daily mobile/tablet operations should be candidate for cold storage archiving.
- **Routine Database Migrations**: Clean up orphaned records, unreferenced stroke arrays, and deprecated schema fields during application updates.
- **Compression**: Use `StorageOptimizationService.compressPayload()` for large JSON blobs or long narrative text fields when necessary.

---

## 4. Pull Request Checklist (For Developers & Agents)
- [ ] Brief storage impact assessment included in feature documentation.
- [ ] Verified zero base64 images or raw binary strings stored in database fields.
- [ ] All new fields strictly typed and validated.
- [ ] Tested with `StorageOptimizationService.auditAndOptimizePayload()`.
