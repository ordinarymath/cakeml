(*
  Compiles the CNF + PB checker
*)
open preamble compilationLib cnfProgTheory

val _ = new_theory "cnfCompile"

val _ = intermediate_prog_prefix := "arm8_"

val cnf_compiled_arm8 = save_thm("cnf_compiled_arm8",
  compile_arm8 "cake_pb_cnf_arm8" main_prog_def);

(* Default has no prefix *)
val _ = intermediate_prog_prefix := ""

val cnf_compiled = save_thm("cnf_compiled",
  compile_x64 "cake_pb_cnf" main_prog_def);

val _ = export_theory ();
