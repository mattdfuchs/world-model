/-
  WorldModel.KB.Neo4j.Core
  Neo4jRepr data type, ToNeo4j/FromNeo4j typeclasses, and Cypher generation.
-/

/-- Representation of a Neo4j entity (node or edge) for serialization. -/
inductive Neo4jRepr where
  | node (label : String) (properties : List (String × String))
  | edge (label : String)
         (srcLabel : String) (srcKey : String)
         (tgtLabel : String) (tgtKey : String)
         (properties : List (String × String) := [])
  deriving Repr, BEq

/-- Serialize a Lean type to its Neo4j representation. -/
class ToNeo4j (α : Type) where
  toRepr : α → Neo4jRepr

/-- Deserialize a Neo4j representation to a Lean type. -/
class FromNeo4j (α : Type) where
  fromRepr : Neo4jRepr → Option α

/-- Generate a MERGE Cypher statement from a Neo4jRepr. -/
def Neo4jRepr.toCypher : Neo4jRepr → String
  | .node label props =>
    if props.isEmpty then
      "MERGE (n:" ++ label ++ ")"
    else
      let propStr := ", ".intercalate (props.map fun (k, v) => k ++ ": \"" ++ v ++ "\"")
      "MERGE (n:" ++ label ++ " {" ++ propStr ++ "})"
  | .edge label srcLabel srcKey tgtLabel tgtKey properties =>
    let srcMatch := if srcKey.isEmpty then
      "(a:" ++ srcLabel ++ ")"
    else
      "(a:" ++ srcLabel ++ " {name: \"" ++ srcKey ++ "\"})"
    let tgtMatch := if tgtKey.isEmpty then
      "(b:" ++ tgtLabel ++ ")"
    else
      "(b:" ++ tgtLabel ++ " {name: \"" ++ tgtKey ++ "\"})"
    let propStr := if properties.isEmpty then ""
      else
        let ps := ", ".intercalate (properties.map fun (k, v) => k ++ ": \"" ++ v ++ "\"")
        " {" ++ ps ++ "}"
    "MATCH " ++ srcMatch ++ "\nMATCH " ++ tgtMatch ++ "\nMERGE (a)-[:" ++ label ++ propStr ++ "]->(b)"

/-- Generate a MATCH ... RETURN Cypher query from a Neo4jRepr. -/
def Neo4jRepr.toMatchCypher : Neo4jRepr → String
  | .node label props =>
    if props.isEmpty then
      "MATCH (n:" ++ label ++ ") RETURN n"
    else
      let propStr := ", ".intercalate (props.map fun (k, v) => k ++ ": \"" ++ v ++ "\"")
      "MATCH (n:" ++ label ++ " {" ++ propStr ++ "}) RETURN n"
  | .edge label srcLabel srcKey tgtLabel tgtKey _properties =>
    let srcMatch := if srcKey.isEmpty then
      "(a:" ++ srcLabel ++ ")"
    else
      "(a:" ++ srcLabel ++ " {name: \"" ++ srcKey ++ "\"})"
    let tgtMatch := if tgtKey.isEmpty then
      "(b:" ++ tgtLabel ++ ")"
    else
      "(b:" ++ tgtLabel ++ " {name: \"" ++ tgtKey ++ "\"})"
    "MATCH " ++ srcMatch ++ "-[r:" ++ label ++ "]->" ++ tgtMatch ++ " RETURN r, a, b"
