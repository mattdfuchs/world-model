/-
  WorldModel.KB.SoA
  Schedule of Activities encoding at Type 2.

  A SoA is a typed property graph specifying WHAT needs to happen across a
  multi-encounter clinical trial, without specifying WHO does it, WHERE, or
  with what evidence.  It lives at Type 2 — the abstract interaction type.
  Compilation to Type 1 (SheetDiagram) is a separate step that grounds the
  specification against KB facts.

  Graph structure (following Richardson 2024/2025):
    - Interaction nodes (visits): timing, phase, modality, repeat pattern
    - Activity nodes (procedures): category
    - Edges: performs (visit→activity), follows (visit→visit), requires (activity→activity)
-/

-- ── Study phases ──────────────────────────────────────────────────────────

/-- Classification of study periods. -/
inductive StudyPhase where
  | screening
  | baseline
  | treatment
  | followUp
  | completion
  deriving DecidableEq, Repr, BEq

-- ── Visit modality ────────────────────────────────────────────────────────

/-- How a visit is conducted. -/
inductive Modality where
  | onSite
  | phone
  | home
  deriving DecidableEq, Repr, BEq

-- ── Termination conditions for repeating visits ───────────────────────────

/-- When a repeating visit pattern stops. -/
inductive TerminationCondition where
  | endOfStudy
  | progression
  | withdrawal
  | death
  | fixed (count : Nat)
  deriving DecidableEq, Repr

-- ── Repeat patterns ───────────────────────────────────────────────────────

/-- How a visit repeats.
    - `every days terminateOn`: repeat every N days until a termination condition
    - `cycles cycleDays`: oncology-style treatment cycles (C1D1, C2D1, ...) -/
inductive RepeatPattern where
  | every (days : Nat) (terminateOn : TerminationCondition)
  | cycles (cycleDays : Nat)
  deriving Repr

-- ── Timing ────────────────────────────────────────────────────────────────

/-- Visit timing relative to a reference event (usually randomization).
    `nominalDay` can be negative (e.g., screening at D-28). -/
structure Timing where
  nominalDay   : Int
  windowBefore : Nat := 0
  windowAfter  : Nat := 0
  deriving Repr

-- ── Interaction nodes (visits) ────────────────────────────────────────────

/-- A visit or encounter in the study schedule. -/
structure InteractionNode where
  id        : String
  name      : String
  phase     : StudyPhase
  timing    : Timing
  modality  : Modality := .onSite
  repeating : Option RepeatPattern := none
  deriving Repr

-- ── Activity categories ───────────────────────────────────────────────────

/-- Classification of clinical procedures/assessments.
    Matches categories observed across real protocols. -/
inductive ActivityCategory where
  | initiation   -- consent, demographics, eligibility, randomization
  | clinical     -- physical exam, vital signs, weight, ECG, ECOG
  | labLocal     -- hematology, chemistry, urinalysis, pregnancy test
  | labCentral   -- PK, biomarkers, antibody titers
  | intervention -- drug dispensing, administration, accountability
  | imaging      -- CT/MRI, X-ray, echo
  | pro          -- patient-reported outcomes, questionnaires
  | safety       -- AE/SAE collection, concomitant meds
  deriving DecidableEq, Repr, BEq

-- ── Activity nodes ────────────────────────────────────────────────────────

/-- A procedure or assessment in the study schedule. -/
structure ActivityNode where
  id       : String
  name     : String
  category : ActivityCategory
  deriving Repr

-- ── Cell values (the SoA matrix entry) ────────────────────────────────────

/-- What the SoA matrix says about an activity at a visit.
    Richer than boolean — real protocols use quantities, conditions, frequencies. -/
inductive CellValue where
  | required                     -- X
  | optional                     -- Optional
  | conditional (note : String)  -- X^a with footnote condition
  | quantity (amount : String)   -- ~10 mL, ~50 mL
  | continuous                   -- ←Continuous→
  | frequency (desc : String)    -- "Daily", "Twice weekly", "3 times a day"
  deriving Repr

-- ── Transition spec for follows edges ─────────────────────────────────────

/-- Timing constraint between two sequential visits. -/
structure TransitionSpec where
  minDays : Int := 0
  maxDays : Option Int := none
  deriving Repr

-- ── Edge types ────────────────────────────────────────────────────────────

/-- Typed edges connecting nodes in the SoA graph.
    - `performs`: visit schedules an activity (the matrix cell)
    - `follows`: temporal ordering between visits
    - `requires`: dependency between activities -/
inductive SoAEdge where
  | performs (interaction : String) (activity : String) (value : CellValue)
  | follows  (src : String) (dst : String) (transition : TransitionSpec)
  | requires (activity : String) (prerequisite : String)
  deriving Repr

-- ── The SoA ───────────────────────────────────────────────────────────────

/-- A Schedule of Activities: the complete abstract specification for a
    clinical trial, represented as a typed property graph.

    The SoA is purely abstract: it does NOT reference specific clinicians,
    clinics, rooms, or equipment.  Those are resolved during compilation
    when each interaction is grounded against the KB. -/
structure SoA where
  name         : String
  interactions : List InteractionNode
  activities   : List ActivityNode
  edges        : List SoAEdge
  deriving Repr

-- ── Convenience accessors ─────────────────────────────────────────────────

/-- Find an interaction node by ID. -/
def SoA.getInteraction (soa : SoA) (id : String) : Option InteractionNode :=
  soa.interactions.find? (·.id == id)

/-- Find an activity node by ID. -/
def SoA.getActivity (soa : SoA) (id : String) : Option ActivityNode :=
  soa.activities.find? (·.id == id)

/-- All activities performed at a given visit, with their cell values. -/
def SoA.activitiesAt (soa : SoA) (visitId : String) : List (ActivityNode × CellValue) :=
  soa.edges.filterMap fun
    | .performs iid aid val =>
      if iid == visitId then soa.getActivity aid |>.map (·, val) else none
    | _ => none

/-- All visits where a given activity is performed, with their cell values. -/
def SoA.visitsFor (soa : SoA) (activityId : String) : List (InteractionNode × CellValue) :=
  soa.edges.filterMap fun
    | .performs iid aid val =>
      if aid == activityId then soa.getInteraction iid |>.map (·, val) else none
    | _ => none

/-- Successor visits reachable via `follows` edges from a given visit. -/
def SoA.successors (soa : SoA) (visitId : String) : List (InteractionNode × TransitionSpec) :=
  soa.edges.filterMap fun
    | .follows s d ts =>
      if s == visitId then soa.getInteraction d |>.map (·, ts) else none
    | _ => none

/-- All repeating interaction nodes (the ν-iteration sources). -/
def SoA.repeatingInteractions (soa : SoA) : List InteractionNode :=
  soa.interactions.filter (·.repeating.isSome)

-- ── Basic validators ──────────────────────────────────────────────────────

/-- Check that all interaction IDs are unique. -/
def SoA.interactionIdsUnique (soa : SoA) : Bool :=
  let ids := soa.interactions.map (·.id)
  ids.eraseDups.length == ids.length

/-- Check that all activity IDs are unique. -/
def SoA.activityIdsUnique (soa : SoA) : Bool :=
  let ids := soa.activities.map (·.id)
  ids.eraseDups.length == ids.length

/-- Check that all edge endpoints reference existing node IDs. -/
def SoA.edgesValid (soa : SoA) : Bool :=
  let iids := soa.interactions.map (·.id)
  let aids := soa.activities.map (·.id)
  soa.edges.all fun
    | .performs iid aid _ => iids.contains iid && aids.contains aid
    | .follows s d _     => iids.contains s && iids.contains d
    | .requires act pre  => aids.contains act && aids.contains pre

/-- Check that all activity IDs in the SoA exist in a catalog of known action names.
    Returns the list of unknown activity IDs (empty = all good). -/
def SoA.unknownActivities (soa : SoA) (catalogNames : List String) : List String :=
  soa.activities.filterMap fun a =>
    if catalogNames.contains a.id then none else some a.id

/-- Check that every activity in the SoA has a corresponding entry in the catalog. -/
def SoA.activitiesInCatalog (soa : SoA) (catalogNames : List String) : Bool :=
  soa.unknownActivities catalogNames |>.isEmpty

-- ── Visit plan extraction ────────────────────────────────────────────────

/-- A linearized visit plan extracted from a SoA.
    Each entry represents a visit "slot" in topological order. -/
structure VisitSlot where
  interaction : InteractionNode
  activities  : List (ActivityNode × CellValue)
  deriving Repr

/-- Extract a linearized visit plan from a SoA.
    Orders interactions by nominal day (topological sort via timing).
    Each slot carries its activities. -/
def SoA.visitPlan (soa : SoA) : List VisitSlot :=
  let sorted := soa.interactions.mergeSort
    (fun a b => a.timing.nominalDay < b.timing.nominalDay)
  sorted.map fun node =>
    { interaction := node, activities := soa.activitiesAt node.id }

-- Worked examples: see lean4/test/SoA/ (JoseTrial.lean, TJ301.lean, Osimertinib.lean)
