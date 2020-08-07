(*
  General definitions and theorems that are useful within the proofs
  about the compiler backend.
*)
open preamble

val _ = new_theory"backendProps";

val state_cc_def = Define `
  state_cc f cc =
    (\(state,cfg) prog.
       let (state1,prog1) = f state prog in
         case cc cfg prog1 of
         | NONE => NONE
         | SOME (code,data,cfg1) => SOME (code,data,state1,cfg1))`;

val pure_cc_def = Define `
  pure_cc f cc =
    (\cfg prog.
       let prog1 = f prog in
         cc cfg prog1)`;

val state_co_def = Define `
  state_co f co = OPTION_MAP (\((state, cfg), progs).
      let (state1,progs) = f state progs in (cfg,progs)) o co`;

Theorem FST_state_co:
   OPTION_MAP FST (state_co f co n) = OPTION_MAP (SND o FST) (co n)
Proof
  rw[state_co_def,UNCURRY,OPTION_MAP_COMPOSE,o_DEF]
QED

Theorem SND_state_co:
   OPTION_MAP SND (state_co f co n) =
   OPTION_MAP (\v. SND (f (FST (FST v)) (SND v))) (co n)
Proof
  rw[state_co_def,UNCURRY,OPTION_MAP_COMPOSE,o_DEF]
QED

Theorem the_eqn:
  the x y = case y of NONE => x | SOME z => z
Proof
  Cases_on `y`>>rw[libTheory.the_def]
QED

Theorem the_F_eq:
  the F opt = (?x. (opt = SOME x) /\ x)
Proof
  Cases_on `opt` >> rw[the_eqn]
QED

Theorem OPTION_ALL_EQ_ALL:
  OPTION_ALL P x = (!y. x = SOME y ==> P y)
Proof
  Cases_on `x` \\ simp []
QED

val pure_co_def = Define `
  pure_co f = OPTION_MAP (I ## f)`;

Theorem SND_pure_co[simp]:
   OPTION_MAP SND (pure_co co x) = OPTION_MAP (co o SND) x
Proof
  simp [pure_co_def, OPTION_MAP_COMPOSE, miscTheory.o_PAIR_MAP]
QED

Theorem FST_pure_co[simp]:
   OPTION_MAP FST (pure_co co x) = OPTION_MAP FST x
Proof
  simp [pure_co_def, OPTION_MAP_COMPOSE, miscTheory.o_PAIR_MAP]
QED

Theorem pure_co_comb_pure_co:
  pure_co f o pure_co g o co = pure_co (f o g) o co
Proof
  rw [FUN_EQ_THM, pure_co_def, OPTION_MAP_COMPOSE]
  \\ irule OPTION_MAP_CONG
  \\ simp [FORALL_PROD]
QED

Triviality OPTION_MAP_EQ_SAME =
  Q.SPECL [`x`, `y`, `f`] OPTION_MAP_CONG |> Q.ISPEC `I`
    |> GEN_ALL |> SIMP_RULE std_ss [OPTION_MAP_I]

Theorem pure_co_I:
  pure_co I = I
Proof
  rw [FUN_EQ_THM, pure_co_def, FORALL_PROD, OPTION_MAP_EQ_SAME]
QED

Theorem pure_cc_I:
  pure_cc I = I
Proof
  fs [FUN_EQ_THM, FORALL_PROD, pure_cc_def]
QED

(* somewhat generic wrappers for defining standard properties about oracles *)

Definition opt_f_set_def:
  opt_f_set f x = case x of
    | NONE => {}
    | SOME y => f y
End

Theorem opt_f_set_simps[simp]:
  opt_f_set f (NONE) = {} /\
  opt_f_set f (SOME x) = f x
Proof
  simp [opt_f_set_def]
QED

(* identifiers that appear in the initial state and in oracle steps
   increase monotonically in some sense. *)
val oracle_monotonic_def = Define`
  oracle_monotonic (f : 'a -> 'b set) (R : 'b -> 'b -> bool) (S : 'b set)
    (orac : num -> 'a option) =
    ((!i j x y. i < j /\ x IN opt_f_set f (orac i) /\
            y IN opt_f_set f (orac j) ==> R x y)
        /\ (! i x y. x IN S /\ y IN opt_f_set f (orac i) ==> R x y))`;

val conjs = MATCH_MP quotientTheory.EQ_IMPLIES (SPEC_ALL oracle_monotonic_def)
  |> UNDISCH_ALL |> CONJUNCTS |> map DISCH_ALL

Theorem oracle_monotonic_step = hd conjs;
Theorem oracle_monotonic_init = hd (tl conjs);

Theorem oracle_monotonic_subset:
  St' ⊆ St /\
  (!n. opt_f_set f' (co' n) ⊆ opt_f_set f (co n)) ==>
  oracle_monotonic f R St co ==>
  oracle_monotonic f' R St' co'
Proof
  fs [oracle_monotonic_def, SUBSET_DEF]
  \\ metis_tac []
QED

Theorem oracle_monotonic_shift_subset:
  ((St' ⊆ (IMAGE ((+) (i : num)) St ∪ count i)) /\
    (!n. opt_f_set f' (co' n) ⊆ (IMAGE ((+) i) (opt_f_set f (co n))))) ==>
  oracle_monotonic f (<) St co ==>
  oracle_monotonic f' (<) St' co'
Proof
  fs [oracle_monotonic_def]
  \\ rw []
  \\ fs [SUBSET_DEF]
  \\ res_tac
  \\ res_tac
  \\ fs []
QED

Theorem oracle_monotonic_shift_seq:
  !i. (oracle_monotonic f R St co /\ i > 0 /\
    St' ⊆ opt_f_set f (co (i - 1)) ∪ St ==>
    oracle_monotonic f R St' (shift_seq i co)
  )
Proof
  rw [] \\ rw [oracle_monotonic_def]
  \\ fs [shift_seq_def]
  \\ imp_res_tac SUBSET_IMP
  \\ fs []
  \\ imp_res_tac oracle_monotonic_step
  \\ imp_res_tac oracle_monotonic_init
  \\ simp []
QED

Theorem oracle_monotonic_DISJOINT_init:
  !i. oracle_monotonic f R St co /\ irreflexive R
    ==> DISJOINT St (opt_f_set f (co i))
Proof
  simp [irreflexive_def, IN_DISJOINT]
  \\ metis_tac [oracle_monotonic_init]
QED

(* check that an oracle with config values lists the config values that
   would be produced by the incremental compiler. *)
Definition is_state_oracle_def:
  is_state_oracle compile_inc_f co =
    (!n curr_s curr_xs curr_prog succ.
        co n = SOME ((curr_s, curr_xs), curr_prog) /\
        co (SUC n) = SOME succ ==>
        FST (FST succ) = FST (compile_inc_f curr_s curr_prog))
End

Theorem is_state_oracle_shift:
  is_state_oracle compile_inc_f co ==>
  is_state_oracle compile_inc_f (shift_seq n co)
Proof
  rw [is_state_oracle_def, shift_seq_def]
  \\ res_tac
  \\ rfs [ADD1]
QED

Theorem is_state_oracle_k:
  !k. is_state_oracle compile_inc_f co ==>
  !st oth_st prog. co k = SOME ((st, oth_st), prog) /\ IS_SOME (co (SUC k)) ==>
  FST (FST (THE (co (SUC k)))) = FST (compile_inc_f st prog)
Proof
  rw [is_state_oracle_def, IS_SOME_EXISTS]
  \\ res_tac
  \\ rfs []
QED

(* constructive combinators for building up the config part of an oracle *)

val syntax_to_full_oracle_def = Define `
  syntax_to_full_oracle mk progs i = (mk progs i,progs i)`;

val state_orac_states_def = Define `
  state_orac_states f st progs 0 = st /\
  state_orac_states f st progs (SUC n) =
    FST (f (state_orac_states f st progs n) (progs n))`;

val state_co_progs_def = Define `
  state_co_progs f st orac = let
    states = state_orac_states f st orac;
  in \i. SND (f (states i) (orac i))`;

val add_state_co_def = Define `
  add_state_co f st mk progs = let
    states = state_orac_states f st progs;
    next_progs = state_co_progs f st progs;
    next_orac = mk next_progs in
    (\i. (states i, next_orac i))`;

val pure_co_progs_def = Define `
  pure_co_progs f (orac : num -> 'a) = f o orac`;

Theorem syntax_to_full_oracle_o_assoc:
  syntax_to_full_oracle (f o g o h) progs =
  syntax_to_full_oracle ((f o g) o h) progs
Proof
  simp_tac bool_ss [o_ASSOC]
QED

(* FIXME: return to whether we need this constructor or not
Theorem oracle_monotonic_SND_syntax_to_full:
  oracle_monotonic (f o SND) R St (syntax_to_full_oracle mk progs) =
  oracle_monotonic (f o SND) R St (I syntax_to_full_oracle I progs) /\
  oracle_monotonic (a o b o c) = oracle_monotonic ((a o b) o c)
Proof
  fs [oracle_monotonic_def, syntax_to_full_oracle_def]
QED
*)

(*
Theorem is_state_oracle_add_state_co:
  is_state_oracle f (syntax_to_full_oracle (add_state_co f st mk) progs)
Proof
  fs [is_state_oracle_def, syntax_to_full_oracle_def, add_state_co_def]
  \\ fs [state_orac_states_def]
  \\ metis_tac []
QED
*)

Theorem FST_add_state_co_0:
  FST (add_state_co f st mk orac 0) = st
Proof
  simp [add_state_co_def, state_orac_states_def]
QED

Theorem state_orac_states_inv:
  P st /\
  (! st prog st' prog'. f_inc st prog = (st', prog') /\ P st ==> P st') ==>
  P (state_orac_states f_inc st orac i)
Proof
  rw []
  \\ Induct_on `i`
  \\ fs [state_orac_states_def]
  \\ fs [PAIR_FST_SND_EQ]
QED

(*
Theorem oracle_monotonic_state_with_inv:
  !P n_f. P (FST (FST (orac 0))) /\
  (!x. x ∈ St ==> x < n_f (FST (FST (orac 0)))) /\
  (! st prog st' prog'. f_inc st prog = (st', prog') /\ P st ==>
    P st' /\ n_f st <= n_f st' /\
    (!cfg x. x ∈ f (cfg, prog') ==> n_f st <= x /\ x < n_f st')) /\
  is_state_oracle f_inc orac ==>
  oracle_monotonic f (<) (St : num set) (state_co f_inc orac)
Proof
  rw []
  \\ `!i. P (FST (FST (orac i))) /\
        (!j. j <= i ==> n_f (FST (FST (orac j))) <= n_f (FST (FST (orac i))))`
  by (
    Induct \\ fs [is_state_oracle_def]
    \\ fs [PAIR_FST_SND_EQ, seqTheory.LE_SUC]
    \\ rw [] \\ fs []
    \\ metis_tac [LESS_EQ_TRANS]
  )
  \\ fs [oracle_monotonic_def, is_state_oracle_def, state_co_def, UNCURRY]
  \\ fs [PAIR_FST_SND_EQ]
  \\ rw []
  \\ metis_tac [state_orac_states_def, LESS_LESS_EQ_TRANS,
        arithmeticTheory.LESS_OR, LESS_EQ_TRANS,
        arithmeticTheory.ZERO_LESS_EQ]
QED

Theorem oracle_monotonic_state_with_inv_init:
  !P n_f. f_inc st0 prog0 = (st, prog) /\ P st0 /\
  St ⊆ f (cfg, prog) /\ FST (FST (orac 0)) = st /\
  (! st prog st' prog'. f_inc st prog = (st', prog') /\ P st ==>
    P st' /\ n_f st <= n_f st' /\
    (!cfg x. x ∈ f (cfg, prog') ==> n_f st <= x /\ x < n_f st')) /\
  is_state_oracle f_inc orac ==>
  oracle_monotonic f (<) (St : num set) (state_co f_inc orac)
Proof
  rw []
  \\ match_mp_tac oracle_monotonic_state_with_inv
  \\ qexists_tac `P` \\ qexists_tac `n_f`
  \\ simp []
  \\ metis_tac [SUBSET_IMP]
QED

Theorem oracle_monotonic_state = oracle_monotonic_state_with_inv
  |> Q.SPEC `\x. T` |> SIMP_RULE bool_ss []

Theorem oracle_monotonic_state_init = oracle_monotonic_state_with_inv_init
  |> Q.SPEC `\x. T` |> SIMP_RULE bool_ss []
*)

val restrict_zero_def = Define`
  restrict_zero (labels : num # num -> bool) =
    {l | l ∈ labels ∧ SND l = 0}`

val restrict_nonzero_def = Define`
  restrict_nonzero (labels : num # num -> bool) =
    {l | l ∈ labels ∧ SND l ≠ 0}`

Theorem restrict_nonzero_SUBSET:
  restrict_nonzero l ⊆ l
Proof
  rw[restrict_nonzero_def,SUBSET_DEF]
QED;

Theorem restrict_nonzero_SUBSET_left:
  s ⊆ t ⇒
  restrict_nonzero s ⊆ t
Proof
  metis_tac[restrict_nonzero_SUBSET,SUBSET_TRANS]
QED;

Theorem restrict_nonzero_left_union :
  restrict_nonzero s ⊆ a ∪ b ⇒
  restrict_nonzero s ⊆ restrict_nonzero a ∪ b
Proof
  rw[restrict_nonzero_def,SUBSET_DEF]
QED;

Theorem restrict_nonzero_right_union :
  restrict_nonzero s ⊆ a ∪ b ⇒
  restrict_nonzero s ⊆ a ∪ restrict_nonzero b
Proof
  rw[restrict_nonzero_def,SUBSET_DEF]
QED;

Theorem restrict_nonzero_mono:
  s ⊆ t ⇒
  restrict_nonzero s ⊆ restrict_nonzero t
Proof
 rw[restrict_nonzero_def,SUBSET_DEF]
QED;

Theorem restrict_nonzero_BIGUNION:
  restrict_nonzero(BIGUNION ss) = BIGUNION (IMAGE restrict_nonzero ss)
Proof
  rw[restrict_nonzero_def,EXTENSION]>>
  rw[EQ_IMP_THM]
  >-
    (qexists_tac`{x | x ∈ s ∧ SND x ≠ 0}`>>
    simp[]>>
    qexists_tac`s`>>simp[])>>
  metis_tac[]
QED;

Definition option_le_def[simp]:
  option_le _ NONE = T /\
  option_le NONE (SOME _) = F /\
  option_le (SOME n1) (SOME n2) = (n1 <= n2:num)
End

Theorem option_le_refl[simp]:
  !x. option_le x x
Proof
  Cases_on `x` \\ fs []
QED

Theorem option_le_SOME_0[simp]:
  option_le (SOME 0) x
Proof
  Cases_on `x` \\ fs []
QED

Theorem option_le_trans:
  !x y z. option_le x y /\ option_le y z ==> option_le x z
Proof
  Cases_on `x` \\ Cases_on `y` \\ Cases_on `z` \\ fs []
QED

Theorem option_le_max:
  option_le (OPTION_MAP2 MAX n m) x ⇔ option_le n x /\ option_le m x
Proof
  Cases_on `x` >> Cases_on `n` >> Cases_on `m` >> rw[]
QED

Theorem option_le_max_right:
  option_le x (OPTION_MAP2 MAX n m) ⇔ option_le x n \/ option_le x m
Proof
  Cases_on `x` >> Cases_on `n` >> Cases_on `m` >> rw[]
QED

Theorem option_add_comm:
  OPTION_MAP2 ($+) (n:num option) m = OPTION_MAP2 ($+) m n
Proof
  Cases_on `n` >> Cases_on `m` >> rw[]
QED

Theorem option_add_assoc:
  OPTION_MAP2 ($+) (n:num option) (OPTION_MAP2 ($+) m p)
  = OPTION_MAP2 ($+) (OPTION_MAP2 ($+) n m) p
Proof
  Cases_on `n` >> Cases_on `m` >>  Cases_on `p` >> rw[]
QED

Theorem option_le_eq_eqns:
  (option_le (OPTION_MAP2 $+ n m) (OPTION_MAP2 $+ n p)
   <=> (n = NONE \/ option_le m p)) /\
  (option_le (OPTION_MAP2 $+ n m) (OPTION_MAP2 $+ p m)
   <=> (m = NONE \/ option_le n p))
Proof
  Cases_on `n` >> Cases_on `m` >> Cases_on `p` >> rw[]
QED

Theorem option_map2_max_add:
  (OPTION_MAP2 $+ n (OPTION_MAP2 MAX m p) =
   OPTION_MAP2 MAX (OPTION_MAP2 $+ n m) (OPTION_MAP2 $+ n p)) /\
  (OPTION_MAP2 $+ (OPTION_MAP2 MAX m p) n =
   OPTION_MAP2 MAX (OPTION_MAP2 $+ m n) (OPTION_MAP2 $+ p n))
Proof
  Cases_on `n` >> Cases_on `m` >> Cases_on `p` >> rw[MAX_DEF]
QED

Theorem option_le_add:
  option_le n (OPTION_MAP2 $+ n m)
Proof
  Cases_on `n` >> Cases_on `m` >> rw[]
QED

Theorem OPTION_MAP2_MAX_COMM:
  OPTION_MAP2 MAX x y = OPTION_MAP2 MAX y x
Proof
  Cases_on `x` \\ Cases_on `y` \\ fs [MAX_DEF]
QED

Theorem OPTION_MAP2_MAX_ASSOC:
  OPTION_MAP2 MAX x (OPTION_MAP2 MAX y z) =
  OPTION_MAP2 MAX (OPTION_MAP2 MAX x y) z
Proof
  Cases_on `x` \\ Cases_on `y` \\ Cases_on `z` \\ fs [MAX_DEF]
QED

val _ = export_theory();
