/-
  WorldModel.KB.Neo4j.Instances
  ToNeo4j/FromNeo4j instances for all KB types.
-/
import WorldModel.KB.Neo4j.Derive
import WorldModel.KB.Facts

-- ── Auto-derived: string-indexed entities ────────────────────────────────────

deriving instance ToNeo4j for Human
deriving instance ToNeo4j for Language
deriving instance ToNeo4j for City
deriving instance ToNeo4j for Clinic
deriving instance ToNeo4j for ClinicalTrial
deriving instance ToNeo4j for Room
deriving instance FromNeo4j for Human
deriving instance FromNeo4j for Language
deriving instance FromNeo4j for City
deriving instance FromNeo4j for Clinic
deriving instance FromNeo4j for ClinicalTrial
deriving instance FromNeo4j for Room

-- ── Auto-derived: unit types ─────────────────────────────────────────────────

deriving instance ToNeo4j for ExamBed
deriving instance ToNeo4j for BPMonitor
deriving instance ToNeo4j for VO2Equipment
deriving instance ToNeo4j for ExamBedQual
deriving instance ToNeo4j for BPMonitorQual
deriving instance ToNeo4j for VO2EquipmentQual

deriving instance FromNeo4j for ExamBed
deriving instance FromNeo4j for BPMonitor
deriving instance FromNeo4j for VO2Equipment
deriving instance FromNeo4j for ExamBedQual
deriving instance FromNeo4j for BPMonitorQual
deriving instance FromNeo4j for VO2EquipmentQual

-- ── Auto-derived: relation edges ─────────────────────────────────────────────

deriving instance ToNeo4j for speaks
deriving instance ToNeo4j for lives
deriving instance ToNeo4j for assigned
deriving instance ToNeo4j for isIn
deriving instance ToNeo4j for trialApproves
deriving instance ToNeo4j for clinicHasRoom

deriving instance FromNeo4j for speaks
deriving instance FromNeo4j for lives
deriving instance FromNeo4j for assigned
deriving instance FromNeo4j for isIn
deriving instance FromNeo4j for trialApproves
deriving instance FromNeo4j for clinicHasRoom

-- ── Manual: Role (enum — multiple constructors) ─────────────────────────────

private def roleStr : Role → String
  | .Patient       => "Patient"
  | .Administrator => "Administrator"
  | .Clinician     => "Clinician"

instance : ToNeo4j Role where
  toRepr
    | .Patient       => .node "Role" [("name", "Patient")]
    | .Administrator => .node "Role" [("name", "Administrator")]
    | .Clinician     => .node "Role" [("name", "Clinician")]

instance : FromNeo4j Role where
  fromRepr
    | .node "Role" [("name", v)] =>
      if v == "Patient" then some .Patient
      else if v == "Administrator" then some .Administrator
      else if v == "Clinician" then some .Clinician
      else none
    | _ => none

-- ── Manual: hasRole (edge to enum target) ────────────────────────────────────

instance {h : String} {a : Human h} {r : Role} : ToNeo4j (hasRole a r) where
  toRepr _ := .edge "hasRole" "Human" h "Role" (roleStr r)

instance {h : String} {a : Human h} {r : Role} : FromNeo4j (hasRole a r) where
  fromRepr
    | .edge "hasRole" "Human" sh "Role" sr =>
      if sh == h && sr == roleStr r then some .mk else none
    | _ => none

-- ── Manual: room-equipment edges (unit-type target, empty key) ───────────────

instance {r : String} {room : Room r} {e : ExamBed} : ToNeo4j (roomHasExamBed room e) where
  toRepr _ := .edge "roomHasExamBed" "Room" r "ExamBed" ""

instance {r : String} {room : Room r} {e : ExamBed} : FromNeo4j (roomHasExamBed room e) where
  fromRepr
    | .edge "roomHasExamBed" "Room" sr "ExamBed" _ => if sr == r then some .mk else none
    | _ => none

instance {r : String} {room : Room r} {e : BPMonitor} : ToNeo4j (roomHasBPMonitor room e) where
  toRepr _ := .edge "roomHasBPMonitor" "Room" r "BPMonitor" ""

instance {r : String} {room : Room r} {e : BPMonitor} : FromNeo4j (roomHasBPMonitor room e) where
  fromRepr
    | .edge "roomHasBPMonitor" "Room" sr "BPMonitor" _ => if sr == r then some .mk else none
    | _ => none

instance {r : String} {room : Room r} {e : VO2Equipment} : ToNeo4j (roomHasVO2Equip room e) where
  toRepr _ := .edge "roomHasVO2Equip" "Room" r "VO2Equipment" ""

instance {r : String} {room : Room r} {e : VO2Equipment} : FromNeo4j (roomHasVO2Equip room e) where
  fromRepr
    | .edge "roomHasVO2Equip" "Room" sr "VO2Equipment" _ => if sr == r then some .mk else none
    | _ => none

-- ── Manual: holds-qualification edges (unit-type target, empty key) ─────────

instance {h : String} {person : Human h} {q : ExamBedQual} : ToNeo4j (holdsExamBedQual person q) where
  toRepr _ := .edge "hasQualification" "Human" h "ExamBedQual" ""

instance {h : String} {person : Human h} {q : ExamBedQual} : FromNeo4j (holdsExamBedQual person q) where
  fromRepr
    | .edge "hasQualification" "Human" sh "ExamBedQual" _ => if sh == h then some .mk else none
    | _ => none

instance {h : String} {person : Human h} {q : BPMonitorQual} : ToNeo4j (holdsBPMonitorQual person q) where
  toRepr _ := .edge "hasQualification" "Human" h "BPMonitorQual" ""

instance {h : String} {person : Human h} {q : BPMonitorQual} : FromNeo4j (holdsBPMonitorQual person q) where
  fromRepr
    | .edge "hasQualification" "Human" sh "BPMonitorQual" _ => if sh == h then some .mk else none
    | _ => none

instance {h : String} {person : Human h} {q : VO2EquipmentQual} : ToNeo4j (holdsVO2EquipmentQual person q) where
  toRepr _ := .edge "hasQualification" "Human" h "VO2EquipmentQual" ""

instance {h : String} {person : Human h} {q : VO2EquipmentQual} : FromNeo4j (holdsVO2EquipmentQual person q) where
  fromRepr
    | .edge "hasQualification" "Human" sh "VO2EquipmentQual" _ => if sh == h then some .mk else none
    | _ => none

-- ── Smoke tests ──────────────────────────────────────────────────────────────

-- Entity nodes
#eval ToNeo4j.toRepr (Human.mk "Jose")
#eval ToNeo4j.toRepr ExamBed.mk
#eval ToNeo4j.toRepr Role.Patient

-- Relation edges
#eval ToNeo4j.toRepr (speaks.mk : speaks (Human.mk "Jose") (Language.mk "Spanish"))

-- Cypher output
#eval IO.println (ToNeo4j.toRepr (Human.mk "Jose")).toCypher
#eval IO.println (ToNeo4j.toRepr (speaks.mk : speaks (Human.mk "Jose") (Language.mk "Spanish"))).toCypher

-- Roundtrip checks
#eval (FromNeo4j.fromRepr (ToNeo4j.toRepr (Human.mk "Jose")) : Option (Human "Jose")).isSome
#eval (FromNeo4j.fromRepr (ToNeo4j.toRepr ExamBed.mk) : Option ExamBed).isSome
#eval (FromNeo4j.fromRepr (.node "Human" [("name", "wrong")]) : Option (Human "Jose")).isNone
