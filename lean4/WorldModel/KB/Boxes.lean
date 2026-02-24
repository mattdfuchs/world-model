import WorldModel.KB.Boxes.Derive

inductive Patient : String → Type where
  | mk : (name : String) → Patient name

inductive Decision (name : String) where
  | consent : Patient name → String → Decision name
  | refuse : Patient name → String → Decision name

inductive HeartRate : String → Type where
  | heartRate : {name : String} → Patient name → Int → HeartRate name

inductive Consenting (name : String) where
  | mk : Patient name → Decision name → Consenting name
  deriving ToBox

inductive HeartMeasurement (name : String) where
  | heartMeasurement : Patient name → HeartRate name → HeartMeasurement name
  deriving ToBox

#check mightSubstitute (Consenting "foo") (HeartMeasurement "foo")

-- Decidability checks: same-shaped type substitutes itself; different shapes do not.
example : mightSubstitute (Consenting "foo") (Consenting "foo") := by decide
example : ¬mightSubstitute (Consenting "foo") (HeartMeasurement "foo") := by decide