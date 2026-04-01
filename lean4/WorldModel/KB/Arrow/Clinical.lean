/-
  WorldModel.KB.Arrow.Clinical
  Full clinical pipeline using scope-derived constraints.

  Instead of a monolithic `LegalMeasurementMeeting`, constraints emerge from
  nested scopes:
    - Trial scope  → provides ClinicalTrial, declares clinicianSpeaksPatient
    - Clinic scope → provides Clinic, Clinician, proves city/assignment/approval/language
    - Room scope   → provides Room, Equipment, proves technician qualifications

  Each measurement step declares exactly what it needs (equipment, qualification,
  shared language). Missing constraints = type error.
-/
import WorldModel.KB.Arrow.Arrow
import WorldModel.KB.Arrow.SheetDiagram
import WorldModel.KB.Arrow.Scope
import WorldModel.KB.Facts           -- speaks facts for SharedLangEvidence

open KB.Facts

-- ── Domain types ──────────────────────────────────────────────────────────

inductive Patient : String → Type where
  | mk : (name : String) → Patient name

inductive Clinician : String → Type where
  | mk : (name : String) → Clinician name

inductive HeartRate : String → Type where
  | heartRate : {name : String} → Patient name → Int → HeartRate name

inductive BloodPressure : String → Type where
  | bloodPressure : {name : String} → Patient name → Rat → BloodPressure name

inductive VO2Max : String → Type where
  | vO2Max : {name : String} → Patient name → Int → VO2Max name

inductive ProductsOutput (name : String) where
  | products : String → Int → Rat → Int → ProductsOutput name

inductive AssessmentResult (name : String) where
  | success : Patient name → String → Int → Rat → Int → AssessmentResult name
  | failure : Patient name → String → AssessmentResult name

-- ── Rig-indexed and dependent domain types ────────────────────────────────

/-- A vial with `n` doses remaining.  Rig-indexed: `Vial 2 ≠ Vial 1` at the type level. -/
inductive Vial : Nat → Type where
  | mk : (n : Nat) → Vial n

/-- A drug dose drawn for a specific patient.  `DrugDose "Jose" ≠ DrugDose "Maria"`. -/
inductive DrugDose : String → Type where
  | mk : (patient : String) → DrugDose patient

/-- Record that a dose was administered to a specific patient. -/
inductive AdminRecord : String → Type where
  | mk : (patient : String) → AdminRecord patient

-- ── Dual types (co-endpoints for conserved resources) ──────────────────────

/-- Proof of patient presence at a location. Dual of `Patient`. -/
inductive PatientPresence : String → Type where
  | mk : (name : String) → PatientPresence name

/-- Proof of clinician presence on-site. Dual of `Clinician`. -/
inductive ClinicianPresence : String → Type where
  | mk : (name : String) → ClinicianPresence name

/-- Receipt for checked-out exam bed. Dual of `ExamBed`. -/
inductive ExamBedReceipt : Type where | mk : ExamBedReceipt

/-- Receipt for checked-out BP monitor. Dual of `BPMonitor`. -/
inductive BPMonitorReceipt : Type where | mk : BPMonitorReceipt

/-- Receipt for checked-out VO2 equipment. Dual of `VO2Equipment`. -/
inductive VO2EquipmentReceipt : Type where | mk : VO2EquipmentReceipt

/-- Reservation for a room. Dual of `Room`. -/
inductive RoomReservation : String → Type where
  | mk : (name : String) → RoomReservation name

/-- Reservation for a clinic. Dual of `Clinic`. -/
inductive ClinicReservation : String → Type where
  | mk : (name : String) → ClinicReservation name

/-- Enrollment in a trial. Dual of `ClinicalTrial`. -/
inductive TrialEnrollment : String → Type where
  | mk : (name : String) → TrialEnrollment name

-- ── Obligation types (produced by arrow fission) ──────────────────────────

/-- Obligation that a dose was delivered to a specific patient.
    Produced when a dose is drawn from a vial (fission);
    cancelled by `cap` with `AdminRecord`. -/
inductive DoseObligation : String → Type where
  | mk : (patient : String) → DoseObligation patient

/-- Evidence that a confirmation call was made to a patient before a visit. -/
inductive CallConfirmed : String → Type where
  | mk : (patientName : String) → CallConfirmed patientName

-- ── Evidence types ──────────────────────────────────────────────────────────

/-- Proof that a clinician and patient share a language.
    Included in scope extensions so inner steps can find it via Satisfy/Elem. -/
structure SharedLangEvidence (cn pn : String) : Type where
  lang : String
  cSpeaks : speaks (Human.mk cn) (Language.mk lang)
  pSpeaks : speaks (Human.mk pn) (Language.mk lang)

/-- Proof that a clinic is in the same city where a patient lives. -/
structure ClinicCityEvidence (clinicName patientName : String) : Type where
  city   : String
  cIsIn  : isIn (Clinic.mk clinicName) (City.mk city)
  pLives : lives (Human.mk patientName) (City.mk city)

-- ── Consent and disqualification types ─────────────────────────────────────

/-- Consent was obtained — carries the patient and the consent note. -/
inductive ConsentGiven (name : String) : Type where
  | mk : Patient name → String → ConsentGiven name

/-- Reasons a patient can be disqualified at any measurement step. -/
inductive DisqualificationReason : Type where
  | consentRefused : String → DisqualificationReason
  | heartRateTooFast
  | bloodPressureTooHigh
  | vo2MaxTooLow

/-- Patient disqualified — carries the patient and the reason. -/
inductive NonQualifying (name : String) : Type where
  | mk : Patient name → DisqualificationReason → NonQualifying name

-- ── Constraint interpretation ──────────────────────────────────────────────

/-- Map a `ConstraintId` to the list of proof obligations it generates,
    given the current set of scope entries.  Each constraint is role-indexed:
    it only fires for entries with the matching tag. -/
def interpretConstraint (cid : ConstraintId) (entries : List ScopeEntry) : List Type :=
  match cid with
  | .clinicInPatientCity =>
      let clinics  := entries.filterMap fun e => if e.tag == .clinic  then some e.name else none
      let patients := entries.filterMap fun e => if e.tag == .patient then some e.name else none
      clinics.flatMap fun cn => patients.map fun pn => ClinicCityEvidence cn pn
  | .clinicianSpeaksPatient =>
      let clinicians := entries.filterMap fun e => if e.tag == .clinician then some e.name else none
      let patients   := entries.filterMap fun e => if e.tag == .patient   then some e.name else none
      clinicians.flatMap fun cn => patients.map fun pn => SharedLangEvidence cn pn
  | .clinicianAssigned =>
      let clinicians := entries.filterMap fun e => if e.tag == .clinician then some e.name else none
      let clinics    := entries.filterMap fun e => if e.tag == .clinic    then some e.name else none
      clinicians.flatMap fun cn => clinics.map fun cl => assigned (Human.mk cn) (Clinic.mk cl)
  | .trialApprovesClinic =>
      let trials  := entries.filterMap fun e => if e.tag == .trial  then some e.name else none
      let clinics := entries.filterMap fun e => if e.tag == .clinic then some e.name else none
      trials.flatMap fun tn => clinics.map fun cn => trialApproves (ClinicalTrial.mk tn) (Clinic.mk cn)
  | .examBedQual =>
      (entries.filterMap fun e => if e.tag == .examBedTech then some e.name else none).map fun n =>
        holdsExamBedQual (Human.mk n) .mk
  | .bpQual =>
      (entries.filterMap fun e => if e.tag == .bpTech then some e.name else none).map fun n =>
        holdsBPMonitorQual (Human.mk n) .mk
  | .vo2Qual =>
      (entries.filterMap fun e => if e.tag == .vo2Tech then some e.name else none).map fun n =>
        holdsVO2EquipmentQual (Human.mk n) .mk
  | .callConfirmed =>
      (entries.filterMap fun e => if e.tag == .patient then some e.name else none).map fun pn =>
        CallConfirmed pn

/-- Compute proof obligations that fire when `newItems` enter an existing `ScopeState`.
    - New constraints fire against ALL entries (existing + new)
    - Existing constraints fire against NEW entries only
    This avoids re-proving obligations from earlier scope levels. -/
def newObligations (newItems : List ScopeItem) (existingState : ScopeState) : List Type :=
  let fullState := newItems ++ existingState
  let allEntries := fullState.filterMap fun | .entry e => some e | _ => none
  let newConstraints := newItems.filterMap fun | .constraint c => some c | _ => none
  let existingConstraints := existingState.filterMap fun | .constraint c => some c | _ => none
  let newEntries := newItems.filterMap fun | .entry e => some e | _ => none
  -- New constraints fire against ALL entries
  (newConstraints.flatMap fun cid => interpretConstraint cid allEntries)
  -- Existing constraints fire against NEW entries only
  ++ (existingConstraints.flatMap fun cid => interpretConstraint cid newEntries)

-- ── Worked example: Jose/Allen pipeline ──────────────────────────────────────
-- Everything below is namespaced to avoid collisions with LLM-generated code.

namespace JoseExample

/-- Concrete evidence that Allen and Jose share Spanish. -/
def allenJoseLangEvidence : SharedLangEvidence "Allen" "Jose" :=
  { lang := "Spanish"
    cSpeaks := allen_speaks_spanish
    pSpeaks := jose_speaks_spanish }

/-- Concrete evidence that ValClinic is in Valencia where Jose lives. -/
def valClinicJoseCityEvidence : ClinicCityEvidence "ValClinic" "Jose" :=
  { city := "Valencia"
    cIsIn := valClinic_in_valencia
    pLives := jose_lives_valencia }

-- ── Initial context ─────────────────────────────────────────────────────────

/-- Starting context: just the patient. -/
abbrev joseCtx : Ctx := [Patient "Jose"]

/-- Starting scope state: patient is the initial resource. -/
abbrev initState : ScopeState := [.entry ⟨"Jose", .patient⟩]

-- ── Scope items ───────────────────────────────────────────────────────────

/-- Trial scope: introduces the trial and declares that clinicians must speak
    the patient's language. -/
abbrev trialItems : List ScopeItem :=
  [.entry ⟨"OurTrial", .trial⟩,
   .constraint .clinicianSpeaksPatient]

/-- Clinic scope: introduces clinic + clinician, declares clinic-level constraints. -/
abbrev clinicItems : List ScopeItem :=
  [.entry ⟨"ValClinic", .clinic⟩,
   .entry ⟨"Allen", .clinician⟩,
   .constraint .clinicInPatientCity,
   .constraint .clinicianAssigned,
   .constraint .trialApprovesClinic]

/-- Room scope: introduces room + technician role assignments + equipment constraints. -/
abbrev roomItems : List ScopeItem :=
  [.entry ⟨"Room3", .room⟩,
   .entry ⟨"Allen", .examBedTech⟩,
   .entry ⟨"Allen", .bpTech⟩,
   .entry ⟨"Allen", .vo2Tech⟩,
   .constraint .examBedQual,
   .constraint .bpQual,
   .constraint .vo2Qual]

-- ── Scope extensions (Ctx) ────────────────────────────────────────────────

/-- Trial scope: just the trial object. -/
abbrev trialExt : Ctx := [ClinicalTrial "OurTrial"]

/-- Clinic scope: clinic + clinician + shared language evidence. -/
abbrev clinicExt : Ctx := [Clinic "ValClinic", Clinician "Allen",
                            SharedLangEvidence "Allen" "Jose"]

/-- Room scope: room marker + equipment + clinician qualifications. -/
abbrev roomExt : Ctx := [Room "Room3", ExamBed, BPMonitor, VO2Equipment,
                          holdsExamBedQual allen .mk, holdsBPMonitorQual allen .mk,
                          holdsVO2EquipmentQual allen .mk]

-- ── Full inner context ──────────────────────────────────────────────────────

/-- The full context inside all three nested scopes.
    Index  Type
    0      Room "Room3"
    1      ExamBed
    2      BPMonitor
    3      VO2Equipment
    4      holdsExamBedQual allen .mk
    5      holdsBPMonitorQual allen .mk
    6      holdsVO2EquipmentQual allen .mk
    7      Clinic "ValClinic"
    8      Clinician "Allen"
    9      SharedLangEvidence "Allen" "Jose"
    10     ClinicalTrial "OurTrial"
    11     Patient "Jose" -/
abbrev insideAllScopes : Ctx :=
  roomExt ++ (clinicExt ++ (trialExt ++ joseCtx))

-- ── Full scope state inside all three scopes ────────────────────────────────

abbrev roomState : ScopeState :=
  roomItems ++ (clinicItems ++ (trialItems ++ initState))

-- ── Failure selection and disqualification arrow ───────────────────────────

/-- Select the 12 scope items from any extended context `insideAllScopes ++ extra`.
    All failure branches use this to drop produced items before disqualifying. -/
def insideAllScopesSel {extra : Ctx}
    : Selection (insideAllScopes ++ extra) insideAllScopes :=
  Selection.prefix insideAllScopes extra

/-- Shared disqualification arrow: finds Patient at index 11, produces NonQualifying. -/
def nqArrow : Arrow insideAllScopes (insideAllScopes ++ [NonQualifying "Jose"]) :=
  .step
    { name := "disqualify"
      description := "Records patient disqualification with a reason"
      inputs := Tel.ofList [Patient "Jose"]
      consumes := []
      produces := [NonQualifying "Jose"] }
    insideAllScopes
    (.bind (Patient.mk "Jose") (by elem_tac)
      .nil)

-- ── Stage 0: Consent ────────────────────────────────────────────────────────

def consentArrow : Arrow insideAllScopes (insideAllScopes ++ [ConsentGiven "Jose"]) :=
  .step
    { name := "consent"
      description := "Obtains informed consent from the patient"
      inputs := Tel.ofList [Patient "Jose", SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [ConsentGiven "Jose"] }
    insideAllScopes
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind allenJoseLangEvidence (by elem_tac)
        .nil))

-- ── Stage 1: Heart measurement ──────────────────────────────────────────────

abbrev afterConsent : Ctx := insideAllScopes ++ [ConsentGiven "Jose"]

def heartArrow : Arrow afterConsent (afterConsent ++ [HeartRate "Jose"]) :=
  .step
    { name := "heartMeasurement"
      description := "Measures the patient's heart rate using an exam bed"
      inputs := Tel.ofList [Patient "Jose", Clinician "Allen", ExamBed,
                            holdsExamBedQual allen .mk, SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [HeartRate "Jose"] }
    afterConsent
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (Clinician.mk "Allen") (by elem_tac)
        (.bind ExamBed.mk (by elem_tac)
          (.bind holdsExamBedQual.mk (by elem_tac)
            (.bind allenJoseLangEvidence (by elem_tac)
              .nil)))))

-- ── Stage 2: Blood pressure measurement ─────────────────────────────────────

abbrev afterHeart : Ctx := afterConsent ++ [HeartRate "Jose"]

def bpArrow : Arrow afterHeart (afterHeart ++ [BloodPressure "Jose"]) :=
  .step
    { name := "bpMeasurement"
      description := "Measures the patient's blood pressure using a BP monitor"
      inputs := Tel.ofList [Patient "Jose", Clinician "Allen", BPMonitor,
                            holdsBPMonitorQual allen .mk, SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [BloodPressure "Jose"] }
    afterHeart
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (Clinician.mk "Allen") (by elem_tac)
        (.bind BPMonitor.mk (by elem_tac)
          (.bind holdsBPMonitorQual.mk (by elem_tac)
            (.bind allenJoseLangEvidence (by elem_tac)
              .nil)))))

-- ── Stage 3: VO2 max measurement ────────────────────────────────────────────

abbrev afterBP : Ctx := afterHeart ++ [BloodPressure "Jose"]

def vo2Arrow : Arrow afterBP (afterBP ++ [VO2Max "Jose"]) :=
  .step
    { name := "vo2Measurement"
      description := "Measures the patient's VO2 max using VO2 equipment"
      inputs := Tel.ofList [Patient "Jose", Clinician "Allen", VO2Equipment,
                            holdsVO2EquipmentQual allen .mk, SharedLangEvidence "Allen" "Jose"]
      consumes := []
      produces := [VO2Max "Jose"] }
    afterBP
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (Clinician.mk "Allen") (by elem_tac)
        (.bind VO2Equipment.mk (by elem_tac)
          (.bind holdsVO2EquipmentQual.mk (by elem_tac)
            (.bind allenJoseLangEvidence (by elem_tac)
              .nil)))))

-- ── Stage 4: Products ───────────────────────────────────────────────────────

abbrev afterVO2 : Ctx := afterBP ++ [VO2Max "Jose"]

def productsArrow : Arrow afterVO2 (afterVO2 ++ [ProductsOutput "Jose"]) :=
  .step
    { name := "products"
      description := "Aggregates all measurement results into a single output"
      inputs := Tel.ofList [ConsentGiven "Jose", HeartRate "Jose",
                            BloodPressure "Jose", VO2Max "Jose"]
      consumes := []
      produces := [ProductsOutput "Jose"] }
    afterVO2
    (.bind (ConsentGiven.mk (Patient.mk "Jose") "signed") (by elem_tac)
      (.bind (HeartRate.heartRate (Patient.mk "Jose") 72) (by elem_tac)
        (.bind (BloodPressure.bloodPressure (Patient.mk "Jose") 120) (by elem_tac)
          (.bind (VO2Max.vO2Max (Patient.mk "Jose") 45) (by elem_tac)
            .nil))))

-- ── Stage 5: Final assessment ───────────────────────────────────────────────

abbrev afterProducts : Ctx := afterVO2 ++ [ProductsOutput "Jose"]

def assessmentArrow : Arrow afterProducts (afterProducts ++ [AssessmentResult "Jose"]) :=
  .step
    { name := "assessment"
      description := "Evaluates aggregated results to determine if patient qualifies"
      inputs := Tel.ofList [Patient "Jose", ProductsOutput "Jose"]
      consumes := []
      produces := [AssessmentResult "Jose"] }
    afterProducts
    (.bind (Patient.mk "Jose") (by elem_tac)
      (.bind (ProductsOutput.products "signed" 72 120 45) (by elem_tac)
        .nil))

-- ── Explicit obligation types per scope ────────────────────────────────────
-- newObligations can't reduce at type-checking time (filterMap/BEq chains),
-- so we spell out the obligation lists that the kernel must see.

/-- Trial scope: clinicianSpeaksPatient fires but no clinician in scope yet → empty. -/
abbrev trialObligations : List Type := []

/-- Clinic scope: new constraints (clinicInPatientCity, clinicianAssigned, trialApprovesClinic)
    fire against all entries; existing constraint (clinicianSpeaksPatient from trial)
    fires against new entries (Allen as clinician). -/
abbrev clinicObligations : List Type :=
  [ClinicCityEvidence "ValClinic" "Jose",
   assigned (Human.mk "Allen") (Clinic.mk "ValClinic"),
   trialApproves (ClinicalTrial.mk "OurTrial") (Clinic.mk "ValClinic"),
   SharedLangEvidence "Allen" "Jose"]

/-- Room scope: new constraints (examBedQual, bpQual, vo2Qual) fire against
    new entries (Allen as examBedTech/bpTech/vo2Tech). -/
abbrev roomObligations : List Type :=
  [holdsExamBedQual (Human.mk "Allen") .mk,
   holdsBPMonitorQual (Human.mk "Allen") .mk,
   holdsVO2EquipmentQual (Human.mk "Allen") .mk]

/-- The full clinical pipeline with measurement branching and scoped constraints.

    Scope constraints fire at each scope entry:
      - Trial: no obligations (clinicianSpeaksPatient declared but no clinician yet)
      - Clinic: ClinicCityEvidence, SharedLangEvidence, assigned, trialApproves
      - Room: holdsExamBedQual, holdsBPMonitorQual, holdsVO2EquipmentQual

    Four branch points (consent, heart, BP, VO2), three `.join`s. -/
def scopedClinicalPipeline : SheetDiagram initState joseCtx initState
    [[Patient "Jose", NonQualifying "Jose"],
     joseCtx ++ [ConsentGiven "Jose", HeartRate "Jose",
                  BloodPressure "Jose", VO2Max "Jose",
                  ProductsOutput "Jose", AssessmentResult "Jose"]] :=
  .scope "trial" trialItems trialExt trialExt initState
    trialObligations
    PUnit.unit
    (.scope "clinic" clinicItems clinicExt clinicExt (trialItems ++ initState)
      clinicObligations
      (valClinicJoseCityEvidence, allen_assigned_val, trial_approves_val, allenJoseLangEvidence)
      (.scope "room" roomItems roomExt roomExt (clinicItems ++ (trialItems ++ initState))
        roomObligations
        (allen_holds_exambed, allen_holds_bpmonitor, allen_holds_vo2equip)
        (.join (.join (.join
          (.branch (Split.idLeft insideAllScopes)
            insideAllScopesSel (Selection.id insideAllScopes)
            (.arrow nqArrow)
            (.pipe consentArrow
              (.pipe heartArrow
                (.branch (Split.idLeft afterHeart)
                  insideAllScopesSel (Selection.id afterHeart)
                  (.arrow nqArrow)
                  (.pipe bpArrow
                    (.branch (Split.idLeft afterBP)
                      insideAllScopesSel (Selection.id afterBP)
                      (.arrow nqArrow)
                      (.pipe vo2Arrow
                        (.branch (Split.idLeft afterVO2)
                          insideAllScopesSel (Selection.id afterVO2)
                          (.arrow nqArrow)
                          (.pipe productsArrow
                            (.arrow assessmentArrow)))))))))))))))

end JoseExample

-- ── George negative test ─────────────────────────────────────────────────────
-- ParisClinic is in Paris, but George lives in London.
-- Uncommenting the pipeline body would require `ClinicCityEvidence "ParisClinic" "George"`
-- which is unprovable — Paris ≠ London.

namespace GeorgeExample

abbrev georgeCtx : Ctx := [Patient "George"]
abbrev georgeState : ScopeState := [.entry ⟨"George", .patient⟩]

abbrev trialItems : List ScopeItem :=
  [.entry ⟨"OurTrial", .trial⟩,
   .constraint .clinicianSpeaksPatient]

abbrev clinicItems : List ScopeItem :=
  [.entry ⟨"ParisClinic", .clinic⟩,
   .entry ⟨"Matthew", .clinician⟩,
   .constraint .clinicInPatientCity,
   .constraint .clinicianAssigned,
   .constraint .trialApprovesClinic]

/-- The obligations at clinic scope for George include
    `ClinicCityEvidence "ParisClinic" "George"`.
    ParisClinic is in Paris, George lives in London → unprovable.

    Uncommenting would require providing evidence of type:
      ClinicCityEvidence "ParisClinic" "George"
    which needs a city where both ParisClinic is located AND George lives.
    ParisClinic is in Paris, George lives in London → no such city exists. -/
abbrev clinicObligations : List Type :=
  [ClinicCityEvidence "ParisClinic" "George",
   assigned (Human.mk "Matthew") (Clinic.mk "ParisClinic"),
   trialApproves (ClinicalTrial.mk "OurTrial") (Clinic.mk "ParisClinic"),
   SharedLangEvidence "Matthew" "George"]

-- To build a pipeline here, you would need:
--   (evidence : AllObligations clinicObligations)
-- i.e. ClinicCityEvidence "ParisClinic" "George" × ...
-- The first component is unprovable: no city satisfies both
--   isIn (Clinic.mk "ParisClinic") (City.mk city)  AND
--   lives (Human.mk "George") (City.mk city)

end GeorgeExample

-- ── Drug dose example: Allen with vial, Jose and Maria ──────────────────────

namespace DrugExample

open KB.Facts

-- ── Evidence ────────────────────────────────────────────────────────────────

def allenJoseLangEvidence : SharedLangEvidence "Allen" "Jose" :=
  { lang := "Spanish", cSpeaks := allen_speaks_spanish, pSpeaks := jose_speaks_spanish }

def valClinicJoseCityEvidence : ClinicCityEvidence "ValClinic" "Jose" :=
  { city := "Valencia", cIsIn := valClinic_in_valencia, pLives := jose_lives_valencia }

-- ── Scope state and context ───────────────────────────────────────────────

/-- Initial state: two patients. -/
abbrev initState : ScopeState :=
  [.entry ⟨"Jose", .patient⟩, .entry ⟨"Maria", .patient⟩]

/-- Starting context: clinician Allen + two patients. -/
abbrev drugCtx : Ctx := [Clinician "Allen", Patient "Jose", Patient "Maria"]

-- ── Trial / Clinic scope items (same as JoseExample) ────────────────────────

abbrev trialItems : List ScopeItem :=
  [.entry ⟨"OurTrial", .trial⟩,
   .constraint .clinicianSpeaksPatient]

abbrev clinicItems : List ScopeItem :=
  [.entry ⟨"ValClinic", .clinic⟩,
   .entry ⟨"Allen", .clinician⟩,
   .constraint .clinicInPatientCity,
   .constraint .clinicianAssigned,
   .constraint .trialApprovesClinic]

abbrev trialExt : Ctx := [ClinicalTrial "OurTrial"]
abbrev clinicExt : Ctx := [Clinic "ValClinic"]

-- ── Obligation types ──────────────────────────────────────────────────────

abbrev trialObligations : List Type := []

/-- Clinic obligations: clinicInPatientCity fires for both Jose and Maria.
    clinicianAssigned and trialApprovesClinic fire for Allen/ValClinic.
    clinicianSpeaksPatient (from trial) fires for Allen × {Jose, Maria}. -/
abbrev clinicObligations : List Type :=
  [ClinicCityEvidence "ValClinic" "Jose",
   ClinicCityEvidence "ValClinic" "Maria",
   assigned (Human.mk "Allen") (Clinic.mk "ValClinic"),
   trialApproves (ClinicalTrial.mk "OurTrial") (Clinic.mk "ValClinic"),
   SharedLangEvidence "Allen" "Jose",
   SharedLangEvidence "Allen" "Maria"]

/-- Evidence that ValClinic is in Valencia where Maria lives.
    (For this example we assume Maria also lives in Valencia.) -/
axiom maria_lives_valencia : lives (Human.mk "Maria") (City.mk "Valencia")
axiom maria_speaks_spanish : speaks (Human.mk "Maria") (Language.mk "Spanish")

noncomputable def valClinicMariaCityEvidence : ClinicCityEvidence "ValClinic" "Maria" :=
  { city := "Valencia", cIsIn := valClinic_in_valencia, pLives := maria_lives_valencia }

noncomputable def allenMariaLangEvidence : SharedLangEvidence "Allen" "Maria" :=
  { lang := "Spanish", cSpeaks := allen_speaks_spanish, pSpeaks := maria_speaks_spanish }

-- ── Inside clinic context ───────────────────────────────────────────────────

/-- Context inside trial + clinic scopes (no room scope in drug scenario).
    Index  Type
    0      Clinic "ValClinic"
    1      ClinicalTrial "OurTrial"
    2      Clinician "Allen"
    3      Patient "Jose"
    4      Patient "Maria" -/
abbrev insideClinic : Ctx :=
  clinicExt ++ (trialExt ++ drugCtx)

abbrev clinicState : ScopeState :=
  clinicItems ++ (trialItems ++ initState)

-- ── Supply room scope items ─────────────────────────────────────────────────

abbrev supplyRoomItems : List ScopeItem :=
  [.entry ⟨"SupplyRoom", .room⟩,
   .entry ⟨"Vial", .vial⟩]

abbrev supplyRoomObligations : List Type := []

-- ── Abbreviations for contexts ────────────────────────────────────────────

abbrev Γ₀ : Ctx := insideClinic

-- ── Supply room visit 1: draw dose for Jose ─────────────────────────────────
-- Inner context: [Vial 2] ++ Γ₀.  Draw produces DrugDose + DoseObligation + Vial 1,
-- drop stale Vial 2, rearrange to [Vial 1, DrugDose, DoseObligation] ++ Γ₀.

def drawDoseJose : Arrow ([Vial 2] ++ Γ₀)
    (([Vial 2] ++ Γ₀) ++ [DrugDose "Jose", DoseObligation "Jose", Vial 1]) :=
  mkArrow "drawDoseJose" [Vial 2] [DrugDose "Jose", DoseObligation "Jose", Vial 1]
    (.bind (Vial.mk 2) (by elem_tac) .nil)

def dropVial2 : Split (([Vial 2] ++ Γ₀) ++ [DrugDose "Jose", DoseObligation "Jose", Vial 1])
                       [Vial 2] (Γ₀ ++ [DrugDose "Jose", DoseObligation "Jose", Vial 1]) :=
  .left (Split.idRight (Γ₀ ++ [DrugDose "Jose", DoseObligation "Jose", Vial 1]))

def reorderJose : Arrow ([DrugDose "Jose", DoseObligation "Jose", Vial 1] ++ Γ₀)
    ([Vial 1, DrugDose "Jose", DoseObligation "Jose"] ++ Γ₀) :=
  Arrow.par
    (Arrow.swap (Γ₁ := [DrugDose "Jose", DoseObligation "Jose"]) (Γ₂ := [Vial 1]))
    (Arrow.id (Γ := Γ₀))

def supplyVisit1 : SheetDiagram clinicState Γ₀ clinicState
    [[DrugDose "Jose", DoseObligation "Jose"] ++ Γ₀] :=
  .scope "supply-room" supplyRoomItems [Vial 2] [Vial 1] clinicState
    supplyRoomObligations PUnit.unit
    (.pipe drawDoseJose
      (.pipe (.drop dropVial2)
        (.pipe (Arrow.swap (Γ₁ := Γ₀) (Γ₂ := [DrugDose "Jose", DoseObligation "Jose", Vial 1]))
          (.arrow reorderJose))))

-- ── Administer dose to Jose + cap ──────────────────────────────────────────

abbrev afterSupply1 : Ctx := [DrugDose "Jose", DoseObligation "Jose"] ++ Γ₀

def administerJose : Arrow afterSupply1 (afterSupply1 ++ [AdminRecord "Jose"]) :=
  mkArrow "administerJose" [DrugDose "Jose", Patient "Jose"] [AdminRecord "Jose"]
    (.bind (DrugDose.mk "Jose") (by elem_tac)
      (.bind (Patient.mk "Jose") (by elem_tac) .nil))

def dropUsedDoseJose : Split (afterSupply1 ++ [AdminRecord "Jose"])
                              [DrugDose "Jose"]
                              ([DoseObligation "Jose"] ++ Γ₀ ++ [AdminRecord "Jose"]) :=
  .left (Split.idRight ([DoseObligation "Jose"] ++ Γ₀ ++ [AdminRecord "Jose"]))

/-- Split for cap: extract DoseObligation and AdminRecord, leaving Γ₀.
    Context order: [DoseObligation "Jose", ...Γ₀..., AdminRecord "Jose"]
    DoseObligation → left, Γ₀ (5 items) → right, AdminRecord → left. -/
def capSplitJose : Split ([DoseObligation "Jose"] ++ Γ₀ ++ [AdminRecord "Jose"])
                          [DoseObligation "Jose", AdminRecord "Jose"] Γ₀ :=
  .left (.right (.right (.right (.right (.right (.left .nil))))))

/-- Dose cycle for Jose: administer, drop used dose, cap obligation with record.
    Returns to Γ₀ (clean — no AdminRecords accumulate). -/
def doseCycleJose : SheetDiagram clinicState afterSupply1 clinicState [Γ₀] :=
  .seq (.arrow (administerJose ⟫ .drop dropUsedDoseJose))
    (.cap "dose-delivered-jose" (DoseObligation "Jose") (AdminRecord "Jose") capSplitJose)

-- ── Supply room visit 2: draw dose for Maria ────────────────────────────────
-- Starts from Γ₀ (clean context after Jose's cap).

def drawDoseMaria : Arrow ([Vial 1] ++ Γ₀)
    (([Vial 1] ++ Γ₀) ++ [DrugDose "Maria", DoseObligation "Maria", Vial 0]) :=
  mkArrow "drawDoseMaria" [Vial 1] [DrugDose "Maria", DoseObligation "Maria", Vial 0]
    (.bind (Vial.mk 1) (by elem_tac) .nil)

def dropVial1 : Split (([Vial 1] ++ Γ₀) ++ [DrugDose "Maria", DoseObligation "Maria", Vial 0])
                       [Vial 1] (Γ₀ ++ [DrugDose "Maria", DoseObligation "Maria", Vial 0]) :=
  .left (Split.idRight (Γ₀ ++ [DrugDose "Maria", DoseObligation "Maria", Vial 0]))

def reorderMaria : Arrow ([DrugDose "Maria", DoseObligation "Maria", Vial 0] ++ Γ₀)
    ([Vial 0, DrugDose "Maria", DoseObligation "Maria"] ++ Γ₀) :=
  Arrow.par
    (Arrow.swap (Γ₁ := [DrugDose "Maria", DoseObligation "Maria"]) (Γ₂ := [Vial 0]))
    (Arrow.id (Γ := Γ₀))

def supplyVisit2 : SheetDiagram clinicState Γ₀ clinicState
    [[DrugDose "Maria", DoseObligation "Maria"] ++ Γ₀] :=
  .scope "supply-room" supplyRoomItems [Vial 1] [Vial 0] clinicState
    supplyRoomObligations PUnit.unit
    (.pipe drawDoseMaria
      (.pipe (.drop dropVial1)
        (.pipe (Arrow.swap (Γ₁ := Γ₀) (Γ₂ := [DrugDose "Maria", DoseObligation "Maria", Vial 0]))
          (.arrow reorderMaria))))

-- ── Administer dose to Maria + cap ─────────────────────────────────────────

abbrev afterSupply2 : Ctx := [DrugDose "Maria", DoseObligation "Maria"] ++ Γ₀

def administerMaria : Arrow afterSupply2 (afterSupply2 ++ [AdminRecord "Maria"]) :=
  mkArrow "administerMaria" [DrugDose "Maria", Patient "Maria"] [AdminRecord "Maria"]
    (.bind (DrugDose.mk "Maria") (by elem_tac)
      (.bind (Patient.mk "Maria") (by elem_tac) .nil))

def dropUsedDoseMaria : Split (afterSupply2 ++ [AdminRecord "Maria"])
                               [DrugDose "Maria"]
                               ([DoseObligation "Maria"] ++ Γ₀ ++ [AdminRecord "Maria"]) :=
  .left (Split.idRight ([DoseObligation "Maria"] ++ Γ₀ ++ [AdminRecord "Maria"]))

/-- Split for cap: extract DoseObligation and AdminRecord, leaving Γ₀. -/
def capSplitMaria : Split ([DoseObligation "Maria"] ++ Γ₀ ++ [AdminRecord "Maria"])
                           [DoseObligation "Maria", AdminRecord "Maria"] Γ₀ :=
  .left (.right (.right (.right (.right (.right (.left .nil))))))

/-- Dose cycle for Maria: administer, drop used dose, cap obligation with record. -/
def doseCycleMaria : SheetDiagram clinicState afterSupply2 clinicState [Γ₀] :=
  .seq (.arrow (administerMaria ⟫ .drop dropUsedDoseMaria))
    (.cap "dose-delivered-maria" (DoseObligation "Maria") (AdminRecord "Maria") capSplitMaria)

-- ── Supply room visit 3: discard empty vial ─────────────────────────────────
-- Starts from Γ₀ (clean context after Maria's cap).

def dropEmptyVial : Split ([Vial 0] ++ Γ₀) [Vial 0] Γ₀ :=
  .left (Split.idRight Γ₀)

def supplyVisit3 : SheetDiagram clinicState Γ₀ clinicState [Γ₀] :=
  .scope "supply-room" supplyRoomItems [Vial 0] ([] : Ctx) clinicState
    supplyRoomObligations PUnit.unit
    (.arrow (.drop dropEmptyVial))

-- ── Full drug pipeline ──────────────────────────────────────────────────────

/-- The complete two-patient drug administration pipeline with fission pattern:
    1. Supply room visit 1: draw dose for Jose (Vial 2 → Vial 1, produces DoseObligation)
    2. Administer to Jose, drop used dose, cap obligation with AdminRecord → Γ₀
    3. Supply room visit 2: draw dose for Maria (Vial 1 → Vial 0, produces DoseObligation)
    4. Administer to Maria, drop used dose, cap obligation with AdminRecord → Γ₀
    5. Supply room visit 3: discard empty vial → Γ₀
    Cap cancels (AdminRecord, DoseObligation) pairs — pipeline returns to clean Γ₀. -/
def drugPipeline : SheetDiagram clinicState Γ₀ clinicState [Γ₀] :=
  .seq supplyVisit1
    (.seq doseCycleJose
      (.seq supplyVisit2
        (.seq doseCycleMaria
          supplyVisit3)))

/-- The full pipeline with trial + clinic scopes wrapping the drug pipeline.
    Output is clean `drugCtx` — no AdminRecords accumulate (consumed by cap). -/
noncomputable def fullDrugPipeline : SheetDiagram initState drugCtx initState [drugCtx] :=
  .scope "trial" trialItems trialExt trialExt initState
    trialObligations PUnit.unit
    (.scope "clinic" clinicItems clinicExt clinicExt (trialItems ++ initState)
      clinicObligations
      (valClinicJoseCityEvidence, valClinicMariaCityEvidence,
       allen_assigned_val, trial_approves_val,
       allenJoseLangEvidence, allenMariaLangEvidence)
      drugPipeline)

end DrugExample
