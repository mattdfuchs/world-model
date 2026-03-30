/-
  WorldModel.KB.Arrow.Scope
  Resource-as-scope constraint system.

  A `ScopeState` is a stack of `ScopeItem`s — resource entries (tagged with roles)
  and constraint declarations.  Each scope push extends the stack; each scope pop
  strips it.  `newObligations` computes the proof obligations that fire when new
  items enter scope.
-/

-- ── Tags: roles and resource kinds ──────────────────────────────────────────

inductive Tag where
  | clinic | trial | room
  | examBed | bpMonitor | vo2Equipment
  | patient | clinician
  | examBedTech | bpTech | vo2Tech
  | vial | drugDose
  deriving DecidableEq, Repr

-- ── Scope entries ───────────────────────────────────────────────────────────

structure ScopeEntry where
  name : String
  tag  : Tag
  deriving DecidableEq, Repr

-- ── Constraint identifiers ──────────────────────────────────────────────────

inductive ConstraintId where
  | clinicInPatientCity
  | clinicianSpeaksPatient
  | clinicianAssigned
  | trialApprovesClinic
  | examBedQual | bpQual | vo2Qual
  deriving DecidableEq, Repr

-- ── Scope items: entries + constraints on a single stack ────────────────────

inductive ScopeItem where
  | entry      : ScopeEntry → ScopeItem
  | constraint : ConstraintId → ScopeItem
  deriving Repr

abbrev ScopeState := List ScopeItem

-- ── AllObligations: dependent tuple of proof obligations ────────────────────

/-- Collapse a list of types into a single dependent product.
    `[]` → `PUnit`, `[T]` → `T`, `[T₁, T₂, ...]` → `T₁ × AllObligations [T₂, ...]`. -/
def AllObligations : List Type → Type
  | []        => PUnit
  | [T]       => T
  | T :: rest => T × AllObligations rest
