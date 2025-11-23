# 🚀 GasGuard

## Smart Contract Optimization Assistant

### 💡 Overview

The **GasGuard** smart contract provides a comprehensive, on-chain framework for **analyzing, tracking, and optimizing** smart contract performance and gas efficiency within the Stacks ecosystem. It serves as a decentralized marketplace and reputation system, connecting developers who seek to optimize their contracts with expert analysts (Auditors/Optimizers) who provide detailed suggestions. The contract meticulously records initial and final gas estimates, tracks specific optimization suggestions, monitors implementation status, and maintains a transparent, reputation-based scoring system for contributing analyzers.

This system is designed to foster a culture of gas-efficient contract development, rewarding analysts for quantifiable gas savings and providing developers with clear, actionable insights into their contract's operational costs. It moves beyond simple static analysis by integrating real-world gas usage history tracking and a mechanism to calculate a definitive **Optimization Score** based on achieved savings.

---

### 🏛️ Contract Architecture and Data Structures

The core functionality of GasGuard revolves around several key maps and variables that manage the submission lifecycle, optimization suggestions, reputation, and historical usage data.

| Data Structure | Type | Purpose | Key Fields | Value Fields |
| :--- | :--- | :--- | :--- | :--- |
| `contract-submissions` | Map | Tracks contracts submitted for analysis. | `contract-id: principal` | `owner: principal`, `submission-height: uint`, `status: (string-ascii 20)`, `gas-estimate: uint`, `optimization-score: uint` |
| `optimization-suggestions` | Map | Stores specific optimization suggestions. | `contract-id: principal`, `suggestion-id: uint` | `severity: uint`, `category: (string-ascii 50)`, `description: (string-utf8 500)`, `estimated-savings: uint`, `implemented: bool` |
| `suggestion-counter` | Map | Counts the number of suggestions per contract. | `contract-id: principal` | `count: uint` |
| `analyzer-reputation` | Map | Stores performance metrics for analysts. | `analyzer: principal` | `total-analyses: uint`, `successful-optimizations: uint`, `reputation-score: uint`, `total-savings-achieved: uint` |
| `gas-usage-history` | Map | Records gas consumption for specific function executions. | `contract-id: principal`, `execution-id: uint` | `function-name: (string-ascii 50)`, `gas-used: uint`, `block-height: uint`, `optimized: bool` |
| `analysis-payments` | Map | Tracks payments made to analysts for services. | `contract-id: principal` | `amount-paid: uint`, `analyzer: principal`, `payment-height: uint` |
| `total-contracts-analyzed` | Data Variable | Global count of all submitted contracts. | N/A | `uint` |
| `total-gas-saved` | Data Variable | Total gas saved across all completed optimizations. | N/A | `uint` |
| `total-optimizations-implemented` | Data Variable | Total count of suggestions marked as implemented. | N/A | `uint` |

---

### ⚙️ Constants and Error Codes

The contract defines several constants for clarity, standardization, and robust error handling.

#### Severity Levels

| Constant | Value | Description |
| :--- | :--- | :--- |
| `severity-critical` | `u1` | Mandatory or high-impact optimization. |
| `severity-high` | `u2` | Significant gas savings possible. |
| `severity-medium` | `u3` | Moderate, but worthwhile, improvement. |
| `severity-low` | `u4` | Minor optimization, best practices. |

#### Financial Constants

| Constant | Value | Description |
| :--- | :--- | :--- |
| `min-analysis-fee` | `u1000000` | Minimum payment amount (in microSTX) required for analysis. |

#### Error Codes

| Constant | Value | Description |
| :--- | :--- | :--- |
| `err-owner-only` | `u100` | Caller is not the contract owner. |
| `err-not-found` | `u101` | Requested record (e.g., submission) does not exist. |
| `err-already-exists` | `u102` | Contract submission already exists. |
| `err-invalid-input` | `u103` | Invalid function input (e.g., zero gas estimate, invalid severity). |
| `err-unauthorized` | `u104` | Caller is not authorized (e.g., not the contract owner). |
| `err-insufficient-payment` | `u105` | Payment amount is below the minimum required fee. |

---

### 🛠️ API Documentation (Public and Read-Only Functions)

This section details all callable functions, including required inputs, expected outputs, and behavior.

#### Public Functions

Public functions require a transaction and may result in state changes.

| Function | Description | Authorization | Returns |
| :--- | :--- | :--- | :--- |
| **`submit-contract-for-analysis`** | Initiates the optimization process by submitting a contract and its initial gas estimate. | Any principal. | `(ok true)` or error. |
| **`add-optimization-suggestion`** | Adds a specific optimization suggestion for a submitted contract. **Note:** *Future versions may restrict this to verified Analyzers.* | Any principal. | `(ok suggestion-id)` or error. |
| **`mark-suggestion-implemented`** | Marks a suggestion as implemented by the contract owner and updates global gas savings statistics. | Contract owner. | `(ok true)` or error. |
| **`record-gas-usage`** | Allows the contract owner to log historical gas usage for specific functions (pre- and post-optimization). | Contract owner. | `(ok true)` or error. |
| **`pay-for-analysis`** | Transfers the analysis fee from the contract owner to a specified analyzer. | Contract owner. | `(ok true)` or error. |
| **`generate-comprehensive-optimization-report`** | Calculates the final `optimization-score`, updates contract status to "completed," updates global stats, updates the Analyzer's reputation, and returns a detailed report. | Contract owner. | `(ok { report-details })` or error. |

##### `(submit-contract-for-analysis (contract-id principal) (initial-gas-estimate uint))`

* **Logic:** Asserts the contract hasn't been submitted, records the owner and initial gas estimate, and initializes the suggestion counter. Increments `total-contracts-analyzed`.
* **Errors:** `err-already-exists`, `err-invalid-input`.

##### `(add-optimization-suggestion (contract-id principal) (severity uint) (category (string-ascii 50)) (description (string-utf8 500)) (estimated-savings uint))`

* **Logic:** Retrieves the next suggestion ID, validates the severity and savings, and maps the suggestion data. Increments the `suggestion-counter`.
* **Errors:** `err-not-found`, `err-invalid-input`.

##### `(mark-suggestion-implemented (contract-id principal) (suggestion-id uint))`

* **Logic:** **Authorization check** ensures only the contract owner can mark it implemented. Prevents marking an already implemented suggestion. Updates `total-gas-saved` and `total-optimizations-implemented`.
* **Errors:** `err-not-found`, `err-unauthorized`, `err-invalid-input`.

##### `(generate-comprehensive-optimization-report (contract-id principal) (original-gas uint) (optimized-gas uint))`

* **Logic:**
    1.  Calculates `gas-saved` and `optimization-score` using the private helper.
    2.  Updates the `contract-submissions` map with the final score, status ("completed"), and optimized gas estimate.
    3.  Updates the global `total-gas-saved` variable.
    4.  If payment info exists in `analysis-payments`, calls `update-analyzer-reputation`.
    5.  Returns a detailed report tuple.
* **Errors:** `err-not-found`, `err-unauthorized`, `err-invalid-input`.

#### Read-Only Functions

Read-only functions allow querying contract data without transaction fees or state changes.

| Function | Description | Authorization | Returns |
| :--- | :--- | :--- | :--- |
| **`get-contract-submission`** | Retrieves the full details of a submitted contract. | Any principal. | `(ok (optional { submission-details }))` |
| **`get-optimization-suggestion`** | Retrieves a specific optimization suggestion by its ID. | Any principal. | `(ok (optional { suggestion-details }))` |
| **`get-analyzer-reputation`** | Retrieves the reputation profile for a given principal. | Any principal. | `(ok (optional { reputation-details }))` |
| **`get-global-statistics`** | Retrieves all global tracking variables. | Any principal. | `(ok { global-stats })` |

---

### 🧠 Private Helper Functions

Private functions manage internal contract logic, calculations, and complex state updates.

#### `(calculate-optimization-score (original-gas uint) (optimized-gas uint))`

* **Purpose:** Assigns an optimization score (0-100) based on the percentage of gas saved.
* **Scoring Logic:**
    * Savings $\ge 50\%$: Score **100**
    * Savings $\ge 30\%$: Score **80**
    * Savings $\ge 15\%$: Score **60**
    * Savings $\ge 5\%$: Score **40**
    * Savings $< 5\%$: Score **20**

#### `(is-valid-severity (severity uint))`

* **Purpose:** Utility function to ensure a submitted severity level matches one of the defined constants (`u1` to `u4`).

#### `(update-analyzer-reputation (analyzer principal) (gas-saved uint))`

* **Purpose:** Updates the analyzer's reputation record after a successful, reported optimization (via `generate-comprehensive-optimization-report`).
* **Reputation Score Calculation:** The `reputation-score` is increased by the total gas saved, divided by a scaling factor of **1000** (`(/ gas-saved u1000)`). This scales high gas savings into manageable reputation points.

---

### 📝 Contribution and Development Guidelines

We welcome contributions to enhance the GasGuard contract's functionality, security, and efficiency.

#### Submitting a Contract for Optimization

1.  Call `submit-contract-for-analysis(contract-id, initial-gas-estimate)` with the principal of the target contract and its pre-optimization gas estimate.
2.  (Optional) Call `pay-for-analysis(contract-id, analyzer, amount)` to commission an analyzer.
3.  Once the analysis is complete, the analyzer calls `add-optimization-suggestion` for each finding.
4.  After implementing a suggestion, the contract owner calls `mark-suggestion-implemented(contract-id, suggestion-id)`.
5.  After all optimizations are complete and final gas usage is confirmed, the owner calls `generate-comprehensive-optimization-report` with the final optimized gas value.

#### Analyzer Roles

Analyzers contribute by:
* Providing high-quality suggestions via `add-optimization-suggestion`.
* Receiving STX payments via `pay-for-analysis`.
* Having their reputation automatically updated upon successful report generation via `generate-comprehensive-optimization-report`. Their reputation is directly tied to the *total gas saved*.

#### Testing

To ensure the contract's integrity, all contributions must include exhaustive unit tests covering:
* **Error Handling:** Testing all defined `err-` codes are triggered correctly (e.g., unauthorized access, invalid inputs).
* **State Transitions:** Verifying the status changes in `contract-submissions` (e.g., from "pending" to "completed").
* **Calculation Accuracy:** Validating the `calculate-optimization-score` and reputation updates based on expected gas savings.
* **Payment Flow:** Confirming the STX transfer in `pay-for-analysis` is successful and the `analysis-payments` map is updated.

---

### 📜 License

```text
The MIT License (MIT)

Copyright (c) 2025 GasGuard Developers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

This comprehensive license ensures that the GasGuard smart contract and its
associated tools remain open-source and freely accessible for the benefit
of the entire Stacks development community.
