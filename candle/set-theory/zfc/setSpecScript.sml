(*
  Zermelo's set theory
*)
app load ["SatisfySimps"];
open HolKernel SatisfySimps boolLib boolSimps bossLib pred_setTheory cardinalTheory pairTheory
val _ = temp_tight_equality()
val _ = new_theory"setSpec"

(* TODO: this functionality should be implemented by Parse *)
local val ct = current_theory () in
fun remove_tyabbrev s =
  let
    val _ = Parse.temp_set_grammars(type_grammar.remove_abbreviation(Parse.type_grammar())s,Parse.term_grammar())
    val q = String.concat["val ",ct,"_grammars = (type_grammar.remove_abbreviation(#1 ",ct,"_grammars)\"",s,"\",#2 ",ct,"_grammars);"]
    val _ = adjoin_to_theory{sig_ps=NONE, struct_ps=SOME(fn _ => PP.add_string q)}
  in () end
end
val _ = remove_tyabbrev"reln"
val _ = remove_tyabbrev"inf"
(* -- *)

val REFORM_RULE = CONV_RULE (TOP_DEPTH_CONV RIGHT_IMP_FORALL_CONV
                             THENC REWRITE_CONV[AND_IMP_INTRO])

(* http://www.lemma-one.com/ProofPower/specs/spc002.pdf *)

val mem = ``mem:'U->'U->bool``

val _ = Parse.add_infix("<:",425,Parse.NONASSOC)
Overload "<:" = ``mem:'U->'U->bool``

Definition extensional_def:
  extensional ^mem ⇔ ∀x y. x = y ⇔ ∀a. mem a x ⇔ mem a y
End

Definition is_separation_def:
  is_separation ^mem sub ⇔ ∀x P. ∀a. mem a (sub x P) ⇔ mem a x ∧ P a
End

Definition is_power_def:
  is_power ^mem power ⇔ ∀x. ∀a. mem a (power x) ⇔ ∀b. mem b a ⇒ mem b x
End

Definition is_union_def:
  is_union ^mem union ⇔ ∀x. ∀a. mem a (union x) ⇔ ∃b. mem a b ∧ mem b x
End

Definition is_upair_def:
  is_upair ^mem upair ⇔ ∀x y. ∀a. mem a (upair x y) ⇔ a = x ∨ a = y
End

Definition regular_def:
  regular ^mem ⇔ ∀x. (∃y. mem y x) ⇒ ∃y. mem y x ∧ ∀z. ~(mem z x ∧ mem z y)
End

Definition is_functional_def:
  is_functional (R:'a -> 'b -> bool) ⇔ ∀x y z. R x y ∧ R x z ⇒ y = z
End

Definition replacement_def:
  replacement ^mem ⇔
      ∀R. is_functional R ⇒
          ∀d. ∃r. ∀y. mem y r ⇔ ∃x. mem x d ∧ R x y
End

Definition is_set_theory_def:
  is_set_theory ^mem ⇔
    extensional mem ∧
    (∃sub. is_separation mem sub) ∧
    (∃power. is_power mem power) ∧
    (∃union. is_union mem union) ∧
    (∃upair. is_upair mem upair) ∧
    regular mem ∧
    replacement mem
End

Theorem separation_unique:
   extensional ^mem ⇒
    ∀sub1 sub2. is_separation mem sub1 ∧ is_separation mem sub2 ⇒ sub1 = sub2
Proof
  rw[is_separation_def,extensional_def,FUN_EQ_THM]
QED

Theorem power_unique:
   extensional ^mem ⇒
    ∀power1 power2. is_power mem power1 ∧ is_power mem power2 ⇒ power1 = power2
Proof
  rw[is_power_def,extensional_def,FUN_EQ_THM]
QED

Theorem union_unique:
   extensional ^mem ⇒
    ∀union1 union2. is_union mem union1 ∧ is_union mem union2 ⇒ union1 = union2
Proof
  rw[is_union_def,extensional_def,FUN_EQ_THM]
QED

Theorem upair_unique:
   extensional ^mem ⇒
    ∀upair1 upair2. is_upair mem upair1 ∧ is_upair mem upair2 ⇒ upair1 = upair2
Proof
  rw[is_upair_def,extensional_def,FUN_EQ_THM]
QED

Definition sub_def:
  sub ^mem = @sub. is_separation mem sub
End

Definition power_def:
  power ^mem = @power. is_power mem power
End

Definition union_def:
  union ^mem = @union. is_union mem union
End

Definition upair_def:
  upair ^mem = @upair. is_upair mem upair
End

Theorem is_extensional:
   is_set_theory ^mem ⇒ extensional mem
Proof
  rw[is_set_theory_def]
QED

Theorem is_separation_sub:
   is_set_theory ^mem ⇒ is_separation mem (sub mem)
Proof
  rw[sub_def] >> SELECT_ELIM_TAC >> fsrw_tac[SATISFY_ss][is_set_theory_def]
QED

Theorem is_power_power:
   is_set_theory ^mem ⇒ is_power mem (power mem)
Proof
  rw[power_def] >> SELECT_ELIM_TAC >> fsrw_tac[SATISFY_ss][is_set_theory_def]
QED

Theorem is_union_union:
   is_set_theory ^mem ⇒ is_union mem (union mem)
Proof
  rw[union_def] >> SELECT_ELIM_TAC >> fsrw_tac[SATISFY_ss][is_set_theory_def]
QED

Theorem is_upair_upair:
   is_set_theory ^mem ⇒ is_upair mem (upair mem)
Proof
  rw[upair_def] >> SELECT_ELIM_TAC >> fsrw_tac[SATISFY_ss][is_set_theory_def]
QED

Theorem is_regular:
   is_set_theory ^mem ⇒ regular mem
Proof
  rw[is_set_theory_def]
QED

val _ = Parse.add_infix("suchthat",9,Parse.LEFT)
Overload suchthat = ``sub ^mem``
Overload Pow = ``power ^mem``
Overload "+" = ``upair ^mem``
Overload "⋃" = ``union ^mem``

Theorem mem_sub:
   is_set_theory ^mem ⇒ ∀x s P. x <: (s suchthat P) ⇔ x <: s ∧ P x
Proof
  strip_tac >> imp_res_tac is_separation_sub >> fs[is_separation_def]
QED

Theorem mem_power:
   is_set_theory ^mem ⇒
    ∀x y. x <: (Pow y) ⇔ (∀b. b <: x ⇒ b <: y)
Proof
  strip_tac >> imp_res_tac is_power_power >> fs[is_power_def]
QED

Theorem mem_union:
   is_set_theory ^mem ⇒
    ∀x s. x <: ⋃ s ⇔ ∃a. x <: a ∧ a <: s
Proof
  strip_tac >> imp_res_tac is_union_union >> fs[is_union_def]
QED

Theorem mem_upair:
   is_set_theory ^mem ⇒ ∀a x y. a <: (x + y) ⇔ a = x ∨ a = y
Proof
  strip_tac >> imp_res_tac is_upair_upair >> fs[is_upair_def]
QED

Definition empty_def:
  empty ^mem = sub mem ARB (K F)
End

Overload "∅" = ``empty ^mem``

Theorem mem_empty:
   is_set_theory ^mem ⇒ ∀x. ¬(x <: ∅)
Proof
  strip_tac >> imp_res_tac is_separation_sub >>
  fs[empty_def,is_separation_def]
QED

Theorem not_empty:
   is_set_theory ^mem ⇒ ∀x. ¬(x = ∅) ⇔ ∃y. y <: x
Proof
  strip_tac >> imp_res_tac is_extensional >>
  fs[empty_def,extensional_def,mem_sub]
QED

Theorem eq_empty:
   is_set_theory ^mem ⇒ ∀x. (x = ∅) ⇔ ∀y. ~(y <: x)
Proof
  strip_tac >> imp_res_tac is_extensional >>
  fs[empty_def,extensional_def,mem_sub]
QED

Definition unit_def:
  unit ^mem x = x + x
End

Overload Unit = ``unit ^mem``

Theorem mem_unit:
   is_set_theory ^mem ⇒
    ∀x y. x <: (Unit y) ⇔ x = y
Proof
  strip_tac >> imp_res_tac is_upair_upair >>
  fs[is_upair_def,unit_def]
QED

Theorem unit_inj:
   is_set_theory ^mem ⇒
    ∀x y. Unit x = Unit y ⇔ x = y
Proof
  strip_tac >>
  imp_res_tac is_extensional >>
  fs[extensional_def,mem_unit] >>
  metis_tac[]
QED

Definition one_def:
  one ^mem = Unit ∅
End

Overload One = ``one ^mem``

Theorem mem_one:
   is_set_theory ^mem ⇒
    ∀x. x <: One ⇔ x = ∅
Proof
  strip_tac >> simp[mem_unit,one_def]
QED

Definition two_def:
  two ^mem = ∅ + One
End

Overload Two = ``two ^mem``

Theorem mem_two:
   is_set_theory ^mem ⇒
    ∀x. x <: Two ⇔ x = ∅ ∨ x = One
Proof
  strip_tac >> simp[mem_upair,mem_one,two_def]
QED

Definition binary_inter_def:
  binary_inter ^mem x y = (x suchthat λz. z <: y)
End

Overload INTER = ``binary_inter ^mem``

Theorem mem_binary_inter:
   is_set_theory ^mem ⇒
    ∀x y z. x <: y ∩ z ⇔ x <: y ∧ x <: z
Proof
  strip_tac >> simp[binary_inter_def,mem_sub]
QED

Definition subset_def:
  subset ^mem x y = ∀z. z <: x ⇒ z <: y
End

Overload SUBSET = ``subset ^mem``

Theorem subset_refl:
   is_set_theory ^mem ⇒
    ∀x. x ⊆ x
Proof
  strip_tac >> simp[subset_def]
QED

Theorem subset_mem:
   is_set_theory ^mem ⇒
    ∀x y z. x <: y ∧ y ⊆ z ⇒ x <: z
Proof
  strip_tac >> simp[subset_def]
QED

Definition psubset_def:
  psubset ^mem x y = (x ⊆ y ∧ ~(x = y))
End

Overload PSUBSET = ``psubset ^mem``

Definition pair_def:
  pair ^mem x y = (Unit x) + (x + y)
End

Overload "," = ``pair ^mem``

Theorem mem_pair:
   is_set_theory ^mem ⇒
    ∀a x y. a <: (x,y) ⇔ a = Unit x ∨ a = (x + y)
Proof
  strip_tac >>
  simp[pair_def,mem_upair]
QED

Theorem upair_inj:
   is_set_theory ^mem ⇒
    ∀a b c d. a + b = c + d ⇔ a = c ∧ b = d ∨ a = d ∧ b = c
Proof
  strip_tac >>
  imp_res_tac is_extensional >>
  fs[extensional_def,mem_upair] >>
  metis_tac[]
QED

Theorem unit_eq_upair:
   is_set_theory ^mem ⇒
    ∀x y z. Unit x = y + z ⇔ x = y ∧ y = z
Proof
  strip_tac >>
  imp_res_tac is_extensional >>
  fs[extensional_def,mem_unit,mem_upair] >>
  metis_tac[]
QED

Theorem pair_inj:
   is_set_theory ^mem ⇒
    ∀a b c d. (a,b) = (c,d) ⇔ a = c ∧ b = d
Proof
  strip_tac >> fs[pair_def] >> rw[] >>
  simp[upair_inj,unit_inj,unit_eq_upair] >>
  metis_tac[]
QED

Definition binary_union_def:
  binary_union ^mem x y = ⋃ (upair mem x y)
End

Overload UNION = ``binary_union ^mem``

Theorem mem_binary_union:
   is_set_theory ^mem ⇒
    ∀a x y. a <: (x ∪ y) ⇔ a <: x ∨ a <: y
Proof
  strip_tac >> fs[binary_union_def,mem_union,mem_upair] >>
  metis_tac[]
QED

Definition product_def:
  product ^mem x y =
    (Pow (Pow (x ∪ y)) suchthat
     λa. ∃b c. b <: x ∧ c <: y ∧ a = (b,c))
End

Overload CROSS = ``product ^mem``

Theorem mem_product:
   is_set_theory ^mem ⇒
    ∀a x y. a <: (x × y) ⇔ ∃b c. a = (b,c) ∧ b <: x ∧ c <: y
Proof
  strip_tac >> fs[product_def] >>
  simp[mem_sub,mem_power,mem_binary_union] >>
  rw[EQ_IMP_THM] >> TRY(metis_tac[]) >>
  rfs[pair_def,mem_upair] >> rw[] >>
  rfs[mem_unit,mem_upair]
QED

Definition relspace_def:
  relspace ^mem x y = Pow (x × y)
End

Overload Relspace = ``relspace ^mem``

Theorem mem_relspace:
   is_set_theory ^mem ⇒
    ∀d r f. f <: Relspace d r ⇔
            f <: Pow (d × r)
Proof
  rw[relspace_def]
QED

Theorem relspace_pairs:
   is_set_theory ^mem ⇒
    ∀d r f a. f <: Relspace d r ∧ a <: f ⇒ ∃x y. x <: d ∧ y <: r ∧ a = (x,y)
Proof
  strip_tac >>
  simp[relspace_def,mem_sub,mem_power,mem_product] >>
  metis_tac[]
QED

Theorem mem_rel:
   is_set_theory ^mem ⇒
    ∀d r f. f <: Relspace d r ⇒
            ∀x y. (x,y) <: f ⇒ x <: d ∧ y <: r
Proof
  strip_tac >>
  simp[relspace_def,mem_power,mem_product] >>
  metis_tac[pair_inj]
QED

Definition funspace_def:
  funspace ^mem x y =
    (Relspace x y suchthat
     λf. ∀a. a <: x ⇒ ∃!b. (a,b) <: f)
End

Overload Funspace = ``funspace ^mem``

Theorem mem_funspace:
   is_set_theory ^mem ⇒
    ∀d r f. f <: Funspace d r ⇔
            f <: Relspace d r ∧ ∀x. x <: d ⇒ ∃!y. (x,y) <: f
Proof
  rw[funspace_def,mem_sub]
QED

Theorem funspace_pairs:
   is_set_theory ^mem ⇒
    ∀d r f a. f <: Funspace d r ∧ a <: f ⇒ ∃x y. x <: d ∧ y <: r ∧ a = (x,y)
Proof
  strip_tac >>
  simp[funspace_def,mem_sub] >>
  metis_tac[relspace_pairs]
QED

Definition apply_def:
  apply ^mem x y = @a. (y,a) <: x
End

Overload "'" = ``apply ^mem``

Definition id_def:
  id ^mem d = (d × d suchthat λa. ∃b. a = (b,b))
End

Overload Id = ``id ^mem``

Theorem mem_id:
   is_set_theory ^mem ⇒
        ∀d x y. (x,y) <: Id d ⇔ (y <: d ∧ x = y)
Proof
  strip_tac >>
  simp[id_def,mem_sub,mem_product,pair_inj] >>
  rw[] >>
  EQ_TAC >>
  strip_tac >>
  asm_rewrite_tac[]
QED

Theorem replacement:
   is_set_theory ^mem ⇒
     ∀R. is_functional R ⇒
          ∀d. ∃r. ∀y. y <: r ⇔ ∃x. x <: d ∧ R x y
Proof
  DISCH_TAC >> IMP_RES_TAC is_set_theory_def >>
  IMP_RES_THEN MP_TAC replacement_def >>
  rw[]
QED

Definition image_def:
  image ^mem f d = @r. ∀y. y <: r ⇔ ∃x. x <: d ∧ f x = y
End

val _ = Parse.hide "''"
val _ = Parse.add_infix("''",2000,Parse.LEFT)
Overload "''" = ``image ^mem``

Theorem mem_image:
   is_set_theory ^mem ⇒
    ∀f d y. y <: f '' d ⇔ ∃x. x <: d ∧ f x = y
Proof
  REPEAT STRIP_TAC >>
  IMP_RES_TAC replacement >>
  `is_functional (λx y. f x = y)` by simp[is_functional_def] >>
  rw[image_def] >> SELECT_ELIM_TAC >> rw[replacement]
QED

Definition is_one_one_def:
  is_one_one ^mem f d ⇔ ∀x y z. x <: d ∧ (x,z) <: f ∧ (y,z) <: f ⇒ x = y
End

Overload is_11 = ``is_one_one ^mem``

Definition is_onto_def:
  is_onto ^mem f r ⇔ ∀y. y <: r ⇒ ∃x. (x,y) <: f
End

Overload is_Onto = ``is_onto ^mem``

Definition inverse_def:
  inverse ^mem f ⇔ @f1. ∀a. a <: f1 ⇔ ∃x y. a = (x,y) ∧ (y,x) <: f
End

Overload Inverse = ``inverse ^mem``

Theorem mem_inverse:
   is_set_theory ^mem ⇒
    ∀f x y. (x,y) <: Inverse f ⇔ (y,x) <: f
Proof
  strip_tac >> simp[inverse_def] >> rw[] >>
  SELECT_ELIM_TAC >>
  conj_tac >- (
    qexists_tac`(⋃ (⋃ f) × ⋃ (⋃ f)) suchthat λa. ∃x y. a = (x,y) ∧ (y,x) <: f` >>
    simp[mem_sub,mem_product,mem_union,pair_inj] >>
    metis_tac[mem_pair,mem_unit,mem_upair,pair_inj] ) >>
  metis_tac[pair_inj]
QED

Theorem inverse_pairs:
   is_set_theory ^mem ⇒
    ∀f a. a <: Inverse f ⇒ ∃y x. a = (y,x)
Proof
  strip_tac >> simp[inverse_def] >>
  REPEAT gen_tac >>
  SELECT_ELIM_TAC >>
  conj_tac >- (
    qexists_tac`(⋃ (⋃ f) × ⋃ (⋃ f)) suchthat λa. ∃x y. a = (x,y) ∧ (y,x) <: f` >>
    simp[mem_sub,mem_product,mem_union,pair_inj] >>
    metis_tac[mem_pair,mem_unit,mem_upair,pair_inj] ) >>
  metis_tac[]
QED

(* Unless f is 1-1 and onto, Inverse f is not a function. *)

Theorem funspace_inverse:
   is_set_theory ^mem ⇒
    ∀f d r. f <: Funspace d r ∧ is_11 f d ∧ is_Onto f r ⇒ Inverse f <: Funspace r d
Proof
  strip_tac >>
  simp[is_one_one_def,is_onto_def,mem_funspace,mem_relspace,mem_power,mem_product,EXISTS_UNIQUE_THM] >>
  REPEAT gen_tac >> strip_tac >>
  conj_tac >|
    [ rw[] >>
      imp_res_tac inverse_pairs >>
      metis_tac[mem_inverse,pair_inj],
      simp[mem_inverse] >>
      metis_tac[pair_inj]
    ]
QED

Theorem inverse_is_11_onto:
   is_set_theory ^mem ⇒
    ∀f d r. f <: Funspace d r ∧ is_11 f d ∧ is_Onto f r ⇒ is_11 (Inverse f) r ∧ is_Onto (Inverse f) d
Proof
  strip_tac >>
  simp[is_one_one_def,is_onto_def,mem_funspace,mem_relspace,mem_power,mem_product,EXISTS_UNIQUE_THM] >>
  REPEAT gen_tac >> strip_tac >>
  conj_tac >|
    [ simp[mem_inverse] >>
      metis_tac[pair_inj],
      simp[mem_inverse]
    ]
QED

Theorem mem_funspace_pairs:
   is_set_theory ^mem ⇒
    ∀f d r. f <: Funspace d r ⇒ ∀a. a <: f ⇒ ∃x y. a = (x,y)
Proof
  strip_tac >>
  simp[is_one_one_def,is_onto_def,mem_funspace,mem_relspace,mem_power,mem_product,EXISTS_UNIQUE_THM] >>
  metis_tac[]
QED

val pop_tac = pop_assum (fn th => all_tac)

Theorem inverse_inverse_eq_id:
   is_set_theory ^mem ⇒
    ∀f d r. f <: Funspace d r ∧ is_11 f d ∧ is_Onto f r ⇒ Inverse (Inverse f) = f
Proof
  rw[] >>
  `is_11 (Inverse f) r ∧ is_Onto (Inverse f) d` by metis_tac[inverse_is_11_onto] >>
  `Inverse f <: Funspace r d` by simp[funspace_inverse] >>
  `Inverse (Inverse f) <: Funspace d r` by simp[funspace_inverse] >>
  imp_res_tac is_extensional >>
  fs[extensional_def] >>
  pop_tac >>
  imp_res_tac mem_funspace_pairs >>
  metis_tac[pair_inj,mem_inverse]
QED

Overload boolset = ``Two``

Definition true_def:
  true ^mem = ∅
End

Definition false_def:
  false ^mem = One
End

Overload True = ``true ^mem``
Overload False = ``false ^mem``

Theorem true_neq_false:
   is_set_theory ^mem ⇒ True ≠ False
Proof
  strip_tac >>
  imp_res_tac mem_one >>
  imp_res_tac mem_empty >>
  fs[true_def,false_def,is_set_theory_def,extensional_def,one_def] >>
  metis_tac[]
QED

Theorem mem_boolset:
   is_set_theory ^mem ⇒
    ∀x. x <: boolset ⇔ ((x = True) ∨ (x = False))
Proof
  strip_tac >> fs[mem_two,true_def,false_def]
QED

Definition boolean_def:
  boolean ^mem b = if b then True else False
End

Overload Boolean = ``boolean ^mem``

Theorem boolean_in_boolset:
   is_set_theory ^mem ⇒
    ∀b. Boolean b <: boolset
Proof
  strip_tac >> imp_res_tac mem_boolset >>
  Cases >> simp[boolean_def]
QED

Theorem boolean_eq_true:
   is_set_theory ^mem ⇒ ∀b. Boolean b = True ⇔ b
Proof
  strip_tac >> rw[boolean_def,true_neq_false]
QED

Definition holds_def:
  holds ^mem s x ⇔ s ' x = True
End

Overload Holds = ``holds ^mem``

Definition suc_def:
  suc ^mem x = x ∪ Unit x
End

Overload Suc = ``suc ^mem``

Theorem mem_suc:
   is_set_theory ^mem ⇒
    ∀x y. x <: (Suc y) ⇔ x = y ∨ x <: y
Proof
  strip_tac >> rw[suc_def,mem_binary_union,mem_unit] >> METIS_TAC[]
QED

Theorem suc_not_empty:
   is_set_theory ^mem ⇒
    ∀x. ~(∅ = Suc x)
Proof
  strip_tac >>
  imp_res_tac is_extensional >>
  fs[extensional_def,mem_empty] >>
  simp[suc_def,mem_binary_union,mem_unit] >>
  metis_tac[]
QED

Theorem not_mem_ident:
   is_set_theory ^mem ⇒
    ∀x. ~(x <: x)
Proof
  strip_tac >>
  imp_res_tac is_regular >>
  gen_tac >>
  strip_tac >>
  fs[regular_def] >>
  first_assum (mp_tac o Q.SPEC`Unit x`) >>
  simp[mem_unit]
QED

Theorem not_mem_cycle:
   is_set_theory ^mem ⇒
    ∀x y. ~(x <: y ∧ y <: x)
Proof
  strip_tac >>
  imp_res_tac is_regular >>
  REPEAT gen_tac >>
  strip_tac >>
  fs[regular_def] >>
  first_assum (mp_tac o Q.SPEC`x + y`) >>
  metis_tac[mem_upair]
QED

Theorem suc_11:
   is_set_theory ^mem ⇒
    ∀x y. (Suc x = Suc y) ⇔ (x = y)
Proof
  metis_tac[mem_suc,not_mem_cycle]
QED


Definition abstract_def:
  abstract ^mem dom rng f = (dom × rng suchthat λx. ∃a. x = (a,f a))
End

Overload Abstract = ``abstract ^mem``

Theorem apply_abstract:
   is_set_theory ^mem ⇒
    ∀f x s t. x <: s ∧ f x <: t ⇒ (Abstract s t f) ' x = f x
Proof
  strip_tac >>
  rw[apply_def,abstract_def] >>
  SELECT_ELIM_TAC >>
  simp[mem_sub,mem_product,pair_inj]
QED

Theorem apply_abstract_matchable:
   ∀f x s t u. x <: s ∧ f x <: t ∧ is_set_theory ^mem ∧ f x = u ⇒ Abstract s t f ' x = u
Proof
  metis_tac[apply_abstract]
QED

Theorem apply_in_rng:
   is_set_theory ^mem ⇒
    ∀f x s t. x <: s ∧ f <: Funspace s t ⇒
    f ' x <: t
Proof
  strip_tac >>
  simp[funspace_def,mem_sub,relspace_def,
       mem_power,apply_def,mem_product,EXISTS_UNIQUE_THM] >>
  rw[] >> res_tac >> SELECT_ELIM_TAC >> res_tac >> rfs[pair_inj] >> metis_tac[]
QED

Theorem abstract_in_funspace:
   is_set_theory ^mem ⇒
    ∀f s t. (∀x. x <: s ⇒ f x <: t) ⇒ Abstract s t f <: Funspace s t
Proof
  strip_tac >>
  simp[funspace_def,relspace_def,abstract_def,mem_power,mem_product,mem_sub] >>
  simp[EXISTS_UNIQUE_THM,pair_inj]
QED

Theorem abstract_eq:
   is_set_theory ^mem ⇒
    ∀s t1 t2 f g.
    (∀x. x <: s ⇒ f x <: t1 ∧ g x <: t2 ∧ f x = g x)
    ⇒ Abstract s t1 f = Abstract s t2 g
Proof
  rw[] >>
  imp_res_tac is_extensional >>
  pop_assum mp_tac >>
  simp[extensional_def] >>
  disch_then kall_tac >>
  simp[abstract_def,mem_sub,mem_product] >>
  metis_tac[pair_inj]
QED

Theorem in_funspace_abstract:
   is_set_theory ^mem ⇒
    ∀z s t. z <: Funspace s t ⇒
    ∃f. z = Abstract s t f ∧ (∀x. x <: s ⇒ f x <: t)
Proof
  rw[funspace_def,mem_sub,relspace_def,mem_power] >>
  qexists_tac`λx. @y. (x,y) <: z` >>
  conj_tac >- (
    imp_res_tac is_extensional >>
    pop_assum(fn th => SIMP_TAC std_ss [SIMP_RULE std_ss [extensional_def] th]) >>
    simp[abstract_def,EQ_IMP_THM] >> gen_tac >>
    rfs[mem_sub,mem_product] >>
    conj_tac >>
    TRY strip_tac >>
    rfs[pair_inj] >>
    fs[EXISTS_UNIQUE_THM] >>
    metis_tac[] ) >>
  rfs[EXISTS_UNIQUE_THM,mem_product] >>
  metis_tac[pair_inj]
QED

Theorem apply_eq_mem:
   is_set_theory ^mem ⇒
    ∀f d r. f <: Funspace d r ⇒
            ∀x. x <: d ⇒ ∀y. f ' x = y ⇔ (x,y) <: f
Proof
  strip_tac >> simp[apply_def,mem_funspace,EXISTS_UNIQUE_THM] >> rw[] >>
  SELECT_ELIM_TAC >>
  conj_tac >- simp[] >>
  metis_tac[]
QED

Theorem id_funspace:
   is_set_theory ^mem ⇒
    ∀d. Id d <: Funspace d d
Proof
  strip_tac >>
  simp[id_def,funspace_def,mem_sub,mem_relspace,mem_power,mem_product,pair_inj,EXISTS_UNIQUE_THM]
QED

Theorem apply_id:
   is_set_theory ^mem ⇒
    ∀d x. x <: d ⇒ Id d ' x = x
Proof
  rw[] >>
  imp_res_tac id_funspace >>
  pop_assum (assume_tac o SPEC_ALL) >>
  imp_res_tac apply_eq_mem >>
  asm_rewrite_tac[] >>
  simp[mem_id]
QED

Theorem apply_extensional:
   is_set_theory ^mem ⇒
    ∀d r f g. f <: Funspace d r ∧ g <: Funspace d r ⇒ ((f = g) ⇔ ∀x. x <: d ⇒ f ' x = g ' x)
Proof
  rw[] >>
  EQ_TAC >|
    [ strip_tac >>
      asm_rewrite_tac[],

      strip_tac >>
      imp_res_tac is_extensional >>
      pop_assum mp_tac >>
      simp[extensional_def] >>
      disch_then kall_tac >>
      gen_tac >> EQ_TAC >> strip_tac >>
      `∃x y. x <: d ∧ y <: r ∧ a = (x,y)` by metis_tac[funspace_pairs] >>
      pop_assum (fn th => fs[th]) >>
      res_tac >>
      pop_assum mp_tac >>
      metis_tac[apply_eq_mem]
    ]
QED

Definition dep_funspace_def:
  dep_funspace ^mem d f =
    (Funspace d (⋃ (f '' d)) suchthat
     λg. ∀x. x <: d ⇒ g ' x <: f x)
End

Overload Dep_funspace = ``dep_funspace ^mem``

Theorem mem_dep_funspace:
   is_set_theory ^mem ⇒
    ∀f d g. g <: Dep_funspace d f ⇔
            g <: Relspace d (⋃ (f '' d)) ∧
            ∀x. x <: d ⇒ (∃!y. (x,y) <: g) ∧ g ' x <: f x
Proof
  rw[dep_funspace_def,mem_sub,mem_funspace] >>
  METIS_TAC[]
QED

Definition dep_prodspace_def:
  dep_prodspace ^mem d f =
    (d × ⋃ (f '' d) suchthat
     λr. ∀x y. (x,y) <: r ⇒ x <: d ∧ y <: f x)
End

Overload Dep_prodspace = ``dep_prodspace ^mem``

Theorem mem_dep_prodspace:
   is_set_theory ^mem ⇒
    ∀f d r. r <: Dep_prodspace d f ⇔
            r <: d × ⋃ (f '' d) ∧
            ∀x y. (x,y) <: r ⇒ x <: d ∧ y <: f x
Proof
  rw[dep_prodspace_def,mem_sub]
QED

Theorem axiom_of_choice =
  UNDISCH(prove(
  ``is_set_theory ^mem ⇒
    ∀x. (∀a. mem a x ⇒ ∃b. mem b a) ⇒
       ∃f. ∀a. mem a x ⇒ mem (f ' a) a``,
  rw[] >>
  qexists_tac`Abstract x (union mem x) (λa. @b. mem b a)` >>
  rw[] >>
  qmatch_abbrev_tac`z <: a` >>
  qsuff_tac`z = @b. b <: a` >- (
    SELECT_ELIM_TAC >> rw[] ) >>
  unabbrev_all_tac >>
  match_mp_tac apply_abstract_matchable >>
  rw[mem_union] >>
  SELECT_ELIM_TAC >> rw[] >>
  metis_tac[]))

val indset = ``indset:'U``
val ch = ``ch:'U->'U``
val s = ``(^mem,^indset,^ch)``

Overload M = ``(^mem,^indset,^ch)``

Definition is_choice_def:
  is_choice ^mem ch = ∀x. (∃a. a <: x) ⇒ ch x <: x
End

Definition is_infinite_def:
  is_infinite ^mem s = INFINITE {a | a <: s}
End

(* The following version of the infinity axiom is taken from page 12 of
   "Set Theory, The Third Millennium Edition" by Thomas Jech, Springer, 2006,
   using the successor operator as defined (Definition 1.20) on page 19 of
   "Introduction to Set Theory" by J. Donald Monk, McGraw Hill, 1969.
*)

Definition is_inductive_def:
  is_inductive ^mem s ⇔
      ∅ <: s ∧ ∀x. x <: s ⇒ Suc x <: s
End

Definition is_model_def:
  is_model ^s ⇔
    is_set_theory mem ∧
    is_inductive mem indset ∧
    is_choice mem ch
End

Theorem is_model_is_set_theory:
   is_model M ⇒ is_set_theory ^mem
Proof
  rw[is_model_def]
QED

Theorem indset_inhabited:
   is_infinite ^mem indset ⇒ ∃i. i <: indset
Proof
  rw[is_infinite_def] >> imp_res_tac INFINITE_INHAB >>
  fs[] >> metis_tac[]
QED

Theorem inductive_set_inhabited:
   is_inductive ^mem indset ⇒ ∃i. i <: indset
Proof
  metis_tac[is_inductive_def]
QED

Definition num2indset_def:
  (num2indset ^mem 0 = ∅) ∧
  (num2indset ^mem (SUC n) = Suc (num2indset mem n))
End

Overload Num2indset = ``num2indset ^mem``

Theorem num2indset_in_indset:
   is_inductive ^mem indset ⇒ ∀n. Num2indset n <: indset
Proof
  simp[is_inductive_def] >>
  strip_tac >>
  Induct >>
  simp[num2indset_def]
QED

Theorem empty_num2indset:
   is_set_theory ^mem ⇒
    ∀n. ∅ = Num2indset n ∨ ∅ <: Num2indset n
Proof
  strip_tac >>
  Induct >>
  simp[num2indset_def,mem_suc]
QED

Theorem full_mem_num2indset:
   is_set_theory ^mem ⇒
    ∀n m. m < n ⇒ Num2indset m <: Num2indset n
Proof
  strip_tac >>
  Induct >>
  simp[prim_recTheory.NOT_LESS_0,prim_recTheory.LESS_THM,num2indset_def,mem_suc] >>
  metis_tac[]
QED

Theorem mem_num2indset_is_num2indset:
   is_set_theory ^mem ⇒
    ∀n a. a <: Num2indset n ⇒ ∃m. a = Num2indset m ∧ m < n
Proof
  strip_tac >>
  Induct >>
  simp[prim_recTheory.NOT_LESS_0,prim_recTheory.LESS_THM,num2indset_def,mem_empty,mem_suc] >>
  metis_tac[]
QED

Theorem mem_num2indset_is_num2indset_eq:
   is_set_theory ^mem ⇒
    ∀n a. (a <: Num2indset n) = ∃m. a = Num2indset m ∧ m < n
Proof
  metis_tac[mem_num2indset_is_num2indset,full_mem_num2indset]
QED

val MAX_SUC = TAC_PROOF(([],
  ``∀a b. MAX (SUC a) (SUC b) = SUC (MAX a b)``),
  simp[arithmeticTheory.MAX_DEF])

Theorem num2indset_11:
   is_set_theory ^mem ⇒
    ∀n m. (Num2indset n = Num2indset m) ⇔ (n = m)
Proof
  strip_tac >>
  completeInduct_on `MAX n m` >>
  Cases >> Cases >>
  simp[num2indset_def,mem_suc,mem_empty,suc_not_empty,empty_num2indset] >>
  simp[MAX_SUC] >>
  strip_tac >>
  first_assum (mp_tac o Q.SPEC`MAX n' n`) >>
  first_assum (fn th => rewrite_tac[th]) >>
  rewrite_tac[prim_recTheory.LESS_SUC_REFL] >>
  strip_tac >>
  simp[suc_11]
QED

Theorem num2indset_mem_less:
   is_set_theory ^mem ⇒
    ∀n m. (Num2indset m <: Num2indset n) ⇔ (m < n)
Proof
  strip_tac >>
  simp[mem_num2indset_is_num2indset_eq] >>
  simp[num2indset_11]
QED

Theorem inductive_set_infinite:
   is_set_theory ^mem ∧ is_inductive ^mem indset ⇒ is_infinite mem indset
Proof
  rw[is_infinite_def] >>
  match_mp_tac (REFORM_RULE INFINITE_SUBSET) >>
  qexists_tac`pred_set$IMAGE Num2indset UNIV` >>
  conj_tac >| [
      match_mp_tac (REFORM_RULE IMAGE_11_INFINITE) >>
      simp_tac (bool_ss ++ pred_setLib.PRED_SET_ss) [] >>
      simp[num2indset_11],

      simp_tac (bool_ss ++ pred_setLib.PRED_SET_ss) [SUBSET_DEF] >>
      rw[] >>
      simp[num2indset_in_indset] ]
QED

Theorem funspace_inhabited:
   is_set_theory ^mem ⇒ ∀s t. (∃x. x <: s) ∧ (∃x. x <: t) ⇒ ∃f. f <: Funspace s t
Proof
  rw[] >> qexists_tac`Abstract s t (λx. @x. x <: t)` >>
  match_mp_tac (MP_CANON abstract_in_funspace) >>
  metis_tac[]
QED

Definition tuple_def:
  (tuple0 ^mem [] = ∅) ∧
  (tuple0 ^mem (a::as) = (a, tuple0 ^mem as))
End
Overload tuple = ``tuple0 ^mem``

Theorem pair_not_empty:
   is_set_theory ^mem ⇒ (x,y) ≠ ∅
Proof
  rw[] >>
  imp_res_tac is_extensional >>
  fs[extensional_def,mem_empty] >>
  pop_assum kall_tac >>
  simp[pair_def,mem_upair] >>
  metis_tac[]
QED

Theorem tuple_empty:
   is_set_theory ^mem ⇒ ∀ls. tuple ls = ∅ ⇔ ls = []
Proof
  strip_tac >> Cases >> simp[tuple_def] >>
  simp[pair_not_empty]
QED

Theorem tuple_inj:
   is_set_theory ^mem ⇒
    ∀l1 l2. tuple l1 = tuple l2 ⇔ l1 = l2
Proof
  strip_tac >>
  Induct >> simp[tuple_def] >- metis_tac[tuple_empty] >>
  gen_tac >> Cases >> simp[tuple_def,pair_not_empty] >>
  simp[pair_inj]
QED

Definition bigcross_def:
  (bigcross0 ^mem [] = One) ∧
  (bigcross0 ^mem (a::as) = a × (bigcross0 ^mem as))
End
Overload bigcross = ``bigcross0 ^mem``

Theorem mem_bigcross:
   is_set_theory ^mem ⇒
    ∀ls x. (mem x (bigcross ls) ⇔ ∃xs. x = tuple xs ∧ LIST_REL mem xs ls)
Proof
  strip_tac >> Induct >>
  simp[bigcross_def,tuple_def,mem_one] >>
  simp[mem_product,PULL_EXISTS,tuple_def]
QED

val _ = print_theory_to_file "-" "setSpec";

val _ = export_theory()
