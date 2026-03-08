/-
  WorldModel.KB.Boxes.Ontology
  Marker typeclasses forming an is-a hierarchy over Box types.

  Classes are all in `Prop` with no methods — they exist solely to classify
  types.  Because they carry no generated code, instances are written
  explicitly wherever needed.

  Hierarchy:
    Step
    └── MeasurementStep      (steps that take a clinical measurement)

    Measurement              (the measurement value types themselves)

    ClinicalEncounter        (a ToBox type representing a full encounter)
-/
import WorldModel.KB.Boxes
import WorldModel.KB.Types

/-- A clinical measurement value type.
    Inhabited by `HeartRate`, `BloodPressure`, and `VO2Max`. -/
class Measurement (α : Type) : Prop

/-- Any pipeline stage type. -/
class Step (α : Type) : Prop

/-- A pipeline stage that takes a clinical measurement. -/
class MeasurementStep (α : Type) : Prop

/-- Every `MeasurementStep` is also a `Step`. -/
instance [MeasurementStep α] : Step α := ⟨⟩

/-- A `ToBox` type that represents a complete clinical encounter.
    Assigned manually to pipeline types that satisfy encounter conditions. -/
class ClinicalEncounter (α : Type) [ToBox α] : Prop

-- ── Patient / Human bridge ───────────────────────────────────────────
-- `Patient` (Boxes layer) and `Human` (KB layer) are structurally identical
-- types.  These coercions let KB-level proof conditions (which speak of
-- `Human name`) be satisfied directly by Boxes-layer values.

instance {name : String} : Coe (Patient name) (Human name) :=
  ⟨fun _ => .mk name⟩

instance {name : String} : Coe (Clinician name) (Human name) :=
  ⟨fun _ => .mk name⟩

-- ── Measurement instances ─────────────────────────────────────────────
instance {name} : Measurement (HeartRate name)     := ⟨⟩
instance {name} : Measurement (BloodPressure name) := ⟨⟩
instance {name} : Measurement (VO2Max name)        := ⟨⟩

-- ── Step instances (non-measurement stages) ───────────────────────────
instance {name}  : Step (Consenting name)            := ⟨⟩
instance {pn cn} : Step (ExplainedConsent pn cn)     := ⟨⟩
instance {name}  : Step (Products name)              := ⟨⟩
instance {name}  : Step (ConsentRefusal name)        := ⟨⟩
instance {name}  : Step (FinalAssessment name)       := ⟨⟩

-- Composed pipelines are also Steps, enabling sub-pipeline composition.
instance {types wirings} : Step (Pipeline types wirings) := ⟨⟩

-- ── MeasurementStep instances (Step is satisfied via the coercion above)
instance {name} : MeasurementStep (HeartMeasurement name)         := ⟨⟩
instance {name} : MeasurementStep (BloodPressureMeasurement name) := ⟨⟩
instance {name} : MeasurementStep (VO2MaxMeasurement name)        := ⟨⟩
