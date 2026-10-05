# RetailIQ

### Retail Sales, Inventory & Business Intelligence Platform

RetailIQ is a Flutter-based retail management and business intelligence platform designed for small retail businesses.

It helps businesses record sales and supplier purchases, manage products and inventory, generate invoices, export business data, and understand performance through dashboards, analytics, and rule-based business insights.

> **Core idea:** Record the business transaction once — RetailIQ handles the rest.

---

## 📌 Project Overview

Small retail businesses often manage sales, inventory, purchases, and business analysis across separate systems or spreadsheets.

RetailIQ brings these day-to-day operations together in one application.

A completed transaction can automatically contribute to:

- Sales and revenue tracking
- Units sold
- Inventory updates
- Customer transaction history
- Payment-method analysis
- Product and category performance
- Profit calculations where cost data is available
- Business alerts and insights

The application uses **Flutter** for the user interface and **Firebase Authentication + Cloud Firestore** for authentication and persistent, user-scoped business data.

---

## ✨ Key Features

### 🧾 Billing & Checkout

- Create customer bills
- Support walk-in customers
- Add multiple products to a bill
- Adjust quantities
- Apply discounts
- Select payment method
- Review the bill before confirmation
- Save completed transactions
- Automatically reduce inventory after a successful sale

### 📦 Inventory Management

- Add, edit, and manage products
- Maintain SKU, category, supplier, purchase price, and selling price
- Track current stock
- Configure reorder levels
- Identify:
  - In Stock
  - Low Stock
  - Out of Stock
- Automatically update stock after sales and purchases

### 🏪 Supplier & Purchase Management

- Add and manage suppliers
- Record supplier purchases
- Add products and quantities received
- Track purchase cost
- Automatically increase inventory after a completed purchase
- Maintain purchase history

### 📊 Business Dashboard

The dashboard provides a quick overview of business activity, including:

- Total revenue
- Total bills
- Units sold
- Purchase activity
- Inventory value
- Stock status
- Business alerts
- Key insights

### 📈 Analytics

RetailIQ provides analytics for understanding business performance through:

- Sales trends
- Revenue
- Profit
- Units sold
- Product performance
- Category performance
- Payment-method analysis
- Customer aggregates
- Date-based filtering

### 💡 Business Insights

The application generates **rule-based business insights** from available business data.

Examples include:

- Revenue changes
- Low-stock alerts
- Out-of-stock alerts
- Category performance
- Profit-margin signals
- Customer spending patterns

> These insights are **rule-based analytics**, not AI/ML-generated predictions.

### 🧾 PDF Invoices

Generate digital invoices from completed bills.

Supported actions include:

- PDF preview
- Print
- Share
- Product details
- SKU
- Quantity
- Prices
- Discounts
- Final bill total

### 📤 CSV Data Export

Export business data for further analysis in Excel, Google Sheets, or other analytics tools.

Available exports include:

- Sales data
- Inventory data
- Customer aggregates

The exported data is structured for spreadsheet and data-analysis workflows.

### 📱 Responsive Interface

RetailIQ adapts its navigation and layout to different screen sizes:

| Device | Navigation |
|---|---|
| 📱 Mobile | Bottom Navigation Bar |
| 📲 Tablet | Navigation Rail |
| 🖥️ Desktop | Extended Sidebar |

The UI was designed with responsive breakpoints, consistent spacing, typography, cards, forms, loading states, empty states, and error states.

---

## 🔄 Core Business Workflow

```text
                    ┌──────────────────┐
                    │   RetailIQ App   │
                    └────────┬─────────┘
                             │
              ┌──────────────┴──────────────┐
              │                             │
        Customer Sale                 Supplier Purchase
              │                             │
              ▼                             ▼
        Create Bill                  Record Purchase
              │                             │
              ▼                             ▼
          Checkout                  Stock Increases
              │
              ▼
        Stock Decreases
              │
              └──────────────┬──────────────┘
                             ▼
                    Firestore Transaction Data
                             │
          ┌──────────────────┼──────────────────┐
          ▼                  ▼                  ▼
      Dashboard          Analytics          Insights
          │                  │                  │
          └──────────────────┼──────────────────┘
                             ▼
                    Business Understanding

```
## Example

If a customer purchases 2 units of a product:

Sale recorded
     ↓
Bill saved
     ↓
Revenue updated
     ↓
Units sold updated
     ↓
Inventory decreases by 2
     ↓
Customer transaction history updated
     ↓
Analytics reflect the sale

Similarly, when a supplier purchase is recorded:

Purchase recorded
     ↓
Purchase saved
     ↓
Inventory increases
     ↓
Purchase analytics updated

---

## 🛠️ Tech Stack

### Frontend

- Flutter
- Dart
- Material 3
- Responsive UI

### Backend & Database

- Firebase Authentication
- Cloud Firestore

### Document & Data Export

- pdf
- printing
- share_plus
- CSV generation

### Development & Tools

- VS Code
- Android Studio
- Git
- GitHub
- FlutterFire CLI
## 🏗️ Architectural Responsibilities

### Models

Represent business entities such as:

- Products
- Bills
- Purchases
- Suppliers
- Dashboard summaries
- Analytics summaries
- Insights
- Alerts

### Repositories

Handle Firestore-backed data access and business summaries.

### Services

Handle reusable application operations such as:

- Authentication
- PDF generation
- CSV export

### Features

Contain the screens and workflows for individual areas of the application.

---

## 🔐 Authentication & Data Security

RetailIQ uses **Firebase Authentication** with **Email/Password sign-in**.

Business data is stored in **Cloud Firestore** using user-scoped collections and security rules.

The application includes authenticated access for business data so users cannot access another user's protected records through the configured Firestore rules.

Firebase client configuration is included as required by the Flutter application. Server-side credentials and service-account private keys are not included in the repository.

---

## 🚀 Getting Started

### Prerequisites

Make sure you have:

- Flutter SDK
- Dart SDK compatible with the project's `pubspec.yaml`
- Android Studio or VS Code
- A connected Android device/emulator or supported desktop/web target
- A Firebase project

## 🚀 Getting Started

### 1. Clone the Repository

```bash
git clone https://github.com/Ayeshafirdous5/RetailIQ.git
cd RetailIQ
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

Create or use a Firebase project and configure the required Flutter platforms using FlutterFire.

Enable:

- Firebase Authentication
- Email/Password sign-in
- Cloud Firestore

If using your own Firebase project, regenerate the Flutter Firebase configuration for your project rather than using another developer's backend configuration.

### 4. Run the Application

```bash
flutter run
```

You can select a connected device, emulator, Chrome, or another supported Flutter target.

---

## 🧪 Testing & Validation

Run the automated test suite:

```bash
flutter test
```

Run static analysis:

```bash
flutter analyze
```

Build the web version:

```bash
flutter build web
```

The project has been tested across responsive layouts for:

- 360px
- 390px
- 430px
- 600px
- 768px
- 900px
- 1024px
- 1280px
- 1440px

The Android application was also tested on a physical Android device, including:

- Authentication
- Dashboard
- Billing
- Inventory
- Purchases
- PDF preview
- Printing
- Sharing
- CSV exports


## 📊 Data Flow

RetailIQ is designed around a **transaction-first approach**.

```text
                    BUSINESS TRANSACTION
                            │
             ┌──────────────┴──────────────┐
             │                             │
          Sales                        Purchases
             │                             │
             ▼                             ▼
        Billing Data                 Purchase Data
             │                             │
             └──────────────┬──────────────┘
                            ▼
                       Firestore
                            │
             ┌──────────────┼──────────────┐
             ▼              ▼              ▼
        Inventory       Analytics       Dashboard
             │              │              │
             └──────────────┼──────────────┘
                            ▼
                         Insights
```

This approach reduces duplicate manual data entry and allows operational transactions to become the source for business reporting.

---

## 🎯 Current Scope

RetailIQ currently focuses on the core retail workflow:

- Authentication
- Product management
- Inventory management
- Supplier management
- Purchase receiving
- Billing and checkout
- Dashboard
- Analytics
- Rule-based insights
- PDF invoices
- CSV exports
- Responsive UI

Customer information is currently represented through sales transactions and derived customer summaries/exports. A complete standalone customer CRUD/management module is not currently part of the completed scope.

Some additional sections in the **More** menu remain placeholders for future development.
## 🔮 Future Improvements

Potential future enhancements include:

- Dedicated customer management
- Advanced customer segmentation
- Sales forecasting
- More advanced inventory forecasting
- Additional dashboard visualizations
- Role-based staff permissions
- Production release configuration
- Cloud deployment
- Automated reporting
- Advanced business intelligence features

---

## 📸 Screenshots

Screenshots of the application will be added here as part of the portfolio documentation.

### Planned Sections

- Dashboard
- Billing
- Inventory
- Analytics
- Insights
- PDF Invoice
- Mobile responsive UI

---

## Author

**Ayesha Firdous**  
Computer Science Engineering Student

---

## 📄 License

This project is currently maintained as a **portfolio and academic project**.

