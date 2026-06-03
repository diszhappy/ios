# FinanceLens AI

100% offline AI-powered personal finance analyzer for iPhone.

## Privacy First

- All data stays on device
- No backend, no cloud, no analytics
- Works in Airplane Mode
- No third-party SDKs that transmit data

## Architecture

```
┌─────────────────────────────────────────────┐
│              SwiftUI Views                   │
├─────────────────────────────────────────────┤
│              ViewModels (MVVM)               │
├─────────────────────────────────────────────┤
│              Domain Services                 │
│  Categorization │ Forecasting │ AI Chat     │
├─────────────────────────────────────────────┤
│              Repositories                    │
├─────────────────────────────────────────────┤
│     SwiftData │ CoreML │ Vision │ NLP       │
└─────────────────────────────────────────────┘
```

## Tech Stack

| Layer     | Technology                                |
|-----------|-------------------------------------------|
| UI        | SwiftUI, Swift Charts                     |
| Storage   | SwiftData, SQLite FTS                     |
| AI        | CoreML, Natural Language, Foundation Models|
| OCR       | Vision Framework                          |
| PDF       | PDFKit                                    |
| Security  | Keychain, LocalAuthentication, CryptoKit  |

## Features

- Manual transaction entry + PDF/CSV/TXT import
- OCR from screenshots
- SMS bank message parsing (paste-based, fully offline)
- AI categorization with confidence scores (17 categories incl. Fruits)
- Merchant normalization
- Subscription detection
- Budget tracking with alerts
- Analytics with drilldown charts & tooltips
- Financial health score (0-100)
- Spending forecasts
- Local AI chat assistant
- Semantic search
- PDF/CSV report export

## Requirements

- macOS 14+ (Sonoma)
- Xcode 16+
- iOS 17.0+ deployment target
- No external dependencies — zero CocoaPods/SPM packages

## Build & Run

1. Open `FinanceLens.xcodeproj` in Xcode (it's at the project root level)
2. Select your development team: Target → Signing & Capabilities → Team
3. Choose an iOS 17+ simulator (e.g. iPhone 15 Pro)
4. Press `Cmd + R` to build and run

## Simulator Tips

| Feature | Simulator Setup |
|---------|----------------|
| Face ID | Simulator → Features → Face ID → Enrolled |
| Touch ID | Simulator → Features → Touch ID → Enrolled |
| File Import | Drag a PDF/CSV into the simulator Files app |

## Load Sample Data

On first launch the app is empty. To populate with test data, go to Settings and add a debug call:

```swift
SampleDataGenerator.generateSampleTransactions(context: context)
SampleDataGenerator.generateSampleBudgets(context: context)
```

Or import the included `sample_statement.csv` via the Import Statement screen.
