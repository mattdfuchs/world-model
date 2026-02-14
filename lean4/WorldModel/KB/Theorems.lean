/-
  WorldModel.KB.Theorems
  Proved statements about the clinical-trial knowledge base.
-/
import WorldModel.KB.Relations

-- 1. Direct lookups

theorem jose_is_patient : hasRole .Jose .Patient :=
  hasRole.jose_patient

theorem allen_speaks_spanish : speaks .Allen .Spanish :=
  speaks.allen_spanish

theorem valClinic_in_valencia : isIn .ValClinic .Valencia :=
  isIn.valClinic_valencia

-- 2. Communication reachability

theorem allen_can_communicate_with_jose : canCommunicate .Allen .Jose :=
  ⟨.Spanish, speaks.allen_spanish, speaks.jose_spanish⟩

theorem rick_can_communicate_with_allen : canCommunicate .Rick .Allen :=
  ⟨.English, speaks.rick_english, speaks.allen_english⟩

-- 3. Negative facts

theorem matthew_cannot_communicate_with_jose : ¬ canCommunicate .Matthew .Jose := by
  intro ⟨l, hm, hj⟩
  cases hm with
  | matthew_english => cases hj
  | matthew_french  => cases hj

theorem rick_is_not_clinician : ¬ hasRole .Rick .Clinician := by
  intro h; cases h

-- 4. Clinician can serve patient

theorem allen_can_serve_jose : clinicianCanServe .Allen .Jose :=
  ⟨hasRole.allen_clinician, hasRole.jose_patient, .Spanish, speaks.allen_spanish, speaks.jose_spanish⟩

-- 5. Composite query: appointment possible for Jose
-- There exists a clinician assigned to a clinic in Jose's city who can communicate with him.

theorem appointment_possible_for_jose :
    ∃ (clinician : Human) (c : Clinic),
      hasRole clinician .Clinician ∧
      assigned clinician c ∧
      clinicInPatientCity c .Jose ∧
      canCommunicate clinician .Jose :=
  ⟨.Allen, .ValClinic,
    hasRole.allen_clinician,
    assigned.allen_val,
    ⟨.Valencia, isIn.valClinic_valencia, lives.jose_valencia⟩,
    ⟨.Spanish, speaks.allen_spanish, speaks.jose_spanish⟩⟩

-- 6. Universal negation: nobody lives in London (per the Cypher data)

theorem nobody_lives_in_london : ∀ h : Human, ¬ lives h .London := by
  intro h hlives
  cases hlives
