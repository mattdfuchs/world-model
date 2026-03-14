/-
  WorldModel.KB.Neo4j.Derive
  Deriving handlers for ToNeo4j and FromNeo4j.

  ## Patterns recognized

  | Pattern                   | Example                  | Detection                                          |
  |--------------------------|--------------------------|-----------------------------------------------------|
  | String-parameterized entity | `Human : String → Type`  | all params String, 1 ctor, 0 additional ctor args  |
  | Relation edge             | `speaks {h l} (a) (b)`   | numParams≥2, ≥2 entity-typed params, 0 ctor args  |
  | Unit type                 | `ExamBed : Type`         | numParams=0, 1 ctor, 0 ctor args                   |

  ## Implementation strategy

  Same as Boxes/Derive.lean: build instance declaration as a string,
  parse with `Parser.runParserCategory`, elaborate with `elabCommand`.

  ## Note on parameter names

  For `Human : String → Type`, Lean sets numParams=1 (the String is uniform
  across constructors). The binder is anonymous (`String →`), so the fvar
  gets an inaccessible name like `a✝`. We generate fresh names (`s`, `s1`, ...)
  to avoid parser issues with `✝`.
-/
import Lean
import WorldModel.KB.Neo4j.Core

open Lean Meta Elab Command Term

/-- Build a `ToNeo4j` instance declaration as a string by inspecting the inductive. -/
private def buildToNeo4jCmd (indVal : InductiveVal) : MetaM String := do
  let env ← getEnv
  let declName := indVal.name
  let declNameStr := toString declName
  if indVal.ctors.length != 1 then return ""
  let ctorName := indVal.ctors[0]!
  let some ctorInfo := env.find? ctorName | return ""
  forallBoundedTelescope indVal.type (some indVal.numParams) fun indParams _ => do
    -- Track how many params are String-typed vs entity-typed
    let mut stringParamCount : Nat := 0
    let mut entityArgs : Array (String × String) := #[] -- (label, keyVarName)
    -- For relations: build binder strings from real param names
    let mut relBinderParts : Array String := #[]
    let mut relExplicitNames : Array String := #[]
    for p in indParams do
      let ldecl ← p.fvarId!.getDecl
      if ldecl.type.isConstOf `String then
        stringParamCount := stringParamCount + 1
      else
        let fn := ldecl.type.getAppFn
        let args := ldecl.type.getAppArgs
        if let some constName := fn.constName? then
          if args.size == 1 then
            if let .fvar keyFvarId := args[0]! then
              let keyDecl ← keyFvarId.getDecl
              entityArgs := entityArgs.push (toString constName, toString keyDecl.userName)
      -- Always build relation binder info (only used if pattern 3 matches)
      let tyStr := toString (← ppExpr ldecl.type)
      relBinderParts := relBinderParts.push s!"\{{ldecl.userName} : {tyStr}}"
      if ldecl.binderInfo == .default then
        relExplicitNames := relExplicitNames.push (toString ldecl.userName)
    -- Instantiate ctor type and check for additional args
    let ctorType ← instantiateForall ctorInfo.type indParams
    forallTelescopeReducing ctorType fun ctorArgs _ => do
      let mut ctorExplicitCount : Nat := 0
      for arg in ctorArgs do
        let ldecl ← arg.fvarId!.getDecl
        if ldecl.binderInfo == .default then
          ctorExplicitCount := ctorExplicitCount + 1

      -- Pattern 1: Unit type (0 params, 0 ctor args)
      if indVal.numParams == 0 && ctorExplicitCount == 0 then
        return s!"instance : ToNeo4j {declNameStr} where\n  toRepr _ := .node \"{declNameStr}\" []"

      -- Pattern 2: String-parameterized entity (all params String, 0 ctor args)
      if stringParamCount == indVal.numParams && indVal.numParams > 0 && ctorExplicitCount == 0 then
        -- Generate fresh names to avoid inaccessible fvar names like a✝
        let freshNames : Array String :=
          if indVal.numParams == 1 then #["s"]
          else (Array.range indVal.numParams).map fun i => s!"s{i + 1}"
        let binderStr := " ".intercalate (freshNames.map fun n => s!"\{{n} : String}").toList
        let appStr := " ".intercalate freshNames.toList
        let header := s!"instance {binderStr} : ToNeo4j ({declNameStr} {appStr}) where\n  "
        if freshNames.size == 1 then
          return header ++ "toRepr _ := .node \"" ++ declNameStr ++ "\" [(\"name\", s)]"
        else
          let propParts := freshNames.map fun n => s!"(\"{n}\", {n})"
          let propsStr := ", ".intercalate propParts.toList
          return header ++ s!"toRepr _ := .node \"{declNameStr}\" [{propsStr}]"

      -- Pattern 3: Relation edge (≥2 params, ≥2 entity args, 0 ctor args)
      if indVal.numParams >= 2 && ctorExplicitCount == 0 && entityArgs.size >= 2 then
        let binderStr := " ".intercalate relBinderParts.toList
        let appStr := " ".intercalate relExplicitNames.toList
        let typeApp := if relExplicitNames.isEmpty then declNameStr else s!"({declNameStr} {appStr})"
        let (srcLabel, srcKey) := entityArgs[0]!
        let (tgtLabel, tgtKey) := entityArgs[1]!
        let header := s!"instance {binderStr} : ToNeo4j {typeApp} where\n  "
        return header ++ s!"toRepr _ := .edge \"{declNameStr}\" \"{srcLabel}\" {srcKey} \"{tgtLabel}\" {tgtKey}"

      return ""

/-- Build a `FromNeo4j` instance declaration as a string by inspecting the inductive. -/
private def buildFromNeo4jCmd (indVal : InductiveVal) : MetaM String := do
  let env ← getEnv
  let declName := indVal.name
  let declNameStr := toString declName
  if indVal.ctors.length != 1 then return ""
  let ctorName := indVal.ctors[0]!
  let some ctorInfo := env.find? ctorName | return ""
  forallBoundedTelescope indVal.type (some indVal.numParams) fun indParams _ => do
    let mut stringParamCount : Nat := 0
    let mut entityArgs : Array (String × String) := #[]
    let mut relBinderParts : Array String := #[]
    let mut relExplicitNames : Array String := #[]
    for p in indParams do
      let ldecl ← p.fvarId!.getDecl
      if ldecl.type.isConstOf `String then
        stringParamCount := stringParamCount + 1
      else
        let fn := ldecl.type.getAppFn
        let args := ldecl.type.getAppArgs
        if let some constName := fn.constName? then
          if args.size == 1 then
            if let .fvar keyFvarId := args[0]! then
              let keyDecl ← keyFvarId.getDecl
              entityArgs := entityArgs.push (toString constName, toString keyDecl.userName)
      let tyStr := toString (← ppExpr ldecl.type)
      relBinderParts := relBinderParts.push s!"\{{ldecl.userName} : {tyStr}}"
      if ldecl.binderInfo == .default then
        relExplicitNames := relExplicitNames.push (toString ldecl.userName)
    let ctorType ← instantiateForall ctorInfo.type indParams
    forallTelescopeReducing ctorType fun ctorArgs _ => do
      let mut ctorExplicitCount : Nat := 0
      for arg in ctorArgs do
        let ldecl ← arg.fvarId!.getDecl
        if ldecl.binderInfo == .default then
          ctorExplicitCount := ctorExplicitCount + 1

      -- Pattern 1: Unit type
      if indVal.numParams == 0 && ctorExplicitCount == 0 then
        return s!"instance : FromNeo4j {declNameStr} where\n  fromRepr\n    | .node \"{declNameStr}\" [] => some .mk\n    | _ => none"

      -- Pattern 2: String-parameterized entity
      if stringParamCount == indVal.numParams && indVal.numParams > 0 && ctorExplicitCount == 0 then
        let freshNames : Array String :=
          if indVal.numParams == 1 then #["s"]
          else (Array.range indVal.numParams).map fun i => s!"s{i + 1}"
        let binderStr := " ".intercalate (freshNames.map fun n => s!"\{{n} : String}").toList
        let appStr := " ".intercalate freshNames.toList
        let header := s!"instance {binderStr} : FromNeo4j ({declNameStr} {appStr}) where\n  "
        if freshNames.size == 1 then
          return header ++ "fromRepr\n    | .node \"" ++ declNameStr ++ "\" [(\"name\", v)] => if v == s then some (.mk s) else none\n    | _ => none"
        else
          let matchParts := freshNames.map fun n => s!"(\"{n}\", v_{n})"
          let matchStr := ", ".intercalate matchParts.toList
          let condParts := freshNames.map fun n => s!"v_{n} == {n}"
          let condStr := " && ".intercalate condParts.toList
          let mkArgs := " ".intercalate freshNames.toList
          return header ++ s!"fromRepr\n    | .node \"{declNameStr}\" [{matchStr}] => if {condStr} then some (.mk {mkArgs}) else none\n    | _ => none"

      -- Pattern 3: Relation edge
      if indVal.numParams >= 2 && ctorExplicitCount == 0 && entityArgs.size >= 2 then
        let binderStr := " ".intercalate relBinderParts.toList
        let appStr := " ".intercalate relExplicitNames.toList
        let typeApp := if relExplicitNames.isEmpty then declNameStr else s!"({declNameStr} {appStr})"
        let (srcLabel, srcKey) := entityArgs[0]!
        let (tgtLabel, tgtKey) := entityArgs[1]!
        let header := s!"instance {binderStr} : FromNeo4j {typeApp} where\n  "
        return header ++ s!"fromRepr\n    | .edge \"{declNameStr}\" \"{srcLabel}\" sh \"{tgtLabel}\" sl => if sh == {srcKey} && sl == {tgtKey} then some .mk else none\n    | _ => none"

      return ""

/-- Entry point for `deriving instance ToNeo4j`. -/
private def deriveToNeo4j (declNames : Array Name) : CommandElabM Bool := do
  if declNames.size != 1 then return false
  let some indVal := (← getEnv).find? declNames[0]! |>.bind fun ci =>
    match ci with | .inductInfo v => some v | _ => none
    | return false
  let cmdStr ← liftTermElabM (buildToNeo4jCmd indVal)
  if cmdStr.isEmpty then return false
  match Parser.runParserCategory (← getEnv) `command cmdStr "<deriving ToNeo4j>" with
  | .ok stx => elabCommand stx; return true
  | .error e => throwError s!"deriving ToNeo4j: parse error: {e}\nGenerated:\n{cmdStr}"

/-- Entry point for `deriving instance FromNeo4j`. -/
private def deriveFromNeo4j (declNames : Array Name) : CommandElabM Bool := do
  if declNames.size != 1 then return false
  let some indVal := (← getEnv).find? declNames[0]! |>.bind fun ci =>
    match ci with | .inductInfo v => some v | _ => none
    | return false
  let cmdStr ← liftTermElabM (buildFromNeo4jCmd indVal)
  if cmdStr.isEmpty then return false
  match Parser.runParserCategory (← getEnv) `command cmdStr "<deriving FromNeo4j>" with
  | .ok stx => elabCommand stx; return true
  | .error e => throwError s!"deriving FromNeo4j: parse error: {e}\nGenerated:\n{cmdStr}"

initialize
  registerDerivingHandler ``ToNeo4j fun args => deriveToNeo4j args
  registerDerivingHandler ``FromNeo4j fun args => deriveFromNeo4j args
