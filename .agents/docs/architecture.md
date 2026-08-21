# System Architecture & Models

## Overview
The Digital Ophthalmology Clinical Record System is a specialized Flutter application built for optometrists and ophthalmologists. It merges modern structured EHR/EMR workflows with natural vector-ink clinical drawing canvases.

## Key Subsystems

### 1. Data Models (`lib/models/`)
- `Patient` (`patient.dart`): Core patient demographic and clinical history model, containing patient identification, visits, medical alerts, and past encounters.
- `Encounter` (`encounter.dart`): Individual clinical encounters and examination records.
- `EyeExam` (`eye_exam.dart`): Structured ophthalmology examination findings (visual acuity, refraction, IOP, slit lamp, anterior segment, fundus evaluation).
- `Prescription` (`prescription.dart`): Optical and pharmaceutical prescriptions generated from encounter findings.
- `DrawingStroke` (`drawing_stroke.dart`): `VectorStroke` model containing serialized point arrays, stroke widths, colors, and timestamps for smooth vector replication.

### 2. Clinical Views (`lib/views/`)
- `MainLayout` (`main_layout.dart`): Primary navigation container with sidebar and responsive workspace.
- `DashboardScreen` (`dashboard_screen.dart`): Clinic overview, appointment schedule, patient queue, and quick statistics.
- `PatientsScreen` (`patients_screen.dart`): Searchable patient directory, filtering, and rapid profile creation.
- `PatientProfileView` (`patient_profile_view.dart`): Comprehensive patient record view with chronological encounter history, ocular metrics timeline, and new visit triggers.
- `EyeExamView` (`eye_exam_view.dart`): Main clinical examination suite featuring structured tabs (Subjective, Objective, Assessment, Plan) integrated with vector diagramming.
- `HistoricalComparisonView` (`historical_comparison_view.dart`): Side-by-side historical comparison of visual acuity, IOP trends, and ocular drawings.
- `PrescriptionView` (`prescription_view.dart`): Prescription generator with print and PDF export.

### 3. Drawing & Diagramming Canvas (`lib/widgets/drawing/`)
- `PaperSheetCanvas` (`paper_sheet_canvas.dart`): Full-page paper chart replica supporting natural handwriting, stylus input, highlighters, and eraser tools.
- `EyeDrawingCanvas` (`eye_drawing_canvas.dart`): Diagramming tool loaded with ocular anatomical templates (Cornea, Anterior Chamber, Iris/Lens, Fundus/Retina) with OD/OS segregation and color-coded clinical layers.

### 4. PDF Generation & Reporting (`lib/widgets/pdf_exam_preview_dialog.dart`)
- Generates clinical encounter summaries and official consultation records for export or printing.
