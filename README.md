# RetailIQ

RetailIQ is a Flutter retail operations app for recording sales, managing stock and purchases, and understanding business performance. It combines day-to-day workflows with responsive analytics, rule-based insights, invoice PDFs, and CSV exports.

**Project:** [github.com/Ayeshafirdous5/RetailIQ](https://github.com/Ayeshafirdous5/RetailIQ)

## Overview

The app is designed for a small retail business: staff can sign in, record customer sales, maintain product and supplier records, track purchases, and review sales and inventory signals. Firebase Authentication and Cloud Firestore provide authentication and persistent, user-scoped business data.

## Features and workflows

- **Billing:** create and check out sales, apply discounts, record payment methods, and review saved bills.
- **PDF invoices:** generate invoice PDFs for printing or sharing from bill details.
- **Purchases and suppliers:** record supplier purchases and maintain supplier records.
- **Inventory:** create and edit products, track stock and reorder levels, and review low- and out-of-stock items.
- **Analytics:** review sales, profit, products, categories, payment methods, and customer aggregates, with date filters.
- **Business insights:** view rule-based sales signals and inventory or profit-margin alerts. These are not AI/ML-generated.
- **CSV export:** export sales line items, current inventory (including available supplier details), and customer aggregates for use in spreadsheet and analysis tools.
- **Responsive navigation:** use a bottom navigation bar on mobile, a navigation rail on tablet, and an extended sidebar on desktop.

Customer names and IDs can be captured with sales and appear in analytics and customer exports. A complete standalone customer-management module is not currently included. The More menu also contains sections that are placeholders rather than completed workflows.

## Tech stack

- Flutter and Dart
- Firebase Authentication
- Cloud Firestore
- `pdf` and `printing` for invoice generation and print/share flows
- `share_plus` for sharing exported CSV files

## Project structure

```text
lib/
  core/           Shared theme, layout breakpoints, spacing, and widgets
  features/       Authentication, app shell, billing, inventory, purchases,
                  suppliers, dashboard, analytics, insights, and More screens
  models/         Business and summary data models
  repositories/   Firestore-backed data access and feature summaries
  services/       Authentication, PDF invoice, and CSV export services
  main.dart       Firebase initialization and app entry point
test/             Flutter unit and widget tests
```

## Setup

### Prerequisites

- Flutter SDK with a Dart SDK compatible with the `^3.5.3` constraint in `pubspec.yaml`
- A Firebase project with **Email/Password Authentication** enabled and Cloud Firestore configured
- A supported device, emulator, or desktop target

### Firebase configuration

The repository contains Firebase client configuration used by the app. To connect a different Firebase project, configure its Flutter apps with the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup) and update the generated platform configuration files. Enable Email/Password sign-in and create/configure Firestore for the app's user-scoped data. Do not add service-account credentials to the client app or repository.

The current `DefaultFirebaseOptions` does not configure Linux, so Firebase-backed app startup is not available on that target without additional platform configuration.

### Run

From the repository root:

```sh
flutter pub get
flutter run
```

Select a connected device or emulator if Flutter does not choose one automatically.

## Testing and validation

Run the automated tests and static analysis from the repository root:

```sh
flutter test
flutter analyze
```

## Scope

RetailIQ is a portfolio project demonstrating retail workflows and reporting. Customer data is represented through bills and derived summaries/exports rather than a standalone customer CRUD feature. Some More-menu destinations remain placeholders, and platform-specific Firebase setup may be needed for a developer's own Firebase project or target.
