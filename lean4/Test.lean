import WorldModel

open WorldModel

def main : IO Unit := do
  IO.println "Running Lean tests..."
  IO.println s!"greet: {greet hello}"
  IO.println s!"sum: {add 2 3}"
