/-
  WorldModel.KB.Boxes.Compose
  Custom `compose!` elaborator that validates type matching at compile time.

  ## Syntax

      compose! [
        (srcExpr, "branchName", [idx1, idx2, ...]),
        ...
      ] => targetExpr

  Each triple selects types from a source Box's output branch at the given
  indices. The elaborator checks that the collected types (flattened across
  all triples) match the target Box's input types via definitional equality.

  On success, produces a `Compose` value.
  On mismatch, reports a compile-time error with the position and expected/got types.
-/
import Lean
import WorldModel.KB.Boxes

open Lean Meta Elab Term

/-! ### Helpers to extract Box info from a type expression -/

/--
  Get explicit param types of a constructor, after unifying its return type
  with `expectedRetType`. Returns (constructorShortName, explicitParamTypes).
  Same logic as in Derive.lean, but returns `Expr` instead of `String`.
-/
private def getCtorExplicitExprs (ctorInfo : ConstantInfo) (expectedRetType : Expr)
    : MetaM (Option (String × Array Expr)) := do
  let (mvars, binderInfos, retTy) ← forallMetaTelescopeReducing ctorInfo.type
  unless ← isDefEq retTy expectedRetType do return none
  let mut types : Array Expr := #[]
  for i in [:mvars.size] do
    if binderInfos[i]! == .default then
      types := types.push (← instantiateMVars (← inferType mvars[i]!))
  return some (ctorInfo.name.getString!, types)

/--
  Extract Box info from a concrete type like `HeartMeasurement "alice"`.
  Returns (inputTypes, outputBranches) where each branch is (name, types).

  Uses the same structural convention as the deriving handler:
  - Single constructor with exactly 2 explicit params
  - First param's type → inputs
  - Second param's type → an inductive whose constructors define the output branches
-/
private def getBoxInfoFromType (type : Expr)
    : MetaM (Array Expr × Array (String × Array Expr)) := do
  let env ← getEnv
  let typeFn := type.getAppFn
  let typeArgs := type.getAppArgs
  let some typeName := typeFn.constName?
    | throwError "compose!: not a named type: {← ppExpr type}"
  let some indVal := env.find? typeName |>.bind fun ci =>
    match ci with | .inductInfo v => some v | _ => none
    | throwError "compose!: {typeName} is not an inductive type"
  if indVal.ctors.length != 1 then
    throwError "compose!: {typeName} must have exactly one constructor"
  let ctorName := indVal.ctors[0]!
  let some ctorInfo := env.find? ctorName
    | throwError "compose!: constructor {ctorName} not found"
  -- Instantiate the constructor type with the inductive's type arguments
  -- (e.g., substitute "alice" for the {name : String} param)
  let paramArgs := typeArgs[:indVal.numParams].toArray
  let ctorType ← instantiateForall ctorInfo.type paramArgs
  forallTelescopeReducing ctorType fun ctorArgs _ => do
    let mut explicitTypes : Array Expr := #[]
    for arg in ctorArgs do
      let ldecl ← arg.fvarId!.getDecl
      if ldecl.binderInfo == .default then
        explicitTypes := explicitTypes.push ldecl.type
    if explicitTypes.size != 2 then
      throwError "compose!: {typeName} constructor must have exactly 2 explicit params, got {explicitTypes.size}"
    let inputType := explicitTypes[0]!
    let outputType := explicitTypes[1]!
    let some outputName := outputType.getAppFn.constName?
      | throwError "compose!: output type is not a named type: {← ppExpr outputType}"
    let some outputIndVal := env.find? outputName |>.bind fun ci =>
      match ci with | .inductInfo v => some v | _ => none
      | throwError "compose!: {outputName} is not an inductive type"
    let mut branches : Array (String × Array Expr) := #[]
    for ctor in outputIndVal.ctors do
      let some ci := env.find? ctor | continue
      if let some (branchName, branchTypes) ← getCtorExplicitExprs ci outputType then
        branches := branches.push (branchName, branchTypes)
    return (#[inputType], branches)

/-! ### Syntax definition -/

-- A single source triple: (expression, "branchName", [index, ...])
declare_syntax_cat composeTriple
syntax "(" term ", " str ", " "[" num,* "]" ")" : composeTriple

-- compose! [triples...] => target
syntax "compose! " "[" composeTriple,* "]" " => " term : term

/-! ### Elaborator -/

elab_rules : term
  | `(compose! [$triples,*] => $target) => do
    -- Step 1: Elaborate the target expression and extract its input types
    let tgtExpr ← elabTerm target none
    let tgtType ← inferType tgtExpr
    let (tgtInputs, _) ← getBoxInfoFromType tgtType

    -- Step 2: For each source triple, resolve the selected types
    let mut allSelectedTypes : Array Expr := #[]
    let mut triplesSyntax : Array (TSyntax `term) := #[]

    for triple in triples.getElems do
      -- Parse the triple's components by position in the syntax node:
      --   [0]="("  [1]=term  [2]=","  [3]=str  [4]=","  [5]="["  [6]=num,*  [7]="]"  [8]=")"
      let srcStx : TSyntax `term := ⟨triple.raw[1]!⟩
      let branchStx := triple.raw[3]!
      let indicesNode := triple.raw[6]!

      -- Elaborate the source expression and get its Box info
      let srcExpr ← elabTerm srcStx none
      let srcType ← inferType srcExpr
      let (_, srcOutputs) ← getBoxInfoFromType srcType

      -- Find the named branch in the source's outputs
      let branchName := branchStx.isStrLit?.getD ""
      let some (_, branchTypes) := srcOutputs.toList.find? (fun (n, _) => n == branchName)
        | throwErrorAt branchStx s!"compose!: branch \"{branchName}\" not found in {← ppExpr srcType}"

      -- Collect types at the specified indices
      let idxArgs := indicesNode.getSepArgs
      let mut idxLits : Array (TSyntax `num) := #[]
      for idxStx in idxArgs do
        let idx := idxStx.isNatLit?.getD 0
        idxLits := idxLits.push ⟨idxStx⟩
        if h : idx < branchTypes.size then
          allSelectedTypes := allSelectedTypes.push branchTypes[idx]
        else
          throwErrorAt idxStx s!"compose!: index {idx} out of bounds (branch \"{branchName}\" has {branchTypes.size} types)"

      -- Build the syntax for this triple: (BoxSource.mk src, "branch", [i, j, ...])
      let branchLit : TSyntax `str := ⟨branchStx⟩
      let oneSyntax ← `((BoxSource.mk $srcStx, $branchLit, [$idxLits,*]))
      triplesSyntax := triplesSyntax.push oneSyntax

    -- Step 3: Check that selected types match target inputs (positionally)
    let totalSelected := allSelectedTypes.size
    let totalInputs := tgtInputs.size
    if totalSelected != totalInputs then
      throwError "compose!: selected {totalSelected} types but target expects {totalInputs} inputs"

    for i in [:totalSelected] do
      let expected := tgtInputs[i]!
      let got := allSelectedTypes[i]!
      unless ← isDefEq got expected do
        throwError "compose!: at position {i}: expected {← ppExpr expected}, got {← ppExpr got}"

    -- Step 4: All checks passed — build the Compose term
    let resultStx ← `(mkCompose [$triplesSyntax,*] (BoxSource.mk $target))
    elabTerm resultStx none
