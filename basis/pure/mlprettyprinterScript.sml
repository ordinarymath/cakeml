(*
  Types and pure functions for pretty printing

  Most of these functions are translated in the first phase of the basis
  setup so that default pretty-printing (c.f. the addTypePP system) will
  work from then on.
*)
open
  preamble
  mlstringTheory
  mlintTheory
  mlvectorTheory
  wordsTheory

val _ = new_theory "mlprettyprinter"

(* Data for pretty-printing. The bool indicates if this data needs to be
   wrapped in parens, if this data is given as an argument to an application.
*)
Datatype:
  pp_data = PP_Data bool (mlstring app_list)
End

Definition pp_token_def:
  pp_token s = PP_Data F (List [s])
End

Definition pp_fun_def:
  pp_fun = pp_token (strlit "<fun>")
End

(* there is a plan to replace this with an impure extensible implementation *)
Definition pp_exn_def:
  pp_exn e = pp_token (strlit "<exn>")
End

Definition app_intersperse_def:
  app_intersperse c [] = Nil /\
  app_intersperse c [x] = x /\
  app_intersperse c (x :: y :: zs) = Append (Append x (List [c])) (app_intersperse c (y :: zs))
End

Definition pp_contents_def:
  pp_contents (PP_Data _ xs) = xs
End

Definition pp_no_parens_def:
  pp_no_parens pp = PP_Data F (pp_contents pp)
End

Definition app_list_wrap_def:
  app_list_wrap l xs r = Append (List [l]) (Append xs (List [r]))
End

Definition pp_paren_contents_def:
  pp_paren_contents (PP_Data F xs) = xs /\
  pp_paren_contents (PP_Data T xs) = app_list_wrap (strlit "(") xs (strlit ")")
End

Definition pp_paren_tuple_def:
  pp_paren_tuple pps = PP_Data F (app_list_wrap (strlit "(")
    (app_intersperse (strlit ", ") (MAP pp_contents pps))
    (strlit ")")
  )
End

Definition pp_spaced_block_def:
  pp_spaced_block xs = PP_Data (LENGTH xs > 1)
    (app_intersperse (strlit " ") (MAP pp_paren_contents xs))
End

Definition pp_app_block_def:
  pp_app_block nm xs = pp_spaced_block (pp_token nm :: xs)
End

Definition pp_val_eq_def:
  pp_val_eq nm pp_f v ty = PP_Data F (Append
    (List [strlit "val "; nm; strlit " = "])
    (Append (pp_contents (pp_f v)) (List [strlit ": "; ty; strlit "\n"])))
End

Definition pp_val_hidden_type_def:
  pp_val_hidden_type nm ty = PP_Data F
    (List [strlit "val "; nm; strlit ": <hidden type "; ty; strlit ">\n"])
End

Definition pp_list_def:
  pp_list f xs = PP_Data F (app_list_wrap (strlit "[")
    (app_intersperse (strlit "; ") (MAP (\x. pp_contents (f x)) xs))
    (strlit "]")
  )
End

Definition escape_char_def:
  escape_char c =
    if c = #"\t"
    then SOME (strlit "\\t")
    else if c = #"\n"
    then SOME (strlit "\\n")
    else if c = #"\\"
    then SOME (strlit "\\\\")
    else if c = #"\""
    then SOME (strlit "\\\"")
    else NONE
End

Definition escape_char_str_def:
  escape_char_str c = case escape_char c of
    NONE => [c]
  | SOME s => explode s
End

Definition escape_str_def:
  escape_str i s = case str_findi (\c. IS_SOME (escape_char c)) i s of
    NONE => List [substring s i (strlen s - i)]
  | SOME j => Append (List [substring s i (j - i);
        case escape_char (strsub s j) of NONE => strlit "" | SOME s => s])
    (escape_str (j + 1) s)
Termination
  WF_REL_TAC `measure (\(i, s). strlen s - i)`
  \\ rw []
  \\ drule str_findi_range
  \\ simp []
End

Triviality findi_map_escape_char_str:
  !P i s. P = IS_SOME o escape_char ==>
  FLAT (MAP escape_char_str (DROP i (explode s))) =
  case str_findi P i s of
    NONE => DROP i (explode s)
  | SOME j => TAKE (j - i) (DROP i (explode s))
    ++ (case escape_char (strsub s j) of NONE => "" | SOME s => explode s)
    ++ FLAT (MAP escape_char_str (DROP (j + 1) (explode s)))
Proof
  recInduct str_findi_ind
  \\ rw []
  \\ simp [Once str_findi_def]
  \\ rw []
  \\ simp [listTheory.DROP_LENGTH_TOO_LONG]
  \\ `DROP i (explode s) = strsub s i :: DROP (i + 1) (explode s)`
    by (Cases_on `s` \\ fs [DROP_EL_CONS])
  \\ fs [escape_char_str_def, IS_SOME_EXISTS]
  \\ EVERY_CASE_TAC \\ fs []
  \\ imp_res_tac str_findi_range
  \\ simp [TAKE_def]
QED

Theorem escape_str_thm:
  !i s. concat (append (escape_str i s)) =
  implode (FLAT (MAP escape_char_str (DROP i (explode s))))
Proof
  recInduct escape_str_ind
  \\ rw []
  \\ simp [Once (Q.SPEC `\c. IS_SOME (escape_char c)` findi_map_escape_char_str), FUN_EQ_THM]
  \\ simp [Once escape_str_def]
  \\ Cases_on `s`
  \\ EVERY_CASE_TAC \\ fs []
  \\ rw [substring_def, SEG_TAKE_DROP, mlstringTheory.concat_def, implode_def]
  \\ imp_res_tac str_findi_range
  \\ fs [mlstringTheory.concat_def, implode_def]
  \\ imp_res_tac (Q.prove (`!s. x = SOME s ==> ?xs. s = strlit xs`, Cases \\ simp []))
  \\ simp []
QED

Definition pp_string_def:
  pp_string s = PP_Data F (app_list_wrap (strlit "\"") (escape_str 0 s) (strlit "\""))
End

Definition pp_bool_def:
  pp_bool b = PP_Data F (List [if b then (strlit "True") else (strlit "False")])
End

(* pretty-printers for the pretty-printer types *)
Definition pp_app_list_def:
  pp_app_list f (List xs) = pp_app_block (strlit "List")
    [pp_list f xs] /\
  pp_app_list f Nil = pp_token (strlit "Nil") /\
  pp_app_list f (Append x y) = pp_app_block (strlit "Append")
    [pp_app_list f x; pp_app_list f y]
End

Definition pp_pp_data_def:
  pp_pp_data (PP_Data b d) = pp_app_block (strlit "PP_Data")
    [pp_bool b; pp_app_list pp_string d]
End

Definition pp_char_def:
  pp_char c = PP_Data F (List [strlit "#\""; str c; strlit "\""])
End

Definition pp_int_def:
  pp_int (i : int) = pp_token (mlint$toString i)
End

Definition pp_word8_def:
  pp_word8 (w : 8 word) = pp_app_block (strlit "Word8.fromInt") [pp_int (w2i w)]
End

Definition pp_word64_def:
  pp_word64 (w : 64 word) = pp_app_block (strlit "Word64.fromInt") [pp_int (w2i w)]
End

(* these initial pure and useless pps might be replaced later *)
Definition pp_array_def:
  pp_array f arr = pp_token (strlit "<array>")
End

Definition pp_ref_def:
  pp_ref f r = pp_token (strlit "<ref>")
End

Definition pp_word8array_def:
  pp_word8array arr = pp_token (strlit "<w8array>")
End

Definition pp_vector_def:
  pp_vector f v = pp_app_block (strlit "Vector.fromList")
    [pp_list f (mlvector$toList v)]
End

val fromRat_def = Define`
  fromRat (n:int, d:num) =
  if d = 1 then List [mlint$toString n]
  else List [mlint$toString n; strlit "/"; mlint$toString (& d)]
`

val fromOption_def = Define`
  fromOption f opt =
  case opt of
      NONE => List [strlit "NONE"]
    | SOME x => Append (List [strlit "SOME "]) (f x)
`

val _ = export_theory ()
