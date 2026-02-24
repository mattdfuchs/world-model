/-
  WorldModel.KB.Boxes.Derive
  Deriving handler for `ToBox`.

  ## What this does

  When you write `deriving instance ToBox for SomeType`, this handler
  auto-generates a `ToBox` instance by inspecting the type's constructor.

  ## Convention

  The target type must have a single constructor with exactly 2 explicit
  parameters:

      inductive MyProcess (name : String) where
        | mk : InputType name → OutputType name → MyProcess name
                ─────────────    ───────────────
                param 1 (input)  param 2 (output — must be an inductive)

  - `inputs`  = [type of param 1]
  - `outputs` = one branch per constructor of param 2's type,
                each listing that constructor's explicit parameter types
  - Branch name = the constructor's name (as a string)

  ## Example

  Given:
      inductive HeartRate : String → Type where
        | heartRate : {name : String} → Patient name → Int → HeartRate name

      inductive HeartMeasurement (name : String) where
        | heartMeasurement : Patient name → HeartRate name → HeartMeasurement name

  `deriving instance ToBox for HeartMeasurement` generates:

      instance {name : String} : ToBox (HeartMeasurement name) where
        toBox _ := { inputs  := [Patient name],
                     outputs := [("heartRate", [Patient name, Int])] }

  The output branches come from HeartRate's constructor, not HeartMeasurement's.

  ## Fallback

  If the type doesn't match the 2-param shape (wrong number of constructors,
  wrong number of explicit params, output type isn't inductive), the handler
  generates an instance with empty inputs and outputs.

  ## Implementation strategy

  Rather than building Lean `Syntax` trees directly (which is complex when
  types contain bound variables from the inductive's parameters), we:
    1. Use `ppExpr` to pretty-print each type as a string
    2. Assemble the full `instance ... where ...` declaration as a string
    3. Parse it back into syntax with `Parser.runParserCategory`
    4. Elaborate it with `elabCommand`

  This works because `ppExpr` respects the local context — free variables
  from telescopes print as their user-facing names (e.g. `name`), which
  then re-elaborate correctly when bound by the `{name : String}` implicit
  in the generated instance header.
-/
import Lean
import WorldModel.KB.Boxes.Core

open Lean Meta Elab Command Term

/--
  Decompose a constructor and return its explicit parameter types as strings.

  Given a constructor like `HeartRate.heartRate : {name : String} → Patient name → Int → HeartRate name`
  and an expected return type like `HeartRate name` (with `name` as a concrete fvar):

  1. Open the constructor type with metavariables:
     `?name → ?patient → ?rate → HeartRate ?name`
     (mvars replace each bound variable; binderInfos tracks implicit vs explicit)

  2. Unify the return type `HeartRate ?name` with `HeartRate name`:
     this assigns `?name := name`, linking the constructor's variables to the
     concrete types we care about.

  3. For each explicit (non-implicit) metavar, get its type and substitute
     the now-assigned metavars. E.g. `?patient : Patient ?name` becomes
     `Patient name` after instantiation.

  4. Pretty-print each type and return along with the constructor's short name.

  Returns `none` if unification fails (shouldn't happen for valid constructors).
-/
private def getCtorExplicitTypes (ctorInfo : ConstantInfo) (expectedRetType : Expr)
    : MetaM (Option (String × Array Expr)) := do
  -- forallMetaTelescopeReducing replaces each ∀-bound variable with a fresh
  -- metavariable (?m). Unlike forallTelescopeReducing (which uses fvars),
  -- metavariables can be assigned by isDefEq, letting us discover the
  -- concrete substitution for implicit params.
  let (mvars, binderInfos, retTy) ← forallMetaTelescopeReducing ctorInfo.type
  -- Unify to assign implicit metavars (e.g. ?name := nameVar)
  unless ← isDefEq retTy expectedRetType do return none
  let mut typeExprs : Array Expr := #[]
  for i in [:mvars.size] do
    -- .default = explicit param (not implicit {}, instance [], or strict-implicit ⦃⦄)
    if binderInfos[i]! == .default then
      -- inferType gives the mvar's declared type (may still contain unresolved mvars)
      -- instantiateMVars replaces assigned mvars with their values
      let ty ← instantiateMVars (← inferType mvars[i]!)
      typeExprs := typeExprs.push ty
  -- getString! extracts the last name component: `HeartRate.heartRate` → `"heartRate"`
  return some (ctorInfo.name.getString!, typeExprs)

/--
  Convert a type `Expr` to a Lean source expression (as a `String`) that,
  when elaborated, evaluates to the type's string key at runtime.

  Design goals:
  - **Unique**: two distinct Lean types must produce different strings.
  - **Consistent**: the same type always produces the same string.

  Uniqueness is achieved two ways:
  1. Constants use their fully-qualified `Lean.Name` (dot-separated), not
     the short pretty-printed name, so types from different namespaces with
     the same base name are distinguished.
  2. Applications use parenthesised arguments `F(A)(B)` rather than
     space-separated `F A B`, so `Foo "a b" "c"` → `"Foo(a b)(c)"` is
     distinct from `Foo "a b c"` → `"Foo(a b c)"`.

  Free variables listed in `params` (inductive type parameters, as fvarId →
  userName pairs) are emitted as bare variable references so their runtime
  values are interpolated.

  Examples:
  - `Int`           → `"Int"`            (constant, no params)
  - `Patient name`  → `("Patient" ++ "(" ++ name ++ ")")`
                      evaluates to `"Patient(foo)"` when `name = "foo"`
-/
private partial def exprToStr (e : Expr) (params : Array (FVarId × String))
    : MetaM String := do
  match e with
  | .fvar fid =>
    match params.find? (fun (id, _) => id == fid) with
    | some (_, pname) => return pname  -- emit param variable directly
    | none            => return s!"\"{toString (← ppExpr e)}\""
  | .const name _ =>
    -- Fully-qualified name avoids namespace-collision ambiguity.
    return s!"\"{name}\""
  | .lit (.strVal s) =>
    -- String literal: embed the raw value without extra quoting so that
    -- `Patient "foo"` produces "Patient(foo)", not "Patient(\"foo\")".
    return s!"\"{s}\""
  | .lit (.natVal n) =>
    return s!"\"{n}\""
  | .app f arg =>
    let fs  ← exprToStr f params
    let as_ ← exprToStr arg params
    -- Parenthesise each argument: F(A)(B) is unambiguous regardless of
    -- how many arguments there are or whether values contain spaces.
    return s!"({fs} ++ \"(\" ++ {as_} ++ \")\")"
  | _ =>
    return s!"\"{toString (← ppExpr e)}\""

/--
  Build the full `instance ... : ToBox ... where toBox := { ... }` command
  as a string, by inspecting the inductive type's metaprogramming info.
-/
private def buildToBoxCmd (indVal : InductiveVal) : MetaM String := do
  let env ← getEnv
  let declName := indVal.name
  -- Open the inductive's type parameters as local free variables (fvars).
  -- For `HeartMeasurement (name : String)`, this gives indParams = [nameVar]
  -- where nameVar is an fvar with userName = `name` and type = String.
  -- The `some indVal.numParams` bound stops after the parameters, before
  -- the "→ Type" part.
  forallBoundedTelescope indVal.type (some indVal.numParams) fun indParams _ => do
    -- Build the instance header string.
    -- For HeartMeasurement with param (name : String), we produce:
    --   binderParts = ["{name : String}"]
    --   nameParts   = ["name"]
    --   header      = "instance {name : String} : ToBox (HeartMeasurement name) where\n  "
    let mut binderParts : Array String := #[]
    let mut nameParts : Array String := #[]
    let mut paramFVars : Array (FVarId × String) := #[]
    for p in indParams do
      let ldecl ← p.fvarId!.getDecl
      binderParts := binderParts.push s!"\{{ldecl.userName} : {← ppExpr ldecl.type}}"
      nameParts := nameParts.push (toString ldecl.userName)
      paramFVars := paramFVars.push (p.fvarId!, toString ldecl.userName)
    let binderStr := " ".intercalate binderParts.toList
    let nameStr := " ".intercalate nameParts.toList
    let typeApp := if nameStr.isEmpty then toString declName else s!"({declName} {nameStr})"
    let header := s!"instance {binderStr} : ToBox {typeApp} where\n  "
    let empty := header ++ "toBox := { inputs := [], outputs := [] }"
    -- Require exactly one constructor
    if indVal.ctors.length != 1 then return empty
    let ctorName := indVal.ctors[0]!
    let some ctorInfo := env.find? ctorName | return empty
    -- Substitute the inductive's type params into the constructor's type.
    -- The constructor in the environment is fully quantified:
    --   HeartMeasurement.heartMeasurement : {name : String} → Patient name → HeartRate name → HeartMeasurement name
    -- After instantiateForall with [nameVar], we get:
    --   Patient nameVar → HeartRate nameVar → HeartMeasurement nameVar
    -- (The leading {name : String} binder is consumed.)
    let ctorType ← instantiateForall ctorInfo.type indParams
    -- Open the remaining binders as fvars.
    -- For our example this gives ctorArgs = [p, hr] where:
    --   p  : Patient nameVar   (explicit)
    --   hr : HeartRate nameVar  (explicit)
    -- and return type = HeartMeasurement nameVar (ignored via _)
    forallTelescopeReducing ctorType fun ctorArgs _ => do
      -- Filter to only explicit parameters (skip implicit {}, instance [], etc.)
      let mut explicitTypes : Array Expr := #[]
      for arg in ctorArgs do
        let ldecl ← arg.fvarId!.getDecl
        if ldecl.binderInfo == .default then
          explicitTypes := explicitTypes.push ldecl.type
      -- We require exactly 2 explicit params: input and output
      if explicitTypes.size != 2 then return empty
      -- First explicit param's type → the input type.
      -- exprToStr produces a Lean expression that evaluates to the type's
      -- string name at runtime, with any type params interpolated.
      let inputRStr ← exprToStr explicitTypes[0]! paramFVars
      -- Second explicit param's type → the output type (must be an inductive)
      -- e.g. HeartRate nameVar
      let outputType := explicitTypes[1]!
      -- Extract the head constant name: HeartRate nameVar → HeartRate
      let some outputName := outputType.getAppFn.constName? | return empty
      -- Look it up and confirm it's an inductive type
      let some outputIndVal := env.find? outputName |>.bind fun ci =>
        match ci with | .inductInfo v => some v | _ => none
        | return empty
      -- Build one branch per constructor of the output type.
      -- For HeartRate with constructor `heartRate : Patient name → Int → HeartRate name`,
      -- getCtorExplicitTypes returns ("heartRate", [Expr(Patient name), Expr(Int)]).
      -- Each Expr is then converted to a runtime string expression via exprToStr.
      let mut branchStrs : Array String := #[]
      for ctor in outputIndVal.ctors do
        let some ci := env.find? ctor | continue
        if let some (branchName, typeExprs) ← getCtorExplicitTypes ci outputType then
          let typeRStrs ← typeExprs.mapM (exprToStr · paramFVars)
          let typesStr := ", ".intercalate typeRStrs.toList
          branchStrs := branchStrs.push s!"(\"{branchName}\", [{typesStr}])"
      let branchesStr := ", ".intercalate branchStrs.toList
      -- Assemble the final instance body.
      -- The \{ and } produce literal braces (escaped from string interpolation).
      return header ++ s!"toBox := \{ inputs := [{inputRStr}], outputs := [{branchesStr}] }"

/--
  Entry point called by Lean's deriving machinery.
  `declNames` is the array of type names to derive for (typically just one).
  Returns `true` on success, `false` if the type isn't an inductive.
-/
private def deriveToBox (declNames : Array Name) : CommandElabM Bool := do
  if declNames.size != 1 then return false
  let some indVal := (← getEnv).find? declNames[0]! |>.bind fun ci =>
    match ci with | .inductInfo v => some v | _ => none
    | return false
  -- Build the instance command string inside MetaM (needed for telescopes/ppExpr),
  -- then lift it back to CommandElabM
  let cmdStr ← liftTermElabM (buildToBoxCmd indVal)
  -- Parse the string back into Lean syntax and elaborate it as a command.
  -- This is equivalent to the user having written the instance declaration directly.
  match Parser.runParserCategory (← getEnv) `command cmdStr "<deriving ToBox>" with
  | .ok stx => elabCommand stx; return true
  | .error e => throwError s!"deriving ToBox: parse error: {e}\nGenerated:\n{cmdStr}"

-- Register the handler so `deriving ToBox` and `deriving instance ToBox for`
-- know to call deriveToBox. This runs at module load time (i.e. when another
-- file does `import WorldModel.KB.Boxes.Derive`), which is why the
-- `deriving instance` declarations must live in a separate file (Instances.lean).
initialize
  registerDerivingHandler ``ToBox fun args => deriveToBox args
