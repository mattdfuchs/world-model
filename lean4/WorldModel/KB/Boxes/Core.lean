-- n-ary product: a heterogeneous list of values whose types are given by a List Type
inductive HList : List Type → Type 1 where
  | nil : HList []
  | cons : α → HList αs → HList (α :: αs)

-- n-ary sum of products: pick one branch from a list of branches, each branch is a product
inductive HSum : List (List Type) → Type 1 where
  | here : HList ts → HSum (ts :: rest)
  | there : HSum rest → HSum (ts :: rest)

-- Look up the type at branch i in outputs
def Proj (outputs : List (String × List Type)) (i : Nat) : Option (String × List Type) :=
  outputs[i]?

structure Box where
  inputs : List String
  outputs : List (String × List String)

class ToBox (α : Type) where
  toBox : Box

inductive Bottom where
  | bottom

-- Find a branch by constructor name and get the type at index n
def Box.getType (box : Box) (name : String) (n : Nat) : Option String := do
  let branch ← box.outputs.find? (fun p => p.1 == name)
  branch.2[n]?

inductive Pairing where
  | mk {α : Type} [ToBox α] (obj : α) (selector : String × Nat) (get : Unit → Option String) : Pairing

def mkPairing {α : Type} [inst : ToBox α] (obj : α) (selector : String × Nat) : Pairing :=
  let box := inst.toBox
  Pairing.mk obj selector (fun () => box.getType selector.1 selector.2)

def Pairing.result (p : Pairing) : Option String :=
  match p with
  | @Pairing.mk _ _ _ _ get => get ()

-- Wrapper to store a ToBox object with its type erased
inductive BoxSource where
  | mk {α : Type} [ToBox α] (obj : α) : BoxSource

-- Helper: generate pairings from a BoxSource, branch name, and list of indices
def BoxSource.toPairings : BoxSource → String → List Nat → List Pairing
  | @BoxSource.mk α inst obj, branch, indices =>
    indices.map fun idx => @mkPairing α inst obj (branch, idx)

inductive Compose where
  | mk (triples : List (BoxSource × String × List Nat))
       (target : BoxSource)
       (toPairings : Unit → List Pairing) : Compose

def mkCompose (triples : List (BoxSource × String × List Nat)) (target : BoxSource) : Compose :=
  Compose.mk triples target fun () =>
    triples.flatMap fun (src, branch, indices) =>
      src.toPairings branch indices

def Compose.result (c : Compose) : List Pairing :=
  match c with
  | .mk _ _ f => f ()

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
