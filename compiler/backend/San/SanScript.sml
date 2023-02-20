(*
* A simple instantiation of machin_config for sanity check
*)
open preamble targetSemTheory riscv_targetTheory riscvTheory ffiTheory bitstringTheory;

val _ = new_theory "San";

(* the bool is used as indicating whether the pc is accessing shared memory *)
val san_prog_asm_def = Define`
  san_prog_asm = [
    F, (Inst (Const 5 0w));
    T, (Inst (Mem Load 6 (Addr 5 20000w)));
    F, (Inst (Arith (Binop Add 7 6 (Imm 1w))));
    T, (Inst (Mem Store 7 (Addr 5 20008w)));
    F, (JumpReg 5)]`; (* jump to the halt pc *)

val asm2ast_def = Define`
  asm2ast = MAP (\(b,asm). (b,riscv_ast asm))`;

val asts_encode_def = Define`
  asts_encode = MAP (\(b,ast). (b,FLAT $ MAP riscv_encode ast))`;

val add_halt_and_ccache_def = Define`
  add_halt_and_ccache = (++) (GENLIST (K (F,GENLIST (K 0w) ffi_offset)) 2)`;

val san_flat_def = Define`
  (san_flat [] n = ([],[],[])) /\
  (san_flat ((F,xs)::xss) n =
    let (pcs,pcs',prog) = san_flat xss (n+LENGTH xs) in
    (pcs,pcs',xs++prog)) /\
  (san_flat ((T,xs)::xss) n =
    let (pcs,pcs',prog) = san_flat xss (n+LENGTH xs) in
    (n::pcs,n+LENGTH xs::pcs', xs++prog))`;

val san_enc_result_def = Define`
    san_enc_result =
      flip san_flat 0 o add_halt_and_ccache o asts_encode $
      asm2ast san_prog_asm`;

val san_ffi_pcs_def = Define`
  san_ffi_pcs = MAP n2w o FST $ san_enc_result`;

val san_end_ffi_pcs_def = Define`
  san_end_ffi_pcs = MAP n2w o FST o SND $ san_enc_result`;

val san_program_def = Define`
  san_program = ((SND o SND $ san_enc_result):word8 list)`;

val san_ffi_interfer_def = Define`
  san_ffi_interfer info_func = K (\((n:num),bytes,state).
    if n = 0 then
      let (nb,ad,reg,new_pc) = info_func n in
      state with
      <|c_gpr := (\pid r.
          if pid = state.procID /\ r = n2w reg
          then n2w (bytes2num bytes)
          else state.c_gpr pid r);
        c_PC := (state.procID =+ new_pc) state.c_PC |>
    else if n = 1 then
      let (_,_,_,new_pc) = info_func n in
        state with
      <|c_PC := (state.procID =+ new_pc) state.c_PC |>
    else state)`;

val san_mmio_info_def = Define`
  san_mmio_info =
    let max_size = dimindex (:64) DIV 8 in
    ((0:num) =+ (n2w max_size,20000w,(6:num),EL 0 san_end_ffi_pcs)) $
    (1 =+ (n2w max_size,20008w,7,EL 1 san_end_ffi_pcs)) $
    K ARB`;

val san_ffi_pcs_simp = EVAL ``san_ffi_pcs``;
val san_end_pcs_simp = EVAL ``san_end_ffi_pcs``;

val san_config_def = Define`
  san_config =
  <| prog_addresses := {x | x < 1000w} DELETE 0w DELETE n2w ffi_offset DIFF
  flip MEM san_ffi_pcs
   ; ffi_entry_pcs := san_ffi_pcs
   ; ffi_names := ["MappedRead";"MappedWrite"]
   ; ptr_reg := ARB
   ; len_reg := ARB
   ; ptr2_reg := ARB
   ; len2_reg := ARB
   ; ffi_interfer := san_ffi_interfer 
    (san_mmio_info: num -> word8 # word64 # num # word64)
   ; next_interfer := K I
   ; halt_pc := 0w
   ; ccache_pc := n2w ffi_offset
   ; ccache_interfer :=ARB
   ; target := riscv_target
   ; mmio_info := san_mmio_info|>`;

val san_oracle_def = Define`
  san_oracle s () l1 l2 =
    Oracle_return () 
      (PAD_RIGHT 0w (LENGTH l2) [20w])`; 

val san_init_ffi_state_def = Define`
  san_init_ffi_state =
    <|oracle := san_oracle;
      ffi_state := ();
      io_events := []|>`;

val san_init_pc_def = Define`
  san_init_pc = n2w $ ffi_offset * 2`;

val word_EL_def = Define`
  word_EL l start w = if w2n (w - start) < LENGTH l
          then EL (w2n (w - start)) l else 0w`;

val san_procID_def = Define`
  san_procID = 0w`;

val san_MCSR_def = Define`
  san_MCSR = (san_procID =+
      <|mstatus := <| VM := 0w |>;
      mcpuid := <|ArchBase := 2w |> |>) ARB`;

val san_init_machine_state_def = Define`
  san_init_machine_state =
    ARB with
    <|c_PC := (san_procID =+ san_init_pc) (K 0w);
      procID := san_procID;
      MEM8 := word_EL san_program 0w;
      c_MCSR := san_MCSR;
      exception := NoException;
      c_NextFetch := (san_procID =+ NONE) ARB|>`;

val san_result_def = Define`
  san_result n =
  evaluate san_config san_init_ffi_state n san_init_machine_state`;

(* val all_riscv_Defs = map fst o filter (fn n => snd n = Def ) o 
  map snd $ DB.match ["riscv"] ``_``; *)

val _ = computeLib.add_funs
  [Encode_def,Itype_def,Stype_def,opc_def,word_concat_def];
(* val _ = computeLib.add_funs all_riscv_Defs; *)

val san_program_simp = EVAL ``san_program``;

fun encoded_bytes_in_mem_tac inst offset =
  gvs[encoded_bytes_in_mem_def,riscv_config_def,
    san_init_machine_state_def,san_config_def] \\
  qexistsl [inst, offset] \\
  simp [EVAL $ Parse.Term inst, EVAL $ Parse.Term offset] \\
  fs[riscv_enc_def,LIST_BIND_def,riscv_ast_def] \\
  EVAL_TAC \\
  simp[DELETE_applied,DIFF_DEF];  

Theorem encoded_bytes_in_mem_1:
  encoded_bytes_in_mem riscv_config 32w san_init_machine_state.MEM8
    san_config.prog_addresses
Proof
  encoded_bytes_in_mem_tac `SND $ EL 0 san_prog_asm` `0`
QED

Theorem encoded_bytes_in_mem_3:
  encoded_bytes_in_mem riscv_config 40w (word_EL
   [0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w;
    0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w;
    0w; 0w; 0w; 0w; 147w; 98w; 0w; 0w; 3w; 179w; 2w; 226w;
    147w; 3w; 19w; 0w; 35w; 180w; 114w; 226w; 103w; 128w; 2w;
    0w] (0w:word64))
  {x | ((x < 1000w ∧ x ≠ 0w) ∧ x ≠ 16w) ∧ x ≠ 36w ∧ x ≠ 44w}
Proof
  encoded_bytes_in_mem_tac `SND $ EL 2 san_prog_asm` `0`
QED

val riscv_ok_tac = simp[
  EVAL ``ffi_offset``, riscv_ok_def,aligned_w2n,APPLY_UPDATE_THM];

val decode_conv =
  SIMP_CONV (srw_ss()) [Decode_def,boolify32_def,LET_DEF] THENC
  EVAL THENC
  SIMP_CONV (srw_ss()) [v2w_def] THENC
  EVAL; 

val san_decode_inst_1 = decode_conv ``Decode 25235w``;

val state_1 = ``riscv_next san_init_machine_state`` |> (
  EVAL THENC
  SIMP_CONV (srw_ss())
    [rawReadInst_def,translateAddr_def,vmType_def,MCSR_def,
     APPLY_UPDATE_THM,PC_def,LET_DEF,word_EL_def,boolify8_def] THENC
  SIMP_CONV (srw_ss())
    [write'Skip_def,word_EL_def,word_concat_def] THENC
  SIMP_CONV (srw_ss())
    [san_decode_inst_1,Run_def,dfn'ORI_def,GPR_def,write'GPR_def,write'gpr_def] THENC
  SIMP_CONV (srw_ss()) [NextFetch_def,write'PC_def,Skip_def,APPLY_UPDATE_THM]);

val san_decode_inst_3 = decode_conv ``Decode 0x130393w``;

val state_3 =
``riscv_next
   <|MEM8 :=
       word_EL
         [0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w;
          0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w;
          0w; 0w; 0w; 0w; 0w; 0w; 147w; 98w; 0w; 0w; 3w;
          179w; 2w; 226w; 147w; 3w; 19w; 0w; 35w; 180w; 114w;
          226w; 103w; 128w; 2w; 0w] (0w: word64);
     c_MCSR :=
       ARB⦇
         0w ↦
           <|mcpuid := <|ArchBase := 2w|>;
             mstatus := <|VM := 0w|> |>
       ⦈; c_NextFetch := ARB⦇0w ↦ NONE⦈;
     c_PC := (K 0w)⦇0w ↦ 40w⦈; c_Skip := ARB.c_Skip⦇0w ↦ 4w⦈;
     c_gpr :=
       (λpid r.
            if pid = 0w ∧ r = 6w then
              n2w (bytes2num (PAD_RIGHT 0w 8 [20w:word8]))
            else
              (if pid = 0w then (ARB.c_gpr 0w)⦇5w ↦ 0w⦈
               else ARB.c_gpr pid) r);
     exception := NoException; procID := 0w|>`` |> (
  EVAL THENC
  SIMP_CONV (srw_ss())
    [rawReadInst_def,translateAddr_def,vmType_def,MCSR_def,
     APPLY_UPDATE_THM,PC_def,LET_DEF,word_EL_def,boolify8_def] THENC
  SIMP_CONV (srw_ss())
    [write'Skip_def,word_EL_def,word_concat_def] THENC
  SIMP_CONV (srw_ss())
    [san_decode_inst_3,Run_def,dfn'ADDI_def,GPR_def,write'GPR_def,write'gpr_def] THENC
  SIMP_CONV (srw_ss())
  [NextFetch_def,write'PC_def,Skip_def,APPLY_UPDATE_THM,gpr_def]);

Theorem encoded_bytes_in_mem_5:
  encoded_bytes_in_mem riscv_config 48w
  (word_EL
     [0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w;
      0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w;
      0w; 0w; 0w; 0w; 147w; 98w; 0w; 0w; 3w; 179w; 2w; 226w;
      147w; 3w; 19w; 0w; 35w; 180w; 114w; 226w; 103w; 128w; 2w;
      0w] (0w:word64))
  {x | ((x < 1000w ∧ x ≠ 0w) ∧ x ≠ 16w) ∧ x ≠ 36w ∧ x ≠ 44w}
Proof
  encoded_bytes_in_mem_tac `SND $ EL 4 san_prog_asm` `0`
QED

val san_decode_inst_5 = decode_conv ``Decode 0x28067w``;

val state_5 =
``riscv_next
  <|MEM8 :=
      word_EL
        [0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w;
         0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w; 0w;
         0w; 0w; 0w; 0w; 0w; 0w; 147w; 98w; 0w; 0w; 3w;
         179w; 2w; 226w; 147w; 3w; 19w; 0w; 35w; 180w; 114w;
         226w; 103w; 128w; 2w; 0w] 0w;
    c_MCSR :=
      ARB⦇
        0w ↦
          <|mcpuid := <|ArchBase := 2w|>;
            mstatus := <|VM := 0w|> |>
      ⦈; c_NextFetch := ARB⦇0w ↦ NONE⦈;
    c_PC := (K 0w)⦇0w ↦ 48w⦈; c_Skip := ARB.c_Skip⦇0w ↦ 4w⦈;
    c_gpr :=
      (λpid r.
           if pid = 0w ∧ r = 6w then 20w
           else
             (if pid = 0w then (ARB.c_gpr 0w)⦇5w ↦ 0w⦈
              else ARB.c_gpr pid) r)⦇
        0w ↦
          (λr.
               if r = 6w then 20w
               else if r = 5w then 0w
               else ARB.c_gpr 0w r)⦇
            7w ↦ 21w
          ⦈
      ⦈; exception := NoException; procID := 0w|>`` |> (
  EVAL THENC
  SIMP_CONV (srw_ss())
    [rawReadInst_def,translateAddr_def,vmType_def,MCSR_def,
     APPLY_UPDATE_THM,PC_def,LET_DEF,word_EL_def,boolify8_def] THENC
  SIMP_CONV (srw_ss())
    [write'Skip_def,word_EL_def,word_concat_def] THENC
  SIMP_CONV (srw_ss())
    [san_decode_inst_5,Run_def,dfn'JALR_def,GPR_def,write'GPR_def,write'gpr_def,LET_THM,branchTo_def,write'NextFetch_def] THENC
  SIMP_CONV (srw_ss())
  [NextFetch_def,write'PC_def,Skip_def,APPLY_UPDATE_THM,gpr_def]);

val san_prog_addr_simp =
  ``{x | x < 1000w} DELETE 0w DELETE n2w ffi_offset DIFF
  flip MEM san_ffi_pcs`` |> (EVAL THENC
  SIMP_CONV (srw_ss()) [DELETE_applied,DIFF_DEF]);

val pc_in_prog_addr_tac = simp[PC_def,riscv_target_def,APPLY_UPDATE_THM,
  san_ffi_pcs_def,EVAL ``n2w (2 * ffi_offset)``,san_prog_addr_simp];

val san_mmio_info_simp = EVAL ``san_mmio_info``;

Theorem san_io_event_length:
  LENGTH (SND(SND(san_result 10))).io_events = 2
Proof
  simp[san_result_def, Once evaluate_def]\\
  rewrite_tac[san_config_def,san_init_pc_def,san_procID_def,
    san_init_machine_state_def,san_MCSR_def] \\
  pc_in_prog_addr_tac \\ 
  simp[CONV_RULE
    (SIMP_CONV (srw_ss())
    [san_config_def,san_init_machine_state_def,san_prog_addr_simp])
    encoded_bytes_in_mem_1] \\
  simp[apply_oracle_def] \\ 
  simp[san_MCSR_def,san_procID_def,CONV_RULE (SIMP_CONV (srw_ss())
  [san_MCSR_def,san_procID_def,san_config_def,san_init_machine_state_def,san_init_pc_def,EVAL``ffi_offset``,san_prog_addr_simp])
  state_1] \\
  riscv_ok_tac \\
  rewrite_tac[word_EL_def,san_program_simp] \\
  simp[Once evaluate_def] \\
  pc_in_prog_addr_tac\\
  simp[find_index_def,CONV_RULE (SIMP_CONV (srw_ss()) [san_ffi_pcs_def])
  san_ffi_pcs_simp] \\
  simp[san_mmio_info_simp,APPLY_UPDATE_THM] \\
  simp[call_FFI_def,san_init_ffi_state_def,san_oracle_def] \\
  simp[length_pad_right,
    EVAL ``LENGTH (addr2w8list riscv_config.big_endian (20000w:word64))``] \\
  simp[apply_oracle_def,san_ffi_interfer_def,APPLY_UPDATE_THM] \\
  simp[Once evaluate_def] \\
  simp[APPLY_UPDATE_THM] \\ (* pc_in_prog_addr_tac *)
  (* TODO: third instruction *)
  simp[encoded_bytes_in_mem_3] \\
  simp[apply_oracle_def,shift_seq_def] \\
  simp[state_3] \\
  riscv_ok_tac \\
  simp[Once evaluate_def] \\
  simp[APPLY_UPDATE_THM] \\
  simp[find_index_def,CONV_RULE (SIMP_CONV (srw_ss()) [san_ffi_pcs_def])
  san_ffi_pcs_simp] \\
  simp[san_mmio_info_simp,APPLY_UPDATE_THM] \\
  simp[call_FFI_def,san_init_ffi_state_def,san_oracle_def] \\
  simp[length_pad_right,
    EVAL ``LENGTH (addr2w8list riscv_config.big_endian 20008w)``,
    EVAL ``LENGTH (w2wlist riscv_config.big_endian 21w 8)``] \\
  simp[apply_oracle_def,shift_seq_def] \\
  simp[Once evaluate_def] \\
  simp[APPLY_UPDATE_THM] \\
  simp[encoded_bytes_in_mem_5] \\
  simp[apply_oracle_def,shift_seq_def] \\
  simp[state_5] \\
  riscv_ok_tac \\
  simp[Once evaluate_def, APPLY_UPDATE_THM]
QED
