(*
First simple compressor
*)

open preamble;
open stringLib stringTheory;
open rich_listTheory alistTheory listTheory;
open sortingTheory arithmeticTheory;
open LZSSTheory;
open huffmanTheory;
open rleTheory;
open deflateTableTheory;

val _ = new_theory "deflate";

Overload END_BLOCK = “256:num”;

(******************************************
              Deflate fixed
*******************************************)


Definition fixed_len_tree_def:
  fixed_len_tree =
   let
     ls = (REPLICATE 144 8) ++ (REPLICATE 112 9) ++ (REPLICATE 24 7) ++ (REPLICATE 8 8);
   in
     len_from_codes_inv ls
End

Definition fixed_dist_tree:
  fixed_dist_tree = GENLIST (λ n. (n, pad0 5 (TN2BL n))) 32
End

(******************************************
             Deflate encoding
*******************************************)

(***** Encode codelengths for huffman trees  *****)
Definition clen_position_def:
  clen_position : num list =
  [16; 17; 18; 0; 8; 7; 9; 6; 10; 5; 11; 4; 12; 3; 13; 2; 14; 1; 15;]
End

Definition encode_clen_pos_def:
  encode_clen_pos alph = REVERSE $ FOLDL (λ ls i. (EL i alph)::ls ) [] clen_position
End

Definition trim_zeroes_end_def:
  trim_zeroes_end (alph:num list) =
  let
    zeroes = FOLDL (λ n clen. if clen = 0 then n+1 else 0) 0 alph;
  in
    BUTLASTN zeroes alph
End

Definition encode_clen_alph_def:
  encode_clen_alph (alph: num list) =
  let
    alph = trim_zeroes_end $ encode_clen_pos $ PAD_RIGHT 0 19 alph;
    CLEN_bits = FLAT ( MAP (λa. (pad0 3 (TN2BL a))) alph);
    NCLEN = LENGTH alph
  in
    (NCLEN, CLEN_bits)
End

(***** Encode indiviual LZSS  *****)
Definition find_LZSS_val_def:
  find_LZSS_val l : num # num =
  case l of
    Lit c => (ORD c, 0)
  | LenDist (l, d) =>
      let
        (lnum, _, _) = find_level_in_len_table l;
        (dnum, _, _) = find_level_in_dist_table d;
      in
        (lnum, dnum)
End

Definition encode_LZSS_table_def:
  encode_LZSS_table n table_func tree  =
  let
    (code, bits, value) = table_func n;
  in
    (encode_single_huff_val tree code) ++ (pad0 bits (TN2BL (n - value)))
End


Definition encode_LZSS_def:
  encode_LZSS (Lit c) len_tree dist_tree = encode_single_huff_val len_tree (ORD c) ∧
  encode_LZSS (LenDist (len, dist)) len_tree dist_tree =
  let
    enc_len  = encode_LZSS_table len  (find_level_in_len_table)  len_tree;
    enc_dist = encode_LZSS_table dist (find_level_in_dist_table) dist_tree;
  in
      enc_len ++ enc_dist
End

EVAL “encode_LZSS (Lit #"g") fixed_len_tree”;
EVAL “encode_LZSS (LenDist (3,3)) fixed_len_tree”;

Definition deflate_encoding_def:
  deflate_encoding [] len_tree dist_tree = [] ∧
  deflate_encoding (l::ls) len_tree dist_tree =
  encode_LZSS l len_tree dist_tree ++ deflate_encoding ls len_tree dist_tree
End

(***** help functions for encoder *****)
Definition split_len_dist:
  split_len_dist       []  ls ds = (ls, ds) ∧
  split_len_dist (lz::lzs) ls ds =
  let
    (a, b) = find_LZSS_val lz;
  in
    case a < 257 of
      T => split_len_dist lzs (a::ls) ds
    | F => split_len_dist lzs (a::ls) (b::ds)
End

Definition max_fst_pair_def:
  max_fst_pair ls : num = FOLDL (λ a (b,_). if a < b then b else a) (FST $ HD ls) ls
End

(***** Main encoder functions *****)
Definition deflate_encoding_main_def:
  deflate_encoding_main s fix =
  case fix of
    T =>
      ( let
          BTYPE = [F; T];
          lzList = LZSS_compress s;
          (len_tree, dist_tree) = (fixed_len_tree, fixed_dist_tree);
        in
          BTYPE++
          (deflate_encoding lzList len_tree dist_tree)
      )
  | F =>
      let
        lzList = LZSS_compress s;
        (lenList, distList) = split_len_dist lzList [] [];
        (*    Build huffman tree for len/dist       *)
        (len_tree,  len_alph)  = unique_huff_tree lenList;
        (dist_tree, dist_alph) = unique_huff_tree distList;
        (*    Build huffman tree for len/dist codelengths    *)
        len_dist_alph = (len_alph ++ dist_alph);
        (*    Encode len/dist codelengths                    *)
        (lendist_alph_enc, clen_tree, clen_alph, _) = encode_rle len_dist_alph;
        (NCLEN_num, CLEN_bits) = encode_clen_alph clen_alph;
        (*    Setup header bits                              *)
        BTYPE = [T; F];
        NLIT  = pad0 5 $ TN2BL ((MIN (max_fst_pair len_tree) 257)  - 257);
        NDIST = pad0 5 $ TN2BL ((max_fst_pair dist_tree) - 1);
        NCLEN = pad0 4 $ TN2BL (NCLEN_num - 4);
        header_bits = BTYPE ++ NLIT ++ NDIST ++ NCLEN;
      in
        header_bits ++
        CLEN_bits ++
        lendist_alph_enc ++
        (deflate_encoding lzList len_tree dist_tree)
End

EVAL “deflate_encoding_main "hejsan hejsan" F”;

(************************************
          Deflate Decoding
************************************)

(***** Decodes each LZSS *****)
Definition decode_LZSS_table_def:
  decode_LZSS_table lzvalue bl table =
  let
    (lzvalue', bits, value) = find_code_in_table lzvalue table;
    lz = TBL2N (TAKE bits bl) + value;
  in
    (lz, bits)
End

Definition decode_LZSS_lendist:
  decode_LZSS_lendist lznum bl dist_tree =
  let
    (len, lbits) = decode_LZSS_table lznum bl len_table;
    dist_res = find_decode_match bl dist_tree;
    lz =  case dist_res of
            NONE => (LenDist (len,0),0) (* Something went wrong, huffman can't decode *)
          | SOME (dist_huff, bits) =>
              let
                (dist, dbits) = decode_LZSS_table dist_huff (DROP ((LENGTH bits) + lbits) bl) dist_table;
              in
                (LenDist (len, dist), lbits + (LENGTH bits) + dbits)
  in
    lz
End

Definition decode_LZSS_def:
  decode_LZSS (lznum:num) bl dist_tree =
  case lznum < END_BLOCK of
    T => (Lit $ CHR lznum, 0)
  | F => decode_LZSS_lendist lznum bl dist_tree
End

Definition decode_check_end_block:
  decode_check_end_block bl len_tree =
  case find_decode_match bl len_tree of
    NONE => (T, [], 0, []) (* Something went wrong, huffman can't decode *)
  | SOME (lznum, bits) =>
      case lznum = END_BLOCK of
        T => (T, DROP (LENGTH bits) bl, END_BLOCK, bits) (* End block *)
      | F => (F, bl, lznum, bits)
End

Definition deflate_decoding_def:
  deflate_decoding [] len_tree dist_tree acc = (acc, []) ∧
  deflate_decoding bl len_tree dist_tree acc =
  case decode_check_end_block bl len_tree  of
    (T, bl', _, _) => (acc, bl')
  | (F, bl', lznum, bits) =>
      case bits of
        [] => (acc, bl)
      | _ =>  (let
                 (lz, extra_bits) = decode_LZSS lznum (DROP (LENGTH bits) bl) dist_tree
               in
                 deflate_decoding (DROP (extra_bits + (LENGTH bits)) bl) len_tree dist_tree (acc++[lz]))
Termination
  WF_REL_TAC ‘measure $ λ (bl, len_tree, dist_tree, acc). LENGTH bl’
  \\ rw[decode_check_end_block, find_decode_match_def, decode_LZSS_def, decode_LZSS_table_def, decode_LZSS_def]
End

(***** Decode header dynamic *****)
Definition read_dyn_header_def:
  read_dyn_header bl =
  let
    NLIT = TBL2N (TAKE 5 bl) + 257;
    bl = DROP 5 bl;
    NDIST = TBL2N (TAKE 5 bl) + 1;
    bl = DROP 5 bl;
    NCLEN = TBL2N (TAKE 4 bl) + 4;
    bl = DROP 4 bl;
  in
    (NLIT, NDIST, NCLEN, bl)
End

Definition read_clen_def:
  read_clen bl 0 = [] ∧
  read_clen bl (SUC CLEN) = TBL2N (TAKE 3 bl) :: read_clen (DROP 3 bl) CLEN
End

Definition recreate_clen_def:
  recreate_clen []   _        res = res ∧
  recreate_clen (cl::clen) (clp::clen_pos) res =
  recreate_clen clen clen_pos (LUPDATE cl clp res)
End

Definition decode_clen_def:
  decode_clen bl nclen =
  let
    clens = read_clen bl nclen;
    clens = recreate_clen clens clen_position (GENLIST (λn. 0) 19);
  in
    (len_from_codes_inv clens, DROP (3*nclen) bl)
End

(***** Main decoder function *****)
Definition deflate_decoding_main_def:
  deflate_decoding_main (b1::b2::bl) =
  if b1 = F ∧ b2 = T
  then
    ( let
        (len_tree, dist_tree) = (fixed_len_tree, fixed_dist_tree);
        (lzList, bl') = deflate_decoding bl len_tree dist_tree [];
        res = LZSS_decompress lzList
      in
        (res, bl'))
  else if b1 = T ∧ b2 = F
  then
    ( let
        (NLIT, NDIST, NCLEN, bl) = read_dyn_header bl;
        (clen_tree, bl') = decode_clen bl NCLEN;
        (len_dist_alph, bl'') = decode_rle bl' (NLIT + NDIST) clen_tree;
        len_alph = TAKE (NLIT + 257) len_dist_alph;
        dist_alph = DROP (NLIT + 257) len_dist_alph;

        len_tree = len_from_codes_inv len_alph;
        dist_tree = len_from_codes_inv dist_alph;

        (lzList, bl''') = deflate_decoding bl'' len_tree dist_tree [];
        res = LZSS_decompress lzList;
      in
        (res, bl''')
    )
  else ("", [])
End

(* Fixed Huffman *)
EVAL “let
        inp = "hejhejhellohejsanhello";
        enc =  deflate_encoding_main inp T;
        (dec, rest) = deflate_decoding_main enc;
      in
        (inp, dec)
     ”;

(* Dynamic Huffman*)
EVAL “let
        inp = "hejhejhellohejsanhello";
        enc =  deflate_encoding_main inp F;
        (dec, rest) = deflate_decoding_main enc;
      in
        (inp, dec)
     ”;

EVAL “
 let
   inp = "hejsan hejsan";
   lzList = LZSS_compress inp;
   (lenList, distList) = split_len_dist lzList [] [];
   (*    Build huffman tree for len/dist       *)
   (len_tree,  len_alph)  = unique_huff_tree lenList;
   (dist_tree, dist_alph) = unique_huff_tree distList;
   (*    Build huffman tree for len/dist codelengths    *)
   len_dist_alph = (len_alph ++ dist_alph);
   (*    Encode len/dist codelengths                    *)
   (lendist_alph_enc, clen_tree, clen_alph, _) = encode_rle len_dist_alph;
   (NCLEN_num, CLEN_bits) = encode_clen_alph clen_alph;
   (*    Setup header bits                              *)
   BTYPE = [T; F];
   NLIT  = pad0 5 $ TN2BL ((MIN (max_fst_pair len_tree) 257)  - 257);
   NDIST = pad0 5 $ TN2BL ((max_fst_pair dist_tree) - 1);
   NCLEN = pad0 4 $ TN2BL (NCLEN_num - 4);
   header_bits = BTYPE ++ NLIT ++ NDIST ++ NCLEN;
   enc = header_bits ++
         CLEN_bits ++
         lendist_alph_enc ++
         (deflate_encoding lzList len_tree dist_tree);
   enc = DROP 2 enc;
   bl = enc;
   (NLIT', NDIST', NCLEN', bl) = read_dyn_header bl;
   (clen_tree', bl') = decode_clen bl NCLEN';
   (len_dist_alph', bl'') = decode_rle bl' (NLIT' + NDIST') clen_tree';
   (aa, ab) = decode_rle lendist_alph_enc (LENGTH len_dist_alph) clen_tree';
   len_alph' = TAKE (NLIT' + 257) len_dist_alph';
   dist_alph' = DROP (NLIT' + 257) len_dist_alph';
   len_tree' = len_from_codes_inv len_alph';
   dist_tree' = len_from_codes_inv dist_alph';
   (lzList, bl''') = deflate_decoding  bl'' len_tree' dist_tree' [];
   res = LZSS_decompress lzList;

   ls = [11;12;0;0;0;0;0;0;0;0;0;0;14;0;13;6;6;6;5;4;4;4;4;4;4;2;2;15;1;2;2;2;2];
   (enc, clen_tree, clen_alph, _) = encode_rle ls;
   (output, rest) = decode_rle enc (LENGTH ls) clen_tree;
 in
   (ls, output)
”;



val _ = export_theory();
