/-
  JoseTrial SoA — comprehensive reference example covering all iteration cases.

  Three interaction types:
    1. Screening visit      — one-shot (no repetition)
    2. Drug administration   — bounded μ-iteration (3 weekly doses)
    3. Weekly checkup        — unbounded ν-iteration (weekly until death)

  Run: lake env lean test/SoA/JoseTrial.lean
-/
import WorldModel.KB.Arrow.Obligation

namespace SoAExamples

def joseTrialSoA : SoA :=
  { name := "OurTrial"
    interactions :=
      [{ id := "screening", name := "Screening Visit"
         phase := .screening
         timing := { nominalDay := 0 } }
      ,{ id := "drugDose", name := "Drug Administration"
         phase := .treatment
         timing := { nominalDay := 7, windowBefore := 2, windowAfter := 2 }
         repeating := some (.every 7 (.fixed 3)) }
      ,{ id := "weeklyCheckup", name := "Weekly Checkup"
         phase := .followUp
         timing := { nominalDay := 0 }
         repeating := some (.every 7 .death) }]
    activities :=
      [{ id := "consent",       name := "Informed consent",     category := .initiation }
      ,{ id := "physicalExam",  name := "Physical examination", category := .clinical }
      ,{ id := "vitalSigns",   name := "Vital signs",          category := .clinical }
      ,{ id := "assessment",    name := "Clinical assessment",  category := .clinical }
      ,{ id := "drugAdmin",    name := "Drug administration",  category := .intervention }
      ,{ id := "aeCollection", name := "Adverse events",       category := .safety }
      ,{ id := "survivalCheck", name := "Survival status",      category := .safety }
      ,{ id := "disqualify",   name := "Disqualification",     category := .initiation }]
    edges :=
      -- follows (stream succession)
      [SoAEdge.follows "screening" "drugDose" { minDays := 5, maxDays := some 9 }
      ,SoAEdge.follows "drugDose" "weeklyCheckup" { minDays := 0 }
      -- performs: screening
      ,SoAEdge.performs "screening" "consent"      .required
      ,SoAEdge.performs "screening" "physicalExam" .required
      ,SoAEdge.performs "screening" "vitalSigns"   .required
      ,SoAEdge.performs "screening" "assessment"   .required
      ,SoAEdge.performs "screening" "disqualify"   (.conditional "if exclusion criteria met")
      -- performs: drugDose
      ,SoAEdge.performs "drugDose" "drugAdmin"    .required
      ,SoAEdge.performs "drugDose" "vitalSigns"   .required
      ,SoAEdge.performs "drugDose" "aeCollection" .required
      -- performs: weeklyCheckup
      ,SoAEdge.performs "weeklyCheckup" "vitalSigns"    .required
      ,SoAEdge.performs "weeklyCheckup" "assessment"    .required
      ,SoAEdge.performs "weeklyCheckup" "aeCollection"  .required
      ,SoAEdge.performs "weeklyCheckup" "survivalCheck" .required
      -- requires (activity dependencies)
      ,SoAEdge.requires "physicalExam" "consent"
      ,SoAEdge.requires "drugAdmin"    "consent"
      ,SoAEdge.requires "assessment"   "physicalExam"] }

-- ── Smoke tests ──────────────────────────────────────────────────────────

#eval joseTrialSoA.interactions.length           -- 3
#eval joseTrialSoA.activities.length             -- 8
#eval joseTrialSoA.repeatingInteractions.length  -- 2

#eval (joseTrialSoA.activitiesAt "screening").length     -- 5
#eval (joseTrialSoA.activitiesAt "drugDose").length      -- 3
#eval (joseTrialSoA.activitiesAt "weeklyCheckup").length -- 4

#eval (joseTrialSoA.visitsFor "vitalSigns").length  -- 3

#eval joseTrialSoA.interactionIdsUnique  -- true
#eval joseTrialSoA.activityIdsUnique     -- true
#eval joseTrialSoA.edgesValid            -- true

-- Obligation specs: bounded μ + unbounded ν
#eval joseTrialSoA.obligationSpecs
  -- [.bounded "drugDose" 7 3, .unbounded "weeklyCheckup" 7 .death]

-- Catalog coverage (physicalExam, vitalSigns, drugAdmin, aeCollection, survivalCheck not in catalog)
def catalogNames : List String :=
  ["consent", "heartMeasurement", "bpMeasurement", "vo2Measurement",
   "products", "assessment", "disqualify"]

#eval joseTrialSoA.activitiesInCatalog catalogNames  -- false
#eval joseTrialSoA.unknownActivities catalogNames
  -- ["physicalExam", "vitalSigns", "drugAdmin", "aeCollection", "survivalCheck"]

end SoAExamples
