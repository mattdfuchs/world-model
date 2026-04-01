/-
  JoseTrial SoA — single screening visit.
  Matches the JoseExample pipeline in Clinical.lean:
  consent → heart → BP → VO2 → products → assessment.

  Run: lake env lean test/SoA/JoseTrial.lean
-/
import WorldModel.KB.Arrow.Obligation

namespace SoAExamples

def joseTrialSoA : SoA :=
  { name := "OurTrial"
    interactions :=
      [{ id := "screening", name := "Screening Visit"
         phase := .screening
         timing := { nominalDay := 0 } }]
    activities :=
      [{ id := "consent",          name := "Informed consent",          category := .initiation }
      ,{ id := "heartMeasurement", name := "Heart rate measurement",    category := .clinical }
      ,{ id := "bpMeasurement",    name := "Blood pressure measurement", category := .clinical }
      ,{ id := "vo2Measurement",   name := "VO2 max measurement",       category := .clinical }
      ,{ id := "products",         name := "Aggregate results",         category := .clinical }
      ,{ id := "assessment",       name := "Final assessment",          category := .clinical }]
    edges :=
      -- performs edges (the SoA matrix row)
      [SoAEdge.performs "screening" "consent"          .required
      ,SoAEdge.performs "screening" "heartMeasurement" .required
      ,SoAEdge.performs "screening" "bpMeasurement"    .required
      ,SoAEdge.performs "screening" "vo2Measurement"   .required
      ,SoAEdge.performs "screening" "products"         .required
      ,SoAEdge.performs "screening" "assessment"       .required
      -- activity dependencies
      ,SoAEdge.requires "heartMeasurement" "consent"
      ,SoAEdge.requires "bpMeasurement"    "consent"
      ,SoAEdge.requires "vo2Measurement"   "consent"
      ,SoAEdge.requires "products"         "heartMeasurement"
      ,SoAEdge.requires "products"         "bpMeasurement"
      ,SoAEdge.requires "products"         "vo2Measurement"
      ,SoAEdge.requires "assessment"       "products"] }

-- ── Smoke tests ──────────────────────────────────────────────────────────

#eval joseTrialSoA.interactions.length  -- 1
#eval joseTrialSoA.activities.length    -- 6
#eval (joseTrialSoA.activitiesAt "screening").length  -- 6
#eval joseTrialSoA.interactionIdsUnique  -- true
#eval joseTrialSoA.activityIdsUnique     -- true
#eval joseTrialSoA.edgesValid            -- true

-- No repeating visits → no obligation specs
#eval joseTrialSoA.obligationSpecs       -- []

-- All activities match the ActionCatalog
def catalogNames : List String :=
  ["consent", "heartMeasurement", "bpMeasurement", "vo2Measurement",
   "products", "assessment", "disqualify"]

#eval joseTrialSoA.activitiesInCatalog catalogNames  -- true
#eval joseTrialSoA.unknownActivities catalogNames    -- []

end SoAExamples
