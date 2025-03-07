(*
  Proves an end-to-end correctness theorem for the bootstrapped compiler.
*)
open preamble
     semanticsPropsTheory backendProofTheory
     ag32_configProofTheory ag32_machine_configTheory
     ag32_memoryProofTheory ag32_basis_ffiProofTheory ag32_ffi_codeProofTheory
     compiler32ProgTheory ag32BootstrapTheory

val _ = new_theory"ag32BootstrapProof";

Triviality with_clos_conf_simp:
    (mc_init_ok (ag32_backend_config with <| clos_conf := z ; bvl_conf updated_by
                    (λc. c with <|inline_size_limit := t1; exp_cut := t2|>) |>) =
     mc_init_ok ag32_backend_config) /\
    (x.max_app <> 0 /\ (case x.known_conf of NONE => T | SOME k => k.val_approx_spt = LN) ==>
     (backend_config_ok (ag32_backend_config with clos_conf := x) =
      backend_config_ok ag32_backend_config))
Proof
  fs [mc_init_ok_def,FUN_EQ_THM,backend_config_ok_def]
  \\ rw [] \\ eq_tac \\ rw [] \\ EVAL_TAC
QED

Overload cake_config = “ag32Bootstrap$info”;

Definition compiler_instance_def:
  compiler_instance =
    <| init_state := config_to_inc_config cake_config ;
       compiler_fun := compile_inc_progs_for_eval cake_config.lab_conf.asm_conf ;
       config_dom := UNIV ;
       config_v := BACKEND_INC_CONFIG_v ;
       decs_dom := decs_allowed ;
       decs_v := LIST_v AST_DEC_v |>
End

Triviality compiler_instance_lemma:
  INJ compiler_instance.config_v 𝕌(:inc_config) 𝕌(:semanticPrimitives$v) ∧
  compiler_instance.init_state = config_to_inc_config cake_config ∧
  compiler_instance.compiler_fun =
    compile_inc_progs_for_eval cake_config.lab_conf.asm_conf
Proof
  fs [compiler_instance_def]
QED

Theorem cake_config_lab_conf_asm_conf:
  cake_config.lab_conf.asm_conf = ag32_config
Proof
  assume_tac $ cj 1 compiler32_compiled
  \\ drule compile_asm_config_eq
  \\ gvs [backendTheory.set_oracle_def]
  \\ strip_tac \\ EVAL_TAC
QED

val cake_io_events_def = new_specification("cake_io_events_def",["cake_io_events"],
  semantics_compiler32_prog
  |> Q.INST[‘eval_state_var’|->‘the_EvalDecs (mk_init_eval_state compiler_instance)’]
  |> SIMP_RULE (srw_ss()) [source_evalProofTheory.mk_init_eval_state_def,the_EvalDecs_def]
  |> SIMP_RULE (srw_ss()) [GSYM source_evalProofTheory.mk_init_eval_state_def
                           |> SIMP_RULE (srw_ss()) []]
  |> Q.GENL[`cl`,`fs`]
  |> SIMP_RULE bool_ss [SKOLEM_THM,Once(GSYM RIGHT_EXISTS_IMP_THM)]);

val (cake_sem,cake_output) = cake_io_events_def |> SPEC_ALL |> UNDISCH |> CONJ_PAIR
val (cake_not_fail,cake_sem_sing) = MATCH_MP semantics_prog_Terminate_not_Fail cake_sem |> CONJ_PAIR

Theorem extcalls_ffi_names:
  extcalls cake_config.lab_conf.ffi_names = ffis
Proof
  rewrite_tac [compiler32_compiled]
  \\ qspec_tac (‘cake_config.lab_conf.ffi_names’,‘xs’) \\ Cases
  \\ gvs [extcalls_def,backendTheory.ffinames_to_string_list_def,
          miscTheory.the_def]
  \\ Induct_on ‘x’ \\ gvs []
  \\ gvs [extcalls_def,backendTheory.ffinames_to_string_list_def,
          miscTheory.the_def]
  \\ Cases
  \\ gvs [extcalls_def,backendTheory.ffinames_to_string_list_def,
          miscTheory.the_def]
QED

val ffis = ffis_def |> CONV_RULE (RAND_CONV EVAL);
val ffi_names = extcalls_ffi_names |> SRULE [ffis]

val LENGTH_code = “LENGTH code” |> SCONV [compiler32_compiled];
val LENGTH_data = “LENGTH data” |> SCONV [compiler32_compiled];
val shmem = “info.lab_conf.shmem_extra” |> SCONV [compiler32_compiled];

Overload cake_machine_config =
  “ag32_machine_config (extcalls info.lab_conf.ffi_names) (LENGTH code) (LENGTH data)”

Theorem target_state_rel_cake_start_asm_state:
   SUM (MAP strlen cl) + LENGTH cl ≤ cline_size ∧
   LENGTH inp ≤ stdin_size ∧
   is_ag32_init_state (init_memory code data (extcalls info.lab_conf.ffi_names) (cl,inp)) ms ⇒
   ∃n. target_state_rel ag32_target
          (init_asm_state code data (extcalls info.lab_conf.ffi_names) (cl,inp))
          (FUNPOW Next n ms) ∧
       ((FUNPOW Next n ms).io_events = ms.io_events) ∧
       (∀x. x ∉ (ag32_startup_addresses) ⇒
         ((FUNPOW Next n ms).MEM x = ms.MEM x))
Proof
  strip_tac
  \\ drule (GEN_ALL init_asm_state_RTC_asm_step)
  \\ disch_then drule
  \\ simp_tac std_ss []
  \\ disch_then(qspecl_then[`code`,`data`,`extcalls info.lab_conf.ffi_names`]mp_tac)
  \\ impl_tac >- ( EVAL_TAC>> fs[ffi_names,LENGTH_data,LENGTH_code,extcalls_def])
  \\ strip_tac
  \\ drule (GEN_ALL target_state_rel_ag32_init)
  \\ rveq
  \\ qmatch_goalsub_abbrev_tac`_ ∉ md`
  \\ disch_then(qspec_then`md`assume_tac)
  \\ drule (GEN_ALL RTC_asm_step_ag32_target_state_rel_io_events)
  \\ simp[EVAL``(ag32_init_asm_state m md).mem_domain``]
QED

val cake_startup_clock_def =
  new_specification("cake_startup_clock_def",["cake_startup_clock"],
  GEN_ALL (Q.SPEC`ms0`(Q.GEN`ms`target_state_rel_cake_start_asm_state))
  |> SIMP_RULE bool_ss [GSYM RIGHT_EXISTS_IMP_THM,SKOLEM_THM]);

val compile_correct_applied =
  MATCH_MP compile_correct_eval (cj 1 compiler32_compiled)
  |> SIMP_RULE(srw_ss())[LET_THM,ml_progTheory.init_state_env_thm,
                         GSYM AND_IMP_INTRO,with_clos_conf_simp]
  |> Q.INST [‘ev’|->‘SOME compiler_instance’]
  |> SIMP_RULE (srw_ss()) [add_eval_state_def,opt_eval_config_wf_def,
                           compiler_instance_lemma]
  |> C MATCH_MP cake_not_fail
  |> C MATCH_MP ag32_backend_config_ok
  |> REWRITE_RULE[cake_sem_sing,AND_IMP_INTRO]
  |> REWRITE_RULE[Once (GSYM AND_IMP_INTRO)]
  |> C MATCH_MP (CONJ(UNDISCH ag32_machine_config_ok)(UNDISCH ag32_init_ok))
  |> DISCH(#1(dest_imp(concl ag32_init_ok)))
  |> C MATCH_MP is_ag32_machine_config_ag32_machine_config
  |> Q.GEN`cbspace` |> Q.SPEC`0`
  |> Q.GEN`data_sp` |> Q.SPEC`0`
  |> REWRITE_RULE[AND_IMP_INTRO]

Theorem cake_compiled_thm =
  CONJ compile_correct_applied cake_output
  |> DISCH_ALL
  |> check_thm;

Theorem cake_installed:
   SUM (MAP strlen cl) + LENGTH cl ≤ cline_size ∧
   LENGTH inp ≤ stdin_size ∧
   is_ag32_init_state (init_memory code data
                         (extcalls info.lab_conf.ffi_names) (cl,inp)) ms0 ⇒
   installed code 0 data 0 info.lab_conf.ffi_names
     (heap_regs ag32_backend_config.stack_conf.reg_names)
     (cake_machine_config) info.lab_conf.shmem_extra
     (FUNPOW Next (cake_startup_clock ms0 inp cl) ms0)
Proof
  rewrite_tac[ffi_names, extcalls_def, shmem]
  \\ strip_tac
  \\ qmatch_asmsub_abbrev_tac ‘init_memory _ _ ff’
  \\ qmatch_goalsub_abbrev_tac ‘installed _ _ _ _ dd’
  \\ ‘dd = SOME (MAP ExtCall ff)’ by
   (unabbrev_all_tac
    \\ assume_tac (cj 1 compiler32_compiled)
    \\ drule ag32_configProofTheory.compile_imp_ffi_names
    \\ gvs [compiler32_compiled]
    \\ gvs [GSYM compiler32_compiled,ffis]
    \\ simp [backendTheory.set_oracle_def,
             ag32_configTheory.ag32_backend_config_def])
  \\ asm_rewrite_tac []
  \\ irule ag32_installed
  \\ unabbrev_all_tac
  \\ drule cake_startup_clock_def
  \\ disch_then drule
  \\ rewrite_tac[ffi_names, extcalls_def]
  \\ disch_then drule
  \\ strip_tac
  \\ simp[ag32_memoryTheory.ffi_exitpcs_def]
  \\ conj_tac >- (simp[LENGTH_code] \\ EVAL_TAC)
  \\ conj_tac >- (simp[LENGTH_code, LENGTH_data] \\ EVAL_TAC)
  \\ asm_exists_tac \\ simp[]
  \\ last_x_assum $ irule_at Any \\ fs []
QED

Theorem cake_machine_sem =
  compile_correct_applied
  |> C MATCH_MP (UNDISCH cake_installed)
  |> DISCH_ALL;

(* TODO: move *)

Theorem get_stdin_stdin_fs[simp]:
   get_stdin (stdin_fs inp) = inp
Proof
  EVAL_TAC
  \\ SELECT_ELIM_TAC
  \\ simp[EXISTS_PROD, FORALL_PROD]
QED

Theorem inFS_fname_fastForwardFD[simp]:
   inFS_fname (fastForwardFD fs fd) fnm ⇔ inFS_fname fs fnm
Proof
  rw[fsFFIPropsTheory.inFS_fname_def]
QED

Theorem not_inFS_fname_stdin_fs[simp]:
   ∀nm. ¬ inFS_fname (stdin_fs inp) nm
Proof
  rw[stdin_fs_def,fsFFIPropsTheory.inFS_fname_def]
QED

Theorem ALOOKUP_stdin_fs_File_NONE[simp]:
  ALOOKUP (stdin_fs inp).inode_tbl (File ino) = NONE
Proof rw[stdin_fs_def]
QED

Theorem ALOOKUP_fastForwardFD_infds_neq:
   fd ≠ fd' ⇒ (ALOOKUP (fastForwardFD fs fd).infds fd' = ALOOKUP fs.infds fd')
Proof
  rw[fsFFIPropsTheory.fastForwardFD_def]
  \\ Cases_on`ALOOKUP fs.infds fd` \\ simp[miscTheory.the_def]
  \\ pairarg_tac \\ simp[]
  \\ Cases_on`ALOOKUP fs.inode_tbl ino` \\ simp[miscTheory.the_def]
  \\ simp[AFUPDKEY_ALOOKUP]
  \\ CASE_TAC
QED

Theorem FST_ALOOKUP_fastForwardFD_infds:
   OPTION_MAP FST (ALOOKUP (fastForwardFD fs fd).infds fd') =
   OPTION_MAP FST (ALOOKUP fs.infds fd')
Proof
  rw[fsFFIPropsTheory.fastForwardFD_def]
  \\ Cases_on`ALOOKUP fs.infds fd` \\ simp[miscTheory.the_def]
  \\ pairarg_tac \\ simp[]
  \\ Cases_on`ALOOKUP fs.inode_tbl ino` \\ simp[miscTheory.the_def]
  \\ simp[AFUPDKEY_ALOOKUP]
  \\ CASE_TAC \\ simp[]
  \\ CASE_TAC \\ simp[]
QED

Theorem FST_ALOOKUP_add_stdo_infds:
   OPTION_MAP FST (ALOOKUP (add_stdo fd nm fs out).infds fd') =
   OPTION_MAP FST (ALOOKUP fs.infds fd')
Proof
  mp_tac TextIOProofTheory.add_stdo_MAP_FST_infds
  \\ strip_tac
  \\ drule (GEN_ALL data_to_word_bignumProofTheory.MAP_FST_EQ_IMP_IS_SOME_ALOOKUP)
  \\ disch_then(qspec_then`fd'`mp_tac)
  \\ Cases_on`ALOOKUP fs.infds fd'` \\ simp[]
  \\ rw[IS_SOME_EXISTS] \\ rw[]
  \\ fs[TextIOProofTheory.add_stdo_def, TextIOProofTheory.up_stdo_def, fsFFITheory.fsupdate_def]
  \\ pop_assum mp_tac \\ TOP_CASE_TAC \\ fs[]
  \\ TOP_CASE_TAC \\ fs[]
  \\ simp[AFUPDKEY_ALOOKUP]
  \\ rw[] \\ Cases_on`x` \\ rw[]
QED

Theorem ALOOKUP_add_stdout_inode_tbl:
   STD_streams fs ⇒ (
   ALOOKUP (add_stdout fs out).inode_tbl fnm =
   if fnm = UStream(strlit"stdout") then
     SOME (THE (ALOOKUP fs.inode_tbl fnm) ++ explode out)
   else ALOOKUP fs.inode_tbl fnm)
Proof
  strip_tac
  \\ imp_res_tac TextIOProofTheory.STD_streams_stdout
  \\ simp[TextIOProofTheory.add_stdo_def]
  \\ SELECT_ELIM_TAC
  \\ conj_tac >- metis_tac[]
  \\ gen_tac \\ strip_tac
  \\ simp[TextIOProofTheory.up_stdo_def]
  \\ simp[fsFFITheory.fsupdate_def]
  \\ fs[fsFFIPropsTheory.STD_streams_def, TextIOProofTheory.stdo_def]
  \\ rveq
  \\ simp[AFUPDKEY_ALOOKUP]
  \\ TOP_CASE_TAC
  \\ TOP_CASE_TAC
  \\ fs[]
QED

Theorem ALOOKUP_add_stderr_inode_tbl:
   STD_streams fs ⇒ (
   ALOOKUP (add_stderr fs err).inode_tbl fnm =
   if fnm = UStream(strlit"stderr") then
     SOME (THE (ALOOKUP fs.inode_tbl fnm) ++ explode err)
   else ALOOKUP fs.inode_tbl fnm)
Proof
  strip_tac
  \\ imp_res_tac TextIOProofTheory.STD_streams_stderr
  \\ simp[TextIOProofTheory.add_stdo_def]
  \\ SELECT_ELIM_TAC
  \\ conj_tac >- metis_tac[]
  \\ gen_tac \\ strip_tac
  \\ simp[TextIOProofTheory.up_stdo_def]
  \\ simp[fsFFITheory.fsupdate_def]
  \\ fs[fsFFIPropsTheory.STD_streams_def, TextIOProofTheory.stdo_def]
  \\ rveq
  \\ simp[AFUPDKEY_ALOOKUP]
  \\ TOP_CASE_TAC
  \\ TOP_CASE_TAC
  \\ fs[]
QED

Theorem ALOOKUP_add_stdout_infds:
   STD_streams fs ⇒ (
   ALOOKUP (add_stdout fs out).infds fd =
   if fd = 1 then
     SOME ((I ## I ## ((+) (strlen out))) (THE (ALOOKUP fs.infds fd)))
   else ALOOKUP fs.infds fd)
Proof
  strip_tac
  \\ imp_res_tac TextIOProofTheory.STD_streams_stdout
  \\ simp[TextIOProofTheory.add_stdo_def]
  \\ SELECT_ELIM_TAC
  \\ conj_tac >- metis_tac[]
  \\ gen_tac \\ strip_tac
  \\ simp[TextIOProofTheory.up_stdo_def]
  \\ simp[fsFFITheory.fsupdate_def]
  \\ fs[fsFFIPropsTheory.STD_streams_def, TextIOProofTheory.stdo_def]
  \\ rveq
  \\ simp[AFUPDKEY_ALOOKUP]
  \\ TOP_CASE_TAC \\ rw[]
  >- ( strip_tac \\ fs[] )
  \\ PairCases_on`x`
  \\ fs[]
QED

Theorem ALOOKUP_add_stderr_infds:
   STD_streams fs ⇒ (
   ALOOKUP (add_stderr fs err).infds fd =
   if fd = 2 then
     SOME ((I ## I ## ((+) (strlen err))) (THE (ALOOKUP fs.infds fd)))
   else ALOOKUP fs.infds fd)
Proof
  strip_tac
  \\ imp_res_tac TextIOProofTheory.STD_streams_stderr
  \\ simp[TextIOProofTheory.add_stdo_def]
  \\ SELECT_ELIM_TAC
  \\ conj_tac >- metis_tac[]
  \\ gen_tac \\ strip_tac
  \\ simp[TextIOProofTheory.up_stdo_def]
  \\ simp[fsFFITheory.fsupdate_def]
  \\ fs[fsFFIPropsTheory.STD_streams_def, TextIOProofTheory.stdo_def]
  \\ rveq
  \\ simp[AFUPDKEY_ALOOKUP]
  \\ TOP_CASE_TAC \\ rw[]
  >- ( strip_tac \\ fs[] )
  \\ PairCases_on`x`
  \\ fs[]
QED

(* -- *)

Theorem cake_extract_writes:
   wfcl cl ⇒
   let events = MAP get_output_io_event (cake_io_events cl (stdin_fs inp)) in
   let out = extract_writes 1 events in
   let err = extract_writes 2 events in
   if has_help_flag (TL cl) then
     (out = explode help_string) ∧ (err = "")
   else if has_version_flag (TL cl) then
     (out = explode current_build_info_str) ∧ (err = "")
   else if has_pancake_flag (TL cl) then
     let (cout, cerr) = compile_pancake_32 (TL cl) inp in
     (out = explode (concat (append cout))) ∧
     (err = explode cerr)
   else
     let (cout, cerr) = compile_32 (TL cl) inp in
     (out = explode (concat (append cout))) ∧
     (err = explode cerr)
Proof
  strip_tac
  \\ drule(GEN_ALL(DISCH_ALL cake_output))
  \\ disch_then(qspec_then`stdin_fs inp`mp_tac)
  \\ simp[wfFS_stdin_fs, STD_streams_stdin_fs]
  \\ simp[compilerTheory.full_compile_32_def]
  \\ pairarg_tac \\ simp[]
  \\ ntac 2 (IF_CASES_TAC \\ fs[]
  >- (
    simp[TextIOProofTheory.add_stdo_def]
    \\ SELECT_ELIM_TAC
    \\ simp[TextIOProofTheory.stdo_def]
    \\ conj_tac
    >- (
      simp[stdin_fs_def]
      \\ qexists_tac`implode""`
      \\ simp[] )
    \\ simp[Once stdin_fs_def, AFUPDKEY_def]
    \\ Cases \\ simp[] \\ strip_tac \\ rveq
    \\ pop_assum mp_tac
    \\ simp[TextIOProofTheory.up_stdo_def]
    \\ simp[fsFFITheory.fsupdate_def]
    \\ simp[stdin_fs_def]
    \\ rw[]
    \\ (
      drule (GEN_ALL extract_fs_extract_writes)
      \\ simp[AFUPDKEY_ALOOKUP]
      \\ disch_then match_mp_tac
      \\ rw[fsFFIPropsTheory.inFS_fname_def]
      >- (
        fs[CaseEq"option",CaseEq"bool",FORALL_PROD]
        \\ rw[] \\ CCONTR_TAC \\ fs[]
        \\ rveq \\ fs[] )
      >- (
        pop_assum mp_tac
        \\ rw[] \\ fs[] \\ rw[]
        \\ pop_assum mp_tac \\ rw[])
      >- ( rw[] \\ rw[OPTREL_def]))))>>
  IF_CASES_TAC>>fs[]
  \\ (simp[TextIOProofTheory.add_stdout_fastForwardFD, STD_streams_stdin_fs]
  \\ DEP_REWRITE_TAC[TextIOProofTheory.add_stderr_fastForwardFD]
  \\ simp[TextIOProofTheory.STD_streams_add_stdout, STD_streams_stdin_fs]
  \\ strip_tac
  \\ drule (GEN_ALL extract_fs_extract_writes)
  \\ simp[]
  \\ simp[Once stdin_fs_def]
  \\ strip_tac
  \\ conj_tac
  >- (
    first_x_assum irule
    \\ simp[ALOOKUP_fastForwardFD_infds_neq]
    \\ conj_tac
    >- (
      rw[]
      \\ qmatch_asmsub_abbrev_tac`ALOOKUP fs'.infds _ = _`
      \\ `OPTION_MAP FST (ALOOKUP fs'.infds fd1) = OPTION_MAP FST (ALOOKUP (stdin_fs inp).infds fd1)`
      by( simp_tac(srw_ss())[Abbr`fs'`, FST_ALOOKUP_fastForwardFD_infds, FST_ALOOKUP_add_stdo_infds] )
      \\ rfs[]
      \\ `OPTION_MAP FST (ALOOKUP fs'.infds fd2) = OPTION_MAP FST (ALOOKUP (stdin_fs inp).infds fd2)`
      by( simp_tac(srw_ss())[Abbr`fs'`, FST_ALOOKUP_fastForwardFD_infds, FST_ALOOKUP_add_stdo_infds] )
      \\ rfs[]
      \\ qmatch_assum_abbrev_tac`FST z = FST z'`
      \\ Cases_on`z` \\ Cases_on`z'`
      \\ rfs[]
      \\ fs[stdin_fs_def]
      \\ rw[]
      \\ ntac 2 (pop_assum mp_tac)
      \\ rw[fsFFIPropsTheory.inFS_fname_def] \\ fs[] \\ rw[]
      )
    \\ conj_tac
    >-(
      rw[]
      \\ qmatch_goalsub_abbrev_tac`ALOOKUP fs' x`
      \\ `OPTION_MAP FST (ALOOKUP fs' x) = OPTION_MAP FST (ALOOKUP (stdin_fs inp).infds x)`
      by ( simp[FST_ALOOKUP_fastForwardFD_infds, FST_ALOOKUP_add_stdo_infds, Abbr`fs'`] )
      \\ fs[stdin_fs_def]
      \\ pop_assum mp_tac
      \\ rw[]
      \\ qmatch_asmsub_abbrev_tac`ALOOKUP fs' _ = SOME z`
      \\ Cases_on`z` \\ fs[] \\ rw[]
    )
    \\ conj_tac
    >- (
      rw[]
      \\ qmatch_goalsub_abbrev_tac`ALOOKUP fs'`
      \\ `OPTION_MAP FST (ALOOKUP fs' x) = OPTION_MAP FST (ALOOKUP (stdin_fs inp).infds x)`
      by ( simp[FST_ALOOKUP_fastForwardFD_infds, FST_ALOOKUP_add_stdo_infds, Abbr`fs'`] )
      \\ rw[OPTREL_def]
      \\ Cases_on`ALOOKUP fs' x` \\ fs[] )
    \\ simp[EVAL``(stdin_fs inp).infds``]
    \\ simp[Once stdin_fs_def]
    \\ DEP_REWRITE_TAC[ALOOKUP_add_stderr_inode_tbl]
    \\ simp[]
    \\ DEP_REWRITE_TAC[TextIOProofTheory.STD_streams_add_stdout]
    \\ simp[STD_streams_stdin_fs]
    \\ DEP_REWRITE_TAC[ALOOKUP_add_stdout_inode_tbl]
    \\ simp[STD_streams_stdin_fs]
    \\ DEP_REWRITE_TAC[ALOOKUP_add_stderr_infds]
    \\ DEP_REWRITE_TAC[TextIOProofTheory.STD_streams_add_stdout]
    \\ simp[STD_streams_stdin_fs]
    \\ DEP_REWRITE_TAC[ALOOKUP_add_stdout_infds]
    \\ simp[STD_streams_stdin_fs]
    \\ simp[stdin_fs_def])
  \\ first_x_assum irule
  \\ simp[ALOOKUP_fastForwardFD_infds_neq]
  \\ conj_tac
  >- (
    rw[]
    \\ qmatch_asmsub_abbrev_tac`ALOOKUP fs'.infds _ = _`
    \\ `OPTION_MAP FST (ALOOKUP fs'.infds fd1) = OPTION_MAP FST (ALOOKUP (stdin_fs inp).infds fd1)`
    by( simp_tac(srw_ss())[Abbr`fs'`, FST_ALOOKUP_fastForwardFD_infds, FST_ALOOKUP_add_stdo_infds] )
    \\ rfs[]
    \\ `OPTION_MAP FST (ALOOKUP fs'.infds fd2) = OPTION_MAP FST (ALOOKUP (stdin_fs inp).infds fd2)`
    by( simp_tac(srw_ss())[Abbr`fs'`, FST_ALOOKUP_fastForwardFD_infds, FST_ALOOKUP_add_stdo_infds] )
    \\ rfs[]
    \\ qmatch_assum_abbrev_tac`FST z = FST z'`
    \\ Cases_on`z` \\ Cases_on`z'`
    \\ rfs[]
    \\ fs[stdin_fs_def]
    \\ rw[]
    \\ ntac 2 (pop_assum mp_tac)
    \\ rw[fsFFIPropsTheory.inFS_fname_def] \\ fs[] )
  \\ conj_tac
  >-(
    rw[]
    \\ qmatch_goalsub_abbrev_tac`ALOOKUP fs' x`
    \\ `OPTION_MAP FST (ALOOKUP fs' x) = OPTION_MAP FST (ALOOKUP (stdin_fs inp).infds x)`
    by ( simp[FST_ALOOKUP_fastForwardFD_infds, FST_ALOOKUP_add_stdo_infds, Abbr`fs'`] )
    \\ fs[stdin_fs_def]
    \\ pop_assum mp_tac
    \\ rw[]
    \\ qmatch_asmsub_abbrev_tac`ALOOKUP fs' _ = SOME z`
    \\ Cases_on`z` \\ fs[] \\ rw[]
  )
  \\ conj_tac
  >- (
    rw[]
    \\ qmatch_goalsub_abbrev_tac`ALOOKUP fs'`
    \\ `OPTION_MAP FST (ALOOKUP fs' x) = OPTION_MAP FST (ALOOKUP (stdin_fs inp).infds x)`
    by ( simp[FST_ALOOKUP_fastForwardFD_infds, FST_ALOOKUP_add_stdo_infds, Abbr`fs'`] )
    \\ rw[OPTREL_def]
    \\ Cases_on`ALOOKUP fs' x` \\ fs[] )
  \\ simp[EVAL``(stdin_fs inp).infds``]
  \\ simp[Once stdin_fs_def]
  \\ DEP_REWRITE_TAC[ALOOKUP_add_stderr_inode_tbl]
  \\ simp[]
  \\ DEP_REWRITE_TAC[TextIOProofTheory.STD_streams_add_stdout]
  \\ simp[STD_streams_stdin_fs]
  \\ DEP_REWRITE_TAC[ALOOKUP_add_stdout_inode_tbl]
  \\ simp[STD_streams_stdin_fs]
  \\ DEP_REWRITE_TAC[ALOOKUP_add_stderr_infds]
  \\ DEP_REWRITE_TAC[TextIOProofTheory.STD_streams_add_stdout]
  \\ simp[STD_streams_stdin_fs]
  \\ DEP_REWRITE_TAC[ALOOKUP_add_stdout_infds]
  \\ simp[STD_streams_stdin_fs]
  \\ simp[stdin_fs_def])
QED

Theorem cake_ag32_next:
   SUM (MAP strlen cl) + LENGTH cl ≤ cline_size ∧ wfcl cl ∧
   LENGTH inp ≤ stdin_size ∧
   is_ag32_init_state (init_memory code data (extcalls info.lab_conf.ffi_names) (cl,inp)) ms0
  ⇒
   ∃k1. ∀k. k1 ≤ k ⇒
     let ms = FUNPOW Next k ms0 in
     let outs = MAP (get_ag32_io_event) ms.io_events in
       (ms.PC = (cake_machine_config).halt_pc) ∧
       (get_mem_word ms.MEM ms.PC = Encode (Jump (fAdd,0w,Imm 0w))) ∧
       outs ≼ MAP get_output_io_event (cake_io_events cl (stdin_fs inp)) ∧
       ((ms.R (n2w (cake_machine_config).ptr_reg) = 0w) ⇒
        (outs = MAP get_output_io_event (cake_io_events cl (stdin_fs inp))))
Proof
  strip_tac
  \\ drule (GEN_ALL cake_machine_sem)
  \\ disch_then drule
  \\ disch_then drule
  \\ disch_then(qspec_then`stdin_fs inp`mp_tac)
  \\ impl_tac >- fs[STD_streams_stdin_fs, wfFS_stdin_fs]
  \\ strip_tac
  \\ irule ag32_next
  \\ conj_tac >- simp[ffi_names,extcalls_def]
  \\ conj_tac >- (simp[ffi_names,extcalls_def, LENGTH_code, LENGTH_data] \\ EVAL_TAC)
  \\ conj_tac >- (simp[ffi_names,extcalls_def] \\ EVAL_TAC)
  \\ goal_assum(first_assum o mp_then Any mp_tac)
  \\ goal_assum(first_assum o mp_then Any mp_tac)
  \\ goal_assum(first_assum o mp_then Any mp_tac)
  \\ goal_assum(first_assum o mp_then Any mp_tac)
  \\ goal_assum(first_assum o mp_then Any mp_tac)
  \\ drule cake_startup_clock_def
  \\ disch_then drule
  \\ disch_then drule
  \\ strip_tac
  \\ goal_assum(first_assum o mp_then Any mp_tac)
  \\ goal_assum(first_assum o mp_then Any mp_tac)
  \\ metis_tac[]
QED

val _ = export_theory();
