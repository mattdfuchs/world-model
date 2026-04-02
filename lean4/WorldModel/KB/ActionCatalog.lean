/-
  WorldModel.KB.ActionCatalog
  Action catalog, isA hierarchy, and entity-scoped constraints for the KB.

  This module defines the data that both agents query from Neo4j:
  - Constraint nodes (english + leanType for Designer / Proof agents)
  - Category nodes (Equipment, Qualification, Measurement)
  - Output type nodes (ConsentGiven, HeartRate, etc.)
  - ActionSpec nodes with REQUIRES/PRODUCES edges
  - isA, qualificationFor, equipmentFor, imposesConstraint edges
-/
import WorldModel.KB.Neo4j

open Neo4jRepr

-- ── Constraint descriptions ─────────────────────────────────────────────────

structure ConstraintDesc where
  name     : String
  english  : String
  leanType : String

def constraints : List ConstraintDesc :=
  [ { name := "sharedLanguage"
      english := "Clinician and patient must share a common language"
      leanType := "SharedLangEvidence" }
  , { name := "examBedQualification"
      english := "Operator must hold ExamBed certification"
      leanType := "ExamBedQual" }
  , { name := "bpMonitorQualification"
      english := "Operator must hold BP monitor certification"
      leanType := "BPMonitorQual" }
  , { name := "vo2Qualification"
      english := "Operator must hold VO2 equipment certification"
      leanType := "VO2EquipmentQual" }
  , { name := "callConfirmed"
      english := "Patient must be called to confirm attendance before each visit"
      leanType := "CallConfirmed" }
  ]

-- ── imposesConstraint edges ─────────────────────────────────────────────────

/-- (sourceLabel, sourceKey, constraintName) -/
def imposesConstraintEdges : List (String × String × String) :=
  [ ("ClinicalTrial", "OurTrial", "sharedLanguage")
  , ("ExamBed",       "",         "examBedQualification")
  , ("BPMonitor",     "",         "bpMonitorQualification")
  , ("VO2Equipment",  "",         "vo2Qualification")
  ]

-- ── Category nodes ──────────────────────────────────────────────────────────

def categoryNodes : List String :=
  ["Equipment", "Qualification", "Measurement"]

-- ── Output type nodes ───────────────────────────────────────────────────────

def outputTypeNodes : List String :=
  [ "ConsentGiven", "HeartRate", "BloodPressure", "VO2Max"
  , "ProductsOutput", "AssessmentResult", "NonQualifying"
  , "AdminRecord", "AEReport", "SurvivalStatus"
  , "CallConfirmed" ]

-- ── isA edges ───────────────────────────────────────────────────────────────

/-- (childLabel, childKey, parentLabel) -/
def isAEdges : List (String × String × String) :=
  -- Equipment
  [ ("ExamBed",          "", "Equipment")
  , ("BPMonitor",        "", "Equipment")
  , ("VO2Equipment",     "", "Equipment")
  -- Qualifications
  , ("ExamBedQual",      "", "Qualification")
  , ("BPMonitorQual",    "", "Qualification")
  , ("VO2EquipmentQual", "", "Qualification")
  -- Measurements
  , ("HeartRate",        "", "Measurement")
  , ("BloodPressure",    "", "Measurement")
  , ("VO2Max",           "", "Measurement")
  ]

-- ── qualificationFor / equipmentFor edges ───────────────────────────────────

/-- (qualLabel, qualKey, equipLabel) -/
def qualificationForEdges : List (String × String × String) :=
  [ ("ExamBedQual",      "", "ExamBed")
  , ("BPMonitorQual",    "", "BPMonitor")
  , ("VO2EquipmentQual", "", "VO2Equipment")
  ]

/-- (equipLabel, equipKey, measurementLabel) -/
def equipmentForEdges : List (String × String × String) :=
  [ ("ExamBed",      "", "HeartRate")
  , ("BPMonitor",    "", "BloodPressure")
  , ("VO2Equipment", "", "VO2Max")
  ]

-- ── Action descriptions ─────────────────────────────────────────────────────

structure ActionDesc where
  name        : String
  description : String

def actions : List ActionDesc :=
  [ { name := "consent",          description := "Obtains informed consent from the patient" }
  , { name := "heartMeasurement", description := "Measures the patient's heart rate using an exam bed" }
  , { name := "bpMeasurement",    description := "Measures the patient's blood pressure using a BP monitor" }
  , { name := "vo2Measurement",   description := "Measures the patient's VO2 max using VO2 equipment" }
  , { name := "products",         description := "Aggregates all measurement results into a single output" }
  , { name := "assessment",       description := "Evaluates aggregated results to determine if patient qualifies" }
  , { name := "disqualify",       description := "Records patient disqualification with a reason" }
  , { name := "drugAdmin",        description := "Administers study drug to patient" }
  , { name := "aeCollection",     description := "Collects adverse event reports from patient" }
  , { name := "survivalCheck",    description := "Checks patient survival status" }
  , { name := "confirmationCall", description := "Phone call to confirm patient attendance before visit" }
  ]

-- ── REQUIRES edges ──────────────────────────────────────────────────────────

/-- (actionName, targetLabel, targetKey, role) -/
def requiresEdges : List (String × String × String × String) :=
  [ ("consent",          "Role",           "Patient",   "subject")
  , ("heartMeasurement", "Role",           "Patient",   "subject")
  , ("heartMeasurement", "Role",           "Clinician", "operator")
  , ("heartMeasurement", "ExamBed",        "",          "equipment")
  , ("bpMeasurement",    "Role",           "Patient",   "subject")
  , ("bpMeasurement",    "Role",           "Clinician", "operator")
  , ("bpMeasurement",    "BPMonitor",      "",          "equipment")
  , ("vo2Measurement",   "Role",           "Patient",   "subject")
  , ("vo2Measurement",   "Role",           "Clinician", "operator")
  , ("vo2Measurement",   "VO2Equipment",   "",          "equipment")
  , ("products",         "ConsentGiven",   "",          "prerequisite")
  , ("products",         "HeartRate",      "",          "prerequisite")
  , ("products",         "BloodPressure",  "",          "prerequisite")
  , ("products",         "VO2Max",         "",          "prerequisite")
  , ("assessment",       "Role",           "Patient",   "subject")
  , ("assessment",       "ProductsOutput", "",          "prerequisite")
  , ("disqualify",       "Role",           "Patient",   "subject")
  , ("drugAdmin",         "Role",           "Patient",   "subject")
  , ("drugAdmin",         "Role",           "Clinician", "operator")
  , ("aeCollection",      "Role",           "Patient",   "subject")
  , ("aeCollection",      "Role",           "Clinician", "operator")
  , ("survivalCheck",     "Role",           "Patient",   "subject")
  , ("survivalCheck",     "Role",           "Clinician", "operator")
  , ("confirmationCall",  "Role",           "Patient",   "subject")
  ]

-- ── PRODUCES edges ──────────────────────────────────────────────────────────

/-- (actionName, outputLabel) -/
def producesEdges : List (String × String) :=
  [ ("consent",          "ConsentGiven")
  , ("heartMeasurement", "HeartRate")
  , ("bpMeasurement",    "BloodPressure")
  , ("vo2Measurement",   "VO2Max")
  , ("products",         "ProductsOutput")
  , ("assessment",       "AssessmentResult")
  , ("disqualify",       "NonQualifying")
  , ("drugAdmin",         "AdminRecord")
  , ("aeCollection",      "AEReport")
  , ("survivalCheck",     "SurvivalStatus")
  , ("confirmationCall",  "CallConfirmed")
  ]

-- ── Cypher generation ───────────────────────────────────────────────────────

def constraintCypher : List String :=
  constraints.map fun c =>
    (Neo4jRepr.node "Constraint"
      [("name", c.name), ("english", c.english), ("leanType", c.leanType)]).toCypher

def imposesConstraintCypher : List String :=
  imposesConstraintEdges.map fun (srcLabel, srcKey, cName) =>
    (Neo4jRepr.edge "imposesConstraint" srcLabel srcKey "Constraint" cName).toCypher

def categoryCypher : List String :=
  categoryNodes.map fun label => (Neo4jRepr.node label []).toCypher

def outputTypeCypher : List String :=
  outputTypeNodes.map fun label => (Neo4jRepr.node label []).toCypher

def isACypher : List String :=
  isAEdges.map fun (childLabel, childKey, parentLabel) =>
    (Neo4jRepr.edge "isA" childLabel childKey parentLabel "").toCypher

def qualificationForCypher : List String :=
  qualificationForEdges.map fun (qualLabel, qualKey, equipLabel) =>
    (Neo4jRepr.edge "qualificationFor" qualLabel qualKey equipLabel "").toCypher

def equipmentForCypher : List String :=
  equipmentForEdges.map fun (equipLabel, equipKey, measLabel) =>
    (Neo4jRepr.edge "equipmentFor" equipLabel equipKey measLabel "").toCypher

def actionSpecCypher : List String :=
  actions.map fun a =>
    (Neo4jRepr.node "ActionSpec" [("name", a.name), ("description", a.description)]).toCypher

def requiresCypher : List String :=
  requiresEdges.map fun (actionName, tgtLabel, tgtKey, role) =>
    (Neo4jRepr.edge "REQUIRES" "ActionSpec" actionName tgtLabel tgtKey
      [("role", role)]).toCypher

def producesCypher : List String :=
  producesEdges.map fun (actionName, outLabel) =>
    (Neo4jRepr.edge "PRODUCES" "ActionSpec" actionName outLabel "").toCypher

-- ── REQUIRES_EVIDENCE edges (constraint → output type it demands) ─────────

/-- Maps constraints to the output types they require in context.
    Static constraints (satisfied by KB facts) have no entry here.
    Activity constraints need an action that PRODUCES the required type. -/
def requiresEvidenceEdges : List (String × String) :=
  [ ("callConfirmed", "CallConfirmed") ]

def requiresEvidenceCypher : List String :=
  requiresEvidenceEdges.map fun (constraintName, outputType) =>
    (Neo4jRepr.edge "REQUIRES_EVIDENCE" "Constraint" constraintName outputType "").toCypher

-- ── SoA Activity nodes ────────────────────────────────────────────────────

/-- SoA activity nodes — abstract procedure names from SoA specifications.
    (id, displayName, category) -/
def activityNodes : List (String × String × String) :=
  [ ("consent",       "Informed consent",     "initiation")
  , ("physicalExam",  "Physical examination", "clinical")
  , ("vitalSigns",    "Vital signs",          "clinical")
  , ("assessment",    "Clinical assessment",  "clinical")
  , ("drugAdmin",     "Drug administration",  "intervention")
  , ("aeCollection",  "Adverse events",       "safety")
  , ("survivalCheck", "Survival status",      "safety")
  , ("disqualify",    "Disqualification",     "initiation") ]

def activityNodeCypher : List String :=
  activityNodes.map fun (id, displayName, cat) =>
    (Neo4jRepr.node "Activity" [("name", id), ("displayName", displayName), ("category", cat)]).toCypher

-- ── IMPLEMENTED_BY edges (SoA activity → catalog action) ──────────────────

/-- Mapping from SoA activities to catalog actions.
    One-to-many: compound activities decompose into multiple actions. -/
def implementedByEdges : List (String × String) :=
  [ -- Direct 1:1 mappings
    ("consent",       "consent")
  , ("assessment",    "assessment")
  , ("drugAdmin",     "drugAdmin")
  , ("aeCollection",  "aeCollection")
  , ("survivalCheck", "survivalCheck")
  , ("disqualify",    "disqualify")
    -- Compound: physicalExam → all three measurements
  , ("physicalExam",  "heartMeasurement")
  , ("physicalExam",  "bpMeasurement")
  , ("physicalExam",  "vo2Measurement")
    -- Compound: vitalSigns → heart + BP
  , ("vitalSigns",    "heartMeasurement")
  , ("vitalSigns",    "bpMeasurement") ]

def implementedByCypher : List String :=
  implementedByEdges.map fun (actId, actionName) =>
    (Neo4jRepr.edge "IMPLEMENTED_BY" "Activity" actId "ActionSpec" actionName).toCypher

/-- All catalog Cypher statements in dependency order. -/
def allCatalogCypher : List String :=
  -- Nodes first (constraints, categories, output types, action specs, activities)
  constraintCypher
  ++ categoryCypher
  ++ outputTypeCypher
  ++ actionSpecCypher
  ++ activityNodeCypher
  -- Then edges (depend on nodes existing)
  ++ imposesConstraintCypher
  ++ isACypher
  ++ qualificationForCypher
  ++ equipmentForCypher
  ++ requiresCypher
  ++ producesCypher
  ++ requiresEvidenceCypher
  ++ implementedByCypher

-- ── Smoke tests ─────────────────────────────────────────────────────────────

#eval constraintCypher.length          -- 5
#eval actionSpecCypher.length          -- 11
#eval requiresCypher.length            -- 24
#eval producesCypher.length            -- 11
#eval isACypher.length                 -- 9
#eval activityNodeCypher.length        -- 8
#eval implementedByCypher.length       -- 11
#eval requiresEvidenceCypher.length    -- 1
#eval allCatalogCypher.length          -- 104

#eval do
  for stmt in allCatalogCypher.take 5 do
    IO.println stmt
