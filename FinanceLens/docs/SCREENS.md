# FinanceLens iOS — Screen-by-Screen Documentation

> **Audience:** Developers onboarding to the FinanceLens iOS codebase or conducting code review.  
> **Last Updated:** June 2026

---

## Table of Contents

1. [AppCoordinator](#1-appcoordinator)
2. [MainTabView](#2-maintabview)
3. [LockScreenView](#3-lockscreenview)
4. [DashboardView](#4-dashboardview)
5. [TransactionListView](#5-transactionlistview)
6. [AddTransactionView](#6-addtransactionview)
7. [AnalyticsDashboardView](#7-analyticsdashboardview)
8. [ChatView](#8-chatview)
9. [SettingsView](#9-settingsview)
10. [BudgetView](#10-budgetview)
11. [ImportStatementView](#11-importstatementview)
12. [ReportsView](#12-reportsview)
13. [SMSMonitorView](#13-smsmonitorview)
14. [BackupRestoreView](#14-backuprestoreview)
15. [GoalsView](#15-goalsview)
16. [SplitExpenseView](#16-splitexpenseview)
17. [LendingView](#17-lendingview)
18. [FinanceLensWidget](#18-financelenswidget)

---

## 1. AppCoordinator

**File:** `Core/Navigation/AppCoordinator.swift`

### Purpose
Root-level view that decides whether to show the lock screen or the main app content based on the user's security preferences and unlock state.

### Key UI Components
- Conditional rendering: `LockScreenView` or `MainTabView`
- Animated transition between locked/unlocked states

### User Interactions
- None directly — acts as a routing layer

### Data Flow
- Reads `appLockEnabled` from `@AppStorage`
- Observes `appState.isUnlocked` via `@EnvironmentObject`
- On appear, triggers `RecurringTransactionService.processRecurringTransactions()` to auto-generate recurring entries

### Notable Technical Details
- Uses `.animation(.easeInOut)` keyed on `appState.isUnlocked` for smooth lock/unlock transitions
- `RecurringTransactionService` runs as a `.task` modifier — fires once on first render
- Depends on `ModelContext` from the environment for SwiftData access

---

## 2. MainTabView

**File:** `Core/Navigation/MainTabView.swift`

### Purpose
Primary tab bar navigation container that organizes the five main app sections.

### Key UI Components
- `TabView` with five tabs:
  - **Home** (Dashboard) — `house.fill`
  - **Transactions** — `list.bullet.rectangle`
  - **Analytics** — `chart.bar.fill`
  - **AI Chat** — `bubble.left.and.text.bubble.right`
  - **Settings** — `gearshape.fill`

### User Interactions
- Tap tab items to switch between sections

### Data Flow
- `@State selectedTab` tracks active tab using a `Tab` enum backed by `Int`

### Notable Technical Details
- Clean enum-based tab identification for type safety
- Each tab wraps its own `NavigationStack` (within the child views)

---

## 3. LockScreenView

**File:** `Features/Authentication/Views/LockScreenView.swift`

### Purpose
App lock screen providing biometric (Face ID / Touch ID) and PIN-based authentication before granting access to financial data.

### Key UI Components
- App branding (lock shield icon + title)
- Biometric unlock button (adapts label for Face ID vs Touch ID)
- PIN entry field (SecureField)
- "Forgot PIN?" flow with biometric re-verification or captcha fallback
- Alerts for captcha verification and new PIN creation

### User Interactions
| Action | Result |
|--------|--------|
| Tap biometric button | Triggers Face ID / Touch ID |
| Enter PIN + tap Unlock | Validates via `PINManager.verifyPin()` |
| Tap "Forgot PIN?" | Attempts biometric reset; falls back to math captcha |
| Solve captcha | Grants access to set a new PIN |

### Data Flow
- `@EnvironmentObject appState` — calls `appState.unlock()` on success
- `@StateObject BiometricAuthManager` — checks hardware availability, performs authentication
- `@AppStorage("biometricEnabled")` — user preference toggle
- `PINManager` (static utility) — manages PIN storage and verification

### Notable Technical Details
- Auto-triggers biometric auth on view appear via `.task` modifier
- Captcha uses random addition (10–50 range) as a human-verification fallback
- PIN entry uses `.keyboardType(.numberPad)` and `.textContentType(.password)`
- Multiple `@State` properties manage cascading alert flows

---

## 4. DashboardView

**File:** `Features/Dashboard/Views/DashboardView.swift`

### Purpose
Main home screen displaying a financial overview: income/expense summary, financial health score, spending category breakdown with drilldown, and recent transactions.

### Key UI Components
- **Summary Cards** — Income, Expense, Savings (HStack of `SummaryCard`)
- **Financial Health Score** — Circular progress indicator with color-coded rating
- **Category Pie Chart** — Interactive `SectorMark` chart (Swift Charts) with tappable categories
- **Category Drilldown** — Horizontal `BarMark` chart showing merchant breakdown per category
- **Recent Transactions** — Last 5 transactions list

### User Interactions
| Action | Result |
|--------|--------|
| Tap a category in the grid | Loads merchant-level drilldown bar chart |
| Tap "Back" | Returns to category overview |
| Tap `+` (leading toolbar) | Opens `AddTransactionView` sheet |
| Tap document icon (trailing toolbar) | Opens `ImportStatementView` sheet |

### Data Flow
- `TransactionRepository` — fetches totals, spending by category, recent transactions
- `BudgetRepository` — fetches budget data for widget sharing
- `FinancialHealthEngine` — computes health score (deferred to background `Task.detached`)
- Shares data with Widget via `UserDefaults(suiteName: "group.com.financelens.ai")`
- Triggers `WidgetCenter.shared.reloadAllTimelines()` after data update

### Notable Technical Details
- Health score calculation is dispatched to a detached `@MainActor` task to avoid blocking UI
- Uses `SecureAmount` component for amount display (respects secure mode)
- Chart selection highlights the tapped sector and dims others with opacity animation
- Widget data keys: `todaySpent`, `monthSpent`, `budgetRemaining`, `topCategory`

---

## 5. TransactionListView

**File:** `Features/Transactions/Views/TransactionListView.swift`

### Purpose
Searchable, scrollable list of all transactions with swipe-to-delete and tap-for-detail functionality.

### Key UI Components
- `List` with `TransactionRowView` cells (merchant, category, amount, date)
- Built-in `.searchable` modifier for filtering
- `TransactionDetailView` sheet (medium/large detents)
- Swipe-to-delete gesture

### User Interactions
| Action | Result |
|--------|--------|
| Type in search bar | Filters transactions via `viewModel.searchText` |
| Tap a row | Opens detail sheet |
| Swipe left | Deletes transaction |
| Tap `+` (toolbar) | Opens `AddTransactionView` |

### Data Flow
- `@StateObject TransactionViewModel` — manages filtered list, search, CRUD
- `@Environment(\.modelContext)` — passed to viewModel on `.onAppear`

### Notable Technical Details
- `TransactionDetailView` uses `.presentationDetents([.medium, .large])` for adaptive sizing
- Detail view displays: amount, merchant, normalized merchant, category, date, payment method, type, source, confidence score, recurring flag, balance after, creation timestamp
- `SecureAmount` used in rows for privacy-aware amount display
- Color-coded amounts: green for credits, default for debits

---

## 6. AddTransactionView

**File:** `Features/Transactions/Views/AddTransactionView.swift`

### Purpose
Form for manually adding a new transaction with full control over amount, merchant, date/time, category, type, and payment method.

### Key UI Components
- `Form` with sections: Amount, Details (merchant + notes + date + time), Category picker, Type (segmented), Payment Method picker
- Cancel / Save toolbar buttons

### User Interactions
| Action | Result |
|--------|--------|
| Fill fields + tap Save | Creates `Transaction` and adds via viewModel |
| Tap Cancel | Dismisses without saving |

### Data Flow
- Receives `TransactionViewModel` as `@ObservedObject`
- Builds a `Transaction` model object with `.source = .manual`
- Combines date and time into a single `Date` using `Calendar` components

### Notable Technical Details
- Categories sourced from `Category.defaults` (static list)
- Save button disabled until both amount and merchant are non-empty
- Uses separate `DatePicker`s for date and time components, then merges them
- `TransactionType` and `PaymentMethod` are `CaseIterable` enums

---

## 7. AnalyticsDashboardView

**File:** `Features/Analytics/Views/AnalyticsDashboardView.swift`

### Purpose
Visual analytics dashboard showing cash flow summary, spending by category, and top merchants for the current month.

### Key UI Components
- **Cash Flow Card** — Income / Expense / Savings stat boxes + savings rate
- **Category Bar Chart** — Horizontal bars with interactive selection highlighting
- **Merchant Bar Chart** — Top 8 merchants with transaction count and average amount
- Selection detail panels showing exact values on tap

### User Interactions
| Action | Result |
|--------|--------|
| Tap/select a category bar | Highlights bar, shows amount and percentage detail |
| Tap/select a merchant bar | Shows total spent, transaction count, and average |

### Data Flow
- `AnalyticsEngine` — provides `categoryAnalytics`, `cashFlowAnalytics`, `merchantAnalytics`
- `TransactionRepository` as data source
- Data scoped to current month (start of month → now)

### Notable Technical Details
- Uses `.chartYSelection(value:)` for interactive bar chart selection (iOS 17+)
- `CategoryAnalytics` includes percentage calculation
- `MerchantAnalytics` includes transaction count and average amount
- Charts limited to top 8 items for readability
- Opacity-based highlighting for non-selected items (0.4 opacity)

---

## 8. ChatView

**File:** `Features/Chat/Views/ChatView.swift`

### Purpose
AI-powered financial assistant chat interface that answers questions about the user's spending, budgets, subscriptions, and financial health — all processed locally.

### Key UI Components
- `ScrollView` with `LazyVStack` of `ChatBubbleView` messages
- Suggestion pills (displayed when chat is empty)
- Input bar with `TextField` and send button
- Processing indicator ("Analyzing...")
- Source attribution text below assistant messages

### User Interactions
| Action | Result |
|--------|--------|
| Tap a suggestion | Auto-fills and sends message |
| Type + tap send / press return | Sends query to `FinancialChatEngine` |
| Tap "Clear" toolbar button | Clears chat history |

### Data Flow
- `@StateObject FinancialChatEngine` — manages messages, processing state
- Engine receives `ModelContext` via `.setup(context:)` for database queries
- Messages have `role` (`.user` / `.assistant`) and optional `sources` array

### Notable Technical Details
- Uses `ScrollViewReader` with `.onChange` to auto-scroll to latest message
- `@FocusState` manages keyboard focus on input field
- `ChatBubbleView` renders different styles based on message role (blue for user, gray for assistant)
- Source attribution shows data provenance (e.g., "Transactions", "Budgets")
- Pre-defined suggestions cover common financial queries

---

## 9. SettingsView

**File:** `Features/Settings/Views/SettingsView.swift`

### Purpose
Central configuration screen for security, data management, notifications, and app information.

### Key UI Components
- **Security Section** — App lock toggle, biometric toggle, PIN setup, secure mode
- **Data Section** — Navigation links to Import, SMS, Lendings, Split, Goals, Budgets, Backup
- **Notifications Section** — Daily summary (9 PM) and weekly report (Sunday) toggles
- **About Section** — Version and privacy info

### User Interactions
| Action | Result |
|--------|--------|
| Toggle App Lock | Enables/disables lock screen |
| Toggle Secure Mode | Hides all amounts as `****` app-wide |
| Tap "Set/Change PIN" | Shows PIN setup alert |
| Toggle notifications | Schedules/cancels local notifications |
| Tap any Data navigation link | Navigates to respective feature |

### Data Flow
- Multiple `@AppStorage` properties for persistent preferences
- `SpendingNotificationService` — handles permission requests and scheduling
- Secure mode synced to App Group for widget access

### Notable Technical Details
- Secure mode propagates to widget via shared `UserDefaults` suite
- Notification toggles immediately request permission and schedule/cancel
- "100% Offline" privacy indicator — no network calls in the entire app
- PIN alert uses `SecureField` with number pad

---

## 10. BudgetView

**File:** `Features/Budget/Views/BudgetView.swift`

### Purpose
Category-based budget management with visual progress tracking and over-budget warnings.

### Key UI Components
- **Summary Header** — Total budget vs. remaining (color-coded)
- **Budget List** — `BudgetRowView` with progress bars and over-budget alerts
- **Add Budget Sheet** — Category picker + amount input

### User Interactions
| Action | Result |
|--------|--------|
| Tap `+` | Opens `AddBudgetView` sheet |
| Swipe to delete | Removes a budget |
| View progress bars | See utilization per category |

### Data Flow
- `@StateObject BudgetViewModel` — manages budget CRUD, computes totals
- `BudgetRepository` for persistence
- `Budget` model exposes computed `utilization`, `remaining`, `isOverBudget`

### Notable Technical Details
- Progress bar color dynamically changes: green (<50%), yellow (50-80%), orange (80-100%), red (>100%)
- Utilization capped at 1.0 for `ProgressView` but actual percentage shown in text
- Budget is scoped to month/year

---

## 11. ImportStatementView

**File:** `Features/Import/Views/ImportStatementView.swift`

### Purpose
File-based import of bank statements (PDF, CSV, TXT) with automatic transaction parsing.

### Key UI Components
- Import options view (icon + supported formats + file picker button)
- Processing spinner
- Results view (count + "Save All" button)

### User Interactions
| Action | Result |
|--------|--------|
| Tap "Choose File" | Opens system file picker |
| Select a PDF/CSV/TXT | Parses via `StatementImportService` |
| Tap "Save All" | Inserts all parsed transactions into SwiftData |
| Tap "Close" | Dismisses view |

### Data Flow
- `StatementImportService.importFile(url:)` → returns `[ParsedTransaction]`
- Each `ParsedTransaction` converted via `.toTransaction(source: .pdfImport)` and inserted into context

### Notable Technical Details
- Uses `.fileImporter` with `allowedContentTypes: [.pdf, .commaSeparatedText, .plainText]`
- Async file handling with `Task { await ... }`
- Error state displayed via alert
- Security-scoped resource access handled by the system file picker

---

## 12. ReportsView

**File:** `Features/Reports/Views/ReportsView.swift`

### Purpose
Generate and export financial reports in PDF or CSV format for a user-selected date range.

### Key UI Components
- Date range pickers (From / To)
- Format selector (PDF / CSV segmented picker)
- "Generate Report" button
- Share sheet for exporting the generated file

### User Interactions
| Action | Result |
|--------|--------|
| Select date range | Scopes report data |
| Choose format | PDF or CSV |
| Tap "Generate Report" | Creates file and presents share sheet |

### Data Flow
- `ReportGenerator` (defined in same file) — uses `TransactionRepository` and `BudgetRepository`
- CSV: Headers + all transactions in comma-separated format
- PDF: UIGraphics-based page rendering with title, period, summary, categories, and transaction list

### Notable Technical Details
- PDF generation uses `UIGraphicsBeginPDFContextToData` with 612×792 page size (US Letter)
- Automatic page breaks when content exceeds page height
- CSV escapes commas in merchant names/notes by replacing with semicolons
- `ShareSheet` wraps `UIActivityViewController` via `UIViewControllerRepresentable`
- `IdentifiableURL` wrapper makes `URL` conform to `Identifiable` for sheet presentation

---

## 13. SMSMonitorView

**File:** `Features/SMS/Views/SMSMonitorView.swift`

### Purpose
Manual SMS paste-and-parse interface for extracting transaction data from bank SMS notifications.

### Key UI Components
- `TextEditor` for pasting SMS text
- "Parse SMS" button
- Parsed records list with confirmation checkmarks
- Edit sheet (`EditSMSRecordView`) for correcting parsed data
- "Save All Confirmed" button

### User Interactions
| Action | Result |
|--------|--------|
| Paste SMS + tap "Parse SMS" | Runs `SMSParserEngine.parse()` |
| Tap a parsed record | Opens edit view for corrections |
| Toggle confirm in edit view | Marks record ready for saving |
| Tap "Save All Confirmed" | Inserts confirmed records as transactions |
| Swipe to delete | Removes parsed record |

### Data Flow
- `SMSParserEngine.parse(text)` → `ParsedSMS` (amount, merchant, type, date, account suffix, reference)
- `ParsedSMS.toTransaction()` converts to `Transaction` model
- Only records with `isConfirmed = true` are saved

### Notable Technical Details
- `ParsedSMS` is `Identifiable` for list rendering and sheet binding
- Edit view preserves raw text, account suffix, and reference number as read-only metadata
- Type picker is segmented (Debit/Credit)
- Placeholder text in TextEditor using overlay alignment trick

---

## 14. BackupRestoreView

**File:** `Features/Backup/Views/BackupRestoreView.swift`

### Purpose
Full data backup (export) and restore (import) via JSON files, covering transactions, budgets, and lendings.

### Key UI Components
- Export button + progress indicator
- Import button + progress indicator
- Status message display
- Descriptive captions for each action

### User Interactions
| Action | Result |
|--------|--------|
| Tap "Export Backup" | Generates timestamped JSON file, presents share sheet |
| Tap "Import Backup" | Opens file picker for `.json` files |
| Select file | Restores all data and shows count |

### Data Flow
- `BackupService` (defined in same file):
  - `exportBackup()` → fetches all `Transaction`, `Budget`, `Lending` models → encodes as JSON
  - `importBackup(data:)` → decodes JSON → inserts all records → returns count
- DTO layer (`TransactionDTO`, `BudgetDTO`, `LendingDTO`) for serialization

### Notable Technical Details
- Uses ISO 8601 date encoding strategy
- Pretty-printed JSON output for human readability
- Security-scoped resource access for imported files
- Backup versioned (`version: 1`) for future migration support
- Filename includes timestamp: `FinanceLens_Backup_yyyy-MM-dd_HHmm.json`
- Async processing with spinner to prevent UI hang on large datasets

---

## 15. GoalsView

**File:** `Features/Goals/Views/GoalsView.swift`

### Purpose
Savings goal tracker with progress visualization, deadlines, daily targets, and contribution recording.

### Key UI Components
- **Goal List** — Active goals with progress bars + completed section
- **GoalRow** — Icon, name, progress percentage, amount progress, days remaining
- **AddGoalView** — Name, target amount, optional deadline, icon picker grid
- **GoalDetailView** — Full progress display, daily target calculation, "Add Savings" input

### User Interactions
| Action | Result |
|--------|--------|
| Tap `+` | Opens new goal creation form |
| Tap a goal | Opens detail view with contribution input |
| Enter amount + tap "Add" | Increments `savedAmount`; auto-completes if target reached |
| Swipe to delete | Removes goal |

### Data Flow
- `@Query` with sort by `createdAt` descending — direct SwiftData query
- `SavingsGoal` model properties: `name`, `targetAmount`, `savedAmount`, `deadline`, `icon`, `isCompleted`
- Computed: `progress`, `remaining`, `daysLeft`, `dailyTarget`

### Notable Technical Details
- Uses `@Query` macro (SwiftData) instead of a separate ViewModel
- Icon picker with 9 SF Symbols options in adaptive grid
- Detail view uses `.presentationDetents([.medium, .large])`
- Progress bar scaled 2x height in detail view for visual impact
- Goals auto-mark as completed when `savedAmount >= targetAmount`

---

## 16. SplitExpenseView

**File:** `Features/Split/Views/SplitExpenseView.swift`

### Purpose
Split bill management for shared expenses with per-participant tracking and payment status.

### Key UI Components
- **SplitExpenseListView** — List of splits with participant count, amount, and settlement status
- **AddSplitView** — Title, total amount, participant name entry, even-split toggle
- **SplitDetailView** — Per-person share with individual payment toggle checkmarks

### User Interactions
| Action | Result |
|--------|--------|
| Tap `+` | Opens new split creation |
| Add participant names | Builds participant list |
| Toggle "Split Evenly" | Divides total equally |
| Tap participant checkmark in detail | Toggles `hasPaid` status |
| All participants paid | Auto-marks split as settled |

### Data Flow
- `SplitExpense` SwiftData model with embedded `[SplitParticipant]` (Codable struct)
- `@Query` with sort by `createdAt` descending
- Settlement check: `split.participants.allSatisfy(\.hasPaid)`

### Notable Technical Details
- `SplitParticipant` is a `Codable` + `Identifiable` + `Hashable` struct (embedded in model, not a separate entity)
- Uses `NavigationLink` for detail (push navigation) vs sheets for add
- Enumerated `ForEach` with index for in-place mutation of participant array

---

## 17. LendingView

**File:** `Features/Lending/Views/LendingView.swift`

### Purpose
Track money lent to or borrowed from others, with partial payment recording, due date tracking, and overdue alerts.

### Key UI Components
- **Summary Cards** — "To Receive" (green) and "To Pay" (red) totals
- **Filter Picker** — Segmented: All / Lent / Borrowed / Overdue
- **LendingRow** — Person name, type badge, remaining amount, due date, overdue indicator
- **AddLendingView** — Person, amount, type (segmented), reason, date, optional due date
- **LendingDetailView** — Full breakdown, payment history, record payment, mark settled

### User Interactions
| Action | Result |
|--------|--------|
| Tap `+` | Opens add lending form |
| Select filter | Shows subset of lendings |
| Tap a lending | Opens detail with payment history |
| "Record Payment" | Alert with amount + note fields |
| "Mark as Settled" | Zeros out remaining, marks settled |
| Swipe to delete | Removes lending |

### Data Flow
- `@StateObject LendingViewModel` — CRUD, payment recording, computed totals
- `Lending` model: `personName`, `amount`, `remainingAmount`, `type`, `reason`, `date`, `dueDate`, `isSettled`, `payments: [LendingPayment]`
- Payment reduces `remainingAmount`; auto-settles when reaching zero

### Notable Technical Details
- `LendingViewModel` is `@MainActor` with explicit `ObservableObject` conformance
- Overdue detection via computed `isOverdue` property on model
- `LendingPayment` is `Identifiable` with date, amount, note
- Detail view uses `.presentationDetents([.large])` for full-height sheet
- Settled items shown with 0.6 opacity in a separate section

---

## 18. FinanceLensWidget

**File:** `Features/Widget/FinanceLensWidget.swift`

### Purpose
Home screen widget (small + medium sizes) displaying today's spending, monthly total, budget remaining, and top category.

### Key UI Components
- **SmallWidgetView** — "FinanceLens" header, today's spending (large), monthly total (caption)
- **MediumWidgetView** — Left: today's spending. Right: monthly spent, budget left, top category
- **Secure Mode** — Displays `₹****` when secure mode enabled (except today's spending)

### User Interactions
- Tap widget → launches app (default deep link behavior)

### Data Flow
- `SpendingProvider` (TimelineProvider):
  - Reads from `UserDefaults(suiteName: "group.com.financelens.ai")`
  - Keys: `todaySpent`, `monthSpent`, `budgetRemaining`, `topCategory`
  - Refreshes hourly (`policy: .after(nextUpdate)`)
- Dashboard view writes these values on each load

### Notable Technical Details
- `@main` attribute on `FinanceLensWidgetBundle` — widget extension entry point
- `@AppStorage` with shared suite for secure mode detection
- iOS 17+ uses `.containerBackground(.fill.tertiary, for: .widget)`; fallback for older versions
- Placeholder data provided for widget gallery preview
- Supported families: `.systemSmall`, `.systemMedium`

---

## Architecture Summary

### Navigation Architecture
```
AppCoordinator
├── LockScreenView (if app lock enabled & locked)
└── MainTabView
    ├── Tab 1: DashboardView
    ├── Tab 2: TransactionListView
    ├── Tab 3: AnalyticsDashboardView
    ├── Tab 4: ChatView
    └── Tab 5: SettingsView
        ├── ImportStatementView
        ├── SMSMonitorView
        ├── LendingListView
        ├── SplitExpenseListView
        ├── GoalsView
        ├── BudgetView
        └── BackupRestoreView
```

### Key Patterns Used
| Pattern | Usage |
|---------|-------|
| MVVM | `TransactionViewModel`, `BudgetViewModel`, `LendingViewModel` |
| SwiftData `@Query` | `GoalsView`, `SplitExpenseListView` (direct query without ViewModel) |
| Repository Pattern | `TransactionRepository`, `BudgetRepository` |
| App Groups | Widget data sharing via shared `UserDefaults` |
| Environment Injection | `ModelContext`, `AppState` passed through SwiftUI environment |
| Coordinator Pattern | `AppCoordinator` handles auth gating |

### Data Persistence
- **SwiftData** with `@Model` classes: `Transaction`, `Budget`, `SavingsGoal`, `SplitExpense`, `Lending`
- **UserDefaults / @AppStorage** for preferences and widget data
- **Keychain** for secure PIN storage
- **JSON backup** for full data export/import

### Privacy & Security
- 100% offline — no network calls
- Biometric authentication (Face ID / Touch ID)
- PIN fallback with captcha-based reset
- Secure mode hides all monetary values throughout app and widget
- No cloud sync or telemetry
