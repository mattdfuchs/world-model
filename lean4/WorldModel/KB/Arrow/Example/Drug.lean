/-
  WorldModel.KB.Arrow.Example.Drug
  Two-patient drug administration pipeline with fission pattern.

  Allen administers doses from a Vial 2 to Jose and Maria via three
  supply-room scope visits. Cap cancels (AdminRecord, DoseObligation) pairs
  so the pipeline returns to clean context.
-/
import WorldModel.KB.Arrow.Clinical

open KB.Facts

namespace DrugExample

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

-- ── Trial / Clinic scope items ────────────────────────────────────────────

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
