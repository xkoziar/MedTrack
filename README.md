# MedTrack

MedTrack is a Flutter application for tracking medication schedules, dose confirmations, and adherence across Android and web. It is built around a simple daily workflow: sign in, manage medications, review today's schedule, and confirm doses manually or with NFC on supported Android devices.

**Platforms:** Android, Web
**Recommended platform:** Android for the full feature set

## Features

### Core functionality
- **Authentication** - Sign up and sign in with Firebase Authentication
- **Home dashboard** - Review today's scheduled doses together with adherence-oriented summary cards
- **Medication management** - Create, edit, activate, deactivate, and remove medications with dosage, notes, start/end dates, weekday schedules, and multiple daily times
- **Medication details** - Inspect schedule information, recent dose history, and linked NFC tags for a selected medication
- **Dose history** - Browse taken, upcoming, and missed dose events
- **Profile settings** - Manage notification preferences, reminder lead time, password changes, and account actions

### NFC and reminders
- **NFC tag management** - Create, name, link, unlink, and remove tags assigned to medications
- **NFC-assisted dose confirmation** - Mark the most relevant due doses by scanning a linked NFC tag on supported Android devices
- **Scheduled reminders** - Receive configurable medication reminders through local notifications
- **Cloud sync** - Store authentication, medications, dose events, and NFC metadata in Firebase

## Data Model

The application currently works with these core entities:

- **AppUser** - Email, display name, notification preference, and reminder lead time
- **Medication** - Name, description, dosage, active window, weekday schedule, times, and linked NFC tags
- **DoseEvent** - A scheduled medication event with an optional confirmation timestamp
- **NfcTag** - Physical tag metadata and its medication assignments

## Tech Stack

- **Flutter** for the application shell and UI
- **Firebase Authentication** for account management
- **Cloud Firestore** for cloud-backed storage
- **flutter_local_notifications** and **timezone** for reminder scheduling
- **get_it** for dependency injection
- **json_serializable** and **freezed** for code generation and model support
- Local **packages/nfc_manager** package for NFC access

## Getting Started

### Prerequisites

- Flutter SDK compatible with Dart `^3.9.2`
- Android Studio or VS Code with Flutter tooling
- A Firebase project with Authentication and Cloud Firestore enabled
- An Android device or emulator if you want to test the full reminder and NFC workflow

### Installation

1. Clone the repository.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Configure Firebase for your environment:
   - Generate or replace `lib/firebase_options.dart` using the FlutterFire CLI.
   - Place your Android `google-services.json` in `android/app/`.
4. Run the application:
   ```bash
   # Android
   flutter run

   # Web
   flutter run -d chrome
   ```

## Platform Notes

- Android is the primary target for the complete experience.
- NFC scanning and NFC tag writing are not available on web builds.
- Reminder scheduling depends on notification permissions and exact alarm availability on Android.

## Project Structure

```
android/               # Android host project
lib/
  components/          # Reusable UI components
  database/            # Models, repositories, services, and dependency injection
  pages/               # App screens and feature flows
  utils/               # Styling, helpers, and shared constants
packages/nfc_manager/  # Local NFC package used by the app
web/                   # Web host files
```
