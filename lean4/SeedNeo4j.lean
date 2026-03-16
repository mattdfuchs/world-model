/-
  SeedNeo4j.lean
  Generates Cypher MERGE statements for all KB facts and prints them to stdout.
  Run with: lake env lean --run SeedNeo4j.lean
-/
import WorldModel.KB.Neo4j
import WorldModel.KB.ActionCatalog

open Neo4jRepr
open KB.Facts

def allCypher : List String :=
  -- ── Nodes ──────────────────────────────────────────────────────────────────
  -- Humans
  [ (ToNeo4j.toRepr jose).toCypher
  , (ToNeo4j.toRepr rick).toCypher
  , (ToNeo4j.toRepr allen).toCypher
  , (ToNeo4j.toRepr matthew).toCypher
  , (ToNeo4j.toRepr jean).toCypher
  , (ToNeo4j.toRepr george).toCypher
  -- Languages
  , (ToNeo4j.toRepr english).toCypher
  , (ToNeo4j.toRepr spanish).toCypher
  , (ToNeo4j.toRepr french).toCypher
  -- Cities
  , (ToNeo4j.toRepr valencia).toCypher
  , (ToNeo4j.toRepr london).toCypher
  , (ToNeo4j.toRepr nice).toCypher
  , (ToNeo4j.toRepr paris).toCypher
  -- Clinics
  , (ToNeo4j.toRepr valClinic).toCypher
  , (ToNeo4j.toRepr niceClinic).toCypher
  , (ToNeo4j.toRepr parisClinic).toCypher
  , (ToNeo4j.toRepr londonClinic).toCypher
  -- Clinical trials
  , (ToNeo4j.toRepr ourTrial).toCypher
  -- Rooms
  , (ToNeo4j.toRepr (Room.mk "Room3")).toCypher
  , (ToNeo4j.toRepr (Room.mk "Room7")).toCypher
  -- Qualification types (unit types)
  , (ToNeo4j.toRepr ExamBedQual.mk).toCypher
  , (ToNeo4j.toRepr BPMonitorQual.mk).toCypher
  , (ToNeo4j.toRepr VO2EquipmentQual.mk).toCypher
  -- Roles
  , (ToNeo4j.toRepr Role.Patient).toCypher
  , (ToNeo4j.toRepr Role.Administrator).toCypher
  , (ToNeo4j.toRepr Role.Clinician).toCypher
  -- Equipment (unit types)
  , (ToNeo4j.toRepr ExamBed.mk).toCypher
  , (ToNeo4j.toRepr BPMonitor.mk).toCypher
  , (ToNeo4j.toRepr VO2Equipment.mk).toCypher

  -- ── Edges ──────────────────────────────────────────────────────────────────
  -- hasRole
  , (ToNeo4j.toRepr jose_is_patient).toCypher
  , (ToNeo4j.toRepr rick_is_admin).toCypher
  , (ToNeo4j.toRepr allen_is_clinician).toCypher
  , (ToNeo4j.toRepr matthew_is_clinician).toCypher
  , (ToNeo4j.toRepr jean_is_patient).toCypher
  , (ToNeo4j.toRepr george_is_patient).toCypher
  -- speaks
  , (ToNeo4j.toRepr jose_speaks_spanish).toCypher
  , (ToNeo4j.toRepr rick_speaks_english).toCypher
  , (ToNeo4j.toRepr allen_speaks_english).toCypher
  , (ToNeo4j.toRepr allen_speaks_spanish).toCypher
  , (ToNeo4j.toRepr matthew_speaks_english).toCypher
  , (ToNeo4j.toRepr matthew_speaks_french).toCypher
  , (ToNeo4j.toRepr jean_speaks_french).toCypher
  , (ToNeo4j.toRepr george_speaks_english).toCypher
  -- lives
  , (ToNeo4j.toRepr jose_lives_valencia).toCypher
  , (ToNeo4j.toRepr jean_lives_paris).toCypher
  , (ToNeo4j.toRepr george_lives_london).toCypher
  -- assigned
  , (ToNeo4j.toRepr rick_assigned_london).toCypher
  , (ToNeo4j.toRepr allen_assigned_val).toCypher
  , (ToNeo4j.toRepr matthew_assigned_nice).toCypher
  , (ToNeo4j.toRepr matthew_assigned_paris).toCypher
  -- isIn
  , (ToNeo4j.toRepr valClinic_in_valencia).toCypher
  , (ToNeo4j.toRepr niceClinic_in_nice).toCypher
  , (ToNeo4j.toRepr parisClinic_in_paris).toCypher
  , (ToNeo4j.toRepr londonClinic_in_london).toCypher
  -- trialApproves
  , (ToNeo4j.toRepr trial_approves_val).toCypher
  , (ToNeo4j.toRepr trial_approves_paris).toCypher
  -- clinicHasRoom
  , (ToNeo4j.toRepr valClinic_has_room3).toCypher
  , (ToNeo4j.toRepr parisClinic_has_room7).toCypher
  -- roomHas* (equipment)
  , (ToNeo4j.toRepr room3_has_exambed).toCypher
  , (ToNeo4j.toRepr room3_has_bpmonitor).toCypher
  , (ToNeo4j.toRepr room3_has_vo2equip).toCypher
  , (ToNeo4j.toRepr room7_has_exambed).toCypher
  , (ToNeo4j.toRepr room7_has_bpmonitor).toCypher
  , (ToNeo4j.toRepr room7_has_vo2equip).toCypher
  -- hasQualification
  , (ToNeo4j.toRepr allen_holds_exambed).toCypher
  , (ToNeo4j.toRepr allen_holds_bpmonitor).toCypher
  , (ToNeo4j.toRepr allen_holds_vo2equip).toCypher
  , (ToNeo4j.toRepr matthew_holds_exambed).toCypher
  , (ToNeo4j.toRepr matthew_holds_bpmonitor).toCypher
  , (ToNeo4j.toRepr matthew_holds_vo2equip).toCypher
  ]

def main : IO Unit := do
  for stmt in allCypher do
    IO.println (stmt ++ ";")
  for stmt in allCatalogCypher do
    IO.println (stmt ++ ";")
