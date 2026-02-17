/-
  WorldModel.KB.Theorems
  Proved statements about the clinical-trial knowledge base.
-/
import WorldModel.KB.Facts

-- Communication reachability

theorem allen_can_communicate_with_jose : canCommunicate allen jose :=
  ⟨"Spanish", .mk "Spanish", ⟨.mk⟩, ⟨.mk⟩⟩

theorem rick_can_communicate_with_allen : canCommunicate rick allen :=
  ⟨"English", .mk "English", ⟨.mk⟩, ⟨.mk⟩⟩

-- Clinician can serve patient

theorem allen_can_serve_jose : clinicianCanServe allen jose :=
  ⟨⟨.mk⟩, ⟨.mk⟩, "Spanish", .mk "Spanish", ⟨.mk⟩, ⟨.mk⟩⟩

-- Composite query: appointment possible for Jose

theorem appointment_possible_for_jose :
    ∃ (cl : String) (clinician : Human cl) (c : String) (clinic : Clinic c),
      Nonempty (hasRole clinician .Clinician) ∧
      Nonempty (assigned clinician clinic) ∧
      clinicInPatientCity clinic jose ∧
      canCommunicate clinician jose :=
  ⟨"Allen", allen, "ValClinic", valClinic,
    ⟨.mk⟩, ⟨.mk⟩,
    ⟨"Valencia", .mk "Valencia", ⟨.mk⟩, ⟨.mk⟩⟩,
    ⟨"Spanish", .mk "Spanish", ⟨.mk⟩, ⟨.mk⟩⟩⟩
