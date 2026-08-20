# Digital Ophthalmology Clinical Record System (DOCRS)

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Platform-Web%20%7C%20macOS%20%7C%20Windows%20%7C%20Mobile-blue?style=for-the-badge" alt="Cross Platform" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=for-the-badge" alt="License" />
</p>

An advanced, responsive, cross-platform Electronic Health Record (EHR) & Clinical Decision System built with Flutter specifically tailored for ophthalmologists, optometrists, and eye care clinics.

---

## 🌟 Key Features

### 👁️ Interactive Ophthalmic Drawing Canvas
- **Vector Stylus & Touch Canvas**: Draw and annotate ophthalmic findings directly on Right Eye (**OD**) and Left Eye (**OS**) templates.
- **Anterior & Posterior Segment Templates**: Supports Cornea/Slit Lamp, Fundus/Retina, and Lens visual maps.
- **Standardized Medical Color Palette**:
  - 🔴 **Retinal Red**: Hemorrhages, retinal tears, neovascularization.
  - 🔵 **Vein Blue**: Retinal veins, vein occlusions, cataracts.
  - 🟡 **Drusen Yellow**: Hard/soft drusen, hard exudates.
  - 🟢 **Fluorescein Green**: Epithelial defects, corneal staining, pterygium.
  - 🟠 **Lesion Orange**: Choroidal nevus, optic disc notch.
- **Canvas Tools**: Undo, redo, clear, adjustable stroke width, eraser, and vector path serialization.

### 🩺 Comprehensive Eye Examination Module
- **Visual Acuity**: Log uncorrected, corrected (spectacles/contact lenses), near, distance, and pinhole acuity.
- **Refraction & Manifest Autorefraction**: Track Sphere, Cylinder, Axis, and Add parameters.
- **Intraocular Pressure (IOP)**: Goldmann Applanation Tonometry & Air Puff IOP measurements with automatic time-stamping.
- **Slit Lamp & Fundoscopy Clinical Findings**: Structured input fields for cornea, anterior chamber, iris, lens, vitreous, optic disc, macula, and retina.
- **Diagnosis & Assessment**: Integrated ICD-10 ophthalmic diagnosis coding and management plan logging.

### 📋 Patient Management & Longitudinal EHR Profiles
- **Patient Directory**: Instant search and filtering by Patient Name, Medical Record Number (MRN), Age, Gender, or Diagnosis.
- **Encounter Timeline**: Comprehensive historical view of all previous clinical encounters and visits.
- **Historical Comparison View**: Side-by-side comparison of past vs. present exam findings and eye drawings for OD and OS.

### 💊 Prescription & Medication Writer
- Comprehensive ophthalmic drug database (Mydriatics, Antibiotics, Steroids, Glaucoma Drops, Artificial Tears).
- Auto-formatting for Eye Selection (**OD**, **OS**, **OU**), dosage, frequency, and duration.
- Official prescription printing and export.

### 📷 OCR Document Scanner
- Built-in Optical Character Recognition (OCR) parser for digitizing paper chart records, external optometry referrals, and lab results.

### 🖨️ PDF Export & Clinical Reports
- Generate clean, professional PDF clinical exam summaries and official patient prescriptions directly from the app.

---

## 🛠️ Technology Stack

- **Frontend & Framework**: [Flutter](https://flutter.dev/) (Dart)
- **UI Architecture**: Material Design 3, Responsive Adaptive Layout for Desktop, Web, and Tablet
- **Drawing Engine**: Custom Painter with Vector Path Serialization (`EyeDrawingCanvas`, `DrawingStroke`)
- **PDF Generation**: `pdf` & `printing` packages
- **Platform Support**: Web, macOS, Windows, Linux, iOS, Android

---

## 📁 Repository Structure

```
lib/
├── main.dart                      # Application entrypoint & root theme provider
├── models/                        # Core data models
│   ├── patient.dart               # Patient profile & demographics
│   ├── eye_exam.dart              # Visual acuity, IOP, Refraction, & Findings
│   ├── encounter.dart            # Clinical encounter metadata
│   ├── prescription.dart         # Ophthalmic medication prescriptions
│   ├── drawing_stroke.dart       # Vector canvas stroke serialization
│   └── document_ocr.dart         # OCR parsed document model
├── theme/                         # Application design tokens & theme configuration
│   └── app_theme.dart             # High-contrast clinical Light & Dark themes
├── views/                         # Main application screens
│   ├── main_layout.dart           # Adaptive sidebar navigation & top bar layout
│   ├── dashboard_screen.dart      # Main clinic overview, stats, & quick actions
│   ├── patients_screen.dart       # Searchable patient directory
│   ├── patient_profile_view.dart  # Detailed EHR timeline & past encounters
│   ├── eye_exam_view.dart         # Full interactive eye exam & drawing workstation
│   ├── prescription_view.dart     # Medication prescription builder
│   ├── ocr_scanner_view.dart      # Document OCR scanner view
│   ├── historical_comparison_view.dart # Side-by-side OD/OS timeline comparison
│   └── settings_view.dart         # Workstation preferences & clinic profile
└── widgets/                       # Reusable clinical widgets
    ├── drawing/
    │   └── eye_drawing_canvas.dart # Interactive custom painter vector drawing canvas
    ├── eye_badge.dart             # OD/OS indicator badges
    ├── patient_card.dart          # Patient quick summary card
    └── pdf_exam_preview_dialog.dart # PDF print & export preview modal
```

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19.0 or higher recommended)
- [Dart SDK](https://dart.dev/get-dart)
- Chrome / macOS / Xcode / Android Studio (depending on target platform)

### Installation & Setup

1. **Clone the repository**:
   ```bash
   git clone https://github.com/ArceasCalzada/Digital-Ophthalmology-Clinical-Record-System.git
   cd Digital-Ophthalmology-Clinical-Record-System
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run the application**:
   - For **Web**:
     ```bash
     flutter run -d chrome
     ```
   - For **macOS**:
     ```bash
     flutter run -d macos
     ```
   - For **Windows**:
     ```bash
     flutter run -d windows
     ```

4. **Run tests**:
   ```bash
   flutter test
   ```

---

## 🔒 Security & Medical Compliance Note

This application is designed as a clinical record management interface prototype. When deploying in a live clinical environment, ensure integration with HIPAA / GDPR compliant HIPAA-ready databases, encrypted storage at rest, and role-based access control (RBAC).

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
