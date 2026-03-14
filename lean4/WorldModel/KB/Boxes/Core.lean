structure Box where
  inputs : List String
  outputs : List (String × List String)
  deriving BEq, Repr

class ToBox (α : Type) where
  toBox : Box

inductive Bottom where
  | bottom

-- Boolean decision procedure for substitutability: all string comparisons are decidable.
def mightSubstituteBool (aBox bBox : Box) : Bool :=
  (bBox.inputs.all fun t => aBox.inputs.contains t) &&
  (bBox.outputs.all fun (brName, brTys) =>
    aBox.outputs.any fun (pName, pTys) =>
      pName == brName && (pTys == ["Bottom"] || brTys.all fun t => pTys.contains t))

-- B might substitute A when:
--   • B's inputs are a subset of A's inputs
--   • A has every branch of B (by name), and for each branch,
--     A's output types are either ["Bottom"] (wildcard) or a superset of B's
def mightSubstitute (α β : Type) [instA : ToBox α] [instB : ToBox β] : Prop :=
  mightSubstituteBool instA.toBox instB.toBox = true

instance {α β : Type} [instA : ToBox α] [instB : ToBox β] : Decidable (mightSubstitute α β) :=
  decEq (mightSubstituteBool instA.toBox instB.toBox) true
