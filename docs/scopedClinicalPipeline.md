# scopedClinicalPipeline

Type-level wiring diagram for `scopedClinicalPipeline` defined in
`lean4/WorldModel/KB/Arrow/Clinical.lean`.

Each measurement can disqualify the patient.  All failure branches produce
`NonQualifying "Jose"` and are merged by three `.join`s into a single
disqualification outcome.

```mermaid
flowchart TB
    In((Start))

    subgraph Trial["Trial Scope &mdash; ClinicalTrial"]
    subgraph Clinic["Clinic Scope &mdash; Clinic, Clinician, SharedLangEvidence"]
    subgraph Room["Room Scope &mdash; Room, Equipment, Qualifications"]

        B0{{"Consent?"}}
        C["0 &middot; Consent<br/><small>in: Patient, SharedLangEvidence</small>"]
        HM["1 &middot; HeartMeasurement<br/><small>in: Patient, Clinician, ExamBed,<br/>ExamBedQual, SharedLangEvidence</small>"]
        B1{{"Heart Rate OK?"}}
        BP["2 &middot; BPMeasurement<br/><small>in: Patient, Clinician, BPMonitor,<br/>BPMonitorQual, SharedLangEvidence</small>"]
        B2{{"BP OK?"}}
        V2["3 &middot; VO2MaxMeasurement<br/><small>in: Patient, Clinician, VO2Equipment,<br/>VO2EquipmentQual, SharedLangEvidence</small>"]
        B3{{"VO2 OK?"}}
        PR["4 &middot; Products<br/><small>in: ConsentGiven, HeartRate,<br/>BloodPressure, VO2Max</small>"]
        FA["5 &middot; Assessment<br/><small>in: Patient, ProductsOutput</small>"]

    end
    end
    end

    NQ(("NonQualifying<br/>(disqualified)"))
    OutS(("Success<br/>(qualified)"))

    In -->|"Patient &laquo;Jose&raquo;"| B0

    B0 -->|"consentRefused"| NQ
    B0 -->|"accepted"| C

    C -->|"ConsentGiven"| HM
    HM -->|"HeartRate"| B1

    B1 -->|"heartRateTooFast"| NQ
    B1 -->|"OK"| BP

    BP -->|"BloodPressure"| B2

    B2 -->|"bloodPressureTooHigh"| NQ
    B2 -->|"OK"| V2

    V2 -->|"VO2Max"| B3

    B3 -->|"vo2MaxTooLow"| NQ
    B3 -->|"OK"| PR

    PR -->|"ProductsOutput"| FA
    FA -->|"AssessmentResult"| OutS

    style NQ fill:#f96,stroke:#c00,color:#fff
    style OutS fill:#6c6,stroke:#090,color:#fff
    style B0 fill:#ffd,stroke:#aa0
    style B1 fill:#ffd,stroke:#aa0
    style B2 fill:#ffd,stroke:#aa0
    style B3 fill:#ffd,stroke:#aa0
    style Trial fill:#e8f0fe,stroke:#4a86c8,color:#2a4a78
    style Clinic fill:#f0f4e8,stroke:#6a9a3a,color:#3a5a1a
    style Room fill:#fef4e8,stroke:#c89a4a,color:#6a4a1a
```

## Outcomes

| # | Context after scope exit | Meaning |
|---|--------------------------|---------|
| 1 | `[Patient "Jose", NonQualifying "Jose"]` | Patient disqualified at any step |
| 2 | `[Patient "Jose", ConsentGiven "Jose", HeartRate "Jose", BloodPressure "Jose", VO2Max "Jose", ProductsOutput "Jose", AssessmentResult "Jose"]` | Patient fully qualified |

## Stage descriptions

| # | Arrow | Inputs (from context) | Produces |
|---|-------|-----------------------|----------|
| 0 | `consentArrow` | `Patient`, `SharedLangEvidence` | `ConsentGiven` |
| 1 | `heartArrow` | `Patient`, `Clinician`, `ExamBed`, `ExamBedQual`, `SharedLangEvidence` | `HeartRate` |
| 2 | `bpArrow` | `Patient`, `Clinician`, `BPMonitor`, `BPMonitorQual`, `SharedLangEvidence` | `BloodPressure` |
| 3 | `vo2Arrow` | `Patient`, `Clinician`, `VO2Equipment`, `VO2EquipmentQual`, `SharedLangEvidence` | `VO2Max` |
| 4 | `productsArrow` | `ConsentGiven`, `HeartRate`, `BloodPressure`, `VO2Max` | `ProductsOutput` |
| 5 | `assessmentArrow` | `Patient`, `ProductsOutput` | `AssessmentResult` |

## Disqualification reasons

```lean
inductive DisqualificationReason : Type where
  | consentRefused : String → DisqualificationReason
  | heartRateTooFast
  | bloodPressureTooHigh
  | vo2MaxTooLow
```

All four failure branches use the same `nqArrow`, which finds `Patient "Jose"` in
the scope context and produces `NonQualifying "Jose"`.  The polymorphic
`insideAllScopesSel` drops any produced items so every failure branch sees
identical context — enabling the three `.join`s.

## Scope structure

| Scope | Extension | Provides |
|-------|-----------|----------|
| Trial | `trialExt` | `ClinicalTrial "OurTrial"` |
| Clinic | `clinicExt` | `Clinic "ValClinic"`, `Clinician "Allen"`, `SharedLangEvidence "Allen" "Jose"` |
| Room | `roomExt` | `Room "Room3"`, `ExamBed`, `BPMonitor`, `VO2Equipment`, `ExamBedQual "Allen"`, `BPMonitorQual "Allen"`, `VO2EquipmentQual "Allen"` |

On scope exit each extension is stripped from every outcome context, leaving
only `Patient "Jose"` plus the items produced by the pipeline steps.

## Wiring notes

- **Failure-on-left stacking**: each `.branch` puts the `NQ` outcome on the left.
  Four branches produce `[NQ, NQ, NQ, NQ, success]`; three `.join`s collapse to
  `[NQ, success]`.
- **`insideAllScopesSel`** uses `Selection.prefix` to pick the 12 scope items
  from any extended context, discarding produced items before disqualification.
- **No consumption**: all arrows use `consumes := []`; items persist in context
  via the frame rule.
- Validated at compile time — zero `sorry`s, zero errors.
