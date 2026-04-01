/-
  TJ301 Ulcerative Colitis SoA — bounded biweekly treatment.
  Phase II trial: run-in → screening → 6 biweekly infusions → EOT → follow-up.
  90 patients, Q2W dosing (Days 0, 14, 28, 42, 56, 70), Week 12 end,
  Week 15 safety follow-up.

  Visits are explicitly unrolled (visit3 through visit7) — no RepeatPattern.

  Run: lake env lean test/SoA/TJ301.lean
-/
import WorldModel.KB.Arrow.Obligation

namespace SoAExamples

def tj301SoA : SoA :=
  { name := "TJ301-UC"
    interactions :=
      [{ id := "runIn",     name := "Run-in Visit"
         phase := .screening
         timing := { nominalDay := -42 }
         modality := .onSite }
      ,{ id := "screening", name := "Screening Visit"
         phase := .screening
         timing := { nominalDay := -28, windowAfter := 27 } }
      ,{ id := "baseline",  name := "Randomisation / Baseline"
         phase := .baseline
         timing := { nominalDay := 0 } }
      ,{ id := "visit3",    name := "Visit 3 (Week 2)"
         phase := .treatment
         timing := { nominalDay := 14, windowBefore := 3, windowAfter := 3 } }
      ,{ id := "visit4",    name := "Visit 4 (Week 4)"
         phase := .treatment
         timing := { nominalDay := 28, windowBefore := 3, windowAfter := 3 } }
      ,{ id := "visit5",    name := "Visit 5 (Week 6)"
         phase := .treatment
         timing := { nominalDay := 42, windowBefore := 3, windowAfter := 3 } }
      ,{ id := "visit6",    name := "Visit 6 (Week 8)"
         phase := .treatment
         timing := { nominalDay := 56, windowBefore := 3, windowAfter := 3 } }
      ,{ id := "visit7",    name := "Visit 7 (Week 10)"
         phase := .treatment
         timing := { nominalDay := 70, windowBefore := 3, windowAfter := 3 } }
      ,{ id := "eot",       name := "End of Treatment (Week 12)"
         phase := .treatment
         timing := { nominalDay := 84, windowBefore := 3, windowAfter := 3 } }
      ,{ id := "followUp",  name := "Safety Follow-up (Week 15)"
         phase := .followUp
         timing := { nominalDay := 105, windowBefore := 5, windowAfter := 5 } }]
    activities :=
      [{ id := "consent",       name := "Informed consent",                  category := .initiation }
      ,{ id := "eligibility",   name := "Inclusion/exclusion criteria",      category := .initiation }
      ,{ id := "randomization", name := "Randomisation",                     category := .initiation }
      ,{ id := "vitalSigns",    name := "Vital signs",                       category := .clinical }
      ,{ id := "physicalExam",  name := "Physical examination",              category := .clinical }
      ,{ id := "labs",          name := "Clinical chemistry & haematology",  category := .labLocal }
      ,{ id := "endoscopy",     name := "Endoscopy with biopsy",             category := .clinical }
      ,{ id := "mayoScore",     name := "Mayo score assessment",             category := .clinical }
      ,{ id := "infusion",      name := "Study drug infusion (TJ301/placebo)", category := .intervention }
      ,{ id := "aeCollection",  name := "Adverse event collection",          category := .safety }
      ,{ id := "conMeds",       name := "Concomitant medications",           category := .safety }
      ,{ id := "pk",            name := "PK blood sampling",                 category := .labCentral }]
    edges :=
      -- follows edges (visit sequencing)
      [SoAEdge.follows "runIn"     "screening" { minDays := 0 }
      ,SoAEdge.follows "screening" "baseline"  { minDays := 1, maxDays := some 28 }
      ,SoAEdge.follows "baseline"  "visit3"    { minDays := 11, maxDays := some 17 }
      ,SoAEdge.follows "visit3"    "visit4"    { minDays := 11, maxDays := some 17 }
      ,SoAEdge.follows "visit4"    "visit5"    { minDays := 11, maxDays := some 17 }
      ,SoAEdge.follows "visit5"    "visit6"    { minDays := 11, maxDays := some 17 }
      ,SoAEdge.follows "visit6"    "visit7"    { minDays := 11, maxDays := some 17 }
      ,SoAEdge.follows "visit7"    "eot"       { minDays := 11, maxDays := some 17 }
      ,SoAEdge.follows "eot"       "followUp"  { minDays := 16, maxDays := some 26 }
      -- screening activities
      ,SoAEdge.performs "screening" "consent"      .required
      ,SoAEdge.performs "screening" "eligibility"  .required
      ,SoAEdge.performs "screening" "vitalSigns"   .required
      ,SoAEdge.performs "screening" "physicalExam" .required
      ,SoAEdge.performs "screening" "labs"         .required
      ,SoAEdge.performs "screening" "endoscopy"    .required
      ,SoAEdge.performs "screening" "mayoScore"    .required
      ,SoAEdge.performs "screening" "conMeds"      .required
      -- baseline activities
      ,SoAEdge.performs "baseline" "randomization" .required
      ,SoAEdge.performs "baseline" "vitalSigns"    .required
      ,SoAEdge.performs "baseline" "labs"          .required
      ,SoAEdge.performs "baseline" "infusion"      .required
      ,SoAEdge.performs "baseline" "aeCollection"  .required
      ,SoAEdge.performs "baseline" "pk"            (.conditional "PK subgroup only")
      -- treatment visits (3-7): infusion + monitoring
      ,SoAEdge.performs "visit3" "vitalSigns"   .required
      ,SoAEdge.performs "visit3" "labs"         .required
      ,SoAEdge.performs "visit3" "mayoScore"    .required
      ,SoAEdge.performs "visit3" "infusion"     .required
      ,SoAEdge.performs "visit3" "aeCollection" .required
      ,SoAEdge.performs "visit3" "conMeds"      .required
      ,SoAEdge.performs "visit4" "vitalSigns"   .required
      ,SoAEdge.performs "visit4" "labs"         .required
      ,SoAEdge.performs "visit4" "infusion"     .required
      ,SoAEdge.performs "visit4" "aeCollection" .required
      ,SoAEdge.performs "visit4" "conMeds"      .required
      ,SoAEdge.performs "visit5" "vitalSigns"   .required
      ,SoAEdge.performs "visit5" "labs"         .required
      ,SoAEdge.performs "visit5" "infusion"     .required
      ,SoAEdge.performs "visit5" "aeCollection" .required
      ,SoAEdge.performs "visit5" "conMeds"      .required
      ,SoAEdge.performs "visit6" "vitalSigns"   .required
      ,SoAEdge.performs "visit6" "labs"         .required
      ,SoAEdge.performs "visit6" "mayoScore"    .required
      ,SoAEdge.performs "visit6" "infusion"     .required
      ,SoAEdge.performs "visit6" "aeCollection" .required
      ,SoAEdge.performs "visit6" "conMeds"      .required
      ,SoAEdge.performs "visit7" "vitalSigns"   .required
      ,SoAEdge.performs "visit7" "labs"         .required
      ,SoAEdge.performs "visit7" "infusion"     .required
      ,SoAEdge.performs "visit7" "aeCollection" .required
      ,SoAEdge.performs "visit7" "conMeds"      .required
      -- end of treatment
      ,SoAEdge.performs "eot" "vitalSigns"   .required
      ,SoAEdge.performs "eot" "labs"         .required
      ,SoAEdge.performs "eot" "endoscopy"    .required
      ,SoAEdge.performs "eot" "mayoScore"    .required
      ,SoAEdge.performs "eot" "aeCollection" .required
      ,SoAEdge.performs "eot" "conMeds"      .required
      ,SoAEdge.performs "eot" "pk"           (.conditional "PK subgroup only")
      -- follow-up
      ,SoAEdge.performs "followUp" "vitalSigns"   .required
      ,SoAEdge.performs "followUp" "aeCollection" .required
      ,SoAEdge.performs "followUp" "conMeds"      .required
      -- activity dependencies
      ,SoAEdge.requires "randomization" "consent"
      ,SoAEdge.requires "randomization" "eligibility"
      ,SoAEdge.requires "infusion"      "randomization"] }

-- ── Smoke tests ──────────────────────────────────────────────────────────

#eval tj301SoA.interactions.length  -- 10
#eval tj301SoA.activities.length    -- 12
#eval (tj301SoA.activitiesAt "eot").length  -- 7
#eval (tj301SoA.visitsFor "infusion").length  -- 6
#eval tj301SoA.interactionIdsUnique  -- true
#eval tj301SoA.activityIdsUnique     -- true
#eval tj301SoA.edgesValid            -- true

-- Visits are explicitly unrolled → no obligation specs
#eval tj301SoA.obligationSpecs           -- []

-- Catalog validation: current ActionCatalog only covers JoseExample actions
def catalogNames : List String :=
  ["consent", "heartMeasurement", "bpMeasurement", "vo2Measurement",
   "products", "assessment", "disqualify"]

#eval tj301SoA.activitiesInCatalog catalogNames  -- false
#eval tj301SoA.unknownActivities catalogNames
-- ["eligibility", "randomization", "vitalSigns", "physicalExam",
--  "labs", "endoscopy", "mayoScore", "infusion",
--  "aeCollection", "conMeds", "pk"]

end SoAExamples
