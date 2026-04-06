/-
  WorldModel.KB.Arrow.Example.George
  Negative test: ParisClinic is in Paris, but George lives in London.
  Uncommenting the pipeline body would require `ClinicCityEvidence "ParisClinic" "George"`
  which is unprovable — Paris ≠ London.
-/
import WorldModel.KB.Arrow.Clinical

open KB.Facts

namespace GeorgeExample

abbrev georgeCtx : Ctx := [Patient "George"]
abbrev georgeState : ScopeState := [.entry ⟨"George", .patient⟩]

abbrev trialItems : List ScopeItem :=
  [.entry ⟨"OurTrial", .trial⟩,
   .constraint .clinicianSpeaksPatient]

abbrev clinicItems : List ScopeItem :=
  [.entry ⟨"ParisClinic", .clinic⟩,
   .entry ⟨"Matthew", .clinician⟩,
   .constraint .clinicInPatientCity,
   .constraint .clinicianAssigned,
   .constraint .trialApprovesClinic]

/-- The obligations at clinic scope for George include
    `ClinicCityEvidence "ParisClinic" "George"`.
    ParisClinic is in Paris, George lives in London → unprovable.

    Uncommenting would require providing evidence of type:
      ClinicCityEvidence "ParisClinic" "George"
    which needs a city where both ParisClinic is located AND George lives.
    ParisClinic is in Paris, George lives in London → no such city exists. -/
abbrev clinicObligations : List Type :=
  [ClinicCityEvidence "ParisClinic" "George",
   assigned (Human.mk "Matthew") (Clinic.mk "ParisClinic"),
   trialApproves (ClinicalTrial.mk "OurTrial") (Clinic.mk "ParisClinic"),
   SharedLangEvidence "Matthew" "George"]

-- To build a pipeline here, you would need:
--   (evidence : AllObligations clinicObligations)
-- i.e. ClinicCityEvidence "ParisClinic" "George" × ...
-- The first component is unprovable: no city satisfies both
--   isIn (Clinic.mk "ParisClinic") (City.mk city)  AND
--   lives (Human.mk "George") (City.mk city)

end GeorgeExample
