# FinanceLens AI — Architecture & Implementation Document

## 1. Executive Summary

FinanceLens AI is a 100% offline, privacy-first personal finance analyzer for iPhone. All data processing, AI inference, and storage occurs exclusively on-device. No backend servers, cloud services, or external APIs are used.

**Key Principles:**
- Zero data transmission outside the device
- Works in Airplane Mode
- No third-party analytics or tracking SDKs
- All AI/ML runs locally via CoreML and Natural Language framework

---

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                      Presentation Layer                       │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐       │
│  │Dashboard │ │Transact. │ │Analytics │ │ AI Chat  │ ...    │
│  │  View    │ │  View    │ │  View    │ │  View    │       │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       │
│       │             │             │             │             │
│  ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐ ┌────┴─────┐       │
│  │ViewModel │ │ViewModel │ │ViewModel │ │ViewModel │       │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘       │
├───────┼─────────────┼─────────────┼─────────────┼───────────┤
│       │         Domain Layer      │             │             │
│  ┌────┴─────────────┴─────────────┴─────────────┴─────┐     │
│  │              Domain Services                         │     │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐      │     │
│  │  │Categorize  │ │ Forecast   │ │  Chat AI   │      │     │
│  │  │  Engine    │ │  Engine    │ │  Engine    │      │     │
│  │  └────────────┘ └────────────┘ └────────────┘      │     │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐      │     │
│  │  │Subscription│ │  Health    │ │  Analytics │      │     │
│  │  │ Detection  │ │  Score     │ │  Engine    │      │     │
│  │  └────────────┘ └────────────┘ └────────────┘      │     │
│  │  ┌────────────┐ ┌────────────┐ ┌────────────┐      │     │
│  │  │  Merchant  │ │   OCR      │ │  Import    │      │     │
│  │  │Recognition │ │  Engine    │ │  Service   │      │     │
│  │  └────────────┘ └────────────┘ └────────────┘      │     │
│  └─────────────────────┬───────────────────────────────┘     │
├─────────────────────────┼────────────────────────────────────┤
│       │           Data Layer          │                       │
│  ┌────┴───────────────────────────────┴────┐                 │
│  │           Repositories                   │                 │
│  │  ┌──────────────┐  ┌──────────────┐     │                 │
│  │  │ Transaction  │  │   Budget     │     │                 │
│  │  │  Repository  │  │  Repository  │     │                 │
│  │  └──────┬───────┘  └──────┬───────┘     │                 │
│  └─────────┼─────────────────┼─────────────┘                 │
├─────────────┼─────────────────┼──────────────────────────────┤
│       │     Storage Layer     │                               │
│  ┌────┴───────────────────────┴────┐  ┌──────────────┐       │
│  │         SwiftData / SQLite       │  │   Keychain   │       │
│  │    (Encrypted on-device DB)      │  │  (Secrets)   │       │
│  └──────────────────────────────────┘  └──────────────┘       │
└─────────────────────────────────────────────────────────────┘
```

### 2.2 Layer Responsibilities

| Layer | Responsibility |
|-------|---------------|
| **Presentation** | SwiftUI views + ViewModels (MVVM) |
| **Domain** | Business logic engines, services |
| **Data** | Repository pattern, data access abstraction |
| **Storage** | SwiftData persistence, Keychain for secrets |

### 2.3 Design Patterns

| Pattern | Usage |
|---------|-------|
| MVVM | View ↔ ViewModel separation |
| Repository | Data access abstraction |
| Strategy | Forecasting algorithms |
| Coordinator | Navigation flow control |
| Protocol-Oriented | Parser abstraction, AI model abstraction |
| Observer | Combine + @Published for reactive UI |

---

## 3. Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Language | Swift 6 | Type safety, concurrency |
| UI | SwiftUI | Declarative UI |
| Storage | SwiftData | ORM over SQLite |
| Charts | Swift Charts | Data visualization |
| AI/NLP | Natural Language Framework | Semantic similarity, embeddings |
| ML | CoreML | On-device classification |
| OCR | Vision Framework | Text recognition from images |
| PDF | PDFKit | Statement parsing |
| Security | LocalAuthentication | Face ID / Touch ID |
| Crypto | CryptoKit | PIN hashing (SHA256) |
| Secrets | Keychain Services | Secure credential storage |
| Notifications | UserNotifications | Budget alerts |

---

## 4. Project Structure

```
FinanceLens/
├── App/
│   ├── FinanceLensApp.swift          # @main entry point
│   └── AppState.swift                # Global app state
├── Core/
│   ├── Navigation/
│   │   ├── AppCoordinator.swift      # Auth routing
│   │   └── MainTabView.swift         # Tab navigation
│   ├── Security/
│   │   ├── BiometricAuthManager.swift
│   │   ├── PINManager.swift
│   │   └── KeychainManager.swift
│   ├── DI/                           # Dependency injection
│   ├── Extensions/                   # Swift extensions
│   ├── Storage/                      # DB helpers
│   └── Theme/                        # Colors, fonts
├── Domain/
│   ├── Models/
│   │   ├── Transaction.swift
│   │   ├── Category.swift
│   │   ├── Budget.swift
│   │   ├── Subscription.swift
│   │   ├── Merchant.swift
│   │   ├── ChatModels.swift
│   │   └── Forecast.swift
│   ├── Repositories/
│   │   ├── TransactionRepository.swift
│   │   └── BudgetRepository.swift
│   └── Services/
│       ├── Import/
│       ├── OCR/
│       ├── Categorization/
│       ├── MerchantRecognition/
│       ├── Subscription/
│       ├── Analytics/
│       ├── HealthScore/
│       ├── Forecasting/
│       └── Chat/
├── Features/
│   ├── Authentication/
│   ├── Dashboard/
│   ├── Transactions/
│   ├── Import/
│   ├── Analytics/
│   ├── Budget/
│   ├── Subscriptions/
│   ├── Chat/
│   ├── Reports/
│   └── Settings/
├── Resources/
│   ├── SampleData/
│   └── MLModels/
└── Tests/
    ├── UnitTests/
    └── UITests/
```

---

## 5. Data Model Design

### 5.1 Entity Relationship Diagram

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│  Transaction │──────▶│   Category   │       │   Budget     │
│──────────────│       │──────────────│       │──────────────│
│ id: UUID     │       │ id: UUID     │       │ id: UUID     │
│ amount       │       │ name         │       │ categoryName │
│ currency     │       │ icon         │       │ amount       │
│ merchant     │       │ color        │       │ spent        │
│ normalized   │       │ isDefault    │       │ month        │
│ categoryName │       │ keywords[]   │       │ year         │
│ date         │       └──────────────┘       │ alertAt50    │
│ type         │                               │ alertAt80    │
│ paymentMethod│       ┌──────────────┐       │ alertAt100   │
│ notes        │──────▶│   Merchant   │       └──────────────┘
│ isRecurring  │       │──────────────│
│ confidence   │       │ id: UUID     │       ┌──────────────┐
│ source       │       │ name         │       │ Subscription │
│ balanceAfter │       │ normalized   │       │──────────────│
└──────────────┘       │ aliases[]    │       │ id: UUID     │
       │               │ categoryName │       │ name         │
       │               │ totalSpent   │       │ merchant     │
       ▼               └──────────────┘       │ amount       │
┌──────────────┐                               │ frequency    │
│ Subscription │◀──────────────────────────────│ startDate    │
└──────────────┘                               │ nextDueDate  │
                                               │ isActive     │
┌──────────────┐       ┌──────────────┐       └──────────────┘
│ ChatSession  │──────▶│ ChatMessage  │
│──────────────│       │──────────────│       ┌──────────────┐
│ id: UUID     │       │ id: UUID     │       │   Forecast   │
│ title        │       │ content      │       │──────────────│
│ createdAt    │       │ role         │       │ id: UUID     │
│ updatedAt    │       │ createdAt    │       │ type         │
└──────────────┘       │ sources[]    │       │ categoryName │
                       └──────────────┘       │ predicted    │
                                               │ confidence   │
┌──────────────┐                               │ periodStart  │
│ AppSettings  │                               │ periodEnd    │
│──────────────│                               └──────────────┘
│ id: UUID     │
│ currency     │
│ appLock      │
│ biometric    │
│ pinEnabled   │
│ theme        │
└──────────────┘
```

### 5.2 Enumerations

| Enum | Values |
|------|--------|
| `TransactionType` | debit, credit, upi, card, cash, bankTransfer, subscription |
| `PaymentMethod` | cash, card, upi, netBanking, wallet, bankTransfer, other |
| `TransactionSource` | manual, pdfImport, csvImport, txtImport, ocr |
| `SubscriptionFrequency` | weekly, monthly, quarterly, yearly |
| `ForecastType` | monthlySpending, categorySpending, savings, subscription |
| `MessageRole` | user, assistant, system |
| `HealthGrade` | excellent, good, fair, poor, critical |

### 5.3 Default Categories (17)

| Category | Icon | Keywords |
|----------|------|----------|
| Food | fork.knife | restaurant, cafe, swiggy, zomato |
| Groceries | cart.fill | grocery, bigbasket, blinkit, dmart |
| Fruits | leaf.fill | fruit, mango, apple, banana, organic, juice |
| Fuel | fuelpump.fill | petrol, diesel, hp, iocl |
| Utilities | bolt.fill | electricity, water, internet, phone |
| Travel | airplane | flight, hotel, uber, ola, irctc |
| Shopping | bag.fill | amazon, flipkart, myntra |
| Entertainment | film.fill | netflix, spotify, movie, hotstar |
| Medical | cross.case.fill | hospital, pharmacy, doctor |
| Education | book.fill | school, college, course |
| Investment | chart.line.uptrend | mutual fund, stock, zerodha, groww |
| Insurance | shield.fill | insurance, lic, policy |
| EMI | creditcard.fill | emi, loan, installment |
| Subscription | repeat | subscription, membership |
| Rent | house.fill | rent, lease, housing |
| Salary | banknote.fill | salary, income |
| Miscellaneous | ellipsis.circle.fill | (fallback) |

---

## 6. Module Implementation Details

### 6.1 Authentication & Security Module

**Components:** `BiometricAuthManager`, `PINManager`, `KeychainManager`, `LockScreenView`

**Flow:**
```
App Launch
    │
    ▼
┌─ appLockEnabled? ─┐
│ YES               │ NO
▼                   ▼
LockScreen      MainTabView
    │
    ├── onAppear: checkAvailability() (one-time, non-blocking)
    │
    ├── .task: trigger biometric prompt (async, off render path)
    │       │
    │       ├── Success → Unlock → MainTabView
    │       └── Failure → Show PIN option
    │
    └── PIN Entry
            │
            ├── SHA256(input) == stored hash → Unlock
            └── Mismatch → Error
```

**Performance Design:**
- `LAContext` is **never** stored as an instance property — created fresh per call
- Biometric availability is checked **once** via `onAppear` → stored as `@Published var isAvailable`
- The availability check is **not** a computed property — avoids calling `canEvaluatePolicy()` on every SwiftUI body re-render (that system call blocks for 50-200ms)
- Biometric prompt triggers in `.task` modifier (runs **after** view appears, not during layout)

**Security Measures:**
- PIN stored as SHA256 hash in Keychain (never plaintext)
- Keychain items use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`
- No biometric data stored by app (delegated to Secure Enclave)
- Auto-lock on app background (via AppState)

---

### 6.2 Statement Import Engine

**Components:** `StatementParser` protocol, `PDFStatementParser`, `CSVStatementParser`, `TXTStatementParser`, `StatementImportService`

**Architecture:**
```
┌─────────────────────────────────────────┐
│         StatementImportService           │
│  ┌─────────────────────────────────┐    │
│  │   File Extension Router          │    │
│  │   .pdf → PDFStatementParser      │    │
│  │   .csv → CSVStatementParser      │    │
│  │   .txt → TXTStatementParser      │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────┐
│     StatementParser Protocol             │
│  func parse(data: Data) async throws     │
│       -> [ParsedTransaction]             │
└─────────────────────────────────────────┘
```

**PDF Parser Strategy:**
1. Extract full text from all pages via PDFKit
2. Split into lines
3. For each line: extract date (regex), amounts (regex), description (remainder)
4. Determine debit/credit from context clues

**CSV Parser Strategy:**
1. Parse header row
2. Auto-detect column mapping (date, description, amount, balance)
3. Handle quoted fields, multiple delimiters
4. Parse each row into `ParsedTransaction`

**Supported Date Formats:** `dd/MM/yyyy`, `dd-MM-yyyy`, `yyyy-MM-dd`, `dd MMM yyyy`, `MM/dd/yyyy`

---

### 6.3 OCR Engine

**Components:** `OCREngine`

**Pipeline:**
```
UIImage → CGImage → VNRecognizeTextRequest → Raw Text → Transaction Extraction
```

**Configuration:**
- Recognition level: `.accurate`
- Languages: `["en-IN", "en-US"]`
- Language correction: enabled

**Extraction Logic:**
- Amount: regex `₹?\s?[\d,]+\.?\d{0,2}`
- Date: regex `\d{1,2}[/-]\d{1,2}[/-]\d{2,4}`
- Reference: regex `[A-Z]{2,4}\d{8,20}`
- Merchant: lines without numbers (>3 chars)

---

### 6.4 Categorization Engine

**Components:** `CategorizationEngine`

**4-Tier Classification Pipeline:**
```
Input (merchant + description)
    │
    ▼
┌─ Tier 1: Merchant Exact Match ─┐  confidence: 0.95
│  "swiggy" → Food               │
└─────────────────────────────────┘
    │ miss
    ▼
┌─ Tier 2: Keyword Matching ─────┐  confidence: 0.85
│  contains("restaurant") → Food  │
└─────────────────────────────────┘
    │ miss
    ▼
┌─ Tier 3: Regex Patterns ───────┐  confidence: 0.80
│  /emi|loan/ → EMI              │
└─────────────────────────────────┘
    │ miss
    ▼
┌─ Tier 4: NLP Semantic Match ───┐  confidence: 0.70
│  NLEmbedding word distance      │
│  to category seed words          │
└─────────────────────────────────┘
    │ miss
    ▼
┌─ Fallback ─────────────────────┐  confidence: 0.50
│  "Miscellaneous"                │
└─────────────────────────────────┘
```

**Output:** `CategorizationResult(category, confidence, method)`

---

### 6.5 Merchant Recognition Engine

**Components:** `MerchantRecognitionEngine`

**Normalization Process:**
```
Raw Input: "AMZN MKTP IN*2X4Y7Z"
    │
    ▼ lowercase + strip special chars
"amzn mktp in 2x4y7z"
    │
    ▼ alias database lookup (partial match)
"amzn" found → "Amazon"
    │
    ▼
Output: "Amazon"
```

**Alias Database:** 35+ merchants with multiple aliases each (e.g., Amazon has 6 aliases)

---

### 6.6 Subscription Detection Engine

**Components:** `SubscriptionDetectionEngine`

**Detection Algorithm:**
```
1. Group transactions by normalized merchant
2. Filter: merchant must have ≥ 2 transactions
3. Sort by date, calculate intervals between transactions
4. Detect frequency from average interval:
   - 5-9 days → weekly
   - 25-35 days → monthly
   - 80-100 days → quarterly
   - 350-380 days → yearly
5. Calculate confidence score:
   - Amount consistency (40%): low variance = high score
   - Frequency consistency (40%): close to expected interval
   - Count bonus (20%): more occurrences = more confident
6. Threshold: confidence > 0.6
```

---

### 6.7 Analytics Engine

**Components:** `AnalyticsEngine`

**Capabilities:**

| Method | Output |
|--------|--------|
| `spendingAnalytics(from:to:)` | Total expense, income, savings, daily avg, count |
| `categoryAnalytics(from:to:)` | Per-category amount, %, count, trend vs previous |
| `merchantAnalytics(from:to:)` | Top merchants by spend, count, avg, last date |
| `cashFlowAnalytics(from:to:)` | Income, expense, net flow, savings rate |
| `monthOverMonth()` | Current vs previous period comparison |

**Trend Calculation:** Compares current period spending to equivalent previous period, returns percentage change.

---

### 6.8 Financial Health Score

**Components:** `FinancialHealthEngine`

**Scoring Formula (0-100):**

| Factor | Weight | Calculation |
|--------|--------|-------------|
| Savings Rate | 25 pts | `min(25, savingsRate × 100)` |
| Spending Consistency | 20 pts | `20 × (1 - coefficientOfVariation)` |
| Budget Adherence | 25 pts | `25 × (adherentBudgets / totalBudgets)` |
| Subscription Burden | 15 pts | `15 × (1 - subscriptionRatio × 2)` |
| Income Stability | 15 pts | `15 × (1 - incomeCV)` |

**Grading:**
- 80-100: Excellent
- 60-79: Good
- 40-59: Fair
- 20-39: Poor
- 0-19: Critical

---

### 6.9 Forecasting Engine

**Components:** `ForecastingEngine`, `MovingAverageForecast`, `LinearRegressionForecast`

**Strategy Pattern:**
```
┌─────────────────────────────────┐
│    ForecastingStrategy Protocol   │
│  predict(values, periodsAhead)   │
│       → ForecastResult           │
└─────────────────────────────────┘
         ▲              ▲
         │              │
┌────────┴───┐  ┌──────┴────────┐
│ Moving Avg │  │ Linear Regr.  │
│ (window=3) │  │ (least squares)│
└────────────┘  └───────────────┘
```

**Best-of-Strategies:** Both strategies run; the one with higher confidence wins.

**Linear Regression Confidence:** R² (coefficient of determination)

**Forecast Types:**
- Monthly spending (next month)
- End-of-month projection (daily rate × remaining days)
- Category-specific spending
- Savings forecast

---

### 6.10 AI Financial Chat Assistant

**Components:** `FinancialQueryInterpreter`, `FinancialContextBuilder`, `FinancialChatEngine`

**RAG-like Pipeline (fully local):**
```
User Query: "How much did I spend on food last month?"
    │
    ▼
┌─ Query Interpreter ─────────────────────────┐
│  NLP keyword detection + entity extraction   │
│  → FinancialQueryType.spending(              │
│      category: "Food",                       │
│      period: lastMonth                       │
│    )                                         │
└──────────────────────────────────────────────┘
    │
    ▼
┌─ Context Builder ───────────────────────────┐
│  Queries TransactionRepository               │
│  Builds structured text context:             │
│  "Category 'Food': ₹2,709                   │
│   Transactions: 4                            │
│   - Swiggy: ₹520 on 27 Apr                  │
│   - Zomato: ₹750 on 15 Apr..."              │
└──────────────────────────────────────────────┘
    │
    ▼
┌─ Response Generator ────────────────────────┐
│  Formats context into natural language       │
│  Adds source citations                       │
└──────────────────────────────────────────────┘
    │
    ▼
ChatMessage(role: .assistant, content: "...", sources: ["Local Data"])
```

**Supported Query Types:**
- Spending (by category, merchant, period)
- Comparisons (period vs period)
- Subscriptions
- Budget status
- Forecasts
- Health score
- Search (with amount thresholds)
- General

---

### 6.11 SMS Transaction Parser

**Components:** `SMSParserEngine`, `SMSMonitorView`, `EditSMSRecordView`

**iOS Constraint:** iOS does not allow direct SMS reading. The implementation uses a paste-based approach.

**Workflow:**
```
User copies bank SMS → Pastes in app → Parser extracts data → User reviews/edits → Confirms → Saved as Transaction
```

**Parser Regex Patterns:**

| Field | Patterns |
|-------|----------|
| Debit amount | `debited.*Rs.X`, `spent Rs.X`, `paid Rs.X`, `withdrawn Rs.X` |
| Credit amount | `credited.*Rs.X`, `received Rs.X`, `refund.*Rs.X` |
| Merchant | text after `at`, `to`, `from`, `towards` |
| Account | `a/c.*XXXX` (last 4 digits) |
| Reference | `ref/txn/utr/rrn: XXXXX` |

**Edit Capability:** Users can tap any parsed record to correct amount, merchant, type, and date before confirming.

**Data Flow:**
```
ParsedSMS (temporary, in-memory)
    │
    ▼ [User confirms]
Transaction (persisted in SwiftData)
```

---

## 7. UI Architecture

### 7.1 Navigation Flow

```
App Launch
    │
    ▼
AppCoordinator
    │
    ├── [Lock Enabled] → LockScreenView
    │                         │
    │                         ▼ (unlock)
    │
    └── MainTabView
            │
            ├── Tab 0: Dashboard
            │     └── NavigationStack
            │           ├── DashboardView
            │           └── ImportStatementView (sheet)
            │
            ├── Tab 1: Transactions
            │     └── NavigationStack
            │           ├── TransactionListView
            │           └── AddTransactionView (sheet)
            │
            ├── Tab 2: Analytics
            │     └── NavigationStack
            │           └── AnalyticsDashboardView
            │
            ├── Tab 3: AI Chat
            │     └── NavigationStack
            │           └── ChatView
            │
            └── Tab 4: Settings
                  └── NavigationStack
                        ├── SettingsView
                        ├── BudgetView (push)
                        ├── ImportStatementView (push)
                        └── ReportsView (push)
```

### 7.2 Screen Inventory

| # | Screen | Purpose |
|---|--------|---------|
| 1 | LockScreen | Biometric + PIN authentication |
| 2 | Dashboard | Financial overview, health score, drilldown pie chart |
| 3 | TransactionList | Searchable list with swipe-to-delete |
| 4 | AddTransaction | Form for manual entry |
| 5 | ImportStatement | File picker for PDF/CSV/TXT |
| 6 | AnalyticsDashboard | Charts with selection tooltips, top merchants |
| 7 | BudgetView | Category budgets with progress bars |
| 8 | AddBudget | Category + amount form |
| 9 | ChatView | AI assistant with bubble UI |
| 10 | ReportsView | Date range + format picker + export |
| 11 | SettingsView | Security, data, about |
| 12 | SMSMonitorView | Paste SMS, parse, edit, confirm, save |

### 7.3 Design System

- **Layout:** Card-based design with `RoundedRectangle(cornerRadius: 12)`
- **Colors:** System adaptive (supports Dark Mode automatically)
- **Typography:** Dynamic Type via system fonts
- **Charts:** Swift Charts (BarMark, SectorMark)
- **Accessibility:** VoiceOver labels, Dynamic Type, sufficient contrast

---

## 8. Security Architecture

### 8.1 Threat Model

| Threat | Mitigation |
|--------|-----------|
| Unauthorized device access | Face ID / Touch ID / PIN lock |
| Data extraction from backup | `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` |
| PIN brute force | SHA256 hashing (no rate limiting needed — local only) |
| Memory dump | No secrets held in memory longer than needed |
| Network exfiltration | Zero network calls in entire codebase |
| Third-party SDK leaks | No third-party SDKs included |

### 8.2 Data Protection

```
┌─────────────────────────────────────────┐
│           iOS Data Protection            │
│  (Hardware encryption at rest)           │
├─────────────────────────────────────────┤
│  SwiftData DB    │  Keychain            │
│  ─────────────   │  ────────            │
│  Transactions    │  PIN Hash            │
│  Budgets         │  Encryption Key      │
│  Categories      │                      │
│  Chat History    │                      │
└─────────────────────────────────────────┘
```

### 8.3 Privacy Guarantees

- ✅ No `NSAppTransportSecurity` exceptions needed
- ✅ No network entitlements required
- ✅ No analytics frameworks
- ✅ No crash reporting that uploads data
- ✅ No advertising identifiers
- ✅ No location tracking
- ✅ No contacts/calendar/photos access (except user-initiated file import)

---

## 9. Testing Strategy

### 9.1 Test Pyramid

```
        ┌───────────┐
        │  UI Tests │  (SwiftUI previews + XCUITest)
        ├───────────┤
        │Integration│  (SwiftData in-memory + services)
        ├───────────┤
        │Unit Tests │  (Engines, parsers, algorithms)
        └───────────┘
```

### 9.2 Unit Test Coverage

| Module | Test Cases |
|--------|-----------|
| CategorizationEngine | Merchant match, keyword match, fallback, custom rules |
| MerchantRecognition | Normalization, alias lookup, unknown merchants |
| SubscriptionDetection | Monthly detection, irregular rejection |
| Forecasting | Moving average accuracy, linear regression, flat data |
| PINManager | Set/verify/hasPin lifecycle |
| QueryInterpreter | Spending/subscription/forecast/health query classification |
| CSVParser | Column detection, quoted fields, multi-format dates |

### 9.3 Sample Data

- `sample_statement.csv`: 15 transactions across multiple categories
- `SampleDataGenerator`: 35 programmatic transactions spanning 3 months with realistic merchants, amounts, and categories

---

## 10. Performance Considerations

| Concern | Approach |
|---------|----------|
| Large transaction sets | SwiftData lazy loading, pagination in views |
| PDF parsing | Async processing, progress indicator |
| OCR | Background thread via async/await |
| Analytics computation | On-demand calculation, not pre-computed |
| Chart rendering | Limit to top 5-8 categories |
| Memory | No in-memory caching of full dataset |

---

## 11. Future Enhancements

| Feature | Approach |
|---------|----------|
| Apple Foundation Models | Abstraction layer ready; swap NLP engine when available |
| CoreML custom model | Train transaction classifier, place in `Resources/MLModels/` |
| iCloud Sync (opt-in) | SwiftData supports CloudKit; add as user preference |
| Widgets | WidgetKit extension for dashboard summary |
| Shortcuts | App Intents for "Show spending" queries |
| Apple Watch | WatchKit companion for quick balance view |
| Open Banking | Account Aggregator API integration (future) |

---

## 12. Build & Run

### Requirements
- macOS 14+ (Sonoma)
- Xcode 16+
- iOS 17.0+ deployment target
- No external dependencies (zero CocoaPods/SPM packages)

### Project File
The `FinanceLens.xcodeproj` is located at the root:
```
ios/
├── FinanceLens.xcodeproj/    ← Open this
└── FinanceLens/              ← Source code
```

### Steps
1. Open `FinanceLens.xcodeproj` in Xcode
2. Select your development team: Target → Signing & Capabilities → Team
3. Select an iOS 17+ simulator (e.g. iPhone 15 Pro) or a physical device
4. Press `Cmd + R` to build and run
5. (Optional) Load sample data — see below

### Loading Sample Data
On first launch the app has no transactions. Options:
- **Programmatic:** Call `SampleDataGenerator.generateSampleTransactions(context:)` and `SampleDataGenerator.generateSampleBudgets(context:)` from a debug button in Settings
- **File Import:** Use the Import Statement screen to load `Resources/SampleData/sample_statement.csv`
- **Manual Entry:** Add transactions via the + button on Transactions tab

### Simulator Configuration

| Feature | How to Enable |
|---------|---------------|
| Face ID | Simulator menu → Features → Face ID → Enrolled |
| Touch ID | Simulator menu → Features → Touch ID → Enrolled |
| Trigger Auth | Simulator → Features → Face ID → Matching/Non-matching Face |
| File Import | Drag PDF/CSV onto simulator to add to Files app |

### Entitlements (auto-configured)
- `NSFaceIDUsageDescription` — "Unlock FinanceLens with Face ID"
- Camera usage (for OCR screenshots) — add when implementing photo picker

### Troubleshooting

| Issue | Fix |
|-------|-----|
| Red files in navigator | Right-click project → Add Files → select `FinanceLens/` folder |
| "No such module" errors | Clean Build Folder (`Cmd + Shift + K`) then rebuild |
| SwiftData crash | Ensure simulator runs iOS 17.0+ |
| Face ID not prompting | Simulator → Features → Face ID → Enrolled |
| App hangs on lock screen | Verify you have the latest `BiometricAuthManager.swift` (availability check moved to `onAppear`) |

---

## 13. File Manifest

| File | Lines | Purpose |
|------|-------|---------|
| `FinanceLensApp.swift` | 40 | App entry, ModelContainer setup |
| `AppState.swift` | 24 | Global unlock/lock state |
| `AppCoordinator.swift` | 17 | Auth routing |
| `MainTabView.swift` | 33 | 5-tab navigation |
| `BiometricAuthManager.swift` | 43 | Face ID / Touch ID |
| `PINManager.swift` | 28 | PIN hash/verify |
| `KeychainManager.swift` | 49 | Secure storage |
| `Transaction.swift` | 77 | Core data model |
| `Category.swift` | 42 | 16 default categories |
| `Budget.swift` | 42 | Budget with utilization |
| `Subscription.swift` | 54 | Recurring payment model |
| `Merchant.swift` | 24 | Merchant normalization model |
| `ChatModels.swift` | 44 | Session + Message |
| `Forecast.swift` | 54 | Prediction + Settings |
| `TransactionRepository.swift` | 98 | CRUD + aggregations |
| `BudgetRepository.swift` | 37 | Budget CRUD |
| `PDFStatementParser.swift` | 134 | PDF text extraction |
| `CSVStatementParser.swift` | 93 | CSV column detection |
| `TXTParserAndImportService.swift` | 57 | TXT + service orchestrator |
| `OCREngine.swift` | 141 | Vision text recognition |
| `CategorizationEngine.swift` | 143 | 4-tier classification |
| `MerchantRecognitionEngine.swift` | 94 | Alias normalization |
| `SubscriptionDetectionEngine.swift` | 110 | Recurring detection |
| `AnalyticsEngine.swift` | 163 | Multi-dimensional analytics |
| `FinancialHealthEngine.swift` | 146 | 0-100 health score |
| `ForecastingEngine.swift` | 163 | MA + LR predictions |
| `FinancialChatEngine.swift` | 343 | Query → Context → Response |
| `DashboardView.swift` | 166 | Home screen |
| `TransactionListView.swift` | 64 | Transaction list |
| `AddTransactionView.swift` | 83 | Manual entry form |
| `AnalyticsDashboardView.swift` | 103 | Charts + stats |
| `BudgetView.swift` | 127 | Budget management |
| `ChatView.swift` | 133 | AI chat interface |
| `ReportsView.swift` | 186 | PDF/CSV export |
| `LockScreenView.swift` | 101 | Auth screen |
| `ImportStatementView.swift` | 110 | File import |
| `SettingsView.swift` | 51 | App settings |
| `EngineTests.swift` | 182 | Unit tests |
| `SampleDataGenerator.swift` | 97 | Test data |
| `SMSParserEngine.swift` | 133 | Bank SMS parsing (regex-based) |
| `SMSMonitorView.swift` | 202 | SMS paste UI + edit + confirm |

**Total:** ~4,200 lines of production Swift code across 43 files.

---

*Document generated: June 2026*
*Version: 1.1*
*Last updated: 2 June 2026 — Added SMS parser, Fruits category, drilldown charts, tooltips*
