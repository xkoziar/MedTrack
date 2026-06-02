# MedTrack

A mobile and web application for tracking medication intake. Helps users remember their regular doses through reminders and simple usage logging. Optionally supports NFC tags attached to medication packaging for quick dose confirmation.

**Platforms:** Android, Web
**Authors:** René Češka, Ivan Yatskiv

## Features

### Core Functionality
- **Authentication** - User registration and login with Firebase Authentication
- **Home Dashboard** - View today's scheduled doses with status indicators
- **Medication Management** - Add, edit, and delete medications with custom dosing schedules
- **Medication Details** - View dosing schedule, history, and manage NFC tags
- **Dose History** - Browse complete medication intake history with filtering
- **Adherence Statistics** - Track medication adherence rates and missed doses
- **User Profile** - Manage account settings and notification preferences

### Advanced Features
- **NFC Integration** - Quick dose confirmation by tapping NFC tags on medication packaging
- **Smart Notifications** - Configurable reminders for scheduled doses
- **Cloud Sync** - Automatic data synchronization across devices using Firebase
- **Adherence Tracking** - Calculate and display medication adherence percentages
- **Virtual Dose Detection** - Automatically mark missed doses based on schedule

## Data Model

The application manages the following entities:

- **User** - Account information and notification settings
- **Medication** - Name, description, dosage, and schedule times
- **Dose Event** - Individual dose instances with timestamp and status
- **Notification Settings** - Reminder configuration and preferences
- **NFC Tag** - Tag identifiers linked to medications

## Getting Started

### Prerequisites

- Flutter SDK 3.9.2 or higher
- Android Studio or VS Code
- Firebase project with Firestore and Authentication enabled

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   flutter pub get
   ```

3. Configure Firebase:
   - Add `google-services.json` to `android/app/`
   - Add `firebase_options.dart` to `lib/`

4. Run the application:
   ```bash
   # For Android
   flutter run

   # For Web
   flutter run -d chrome
   ```
## Project Structure

```
lib/
  components/     # UI widgets
  database/       # Models, repositories, services
  pages/          # App screens
  utils/          # Helpers and constants
```
