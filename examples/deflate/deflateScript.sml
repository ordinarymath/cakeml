(*
First simple compressor
*)

open preamble;
open stringLib stringTheory;
open rich_listTheory alistTheory listTheory;
open sortingTheory arithmeticTheory;
open LZSSTheory;
open huffmanTheory;

val _ = new_theory "deflate";


Definition fixed_len_tree_def:
  fixed_len_tree =
   let
     ls = (REPLICATE 144 8) ++ (REPLICATE 112 9) ++ (REPLICATE 24 7) ++ (REPLICATE 8 8);
   in
     len_from_codes_inv ls
End
EVAL “fixed_len_tree”;

Definition fixed_dist_tree:
  fixed_dist_tree = GENLIST (λ n. (n, pad0 5 (TN2BL n))) 32
End
EVAL “fixed_dist_tree”;

(******************************************
               Deflate table
*******************************************)


(* (5-bit code value, number of extra bits after value, inclusive exclusive range for extra bits) *)
Definition dist_table_def:
  dist_table : (num # num # num) list =
  [ (0,   0,     1);
    (1,   0,     2);
    (2,   0,     3);
    (3,   0,     4);
    (4,   1,     5);
    (5,   1,     7);
    (6,   2,     9);
    (7,   2,    13);
    (8,   3,    17);
    (9,   3,    25);
    (10,  4,    33);
    (11,  4,    49);
    (12,  5,    65);
    (13,  5,    97);
    (14,  6,   129);
    (15,  6,   193);
    (16,  7,   257);
    (17,  7,   385);
    (18,  8,   513);
    (19,  8,   769);
    (20,  9,  1025);
    (21,  9,  1537);
    (22, 10,  2049);
    (23, 10,  3073);
    (24, 11,  4097);
    (25, 11,  6145);
    (26, 12,  8193);
    (27, 12, 12289);
    (28, 13, 16384);
    (29, 13, 24577);
]
End

(* (5-bit code value, number of extra bits after value, inclusive exclusive range for extra bits) *)
Definition len_table_def:
  len_table : (num # num # num) list =
  [ (257, 0,   3);
    (258, 0,   4);
    (259, 0,   5);
    (260, 0,   6);
    (261, 0,   7);
    (262, 0,   8);
    (263, 0,   9);
    (264, 0,  10);
    (265, 1,  11);
    (266, 1,  13);
    (267, 1,  15);
    (268, 1,  17);
    (269, 2,  19);
    (270, 2,  23);
    (271, 2,  27);
    (272, 2,  31);
    (273, 3,  35);
    (274, 3,  43);
    (275, 3,  51);
    (276, 3,  59);
    (277, 4,  67);
    (278, 4,  83);
    (279, 4,  99);
    (280, 4, 115);
    (281, 5, 131);
    (282, 5, 163);
    (283, 5, 195);
    (284, 5, 227);
    (285, 0, 258);
]
End

Definition find_level_in_table_def:
  find_level_in_table v [] prev = prev ∧
  find_level_in_table v (((curr, bits, value): num # num # num)::tab) prev  =
  if value <= v
  then find_level_in_table v tab (curr, bits, value)
  else prev
End

Definition find_level_in_len_table_def:
  find_level_in_len_table n = find_level_in_table n len_table (HD len_table)
End

Definition find_in_dist_table_def:
  find_level_in_dist_table n = find_level_in_table n dist_table (HD dist_table)
End


Definition find_code_in_table_def:
  find_code_in_table v [] = (0,0,0) ∧
  find_code_in_table v (((code, bits, value): num # num # num)::tab)  =
  if v = code
  then (code, bits, value)
  else find_code_in_table v tab
End

EVAL “find_in_table 67 len_table (HD len_table)”;


(******************************************
             Deflate encoding
*******************************************)

Overload END_BLOCK = “256:num”;

Definition encode_LZSS_len_def:
  encode_LZSS_len l : num =
  case l of
    Lit c => ORD c
  | LenDist (l, d) =>
      let
        (num, _, _) = find_level_in_len_table l
      in
        num
End

EVAL “encode_LZSS_len (Lit #"g")”;
EVAL “encode_LZSS_len (LenDist (20, 20))”;


(* Encodes each LZSS *)
Definition encode_LZSS_def:
  encode_LZSS (Lit c) len_tree dist_tree = encode_single_huff_val len_tree (ORD c) ∧
  encode_LZSS (LenDist (len, dist)) len_tree dist_tree =
  let
    (lnum, lbits, lvalue) = find_level_in_len_table len;
    (dnum, dbits, dvalue) = find_level_in_dist_table dist;
    enc_len = (encode_single_huff_val len_tree lnum) ++ (pad0 lbits (TN2BL (len - lvalue)));
    enc_dist = (encode_single_huff_val dist_tree dnum) ++ (pad0 dbits (TN2BL (dist - dvalue)))
  in
      enc_len ++ enc_dist
End

EVAL “encode_LZSS (Lit #"g") fixed_len_tree”;
EVAL “encode_LZSS (LenDist (3,3)) fixed_len_tree”;


Definition deflate_encoding_def:
  deflate_encoding [] len_tree dist_tree = [] ∧
  deflate_encoding (l::ls) len_tree dist_tree = encode_LZSS l len_tree dist_tree ++ deflate_encoding ls len_tree dist_tree
End

(* Should handle block level logic *)
Definition deflate_encoding_main_def:
  deflate_encoding_main s =
  let
    lzList = LZSS_compress s;
    lenList = MAP encode_LZSS_len lzList;
    (*assoc_list = unique_huff_tree lenList*)
    (len_tree, dist_tree) = (fixed_len_tree, fixed_dist_tree);
  in
    deflate_encoding lzList len_tree dist_tree
End

EVAL “deflate_encoding_main "hejhejhej"”;


Definition find_decode_match_def:
  find_decode_match s         []  = NONE ∧
  find_decode_match s ((k,v)::ts) =
  if (IS_PREFIX s v)
  then SOME (k,v)
  else find_decode_match s ts
End


(* using num from decode_LZSS, parameter, find_in_table, read num calc len  *)
Definition decode_LZSS_len_def:
  decode_LZSS_len lzlen bl =
  let
    (lnum, lbits, lvalue) = find_code_in_table lzlen len_table;
    len = TBL2N (TAKE lbits bl) + lvalue;
  in
    (len, lbits)
End

(* reads 5 bits, find_in_table, read num bits calc dist*)
Definition decode_LZSS_dist_def:
  decode_LZSS_dist lzcode bl =
  let
    (dnum, dbits, dvalue) = find_code_in_table lzcode dist_table;
    dist = TBL2N (TAKE dbits bl) + dvalue;
  in
    (dist, dbits)
End


(* use find_decode_match to find value stored if num < 256 then return Lit num
   else create LenDist using decode_LZSS_len and decode_LZSS_dist *)
Definition decode_LZSS_def:
  decode_LZSS (lznum:num) bl dist_tree =
  case lznum < END_BLOCK of
    T => (Lit $ CHR lznum, 0)
  | F => let
           (len, lbits) = decode_LZSS_len lznum bl;
         in
           case find_decode_match bl dist_tree of
             NONE => (LenDist (len,0),0) (* Something went wrong, huffman can't decode *)
           | SOME (dist_huff, bits) =>
               let
                 (dist, dbits) = decode_LZSS_dist dist_huff (DROP ((LENGTH bits) + lbits) bl);
               in
                 (LenDist (len, dist), lbits + (LENGTH bits) + dbits)
End

Definition deflate_decoding_def:
  deflate_decoding [] len_tree dist_tree acc = (acc, []) ∧
  deflate_decoding bl len_tree dist_tree acc =
  case find_decode_match bl len_tree of
    NONE => (acc, []) (* Something went wrong, huffman can't decode *)
  | SOME (lznum, bits) =>
      case lznum = END_BLOCK of
        T => (acc, DROP (LENGTH bits) bl) (* End block *)
      | F =>
          case bits of
            [] => (acc, DROP (LENGTH bits) bl)
          | _ => (let
                    (lz, extra_bits) = decode_LZSS lznum (DROP (LENGTH bits) bl) dist_tree
                  in
                    deflate_decoding (DROP (extra_bits + (LENGTH bits)) bl) len_tree dist_tree (acc++[lz])  )
Termination
  WF_REL_TAC ‘measure $ λ (bl, len_tree, dist_tree, acc). LENGTH bl’
  \\ rw[find_decode_match_def, decode_LZSS_def, decode_LZSS_len_def, decode_LZSS_dist_def]
End

EVAL “
 let
   enc =  encode_LZSS (LenDist (3,3)) fixed_len_tree fixed_dist_tree;
   (a, b) = deflate_decoding enc fixed_len_tree fixed_dist_tree [];
 in
   a
”;

EVAL “encode_LZSS (LenDist (3,3)) fixed_len_tree”;

Definition deflate_decoding_main_def:
  deflate_decoding_main bl =
  let
    (len_tree, dist_tree) = (fixed_len_tree, fixed_dist_tree);
    (lzList, bl') = deflate_decoding bl len_tree dist_tree [];
    res = LZSS_decompress lzList
  in
    (res, bl')
End

EVAL “let
        inp = "hejhejhej";
        enc =  deflate_encoding_main inp;
        (dec, rest) = deflate_decoding_main enc;
      in
        (inp, dec,rest)
     ”;


val _ = export_theory();
