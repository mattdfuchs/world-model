/-
  Osimertinib EGFR/NSCLC SoA — unbounded ν-iteration.
  Phase II/III trial for EGFR-mutant NSCLC.

  Four ν-streams (repeating visits):
    1. Treatment cycles (every 21 days) until progression
    2. Imaging assessments (every 42 days) until progression
    3. Progression follow-up (every 42 days) until end of study
    4. Survival follow-up (every 42 days, phone) until withdrawal

  Demonstrates: concurrent repeating interactions at different frequencies,
  event-driven stream termination, stream succession via follows edges.

  Run: lake env lean test/SoA/Osimertinib.lean
-/
import WorldModel.KB.Arrow.Obligation

namespace SoAExamples

def osimertinibSoA : SoA :=
  { name := "AZD3759-003"
    interactions :=
      [-- One-shot visits
       { id := "screening", name := "Screening"
         phase := .screening
         timing := { nominalDay := -28, windowAfter := 27 } }
      ,{ id := "c1d1",      name := "Cycle 1 Day 1"
         phase := .treatment
         timing := { nominalDay := 0 } }
      ,{ id := "discontinuation", name := "IP Discontinuation / Withdrawal"
         phase := .completion
         timing := { nominalDay := 0 }  -- event-triggered, day is relative
         modality := .onSite }
      ,{ id := "day28fu",   name := "28-day Follow-up"
         phase := .followUp
         timing := { nominalDay := 28 }  -- relative to discontinuation
         modality := .onSite }
       -- Repeating visits (ν-streams)
      ,{ id := "treatmentCycle", name := "Treatment Cycle (C2D1+)"
         phase := .treatment
         timing := { nominalDay := 22, windowBefore := 3, windowAfter := 3 }
         repeating := some (.every 21 .progression) }
      ,{ id := "imagingCycle",  name := "Imaging Assessment"
         phase := .treatment
         timing := { nominalDay := 43, windowBefore := 7, windowAfter := 7 }
         repeating := some (.every 42 .progression) }
      ,{ id := "progressionFU", name := "Progression Follow-up"
         phase := .followUp
         timing := { nominalDay := 0 }  -- starts after progression
         repeating := some (.every 42 .endOfStudy) }
      ,{ id := "survivalFU",    name := "Survival Follow-up"
         phase := .followUp
         timing := { nominalDay := 0 }
         modality := .phone
         repeating := some (.every 42 .withdrawal) }]
    activities :=
      [-- Initiation
       { id := "consent",       name := "Informed consent",               category := .initiation }
      ,{ id := "demographics",  name := "Demography & baseline",          category := .initiation }
      ,{ id := "medHistory",    name := "Medical/surgical history",       category := .initiation }
      ,{ id := "eligibility",   name := "Inclusion/exclusion criteria",   category := .initiation }
      -- Clinical
      ,{ id := "physicalExam",  name := "Physical examination",           category := .clinical }
      ,{ id := "neuroExam",     name := "Neurological examination",       category := .clinical }
      ,{ id := "vitalSigns",    name := "Vital signs",                    category := .clinical }
      ,{ id := "weight",        name := "Weight",                         category := .clinical }
      ,{ id := "ecog",          name := "ECOG Score",                     category := .clinical }
      ,{ id := "ecg",           name := "ECG",                            category := .clinical }
      -- Lab
      ,{ id := "labs",          name := "Clinical chemistry & haematology", category := .labLocal }
      ,{ id := "pregnancyTest", name := "Pregnancy test",                   category := .labLocal }
      ,{ id := "egfrTesting",   name := "EGFR testing",                     category := .labCentral }
      ,{ id := "biomarkers",    name := "Blood-borne biomarker samples",    category := .labCentral }
      -- Intervention
      ,{ id := "dispenseDrug",  name := "Dispense study drug",            category := .intervention }
      ,{ id := "doseDrug",      name := "Dose with study drug",           category := .intervention }
      -- Imaging
      ,{ id := "ctMri",         name := "CT/MRI imaging (mod. RECIST)",   category := .imaging }
      ,{ id := "ophthalmo",     name := "Ophthalmologic assessment",      category := .clinical }
      -- PRO
      ,{ id := "qlqC30",        name := "QLQ C-30",                       category := .pro }
      ,{ id := "qlqBN20",       name := "QLQ BN-20",                      category := .pro }
      ,{ id := "mmse",          name := "MMSE",                           category := .pro }
      ,{ id := "rano",          name := "Modified RANO assessment",       category := .pro }
      -- Safety
      ,{ id := "aeCollection",  name := "Adverse events",                 category := .safety }
      ,{ id := "conMeds",       name := "Concomitant medication",         category := .safety }
      ,{ id := "survivalCheck", name := "Survival status check",          category := .safety }]
    edges :=
      -- follows edges (stream succession)
      [SoAEdge.follows "screening"      "c1d1"             { minDays := 1, maxDays := some 28 }
      ,SoAEdge.follows "c1d1"           "treatmentCycle"    { minDays := 18, maxDays := some 24 }
      ,SoAEdge.follows "c1d1"           "imagingCycle"      { minDays := 39, maxDays := some 49 }
      ,SoAEdge.follows "treatmentCycle" "discontinuation"   { minDays := 0 }  -- on progression
      ,SoAEdge.follows "imagingCycle"   "discontinuation"   { minDays := 0 }  -- on progression
      ,SoAEdge.follows "discontinuation" "day28fu"          { minDays := 25, maxDays := some 31 }
      ,SoAEdge.follows "discontinuation" "progressionFU"    { minDays := 0 }
      ,SoAEdge.follows "progressionFU"  "survivalFU"        { minDays := 0 }
      -- screening activities
      ,SoAEdge.performs "screening" "consent"       .required
      ,SoAEdge.performs "screening" "demographics"  .required
      ,SoAEdge.performs "screening" "medHistory"    .required
      ,SoAEdge.performs "screening" "eligibility"   .required
      ,SoAEdge.performs "screening" "physicalExam"  .required
      ,SoAEdge.performs "screening" "neuroExam"     .required
      ,SoAEdge.performs "screening" "ophthalmo"     .required
      ,SoAEdge.performs "screening" "vitalSigns"    .required
      ,SoAEdge.performs "screening" "weight"        .required
      ,SoAEdge.performs "screening" "ecog"          .required
      ,SoAEdge.performs "screening" "ecg"           .required
      ,SoAEdge.performs "screening" "labs"          .required
      ,SoAEdge.performs "screening" "pregnancyTest" .required
      ,SoAEdge.performs "screening" "egfrTesting"   .required
      ,SoAEdge.performs "screening" "ctMri"         .required
      ,SoAEdge.performs "screening" "biomarkers"    .optional
      ,SoAEdge.performs "screening" "qlqC30"        .required
      ,SoAEdge.performs "screening" "qlqBN20"       .required
      ,SoAEdge.performs "screening" "mmse"          .required
      ,SoAEdge.performs "screening" "rano"          .required
      -- C1D1 activities
      ,SoAEdge.performs "c1d1" "eligibility"   .required
      ,SoAEdge.performs "c1d1" "neuroExam"     .required
      ,SoAEdge.performs "c1d1" "vitalSigns"    .required
      ,SoAEdge.performs "c1d1" "weight"        .required
      ,SoAEdge.performs "c1d1" "ecog"          .required
      ,SoAEdge.performs "c1d1" "ecg"           .required
      ,SoAEdge.performs "c1d1" "labs"          .required
      ,SoAEdge.performs "c1d1" "pregnancyTest" .required
      ,SoAEdge.performs "c1d1" "dispenseDrug"  .required
      ,SoAEdge.performs "c1d1" "doseDrug"      .required
      -- treatment cycle (C2D1+, repeats every 21 days)
      ,SoAEdge.performs "treatmentCycle" "neuroExam"    .required
      ,SoAEdge.performs "treatmentCycle" "physicalExam" .required
      ,SoAEdge.performs "treatmentCycle" "vitalSigns"   .required
      ,SoAEdge.performs "treatmentCycle" "weight"       .required
      ,SoAEdge.performs "treatmentCycle" "ecog"         .required
      ,SoAEdge.performs "treatmentCycle" "ecg"          .required
      ,SoAEdge.performs "treatmentCycle" "labs"         .required
      ,SoAEdge.performs "treatmentCycle" "dispenseDrug" .required
      ,SoAEdge.performs "treatmentCycle" "doseDrug"     .required
      ,SoAEdge.performs "treatmentCycle" "aeCollection" .required
      ,SoAEdge.performs "treatmentCycle" "conMeds"      .required
      -- imaging cycle (every 42 days, concurrent with treatment)
      ,SoAEdge.performs "imagingCycle" "ctMri"      .required
      ,SoAEdge.performs "imagingCycle" "qlqC30"     .required
      ,SoAEdge.performs "imagingCycle" "qlqBN20"    .required
      ,SoAEdge.performs "imagingCycle" "mmse"       .required
      ,SoAEdge.performs "imagingCycle" "rano"       .required
      ,SoAEdge.performs "imagingCycle" "biomarkers" (.frequency "every 12 weeks")
      -- discontinuation
      ,SoAEdge.performs "discontinuation" "physicalExam"  .required
      ,SoAEdge.performs "discontinuation" "vitalSigns"    .required
      ,SoAEdge.performs "discontinuation" "ecog"          .required
      ,SoAEdge.performs "discontinuation" "labs"          .required
      ,SoAEdge.performs "discontinuation" "pregnancyTest" .required
      ,SoAEdge.performs "discontinuation" "ophthalmo"     .required
      ,SoAEdge.performs "discontinuation" "aeCollection"  .required
      ,SoAEdge.performs "discontinuation" "conMeds"       .required
      -- progression follow-up (repeats every 42 days)
      ,SoAEdge.performs "progressionFU" "ctMri"         .required
      ,SoAEdge.performs "progressionFU" "qlqC30"        .optional
      ,SoAEdge.performs "progressionFU" "qlqBN20"       .optional
      ,SoAEdge.performs "progressionFU" "mmse"          .optional
      ,SoAEdge.performs "progressionFU" "rano"          .optional
      ,SoAEdge.performs "progressionFU" "aeCollection"  (.conditional "if prior to 28-day follow-up")
      ,SoAEdge.performs "progressionFU" "conMeds"       (.conditional "if prior to 28-day follow-up")
      -- survival follow-up (phone, repeats every 42 days)
      ,SoAEdge.performs "survivalFU" "survivalCheck" .required] }

-- ── Smoke tests ──────────────────────────────────────────────────────────

#eval osimertinibSoA.interactions.length  -- 8
#eval osimertinibSoA.activities.length    -- 25
#eval osimertinibSoA.repeatingInteractions.length  -- 4
#eval (osimertinibSoA.activitiesAt "treatmentCycle").length  -- 11
#eval (osimertinibSoA.activitiesAt "imagingCycle").length    -- 6
#eval (osimertinibSoA.visitsFor "ctMri").length  -- 3 (screening, imagingCycle, progressionFU)
#eval osimertinibSoA.interactionIdsUnique  -- true
#eval osimertinibSoA.activityIdsUnique     -- true
#eval osimertinibSoA.edgesValid            -- true

-- 4 ν-streams with obligation specs
#eval osimertinibSoA.obligationSpecs
-- [unbounded "treatmentCycle" 21 .progression,
--  unbounded "imagingCycle" 42 .progression,
--  unbounded "progressionFU" 42 .endOfStudy,
--  unbounded "survivalFU" 42 .withdrawal]

-- Catalog validation: current ActionCatalog only covers JoseExample actions
def catalogNames : List String :=
  ["consent", "heartMeasurement", "bpMeasurement", "vo2Measurement",
   "products", "assessment", "disqualify"]

#eval osimertinibSoA.activitiesInCatalog catalogNames  -- false
#eval osimertinibSoA.unknownActivities catalogNames
-- ["demographics", "medHistory", "eligibility", "physicalExam",
--  "neuroExam", "vitalSigns", "weight", "ecog", "ecg",
--  "labs", "pregnancyTest", "egfrTesting", "biomarkers",
--  "dispenseDrug", "doseDrug", "ctMri", "ophthalmo",
--  "qlqC30", "qlqBN20", "mmse", "rano",
--  "aeCollection", "conMeds", "survivalCheck"]

end SoAExamples
