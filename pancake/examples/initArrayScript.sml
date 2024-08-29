(*
  Proof of correctness of a really simple array-init program.
*)

open preamble HolKernel Parse boolLib bossLib stringLib numLib intLib
     panLangTheory panPtreeConversionTheory panSemTheory panHoareTheory;

val _ = new_theory "initArray";

(* copied from panConcreteExampleScript *)

fun read_file fname = let
    val s = TextIO.openIn fname
    fun get ss = case TextIO.inputLine s of
        SOME str => get (str :: ss)
      | NONE => rev ss
  in concat (get []) end

fun parse_pancake_file fname =
  let
    val str = stringLib.fromMLstring (read_file fname)
    val thm = EVAL ``parse_funs_to_ast ^str``
    val r = rhs (concl thm)
  in
    if sumSyntax.is_inl r
    then (fst (sumSyntax.dest_inl r), thm)
    else failwith ("parse_pancake_file: failed to EVAL")
  end

val (ast, _) = parse_pancake_file "../examples/init_array.pnk"

Definition the_code_def:
  the_code = FEMPTY |++ (MAP (I ## SND) (^ast))
End

Theorem lookup_init_array = EVAL ``FLOOKUP (the_code) «init_array»``

val init_array_loop =
  lookup_init_array |> concl |> find_term (can (match_term ``Seq (While _ _) _``))

Definition w_count_def:
  w_count i x = (if ~ (i < x) then []
    else GENLIST (\j. i + n2w j) (w2n (x - i)))
End

Theorem w_count_cons:
  i < x ==> w_count i x = i :: w_count (i + 1w) x
Proof
  simp [w_count_def]
  \\ disch_tac
  \\ DEP_ONCE_REWRITE_TAC [GSYM wordsTheory.SUC_WORD_PRED]
  \\ simp [listTheory.GENLIST_CONS, wordsTheory.WORD_LEFT_ADD_DISTRIB]
  \\ simp [combinTheory.o_DEF, wordsTheory.n2w_SUC]
  \\ rw []
  >- (
    strip_tac
    \\ full_simp_tac bool_ss [wordsTheory.WORD_SUB_INTRO]
    \\ fs [wordsTheory.WORD_EQ_SUB_ZERO]
  )
  >- (
    (* requires some rules about inequalities and 1w *)
    cheat
  )
QED

Definition while_then_def:
  while_then C B X = Seq (While C B) X
End

Definition clock_after_def:
  clock_after s1 s2 = (s2.clock < s1.clock)
End

Theorem evaluate_while_then_imp:
  evaluate (while_then C B X, st1) = (res, st2) ==>
  (? res1 step_st. evaluate (If C (Seq Tick B) Break, st1) = (res1, step_st) /\
    (case res1 of
        | NONE => (evaluate (while_then C B X, step_st) = (res, st2) /\
            clock_after st1 step_st)
        | SOME Continue => (evaluate (while_then C B X, step_st) = (res, st2) /\
            clock_after st1 step_st)
        | SOME Break => evaluate (X, step_st) = (res, st2)
        | _ => (res1, step_st) = (res, st2)
    ))
Proof
  simp [evaluate_def]
  \\ simp [while_then_def]
  \\ simp [Once evaluate_def]
  \\ simp [Once evaluate_def]
  \\ simp [GSYM while_then_def]
  \\ pairarg_tac \\ fs []
  \\ fs [CaseEq "option", CaseEq "v", CaseEq "word_lab"]
  \\ fs [CaseEq "bool"]
  \\ simp [evaluate_def]
  \\ pairarg_tac \\ fs []
  \\ rename [`evaluate (_, dec_clock _) = (_, step_st)`]
  \\ reverse (qsuff_tac `clock_after st1 step_st`)
  >- (
    imp_res_tac evaluate_clock
    \\ fs [clock_after_def, dec_clock_def]
  )
  \\ fs [CaseEq "option", CaseEq "result"] \\ rw []
  \\ simp [while_then_def, EVAL ``evaluate (panLang$Seq _ _, _)``]
QED

Theorem clock_after_induct:
  (! s. (! step_st. clock_after s step_st ==> P step_st) ==> P s) ==>
  ! s. P s
Proof
  rw []
  \\ measureInduct_on `s.clock`
  \\ fs [clock_after_def]
QED

Theorem neq_NONE_IMP:
  (x <> NONE) ==> (?y. x = SOME y)
Proof
  Cases_on `x` \\ fs []
QED

Triviality init_array_loop_correct:
  ! st1 res st2. panSem$evaluate (^init_array_loop, st1) = (res, st2) ==>
  local_word st1.locals «i» <> NONE /\
  local_word st1.locals «base_addr» <> NONE /\
  local_word st1.locals «len» <> NONE /\
  set (MAP (\i. (THE (local_word st1.locals «base_addr») + (i * 8w)))
        (w_count (THE (local_word st1.locals «i»)) (THE (local_word st1.locals «len»))))
    SUBSET st1.memaddrs
  ==>
  res <> NONE /\
  (res <> SOME TimeOut ==> (case res of SOME (Return (ValWord i)) => i = 0w | _ => F) /\
  (?n. st2 =
    let i = THE (local_word st1.locals «i»);
        addr = THE (local_word st1.locals «base_addr»);
        len = THE (local_word st1.locals «len»);
        m2 = st1.memory =++ (MAP (\i. (addr + (i * 8w), Word i))
          (w_count i len))
    in (empty_locals st1 with <| memory := m2; clock := st1.clock - n |>)
  ))
Proof

  ho_match_mp_tac clock_after_induct
  \\ simp [GSYM while_then_def]
  \\ rpt (disch_tac ORELSE gen_tac)
  \\ dxrule evaluate_while_then_imp
  \\ rpt (disch_tac ORELSE gen_tac)
  \\ fs [evaluate_def, eval_def]
  \\ gs [GSYM optionTheory.IS_SOME_EQ_NOT_NONE |> REWRITE_RULE [optionTheory.IS_SOME_EXISTS],
    val_word_of_eq_SOME]
  \\ rename [`word_cmp Less i_v len_v`]
  \\ reverse (Cases_on `word_cmp Less i_v len_v`) \\ fs []
  >- (
    gvs [evaluate_def]
    \\ fs [shape_of_def, size_of_shape_def]
    \\ fs [asmTheory.word_cmp_def, w_count_def, miscTheory.UPDATE_LIST_THM]
    \\ simp [panSemTheory.state_component_equality]
    \\ qexists_tac `0`
    \\ gvs [empty_locals_def]
  )
  >- (
    gvs [evaluate_def, eval_def]
    \\ rpt (pairarg_tac \\ fs [])
    \\ fs [CaseEq "bool" |> Q.GEN `x` |> Q.ISPEC `cl = 0n`] \\ gvs []
    \\ gs [dec_clock_def]
    \\ fs [pan_op_def, wordLangTheory.word_op_def, flatten_def, mem_stores_def, mem_store_def]
    \\ fs [asmTheory.word_cmp_def]
    \\ drule_then assume_tac w_count_cons
    \\ gvs [is_valid_value_def, shape_of_def]
    \\ first_x_assum (drule_then drule)
    \\ simp [finite_mapTheory.FLOOKUP_UPDATE]
    \\ simp [empty_locals_def, miscTheory.UPDATE_LIST_THM]
    \\ rw [] \\ fs []
    \\ irule_at Any EQ_REFL
  )
QED

Theorem init_array_correct:
  st1.code = the_code ==>
  panSem$evaluate (Call NONE (Label «init_array») [Const base; Const len], st1) = (res, st2) /\
  (set (MAP (\i. base + (8w * i)) (w_count 0w len)) SUBSET st1.memaddrs) ==>
  res <> NONE /\
  (res <> SOME TimeOut ==> (case res of SOME (Return (ValWord i)) => i = 0w | _ => F) /\
  ?n. st2 = ((empty_locals st1) with <|
    memory := st1.memory =++ (MAP (\i. (base + (i * 8w), Word i)) (w_count 0w len));
    clock := st1.clock - n |>))
Proof
  simp [evaluate_def, eval_def, lookup_code_def,
        REWRITE_RULE [GSYM while_then_def] lookup_init_array]
  \\ simp [shape_of_def]
  \\ rpt disch_tac
  \\ fs [CaseEq "bool"]
  \\ fs [evaluate_def, eval_def]
  \\ pairarg_tac \\ fs []
  \\ dxrule (REWRITE_RULE [GSYM while_then_def] init_array_loop_correct)
  \\ simp [FLOOKUP_FUPDATE_LIST, FLOOKUP_UPDATE, dec_clock_def]
  \\ gvs [CaseEq "option", CaseEq "result"]
  \\ simp [empty_locals_def]
  \\ rw []
  \\ simp [panSemTheory.state_component_equality]
  \\ irule_at Any EQ_REFL
QED

val hoare_simp_rules =
    [DROP_DROP_T, FLOOKUP_UPDATE, res_var_def, FLOOKUP_FUPDATE_LIST,
        shape_of_def, size_of_shape_def, empty_locals_def, dec_clock_def,
        Cong option_case_cong, Cong panSemTheory.result_case_cong,
        PULL_EXISTS, exp_args_def, eval_args_def, eval_def,
        panPropsTheory.exp_shape_def]

val dest_logic_postcond = let
    val ls = [``hoare_logic``, ``eval_logic``, ``logic_imp``]
  in fn tm => let
    val (f, _) = strip_comb tm
  in if exists (same_const f) ls then SOME (rand tm) else NONE end end

fun unbeta_all [] tm = ALL_CONV tm
  | unbeta_all (x :: xs) tm = (UNBETA_CONV x THENC RATOR_CONV (unbeta_all xs)) tm

fun conv_waiting tm = let
    val (qs, body) = strip_exists tm
    val all_fvs = free_vars body
    fun unbeta_qs_conv tm = case (total dest_conj tm, dest_logic_postcond tm) of
        (SOME (lc, rc), _) => BINOP_CONV unbeta_qs_conv tm
      | (NONE, SOME q) => let
            val q_fvs = free_vars q
            val all_fvs = free_vars tm
            val waiting_on = filter (fn ex_q => exists (Term.aconv ex_q) q_fvs) qs
            val extra = filter (fn ex_q => exists (Term.aconv ex_q) all_fvs) qs
                |> filter (fn ex_q => not (exists (Term.aconv ex_q) waiting_on))
          in if null waiting_on then ALL_CONV tm
            else unbeta_all (waiting_on @ [mk_var ("unit_v", oneSyntax.one_ty)] @ extra) tm end
      | _ => ALL_CONV tm
  in STRIP_QUANT_CONV unbeta_qs_conv tm end

fun abbrev_waiting (assms, gl) = let
    val (qs, body) = strip_exists gl
    val bc = strip_conj body
    fun is_waiting t = is_comb t andalso is_abs (fst (strip_comb t))
    fun new_waiting t = let
        val free = free_varsl (gl :: assms)
        val nm = "waiting_on_" ^ Int.toString (length free)
        val v = Term.variant free (mk_var (nm, type_of t))
      in mk_eq (v, t) end
  in case List.find is_waiting bc of
    SOME t => ABBREV_TAC (new_waiting (fst (strip_comb t))) (assms, gl)
  | NONE => NO_TAC (assms, gl)
  end

fun unabbrev_waiting (assms, gl) = let
    fun unblocked_arg t = is_comb t andalso
        not (type_of (rand t) = oneSyntax.one_ty)
        andalso (not (is_var (rand t)) orelse unblocked_arg (rator t))
    val unblockeds = strip_exists gl |> snd |> strip_conj
        |> filter (is_var o fst o strip_comb)
        |> filter unblocked_arg
        |> map (fst o strip_comb)
  in if null unblockeds then NO_TAC (assms, gl)
    else UNABBREV_TAC (fst (dest_var (hd unblockeds))) (assms, gl)
  end

val hoare_tactic2 =
    rpt unabbrev_waiting
    \\ simp hoare_simp_rules
    \\ CONV_TAC conv_waiting
    \\ rpt abbrev_waiting

val hoare_tactic3 =
    MAP_FIRST (irule_at Any) [eval_logic_Const, eval_logic_Cmp,
        eval_logic_Var,
        eval_logic_Struct_CONS, eval_logic_Struct_NIL, eval_logic_args,
        hoare_logic_Seq, hoare_logic_Return,
        hoare_logic_annot_While, hoare_logic_Dec, hoare_logic_Store,
        hoare_logic_Assign]
    \\ hoare_tactic2 

Theorem bool_case_eq_specs =
    CONJ (bool_case_eq |> Q.GEN `t` |> Q.SPEC `v`)
        (bool_case_eq |> Q.GEN `f` |> Q.SPEC `v`)

Theorem init_array_Hoare_correct:
  hoare_logic G
    (\s ls.
        the_code ⊑ s.code /\
        local_word s.locals «base_addr» <> NONE /\
        local_word s.locals «len» <> NONE /\
        let base = THE (local_word s.locals «base_addr») in
        let len = THE (local_word s.locals «len») in
        set (MAP (\i. (base + (i * 8w))) (w_count 0w len)) SUBSET s.memaddrs /\
        (!m. Q (SOME TimeOut) m s.ffi) /\
        (!n. Q (SOME (Return (ValWord 0w)))
            (s.memory =++ (MAP (\i. (base + (i * 8w), Word i)) (w_count 0w len))) s.ffi)
    )
    (TailCall (Label «init_array») [Var «base_addr»; Var «len»])
    (\res s ls. Q res s.memory s.ffi)
Proof
  irule hoare_logic_weaken_imp
  \\ qspec_then `the_code` (irule_at Any) hoare_logic_TailCall_code
  \\ simp [lookup_init_array]
  \\ qspec_then `\s ls.
    local_word s.locals «i» <> NONE /\
    local_word s.locals «base_addr» <> NONE /\
    local_word s.locals «len» <> NONE /\
    let i = THE (local_word s.locals «i»);
        addr = THE (local_word s.locals «base_addr»);
        len = THE (local_word s.locals «len»);
        m2 = s.memory =++ (MAP (\i. (addr + (i * 8w), Word i))
          (w_count i len))
    in
    set (MAP (\i. (addr + (i * 8w))) (w_count i len)) SUBSET s.memaddrs /\
    (Q (SOME (Return (ValWord 0w))) m2 s.ffi) /\ (!m. Q (SOME TimeOut) m s.ffi)`
    (REWRITE_TAC o single) (GSYM annot_While_def)
  \\ rpt hoare_tactic3
  \\ conj_tac
  >- (
    rw [logic_imp_def]
    \\ imp_res_tac neq_NONE_IMP \\ gs []
    \\ imp_res_tac neq_NONE_IMP \\ gs [val_word_of_eq_SOME]
    \\ simp [pan_op_def, wordLangTheory.word_op_def, flatten_def,
        asmTheory.word_cmp_def, bool_case_eq_specs]
    \\ gvs []
    \\ rw []
    >- (
      fs [w_count_def, miscTheory.UPDATE_LIST_THM]
    )
    \\ fs [w_count_cons, mem_stores_def, mem_store_def, miscTheory.UPDATE_LIST_THM]
    \\ simp [shape_of_def]
  )
  >- (
    rw [logic_imp_def]
    \\ imp_res_tac neq_NONE_IMP \\ gs []
    \\ imp_res_tac neq_NONE_IMP \\ gs [val_word_of_eq_SOME]
    \\ simp [shape_of_def]
  )
QED

val _ = export_theory ();
