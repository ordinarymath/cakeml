(*
  Definition of the PEG for CakeML.
  Includes a proof that the PEG is well-formed.
*)

open HolKernel Parse boolLib bossLib
     gramTheory pegexecTheory pegTheory

local open tokenUtilsTheory monadsyntax finite_mapSyntax in end
fun Store_thm(n,t,tac) = store_thm(n,t,tac) before export_rewrites [n]

val _ = new_theory "cmlPEG"
val _ = set_grammar_ancestry ["pegexec", "gram", "tokenUtils"]

val _ = monadsyntax.temp_add_monadsyntax()

Overload monad_bind = “OPTION_BIND”
Overload assert = “OPTION_GUARD”

val distinct_ths = let
  val ntlist = TypeBase.constructors_of ``:MMLnonT``
  fun recurse [] = []
    | recurse (t::ts) = let
      val eqns = map (fn t' => mk_eq(t,t')) ts
      val ths0 = map (SIMP_CONV (srw_ss()) []) eqns
      val ths1 = map (CONV_RULE (LAND_CONV (REWR_CONV EQ_SYM_EQ))) ths0
    in
      ths0 @ ths1 @ recurse ts
    end
in
  recurse ntlist
end


val _ = computeLib.add_thms distinct_ths computeLib.the_compset

Definition sumID_def:
  sumID (INL x) = x ∧
  sumID (INR y) = y
End

Definition mktokLf_def:
  mktokLf t = [Lf (TK (FST t), SND t)]
End

Definition mkNd_def:
  mkNd ntnm l = Nd (ntnm, ptree_list_loc l) l
End

Definition bindNT0_def:
  bindNT0 ntnm l = Nd (mkNT ntnm, ptree_list_loc l) l
End

Definition bindNT_def:
  bindNT ntnm l = [bindNT0 ntnm l]
End

Definition mk_linfix_def:
  mk_linfix tgt acc [] = acc ∧
  mk_linfix tgt acc [t] = acc ∧
  mk_linfix tgt acc (opt::t::rest) =
   mk_linfix tgt (mkNd tgt [acc; opt; t]) rest
End

Definition mk_rinfix_def:
  mk_rinfix tgt [] = mkNd tgt [] ∧
  mk_rinfix tgt [t] = mkNd tgt [t] ∧
  mk_rinfix tgt (t::opt::rest) = mkNd tgt [t; opt; mk_rinfix tgt rest]
End

Definition peg_linfix_def:
  peg_linfix tgtnt rptsym opsym =
    seq rptsym (rpt (seq opsym rptsym (++)) FLAT)
        (λa b. case a of
                   [] => []
                  | h::_ => [mk_linfix tgtnt (mkNd tgtnt [h]) b])
End

(* have to use these versions of choicel and pegf below because the
   "built-in" versions from HOL/examples/ use ARB in their definitions.
   Logically, the ARBs are harmless, but they completely mess with the
   translator
*)
Definition choicel_def:
  choicel [] = not (empty []) [] ∧
  choicel (h::t) = choice h (choicel t) sumID
End

Definition pegf_def:
  pegf sym f = seq sym (empty []) (λl1 l2. f l1)
End

Definition seql_def:
  seql l f = pegf (FOLDR (\p acc. seq p acc (++)) (empty []) l) f
End

(* unused
Definition peg_nonfix_def:
  peg_nonfix tgtnt argsym opsym =
    seql [argsym; choicel [seq opsym argsym (++); empty []]] (bindNT tgtnt)
End *)

Definition try_def:
  try sym = choicel [sym; empty []]
End

Definition tokeq_def:
  tokeq t = tok ((=) t) mktokLf
End

Definition tokSymP_def:
  tokSymP P =
    tok (λt. (do s <- destSymbolT t; assert (P s) od) = SOME ()) mktokLf
End

Definition pnt_def:
  pnt ntsym = nt (mkNT ntsym) I
End

(* ----------------------------------------------------------------------
    PEG for types
   ---------------------------------------------------------------------- *)

Definition peg_UQConstructorName_def:
  peg_UQConstructorName =
    tok (λt. do s <- destAlphaT t ;
                assert (s ≠ "" ∧ isUpper (HD s))
             od = SOME ())
        (bindNT nUQConstructorName o mktokLf)
End

Definition peg_TypeDec_def:
  peg_TypeDec =
    seq (tokeq DatatypeT)
        (peg_linfix (mkNT nDtypeDecls) (pnt nDtypeDecl)
                    (tokeq AndT))
        (λl1 l2. bindNT nTypeDec (l1 ++ l2))
End

(* expressions *)
Definition peg_V_def:
  peg_V =
   choicel [tok (λt.
                  do s <- destAlphaT t;
                     assert(s ∉ {"before"; "div"; "mod"; "o"} ∧
                            s ≠ "" ∧ ¬isUpper (HD s))
                  od = SOME ())
                (bindNT nV o mktokLf);
            pegf (tokSymP validPrefixSym) (bindNT nV)]
End

Definition peg_longV_def:
  peg_longV = tok (λt. do
                        (str,s) <- destLongidT t;
                        assert(s <> "" ∧ (isAlpha (HD s) ⇒ ¬isUpper (HD s)))
                       od = SOME ())
                  (bindNT nFQV o mktokLf)
End

Definition peg_EbaseParenFn_def:
  peg_EbaseParenFn l =
    case l of
      [lp; es; rp] => [mkNd (mkNT nEbase) [lp; mkNd (mkNT nEseq) [es]; rp]]
    | [lp; e; sep; es; rp] =>
      (case destLf sep of
         NONE => []
       | SOME t =>
         (case destTOK t of
            NONE => []
          | SOME t =>
            if t = CommaT then
              [
                mkNd (mkNT nEbase) [
                  mkNd (mkNT nEtuple) [lp; mkNd (mkNT nElist2) [e; sep; es]; rp]
                ]
              ]
            else
              [
                mkNd (mkNT nEbase) [lp; mkNd (mkNT nEseq) [e; sep; es]; rp]
              ]))
    | _ => []
End

Definition peg_EbaseParen_def:
  peg_EbaseParen =
    seql [tokeq LparT; pnt nE;
          choicel [tokeq RparT;
                   seql [tokeq CommaT; pnt nElist1; tokeq RparT] I;
                   seql [tokeq SemicolonT; pnt nEseq; tokeq RparT] I]]
         peg_EbaseParenFn
End
Definition peg_StructName_def:
  peg_StructName =
    tok (λt. do s <- destAlphaT t ;
                assert (s ≠ "")
             od = SOME ())
        (bindNT nStructName o mktokLf)
End

Definition ptPapply0_def:
  ptPapply0 c [] = [] (* can't happen *) ∧
  ptPapply0 c [pb_pt] = bindNT nPapp [c; pb_pt] ∧
  ptPapply0 c (pb::pbs) = ptPapply0 (bindNT0 nPConApp [c;pb]) pbs
End

Definition ptPapply_def:
  ptPapply [] = [] (* can't happen *) ∧
  ptPapply [_] = [] (* can't happen *) ∧
  ptPapply (c::rest) = ptPapply0 (bindNT0 nPConApp [c]) rest
End


Definition cmlPEG_def[nocompute]:
  cmlPEG = <|
    anyEOF := "Didn't expect an EOF";
    tokFALSE := "Failed to see expected token";
    tokEOF := "Failed to see expected token; saw EOF instead";
    notFAIL := "Not combinator failed";
    start := pnt nTopLevelDecs;
    rules := FEMPTY |++
             [(mkNT nV, peg_V);
              (mkNT nTyvarN, pegf (tok isTyvarT mktokLf) (bindNT nTyvarN));
              (mkNT nFQV, choicel [pegf (pnt nV) (bindNT nFQV); peg_longV]);
              (mkNT nEapp,
               seql [pnt nEbase; rpt (pnt nEbase) FLAT]
                    (λl.
                       case l of
                         [] => []
                       | h::t => [FOLDL (λa b. mkNd (mkNT nEapp) [a;b])
                                        (mkNd (mkNT nEapp) [h]) t]));
              (mkNT nElist1,
               seql [pnt nE; try (seql [tokeq CommaT; pnt nElist1] I)]
                    (bindNT nElist1));
              (mkNT nMultOps,
               pegf (
                 choicel (
                   tokSymP validMultSym ::
                   MAP tokeq [StarT; AlphaT "mod"; AlphaT "div"]
                 )
               ) (bindNT nMultOps));
              (mkNT nAddOps, pegf (tokSymP validAddSym) (bindNT nAddOps));
              (mkNT nRelOps,
               pegf (choicel [tokeq EqualsT; tokSymP validRelSym])
                    (bindNT nRelOps));
              (mkNT nListOps, pegf (tokSymP validListSym) (bindNT nListOps));
              (mkNT nCompOps, pegf (choicel [tokeq (SymbolT ":=");
                                             tokeq (AlphaT "o")])
                                   (bindNT nCompOps));
              (mkNT nOpID,
               choicel [tok (λt. do
                                   (str,s) <- destLongidT t;
                                   assert(s ≠ "")
                                 od = SOME ()) (bindNT nOpID o mktokLf);
                        tok (λt. do
                                   s <- destSymbolT t;
                                   assert (s ≠ "")
                                 od = SOME ()) (bindNT nOpID o mktokLf);
                        tok (λt. do
                                   s <- destAlphaT t;
                                   assert (s ≠ "")
                                 od = SOME ()) (bindNT nOpID o mktokLf);
                        pegf (tokeq StarT) (bindNT nOpID);
                        pegf (tokeq EqualsT) (bindNT nOpID);
              ]);
              (mkNT nEliteral,
               choicel [tok isInt (bindNT nEliteral o mktokLf);
                        tok isString (bindNT nEliteral o mktokLf);
                        tok isCharT (bindNT nEliteral o mktokLf);
                        tok isWordT (bindNT nEliteral o mktokLf);
                        tok (IS_SOME o destFFIT) (bindNT nEliteral o mktokLf)]);
              (mkNT nEbase,
               choicel [pegf (pnt nEliteral) (bindNT nEbase);
                        seql [tokeq LparT; tokeq RparT] (bindNT nEbase);
                        peg_EbaseParen;
                        seql [tokeq LbrackT; try (pnt nElist1); tokeq RbrackT]
                             (bindNT nEbase);
                        seql [tokeq LetT; pnt nLetDecs; tokeq InT; pnt nEseq;
                              tokeq EndT] (bindNT nEbase);
                        pegf (pnt nFQV) (bindNT nEbase);
                        pegf (pnt nConstructorName) (bindNT nEbase);
                        seql [tokeq OpT; pnt nOpID] (bindNT nEbase);
              ]);
              (mkNT nEseq,
               seql [pnt nE; try (seql [tokeq SemicolonT; pnt nEseq] I)]
                    (bindNT nEseq));
              (mkNT nEmult,
               peg_linfix (mkNT nEmult) (pnt nEapp) (pnt nMultOps));
              (mkNT nEadd, peg_linfix (mkNT nEadd) (pnt nEmult) (pnt nAddOps));
              (mkNT nElistop,
               seql [pnt nEadd; try (seql [pnt nListOps; pnt nElistop] I)]
                    (bindNT nElistop));
              (mkNT nErel, peg_linfix (mkNT nErel) (pnt nElistop) (pnt nRelOps));
              (mkNT nEcomp, peg_linfix (mkNT nEcomp) (pnt nErel)
                                       (pnt nCompOps));
              (mkNT nEbefore, peg_linfix (mkNT nEbefore) (pnt nEcomp)
                                         (tokeq (AlphaT "before")));
              (mkNT nEtyped, seql [pnt nEbefore;
                                   try (seql [tokeq ColonT; pnt nType] I)]
                                  (bindNT nEtyped));
              (mkNT nElogicAND,
               peg_linfix (mkNT nElogicAND) (pnt nEtyped)
                          (tokeq AndalsoT));
              (mkNT nElogicOR,
               peg_linfix (mkNT nElogicOR) (pnt nElogicAND)
                          (tokeq OrelseT));
              (mkNT nEhandle,
               seql [pnt nElogicOR;
                     try (seql [tokeq HandleT; pnt nPEs] I)]
                    (bindNT nEhandle)
              );
              (mkNT nE,
               choicel [seql [tokeq RaiseT; pnt nE] (bindNT nE);
                        pegf (pnt nEhandle) (bindNT nE);
                        seql [tokeq IfT; pnt nE; tokeq ThenT; pnt nE;
                              tokeq ElseT; pnt nE]
                             (bindNT nE);
                        seql [tokeq FnT; pnt nPattern; tokeq DarrowT; pnt nE]
                             (bindNT nE);
                        seql [tokeq CaseT; pnt nE; tokeq OfT; pnt nPEs]
                             (bindNT nE)]);
              (mkNT nE',
               choicel [seql [tokeq RaiseT; pnt nE'] (bindNT nE');
                        pegf (pnt nElogicOR) (bindNT nE');
                        seql [tokeq IfT; pnt nE; tokeq ThenT; pnt nE;
                              tokeq ElseT; pnt nE'] (bindNT nE')]);
              (mkNT nPEs,
               choicel [seql [pnt nPE'; tokeq BarT; pnt nPEs] (bindNT nPEs);
                        pegf (pnt nPE) (bindNT nPEs)]);
              (mkNT nPE, seql [pnt nPattern; tokeq DarrowT; pnt nE]
                              (bindNT nPE));
              (mkNT nPE', seql [pnt nPattern; tokeq DarrowT; pnt nE']
                               (bindNT nPE'));
              (mkNT nAndFDecls,
               peg_linfix (mkNT nAndFDecls) (pnt nFDecl) (tokeq AndT));
              (mkNT nFDecl,
               seql [pnt nV; pnt nPbaseList1; tokeq EqualsT; pnt nE]
                    (bindNT nFDecl));
              (mkNT nPbaseList1,
               seql [pnt nPbase; try (pnt nPbaseList1)]
                    (bindNT nPbaseList1));
              (mkNT nType,
               seql [pnt nPType; try (seql [tokeq ArrowT; pnt nType] I)]
                    (bindNT nType));
              (mkNT nDType,
               seql [pnt nTbase; rpt (pnt nTyOp) FLAT]
                    (λsubs.
                       case subs of
                           [] => []
                         | h::t => [FOLDL (λa b. mkNd (mkNT nDType) [a; b])
                                          (mkNd (mkNT nDType) [h]) t]));
              (mkNT nTbase,
               choicel [
                 seql [tokeq LparT; pnt nType; tokeq RparT] (bindNT nTbase);
                 seql [tokeq LparT; pnt nTypeList2; tokeq RparT; pnt nTyOp]
                      (bindNT nTbase);
                 tok isTyvarT (bindNT nTbase o mktokLf);
                 pegf (pnt nTyOp) (bindNT nTbase)
               ]);
              (mkNT nPTbase,
               choicel [
                 seql [tokeq LparT; pnt nType; tokeq RparT] (bindNT nPTbase);
                 tok isTyvarT (bindNT nPTbase o mktokLf);
                 pegf (pnt nTyOp) (bindNT nPTbase)
               ]);
              (mkNT nTypeList2,
               seql [pnt nType; tokeq CommaT; pnt nTypeList1]
                    (bindNT nTypeList2));
              (mkNT nTypeList1,
               seql [pnt nType; try (seql [tokeq CommaT; pnt nTypeList1] I)]
                    (bindNT nTypeList1));
              (mkNT nTbaseList,
               pegf (try (seql [pnt nPTbase; pnt nTbaseList] I))
                    (bindNT nTbaseList));
              (mkNT nTyOp,
               pegf (choicel [pnt nUQTyOp; tok isLongidT mktokLf])
                    (bindNT nTyOp));
              (mkNT nUQTyOp,
               pegf (tok isAlphaSym mktokLf) (bindNT nUQTyOp));
              (mkNT nPType,
               seql [pnt nDType; try (seql [tokeq StarT; pnt nPType] I)]
                    (bindNT nPType));
              (mkNT nTypeName,
               choicel [pegf (pnt nUQTyOp) (bindNT nTypeName);
                        seql [tokeq LparT; pnt nTyVarList;
                              tokeq RparT; pnt nUQTyOp] (bindNT nTypeName);
                        seql [tok isTyvarT mktokLf; pnt nUQTyOp]
                             (bindNT nTypeName)
                       ]);
              (mkNT nTyVarList,
               peg_linfix (mkNT nTyVarList) (pnt nTyvarN) (tokeq CommaT));
              (mkNT nTypeDec, peg_TypeDec);
              (mkNT nDtypeDecl,
               seql [pnt nTypeName;
                     tokeq EqualsT;
                     peg_linfix (mkNT nDtypeCons) (pnt nDconstructor) (tokeq BarT)]
                    (bindNT nDtypeDecl));
              (mkNT nDconstructor,
               seql [pnt nUQConstructorName; pnt nTbaseList]
                    (bindNT nDconstructor));
              (mkNT nUQConstructorName, peg_UQConstructorName);
              (mkNT nConstructorName,
               choicel [
                 pegf (pnt nUQConstructorName) (bindNT nConstructorName);
                 tok (λt. do
                            (str,s) <- destLongidT t;
                            assert(s <> "" ∧ isAlpha (HD s) ∧ isUpper (HD s))
                          od = SOME ())
                     (bindNT nConstructorName o mktokLf)]);
              (mkNT nPbase,
               pegf
                 (choicel [pnt nV; pnt nConstructorName; tok isInt mktokLf;
                           tok isString mktokLf; tok isCharT mktokLf;
                           pnt nPtuple; tokeq UnderbarT;
                           seql [tokeq LbrackT; try (pnt nPatternList);
                                 tokeq RbrackT] I;
                           seql [tokeq OpT; pnt nOpID] I])
                 (bindNT nPbase));
              (mkNT nPapp,
               choicel [seql [pnt nConstructorName; rpt (pnt nPbase) FLAT]
                         (λpts. if LENGTH pts = 1 then
                                   bindNT nPapp (bindNT nPbase pts)
                                 else
                                   case pts of
                                       [] => (* can't happen *) []
                                     | [c] => (* can't happen *) []
                                     | _ => ptPapply pts
                         );
                        pegf (pnt nPbase) (bindNT nPapp)
              ]);
              (mkNT nPcons,
               seql [pnt nPapp;
                     try (seql [tokeq (SymbolT "::"); pnt nPcons] I)]
                    (bindNT nPcons));
              (mkNT nPas,
               seql [try (seql [pnt nV; tokeq AsT] I);
                     pnt nPcons]
                    (bindNT nPas));
              (mkNT nPattern,
               seql [pnt nPas; try (seql [tokeq ColonT; pnt nType] I)]
                    (bindNT nPattern));
              (mkNT nPatternList,
               seql [pnt nPattern;
                     try (seql [tokeq CommaT; pnt nPatternList] I)]
                    (bindNT nPatternList));
              (mkNT nPtuple,
               choicel [seql [tokeq LparT; tokeq RparT] (bindNT nPtuple);
                        seql [tokeq LparT; pnt nPatternList; tokeq RparT]
                             (bindNT nPtuple)]);
              (mkNT nLetDec,
               choicel [seql [tokeq ValT; pnt nPattern; tokeq EqualsT; pnt nE]
                             (bindNT nLetDec);
                        seql [tokeq FunT; pnt nAndFDecls] (bindNT nLetDec)]);
              (mkNT nLetDecs,
               choicel [seql [pnt nLetDec; pnt nLetDecs] (bindNT nLetDecs);
                        seql [tokeq SemicolonT; pnt nLetDecs] (bindNT nLetDecs);
                        pegf (empty []) (bindNT nLetDecs)]);
              (mkNT nDecl,
               choicel [
                 seql [tokeq ValT; pnt nPattern; tokeq EqualsT; pnt nE]
                      (bindNT nDecl);
                 seql [tokeq FunT; pnt nAndFDecls] (bindNT nDecl);
                 seql [tokeq ExceptionT; pnt nDconstructor] (bindNT nDecl);
                 seql [tokeq LocalT; pnt nDecls; tokeq InT; pnt nDecls;
                       tokeq EndT] (bindNT nDecl);
                 seql [pnt nTypeDec] (bindNT nDecl);
                 seql [pnt nTypeAbbrevDec] (bindNT nDecl);
                 seql [pnt nStructure] (bindNT nDecl);
               ]);
              (mkNT nTypeAbbrevDec,
               seql [tokeq TypeT; pnt nTypeName; tokeq EqualsT; pnt nType]
                    (bindNT nTypeAbbrevDec));
              (mkNT nDecls,
               choicel [seql [pnt nDecl; pnt nDecls] (bindNT nDecls);
                        seql [tokeq SemicolonT; pnt nDecls] (bindNT nDecls);
                        pegf (empty []) (bindNT nDecls)]);
              (mkNT nOptTypEqn,
               choicel [seql [tokeq EqualsT; pnt nType] (bindNT nOptTypEqn);
                        pegf (empty []) (bindNT nOptTypEqn)]);
              (mkNT nSpecLine,
               choicel [seql [tokeq ValT; pnt nV; tokeq ColonT; pnt nType]
                             (bindNT nSpecLine);
                        seql [tokeq TypeT; pnt nTypeName; pnt nOptTypEqn]
                             (bindNT nSpecLine);
                        seql [tokeq ExceptionT; pnt nDconstructor] (bindNT nSpecLine);
                        pegf (pnt nTypeDec) (bindNT nSpecLine)]);
              (mkNT nSpecLineList,
               choicel [seql [pnt nSpecLine; pnt nSpecLineList]
                             (bindNT nSpecLineList);
                        seql [tokeq SemicolonT; pnt nSpecLineList]
                             (bindNT nSpecLineList);
                        pegf (empty []) (bindNT nSpecLineList)]);
              (mkNT nSignatureValue,
               seql [tokeq SigT; pnt nSpecLineList; tokeq EndT]
                    (bindNT nSignatureValue));
              (mkNT nOptionalSignatureAscription,
               pegf (try (seql [tokeq SealT; pnt nSignatureValue] I))
                    (bindNT nOptionalSignatureAscription));
              (mkNT nStructName, peg_StructName);
              (mkNT nStructure,
               seql [tokeq StructureT; pnt nStructName; pnt nOptionalSignatureAscription;
                     tokeq EqualsT; tokeq StructT; pnt nDecls; tokeq EndT]
                    (bindNT nStructure));
              (mkNT nTopLevelDecs,
               choicel [
                 seql [pnt nE; tokeq SemicolonT; pnt nTopLevelDecs]
                      (bindNT nTopLevelDecs);
                 seql [pnt nDecl; pnt nNonETopLevelDecs]
                      (bindNT nTopLevelDecs);
                 seql [tokeq SemicolonT; pnt nTopLevelDecs]
                      (bindNT nTopLevelDecs);
                 pegf (empty []) (bindNT nTopLevelDecs)]);
              (mkNT nNonETopLevelDecs,
               choicel [
                 seql [pnt nDecl; pnt nNonETopLevelDecs]
                      (bindNT nNonETopLevelDecs);
                 seql [tokeq SemicolonT; pnt nTopLevelDecs]
                      (bindNT nNonETopLevelDecs);
                 pegf (empty []) (bindNT nNonETopLevelDecs)]);
             ] |>
End

val rules_t = ``cmlPEG.rules``
fun ty2frag ty = let
  open simpLib
  val {convs,rewrs} = TypeBase.simpls_of ty
in
  merge_ss (rewrites rewrs :: map conv_ss convs)
end
(* can't use srw_ss() as it will attack the bodies of the rules,
   and in particular, will destroy predicates from tok
   constructors of the form
        do ... od = SOME ()
   which matches optionTheory.OPTION_BIND_EQUALS_OPTION, putting
   an existential into our rewrite thereby *)
val rules = SIMP_CONV (bool_ss ++ ty2frag ``:(α,β,γ,δ)peg``)
                      [cmlPEG_def, combinTheory.K_DEF,
                       finite_mapTheory.FUPDATE_LIST_THM] rules_t

val _ = print "Calculating application of cmlPEG rules\n"
val cmlpeg_rules_applied = let
  val app0 = finite_mapSyntax.fapply_tm
  val theta =
      Type.match_type (type_of app0 |> dom_rng |> #1) (type_of rules_t)
  val app = inst theta app0
  val app_rules = AP_TERM app rules
  val sset = bool_ss ++ ty2frag ``:'a + 'b`` ++ ty2frag ``:MMLnonT``
  fun mkrule t =
      AP_THM app_rules ``mkNT ^t``
             |> SIMP_RULE sset
                  [finite_mapTheory.FAPPLY_FUPDATE_THM]
  val ths = TypeBase.constructors_of ``:MMLnonT`` |> map mkrule
in
    save_thm("cmlpeg_rules_applied", LIST_CONJ ths);
    ths
end

Theorem FDOM_cmlPEG =
  SIMP_CONV (srw_ss()) [cmlPEG_def,
                        finite_mapTheory.FRANGE_FUPDATE_DOMSUB,
                        finite_mapTheory.DOMSUB_FUPDATE_THM,
                        finite_mapTheory.FUPDATE_LIST_THM]
            ``FDOM cmlPEG.rules``

val spec0 =
    peg_nt_thm |> Q.GEN `G`  |> Q.ISPEC `cmlPEG`
               |> SIMP_RULE (srw_ss()) [FDOM_cmlPEG]
               |> Q.GEN `n`

val mkNT = ``mkNT``

Theorem cmlPEG_exec_thm[compute] =
  TypeBase.constructors_of ``:MMLnonT``
    |> map (fn t => ISPEC (mk_comb(mkNT, t)) spec0)
    |> map (SIMP_RULE bool_ss (cmlpeg_rules_applied @ distinct_ths @
                               [sumTheory.INL_11]))
    |> LIST_CONJ;

val test1 = time EVAL
             “peg_exec cmlPEG (pnt nErel)
              (map_loc [IntT 3; StarT; IntT 4; SymbolT "/"; IntT (-2);
                        SymbolT ">"; AlphaT "x"] 0)
              [] NONE [] done failed”

Triviality frange_image:
  FRANGE fm = IMAGE (FAPPLY fm) (FDOM fm)
Proof
  simp[finite_mapTheory.FRANGE_DEF, pred_setTheory.EXTENSION] >> metis_tac[]
QED

val peg_range =
    SIMP_CONV (srw_ss())
              (FDOM_cmlPEG :: frange_image :: cmlpeg_rules_applied)
              ``FRANGE cmlPEG.rules``

val peg_start = SIMP_CONV(srw_ss()) [cmlPEG_def]``cmlPEG.start``

val wfpeg_rwts = wfpeg_cases
                   |> ISPEC ``cmlPEG``
                   |> (fn th => map (fn t => Q.SPEC t th)
                                    [`seq e1 e2 f`, `choice e1 e2 f`, `tok P f`,
                                     `any f`, `empty v`, `not e v`, `rpt e f`,
                                     `choicel []`, `choicel (h::t)`, `tokeq t`,
                                     `pegf e f`, ‘tokSymP P’
                      ])
                   |> map (CONV_RULE
                             (RAND_CONV (SIMP_CONV (srw_ss())
                                                   [choicel_def, seql_def,
                                                    tokeq_def, tokSymP_def,
                                                    pegf_def])))

val wfpeg_pnt = wfpeg_cases
                  |> ISPEC ``cmlPEG``
                  |> Q.SPEC `pnt n`
                  |> CONV_RULE (RAND_CONV (SIMP_CONV (srw_ss()) [pnt_def]))

val peg0_rwts = peg0_cases
                  |> ISPEC ``cmlPEG`` |> CONJUNCTS
                  |> map (fn th => map (fn t => Q.SPEC t th)
                                       [`tok P f`, `choice e1 e2 f`,
                                        ‘seq e1 e2 f’, ‘tokSymP P’,
                                        `tokeq t`, `empty l`, `not e v`])
                  |> List.concat
                  |> map (CONV_RULE
                            (RAND_CONV (SIMP_CONV (srw_ss())
                                                  [tokeq_def, tokSymP_def])))

val pegfail_t = ``pegfail``
val peg0_rwts = let
  fun filterthis th = let
    val c = concl th
    val (l,r) = dest_eq c
    val (f,_) = strip_comb l
  in
    not (same_const pegfail_t f) orelse is_const r
  end
in
  List.filter filterthis peg0_rwts
end

val pegnt_case_ths = peg0_cases
                      |> ISPEC ``cmlPEG`` |> CONJUNCTS
                      |> map (Q.SPEC `pnt n`)
                      |> map (CONV_RULE (RAND_CONV (SIMP_CONV (srw_ss()) [pnt_def])))

val peg0_pegf = Store_thm(
  "peg0_pegf",
  ``peg0 G (pegf s f) = peg0 G s``,
  simp[pegf_def])

val peg0_seql = Store_thm(
  "peg0_seql",
  ``(peg0 G (seql [] f) ⇔ T) ∧
    (peg0 G (seql (h::t) f) ⇔ peg0 G h ∧ peg0 G (seql t I))``,
  simp[seql_def])

val peg0_tokeq = Store_thm(
  "peg0_tokeq",
  ``peg0 G (tokeq t) = F``,
  simp[tokeq_def])

Theorem peg0_tokSymP[simp]:
  peg0 G (tokSymP P) ⇔ F
Proof
  simp[tokSymP_def]
QED

val peg0_choicel = Store_thm(
  "peg0_choicel",
  ``(peg0 G (choicel []) = F) ∧
    (peg0 G (choicel (h::t)) ⇔ peg0 G h ∨ pegfail G h ∧ peg0 G (choicel t))``,
  simp[choicel_def])

fun pegnt(t,acc) = let
  val th =
      Q.prove(`¬peg0 cmlPEG (pnt ^t)`,
            simp pegnt_case_ths >>
            simp cmlpeg_rules_applied >>
            simp[FDOM_cmlPEG, peg_V_def, peg_UQConstructorName_def,
                 peg_StructName_def, peg_EbaseParen_def,
                 peg_TypeDec_def, peg_longV_def, peg_linfix_def] >>
            simp(peg0_rwts @ acc))
  val nm = "peg0_" ^ term_to_string t
  val th' = save_thm(nm, SIMP_RULE bool_ss [pnt_def] th)
  val _ = export_rewrites [nm]
in
  th::acc
end

val npeg0_rwts =
    List.foldl pegnt []
               [“nTypeDec”, “nTypeAbbrevDec”, “nOpID”, “nStructure”,
                “nDecl”, “nV”, “nUQTyOp”,
                “nUQConstructorName”, “nStructName”, “nConstructorName”,
                “nTypeName”,
                “nDtypeDecl”, “nDconstructor”, “nFDecl”, “nTyvarN”,
                “nTyOp”, “nTbase”, “nPTbase”, “nDType”, “nPType”, “nType”,
                “nTypeList1”, “nTypeList2”,
                “nRelOps”, “nPtuple”, “nPbase”, “nPapp”,
                “nPcons”, “nPas”, “nPattern”,
                “nPatternList”, “nPbaseList1”,
                “nLetDec”, “nMultOps”, “nListOps”,
                “nFQV”, “nAddOps”, “nCompOps”, “nEliteral”,
                “nEbase”, “nEapp”,
                “nEmult”, “nEadd”, “nElistop”, “nErel”, “nEcomp”,
                “nEbefore”,
                “nEtyped”, “nElogicAND”, “nElogicOR”, “nEhandle”,
                “nE”, “nE'”, “nElist1”,
                “nSpecLine”
               ]

fun wfnt(t,acc) = let
  val th =
    Q.prove(`wfpeg cmlPEG (pnt ^t)`,
          SIMP_TAC (srw_ss())
                   (cmlpeg_rules_applied @
                    [wfpeg_pnt, FDOM_cmlPEG, try_def, peg_longV_def,
                     seql_def, peg_TypeDec_def, peg_V_def,
                     peg_EbaseParen_def, peg_StructName_def,
                     peg_UQConstructorName_def,
                     tokeq_def, peg_linfix_def]) THEN
          simp(wfpeg_rwts @ npeg0_rwts @ peg0_rwts @ acc))
in
  th::acc
end;

val topo_nts = [“nV”, “nTyvarN”, “nTypeDec”, “nTypeAbbrevDec”,
                “nSpecLine”, “nSpecLineList”, “nSignatureValue”,
                “nStructure”,
                “nDecl”,
                “nUQTyOp”, “nUQConstructorName”, “nStructName”,
                “nConstructorName”, “nTyVarList”, “nTypeName”, “nTyOp”,
                “nTbase”, “nPTbase”, “nTbaseList”, “nDType”, “nPType”,
                “nListOps”, “nRelOps”, “nPtuple”, “nPbase”, “nPapp”,
                “nPcons”, “nPas”, “nPattern”,
                “nPatternList”, “nPbaseList1”, “nPE”,
                “nPE'”, “nPEs”, “nMultOps”, “nLetDec”, “nLetDecs”,
                “nFQV”,
                “nFDecl”, “nAddOps”, “nCompOps”, “nOpID”,
                “nEliteral”, “nEbase”, “nEapp”,
                “nEmult”, “nEadd”, “nElistop”, “nErel”,
                “nEcomp”, “nEbefore”, “nEtyped”, “nElogicAND”,
                “nElogicOR”, “nEhandle”, “nE”, “nE'”,
                “nType”, “nTypeList1”, “nTypeList2”,
                “nEseq”, “nElist1”, “nDtypeDecl”,
                “nOptTypEqn”,
                “nDecls”, “nDconstructor”, “nAndFDecls”,
                “nOptionalSignatureAscription”,
                “nTopLevelDecs”, “nNonETopLevelDecs”
               ]

Theorem cml_wfpeg_thm =
  LIST_CONJ (List.foldl wfnt [] topo_nts)

(*
set_diff (TypeBase.constructors_of ``:MMLnonT``)
         (topo_nts @ [``nTyVarList``, ``nTypeList``, ``nDtypeDecls``,
                      ``nDtypeCons``])
*)

Triviality subexprs_pnt:
  subexprs (pnt n) = {pnt n}
Proof
  simp[subexprs_def, pnt_def]
QED

Theorem PEG_exprs =
  ``Gexprs cmlPEG``
    |> SIMP_CONV (srw_ss())
         [Gexprs_def, subexprs_def,
          subexprs_pnt, peg_start, peg_range, choicel_def, tokeq_def, try_def,
          seql_def, pegf_def, peg_V_def, peg_EbaseParen_def,
          peg_longV_def, peg_linfix_def, peg_StructName_def,
          peg_TypeDec_def, peg_UQConstructorName_def,
          pred_setTheory.INSERT_UNION_EQ
         ]

Theorem PEG_wellformed[simp]:
   wfG cmlPEG
Proof
  simp[wfG_def, Gexprs_def, subexprs_def,
       subexprs_pnt, peg_start, peg_range, DISJ_IMP_THM, FORALL_AND_THM,
       choicel_def, seql_def, pegf_def, tokeq_def, try_def,
       peg_linfix_def, peg_UQConstructorName_def, peg_TypeDec_def,
       peg_V_def, peg_EbaseParen_def, tokSymP_def,
       peg_longV_def, peg_StructName_def] >>
  simp(cml_wfpeg_thm :: wfpeg_rwts @ peg0_rwts @ npeg0_rwts)
QED

Theorem parse_TopLevelDecs_total =
  MATCH_MP peg_exec_total PEG_wellformed
           |> REWRITE_RULE [peg_start] |> Q.GEN `i`

Theorem coreloop_TopLevelDecs_total =
  MATCH_MP coreloop_total PEG_wellformed
    |> REWRITE_RULE [peg_start] |> Q.GEN `i`

Theorem owhile_TopLevelDecs_total =
  SIMP_RULE (srw_ss()) [coreloop_def] coreloop_TopLevelDecs_total

local
  val c = concl FDOM_cmlPEG
  val r = rhs c
  fun recurse acc t =
      case Lib.total pred_setSyntax.dest_insert t of
          SOME(e,t') => recurse (e :: acc) t'
        | NONE => acc
  val nts = recurse [] r
in
val FDOM_cmlPEG_nts = let
  fun p t = Q.prove(`^t ∈ FDOM cmlPEG.rules`, simp[FDOM_cmlPEG])
in
  save_thm("FDOM_cmlPEG_nts", LIST_CONJ (map p nts)) before
  export_rewrites ["FDOM_cmlPEG_nts"]
end
val NTS_in_PEG_exprs = let
  val exprs_th' = REWRITE_RULE [pnt_def] PEG_exprs
                                           |> INST_TYPE [alpha |-> “:string”]
  val exprs_t = rhs (concl exprs_th')
  val nt = mk_thy_const{Thy = "peg", Name = "nt",
                        Ty = ``:MMLnonT inf -> (mlptree list -> mlptree list) ->
                                (token,MMLnonT,mlptree list,string) pegsym``}
  val I_t = mk_thy_const{Thy = "combin", Name = "I",
                         Ty = ``:mlptree list -> mlptree list``}
  fun p t = let
    val _ = print ("PEGexpr: "^term_to_string t^"\n")
    val th0 = prove(pred_setSyntax.mk_in(list_mk_comb(nt,[t,I_t]), exprs_t),
                    simp[pnt_def])
              handle e => (print("Failed on "^term_to_string t^"\n");
                           raise e)
  in
    CONV_RULE (RAND_CONV (K (SYM exprs_th'))) th0
  end
  val th = LIST_CONJ (map p nts)
in
  save_thm("NTS_in_PEG_exprs", th) before export_rewrites ["NTS_in_PEG_exprs"]
end

end (* local *)


val _ = export_theory()
