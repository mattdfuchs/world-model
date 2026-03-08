# alicePipeline

Type-level wiring diagram for `alicePipeline` defined in `lean4/WorldModel/KB/Boxes.lean`.

```mermaid
flowchart TB
    In((●))
    C("0 · Consenting\nin: Patient")
    HM("1 · HeartMeasurement\nin: Patient")
    BP("2 · BloodPressureMeasurement\nin: Patient")
    V2("3 · VO2MaxMeasurement\nin: Patient")
    PR("4 · Products\nin: String · Int · Rat · Int")
    CR("5 · ConsentRefusal\nin: Decision\nout: ⊥")
    FA("6 · FinalAssessment\nin: Patient · String · Int · Rat · Int")
    OutS((●))
    OutF((●))

    In -->|"Patient"| C

    C -->|"consent: Patient"| HM
    C -->|"consent: String"| PR
    C -->|"refuse: Decision"| CR

    HM -->|"heartRate: Patient"| BP
    HM -->|"heartRate: Int"| PR

    BP -->|"bloodPressure: Patient"| V2
    BP -->|"bloodPressure: Rat"| PR

    V2 -->|"vO2Max: Patient"| FA
    V2 -->|"vO2Max: Int"| PR

    PR -->|"products: String, Int, Rat, Int"| FA

    FA -->|"success"| OutS
    FA -->|"failure"| OutF
```

## Stage descriptions

| # | Type | Inputs | Outputs |
|---|------|--------|---------|
| 0 | `Consenting` | `Patient` | `consent: Patient, String` · `refuse: Decision` |
| 1 | `HeartMeasurement` | `Patient` | `heartRate: Patient, Int` |
| 2 | `BloodPressureMeasurement` | `Patient` | `bloodPressure: Patient, Rat` |
| 3 | `VO2MaxMeasurement` | `Patient` | `vO2Max: Patient, Int` |
| 4 | `Products` | `String, Int, Rat, Int` | `products: String, Int, Rat, Int` |
| 5 | `ConsentRefusal` | `Decision` | ⊥ (terminated) |
| 6 | `FinalAssessment` | `Patient, String, Int, Rat, Int` | `success: Patient, String, Int, Rat, Int` · `failure: Patient, String` |

## Wiring notes

- The **Patient token** threads through the main chain: `Consenting → HeartMeasurement → BloodPressureMeasurement → VO2MaxMeasurement → FinalAssessment`
- The **consent String** and each **measurement value** (Int, Rat, Int) are routed into `Products`, which packages them before forwarding to `FinalAssessment`
- The **refuse branch** carries the whole `Decision` value to `ConsentRefusal` (⊥) — no wires escape
- `FinalAssessment` receives all five values and produces either `success` or `failure`
- Validated at compile time via `by native_decide` in `pipeline!`
