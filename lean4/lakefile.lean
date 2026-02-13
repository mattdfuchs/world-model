import Lake
open Lake DSL

package WorldModel where
  version := v!"0.1.0"

lean_lib WorldModel

@[default_target]
lean_exe worldmodel where
  root := `Main

lean_exe worldmodel_test where
  root := `Test
