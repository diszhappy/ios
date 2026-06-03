# FinanceLens AI — Code Documentation & Design

## Part 1: Code Overview & Application Flow

### 1.1 What This App Does

FinanceLens AI is a 100% offline personal finance app for iPhone. It tracks spending, categorizes transactions using AI, detects subscriptions, forecasts expenses, and lets users chat with their financial data — all without any internet connection.

### 1.2 Code Organization

| Folder | Purpose | Key Files |
|--------|---------|-----------|
| `App/` | Entry point & global state | `FinanceLensApp.swift`, `AppState.swift` |
| `Core/Navigation/` | App routing | `AppCoordinator.swift`, `MainTabView.swift` |
| `Core/Security/` | Auth & encryption | `BiometricAuthManager.swift`, `PINManager.swift`, `KeychainManager.swift` |
| `Domain/Models/` | SwiftData entities | `Transaction.swift`, `Budget.swift`, `Category.swift`, etc. |
| `Domain/Repositories/` | Data access layer | `TransactionRepository.swift`, `BudgetRepository.swift` |
| `Domain/Services/` | Business logic engines | 9 service modules |
| `Features/` | UI screens (MVVM) | Views + ViewModels per feature |
| `Resources/` | Sample data & ML models | `SampleDataGenerator.swift`, `sample_statement.csv` |

### 1.3 Application Flow

```mermaid
flowchart TD
    A[App Launch] --> B{App Lock Enabled?}
    B -->|No| D[MainTabView]
    B -->|Yes| C[LockScreenView]
    C --> E{Biometric Available?}
    E -->|Yes| F[Face ID / Touch ID Prompt]
    E -->|No| G[PIN Entry]
    F -->|Success| D
    F -->|Fail| G
    G -->|Correct| D
    G -->|Wrong| H[Error Message]
    H --> G
    G --> I[Forgot PIN?]
    I --> J[Biometric Verify]
    J -->|Success| K[Set New PIN]
    J -->|Fail| L[Math Captcha]
    L -->|Correct| K
    K --> G

    D --> T1[Dashboard Tab]
    D --> T2[Transactions Tab]
    D --> T3[Analytics Tab]
    D --> T4[AI Chat Tab]
    D --> T5[Settings Tab]
```

### 1.4 Transaction Lifecycle Flow

```mermaid
flowchart LR
    subgraph Input Sources
        M[Manual Entry]
        P[PDF Import]
        C[CSV Import]
        T[TXT Import]
        O[OCR Screenshot]
        S[SMS Paste]
    end

    subgraph Processing Pipeline
        MR[Merchant Recognition]
        CAT[Categorization Engine]
        SUB[Subscription Detection]
    end

    subgraph Storage
        DB[(SwiftData / SQLite)]
    end

    M --> MR
    P --> MR
    C --> MR
    T --> MR
    O --> MR
    S --> MR
    MR --> CAT
    CAT --> DB
    DB --> SUB
```

### 1.5 How Each File Works

#### App Layer

**`FinanceLensApp.swift`** — The `@main` entry point. Creates a `ModelContainer` with all SwiftData schemas, injects it into the view hierarchy via `.modelContainer()`.

**`AppState.swift`** — An `ObservableObject` holding `isUnlocked` and `isFirstLaunch`. Controls whether the app shows the lock screen or main content.

#### Navigation Layer

**`AppCoordinator.swift`** — Reads `appLockEnabled` from `@AppStorage`. If lock is on and app isn't unlocked, shows `LockScreenView`; otherwise shows `MainTabView`.

**`MainTabView.swift`** — 5-tab `TabView`: Dashboard, Transactions, Analytics, AI Chat, Settings.

#### Security Layer

**`BiometricAuthManager.swift`** — Wraps `LAContext`. Calls `checkAvailability()` once on appear (not during render to avoid UI blocking). `authenticate()` is async, creates a fresh `LAContext` per call.

**`PINManager.swift`** — Static methods: `setPin()` hashes with SHA256 and stores in Keychain; `verifyPin()` compares hashes; `hasPin()` checks existence.

**`KeychainManager.swift`** — Generic Keychain wrapper with `save/get/delete` for string values. Uses `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`.

#### Domain Models

**`Transaction.swift`** — Core entity: amount, merchant, normalizedMerchant, categoryName, date, type, paymentMethod, notes, confidence, source. Has relationships to Category, Merchant, Subscription.

**`Category.swift`** — 17 default categories with name, icon (SF Symbol), color (hex), and keyword arrays for auto-categorization.

**`Budget.swift`** — Monthly category budgets with spent tracking, utilization calculation, and alert flags at 50/80/100%.

**`Subscription.swift`** — Detected recurring payments with frequency enum, monthly equivalent calculation, and next due date.

#### Repository Layer

**`TransactionRepository.swift`** — CRUD + query methods: `fetchAll` (with optional date/category/merchant/type filters), `totalSpending`, `totalIncome`, `spendingByCategory`, `topMerchants`.

**`BudgetRepository.swift`** — CRUD for budgets, filtered by month/year. `updateSpent()` syncs actual spending from transactions.

#### Service Engines

Each engine is a pure logic class with no UI dependencies:

| Engine | Input | Output |
|--------|-------|--------|
| `PDFStatementParser` | PDF Data | `[ParsedTransaction]` |
| `CSVStatementParser` | CSV Data | `[ParsedTransaction]` |
| `OCREngine` | UIImage | `[OCRResult]` |
| `SMSParserEngine` | String (SMS text) | `ParsedSMS` |
| `CategorizationEngine` | merchant + description | `CategorizationResult` (category, confidence, method) |
| `MerchantRecognitionEngine` | raw merchant string | normalized name |
| `SubscriptionDetectionEngine` | `[Transaction]` | `[DetectedSubscription]` |
| `AnalyticsEngine` | date range | spending/category/merchant/cashflow analytics |
| `FinancialHealthEngine` | all data | score 0-100 with breakdown |
| `ForecastingEngine` | historical values | predicted amounts with confidence |
| `FinancialChatEngine` | user query | structured response with sources |

---

## Part 2: Data Flow Diagrams

### 2.1 Statement Import Data Flow

```mermaid
flowchart TD
    A[User selects file] --> B[iOS File Picker]
    B --> C{File Extension?}
    C -->|.pdf| D[PDFStatementParser]
    C -->|.csv| E[CSVStatementParser]
    C -->|.txt| F[TXTStatementParser]

    D --> G[Extract text via PDFKit]
    G --> H[Regex: dates + amounts]
    H --> I[ParsedTransaction array]

    E --> J[Detect columns from header]
    J --> K[Parse rows]
    K --> I

    F --> L{Tab/Pipe delimited?}
    L -->|Yes| M[Normalize to CSV]
    M --> E
    L -->|No| D

    I --> N[Show count to user]
    N --> O[User taps Save All]
    O --> P[MerchantRecognitionEngine]
    P --> Q[CategorizationEngine]
    Q --> R[Insert into SwiftData]
```

### 2.2 Categorization Data Flow

```mermaid
flowchart TD
    A[Transaction merchant + description] --> B[Tier 1: Merchant Exact Match]
    B -->|Hit| C[Return category - confidence 0.95]
    B -->|Miss| D[Tier 2: Keyword Match]
    D -->|Hit| E[Return category - confidence 0.85]
    D -->|Miss| F[Tier 3: Regex Patterns]
    F -->|Hit| G[Return category - confidence 0.80]
    F -->|Miss| H[Tier 4: NLP Semantic via NLEmbedding]
    H -->|Score > 0.3| I[Return category - confidence 0.70]
    H -->|Score <= 0.3| J[Return Miscellaneous - confidence 0.50]
```

### 2.3 AI Chat Data Flow

```mermaid
sequenceDiagram
    participant U as User
    participant CV as ChatView
    participant CE as ChatEngine
    participant QI as QueryInterpreter
    participant CB as ContextBuilder
    participant TR as TransactionRepo

    U->>CV: Types "How much on food last month?"
    CV->>CE: sendMessage(text)
    CE->>QI: interpret(text)
    QI-->>CE: .spending(category: "Food", period: lastMonth)
    CE->>CB: buildContext(for: queryType)
    CB->>TR: fetchAll(from: lastMonth, category: "Food")
    TR-->>CB: [Transaction...]
    CB-->>CE: "Category Food: ₹2709\n4 transactions\n- Swiggy ₹520..."
    CE-->>CV: ChatMessage(role: .assistant, content: response)
    CV-->>U: Displays bubble with answer
```

### 2.4 Subscription Detection Data Flow

```mermaid
flowchart TD
    A[All Transactions] --> B[Group by normalized merchant]
    B --> C{Count >= 2?}
    C -->|No| X[Skip]
    C -->|Yes| D[Sort by date]
    D --> E[Calculate intervals between dates]
    E --> F{Average interval?}
    F -->|5-9 days| G[Weekly]
    F -->|25-35 days| H[Monthly]
    F -->|80-100 days| I[Quarterly]
    F -->|350-380 days| J[Yearly]
    F -->|Other| X

    G --> K[Calculate Confidence]
    H --> K
    I --> K
    J --> K

    K --> L[Amount consistency 40%]
    K --> M[Frequency consistency 40%]
    K --> N[Count bonus 20%]
    L --> O[Combined score]
    M --> O
    N --> O
    O --> P{Score > 0.6?}
    P -->|Yes| Q[DetectedSubscription]
    P -->|No| X
```

### 2.5 Budget Alert Data Flow

```mermaid
flowchart TD
    A[Transaction saved] --> B[BudgetViewModel.recalculateSpending]
    B --> C[Query spending by category for current month]
    C --> D[Update budget.spent]
    D --> E{Utilization check}
    E -->|>= 50% & not alerted| F[Local Notification: 50% used]
    E -->|>= 80% & not alerted| G[Local Notification: 80% warning]
    E -->|>= 100% & not alerted| H[Local Notification: Budget exceeded!]
    F --> I[Set alertAt50 = true]
    G --> J[Set alertAt80 = true]
    H --> K[Set alertAt100 = true]
```

### 2.6 SMS Parse Data Flow

```mermaid
flowchart TD
    A[User pastes bank SMS] --> B[SMSParserEngine.parse]
    B --> C[Detect type: debit/credit patterns]
    B --> D[Extract amount: Rs/INR/₹ regex]
    B --> E[Extract merchant: after at/to/from]
    B --> F[Extract account: last 4 digits]
    B --> G[Extract reference: txn/utr/ref number]
    C --> H[ParsedSMS struct]
    D --> H
    E --> H
    F --> H
    G --> H
    H --> I[Display in list]
    I --> J[User taps to edit]
    J --> K[EditSMSRecordView]
    K --> L[User confirms]
    L --> M[Convert to Transaction]
    M --> N[Save to SwiftData]
```

---

## Part 3: High Level Design (HLD)

### 3.1 System Context

```mermaid
C4Context
    title FinanceLens AI - System Context

    Person(user, "User", "iPhone owner tracking personal finances")

    System(app, "FinanceLens AI", "100% offline iOS finance app")

    System_Ext(ios, "iOS System", "Face ID, Touch ID, File System, Camera")
    System_Ext(banks, "Bank Statements", "PDF/CSV files from bank websites")

    Rel(user, app, "Uses")
    Rel(app, ios, "Biometric auth, file access, notifications")
    Rel(user, banks, "Downloads statements")
    Rel(banks, app, "Imported via file picker")
```

### 3.2 High-Level Component Architecture

```mermaid
graph TB
    subgraph Presentation["Presentation Layer (SwiftUI)"]
        UI[Views]
        VM[ViewModels]
    end

    subgraph Domain["Domain Layer (Business Logic)"]
        direction TB
        SE[Service Engines]
        RP[Repositories]
    end

    subgraph Infrastructure["Infrastructure Layer"]
        SD[(SwiftData)]
        KC[Keychain]
        VF[Vision Framework]
        NL[NaturalLanguage]
        PK[PDFKit]
        LA[LocalAuthentication]
    end

    UI --> VM
    VM --> SE
    VM --> RP
    SE --> RP
    RP --> SD
    SE --> VF
    SE --> NL
    SE --> PK
    VM --> LA
    VM --> KC

    style Presentation fill:#e1f5fe
    style Domain fill:#f3e5f5
    style Infrastructure fill:#e8f5e9
```

### 3.3 Module Dependency Diagram

```mermaid
graph TD
    subgraph Features
        DASH[Dashboard]
        TRANS[Transactions]
        ANA[Analytics]
        CHAT[Chat]
        BUD[Budget]
        IMP[Import]
        SMS[SMS]
        REP[Reports]
        SET[Settings]
        AUTH[Authentication]
    end

    subgraph Services
        CAT_E[CategorizationEngine]
        MER_E[MerchantRecognition]
        SUB_E[SubscriptionDetection]
        ANA_E[AnalyticsEngine]
        FOR_E[ForecastingEngine]
        HEA_E[HealthScoreEngine]
        CHA_E[ChatEngine]
        OCR_E[OCREngine]
        IMP_E[ImportService]
        SMS_E[SMSParser]
    end

    subgraph Data
        T_REPO[TransactionRepo]
        B_REPO[BudgetRepo]
    end

    DASH --> ANA_E
    DASH --> HEA_E
    DASH --> T_REPO
    TRANS --> T_REPO
    TRANS --> CAT_E
    TRANS --> MER_E
    ANA --> ANA_E
    CHAT --> CHA_E
    CHA_E --> T_REPO
    CHA_E --> B_REPO
    CHA_E --> FOR_E
    CHA_E --> SUB_E
    CHA_E --> HEA_E
    BUD --> B_REPO
    BUD --> T_REPO
    IMP --> IMP_E
    IMP --> OCR_E
    SMS --> SMS_E
    REP --> T_REPO
    REP --> ANA_E
    HEA_E --> T_REPO
    HEA_E --> B_REPO
    FOR_E --> T_REPO
    SUB_E --> T_REPO
    ANA_E --> T_REPO
```

### 3.4 Technology Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Storage | SwiftData | Native Apple ORM, no dependencies, type-safe |
| AI/NLP | NaturalLanguage framework | On-device embeddings, no cloud |
| OCR | Vision framework | System-level accuracy, offline |
| PDF | PDFKit | Built-in, handles all PDF versions |
| Auth | LocalAuthentication | Secure Enclave integration |
| Charts | Swift Charts | Native, declarative, iOS 16+ |
| Secrets | Keychain Services | Hardware-backed, survives reinstalls |
| Architecture | MVVM + Repository | Testable, separation of concerns |
| Navigation | Coordinator + TabView | Centralized routing logic |
| Concurrency | async/await | Modern Swift concurrency |

### 3.5 Security Architecture

```mermaid
graph TD
    subgraph UserFacing["User-Facing Security"]
        FID[Face ID]
        TID[Touch ID]
        PIN[PIN Code]
        CAP[Math Captcha]
    end

    subgraph AppSecurity["App Security Layer"]
        BIO[BiometricAuthManager]
        PINM[PINManager]
        KCM[KeychainManager]
    end

    subgraph SystemSecurity["iOS System Security"]
        SE[Secure Enclave]
        DP[Data Protection]
        KC[Keychain Services]
        SB[App Sandbox]
    end

    FID --> BIO
    TID --> BIO
    PIN --> PINM
    CAP --> PINM
    BIO --> SE
    PINM --> KCM
    KCM --> KC
    KC --> DP

    style UserFacing fill:#fff3e0
    style AppSecurity fill:#fce4ec
    style SystemSecurity fill:#e8eaf6
```

### 3.6 Offline Guarantee

```mermaid
graph LR
    subgraph NeverUsed["NOT Used (by design)"]
        URL[URLSession]
        NET[Network.framework]
        FB[Firebase]
        AWS[AWS/Azure/GCP]
        API[Any REST API]
    end

    subgraph UsedInstead["Used Instead"]
        SD[SwiftData - local DB]
        CM[CoreML - local AI]
        NL[NaturalLanguage - local NLP]
        VN[Vision - local OCR]
        KC[Keychain - local secrets]
        UN[UserNotifications - local alerts]
    end

    style NeverUsed fill:#ffcdd2
    style UsedInstead fill:#c8e6c9
```
