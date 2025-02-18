(**************************************************************************)
(*                                                                        *)
(*                                 OCaml                                  *)
(*                                                                        *)
(*             Xavier Leroy, projet Cristal, INRIA Rocquencourt           *)
(*                                                                        *)
(*   Copyright 1996 Institut National de Recherche en Informatique et     *)
(*     en Automatique.                                                    *)
(*                                                                        *)
(*   All rights reserved.  This file is distributed under the terms of    *)
(*   the GNU Lesser General Public License version 2.1, with the          *)
(*   special exception on linking described in the file LICENSE.          *)
(*                                                                        *)
(**************************************************************************)

open Misc
open Path
open Asttypes

type compile_time_constant =
  | Big_endian
  | Word_size
  | Int_size
  | Max_wosize
  | Ostype_unix
  | Ostype_win32
  | Ostype_cygwin
  | Backend_type

type loc_kind =
  | Loc_FILE
  | Loc_LINE
  | Loc_MODULE
  | Loc_LOC
  | Loc_POS

type tag_info = 
  | Blk_constructor of {name : string ; num_nonconst : int}
  | Blk_tuple
  | Blk_array
  | Blk_poly_var of string 
  | Blk_record of string array (* when its empty means we dont get such information *)
  | Blk_module of string list
  | Blk_module_export of Ident.t list
  | Blk_extension_slot
  | Blk_extension
  | Blk_na of string
  | Blk_some
  | Blk_some_not_nested (* ['a option] where ['a] can not inhabit a non-like value *)
  | Blk_record_inlined of { name : string ; num_nonconst :  int; fields : string array} 
  | Blk_record_ext of string array
  | Blk_lazy_general
  | Blk_class (* Ocaml style class*) 

let default_tag_info : tag_info = Blk_na ""
let blk_record = ref (fun fields -> 
  let all_labels_info = fields |> Array.map (fun (x,_) -> x.Types.lbl_name) in    
  Blk_record all_labels_info
  )

let blk_record_ext =  ref (fun fields -> 
    let all_labels_info = fields |> Array.map (fun (x,_) -> x.Types.lbl_name) in    
    Blk_record_ext all_labels_info
  )

let blk_record_inlined = ref (fun fields name num_nonconst -> 
  let fields = fields |> Array.map (fun (x,_) -> x.Types.lbl_name) in    
  Blk_record_inlined {fields; name; num_nonconst}
) 

let ref_tag_info : tag_info = Blk_record [| "contents" |]
  
type field_dbg_info = 
  | Fld_na of string
  | Fld_record of {name : string; mutable_flag : Asttypes.mutable_flag}
  | Fld_module of {name : string }
  | Fld_record_inline of { name : string}   
  | Fld_record_extension of {name : string}
  | Fld_tuple  
  | Fld_poly_var_tag
  | Fld_poly_var_content
  | Fld_extension
  | Fld_variant
  | Fld_cons 
  | Fld_array
  
let fld_record = ref (fun (lbl : Types.label_description) ->
  Fld_record {name = lbl.lbl_name; mutable_flag = Mutable})

let ref_field_info : field_dbg_info = 
  Fld_record { name = "contents"; mutable_flag = Mutable}
let fld_na = Fld_na ""

type set_field_dbg_info = 
    | Fld_set_na
    | Fld_record_set of string 
    | Fld_record_inline_set of string
    | Fld_record_extension_set of string

let ref_field_set_info : set_field_dbg_info = Fld_record_set "contents"    
let fld_record_set = ref ( fun (lbl : Types.label_description) ->
  Fld_record_set lbl.lbl_name  )

type immediate_or_pointer =
  | Immediate
  | Pointer

type initialization_or_assignment =
  | Assignment
  | Heap_initialization
  | Root_initialization

type is_safe =
  | Safe
  | Unsafe

type primitive =
  | Pidentity
  | Pbytes_to_string
  | Pbytes_of_string
  | Pignore
  | Prevapply
  | Pdirapply
  | Ploc of loc_kind
    (* Globals *)
  | Pgetglobal of Ident.t
  | Psetglobal of Ident.t
  (* Operations on heap blocks *)
  | Pmakeblock of int * tag_info * mutable_flag * block_shape
  | Pfield of int * field_dbg_info
  | Pfield_computed
  | Psetfield of int * immediate_or_pointer * initialization_or_assignment * set_field_dbg_info
  | Psetfield_computed of immediate_or_pointer * initialization_or_assignment
  | Pfloatfield of int * field_dbg_info
  | Psetfloatfield of int * initialization_or_assignment * set_field_dbg_info
  | Pduprecord of Types.record_representation * int
  (* Force lazy values *)
  | Plazyforce
  (* External call *)
  | Pccall of Primitive.description
  (* Exceptions *)
  | Praise of raise_kind
  (* Boolean operations *)
  | Psequand | Psequor | Pnot
  (* Integer operations *)
  | Pnegint | Paddint | Psubint | Pmulint
  | Pdivint of is_safe | Pmodint of is_safe
  | Pandint | Porint | Pxorint
  | Plslint | Plsrint | Pasrint
  | Pintcomp of comparison
  | Poffsetint of int
  | Poffsetref of int
  (* Float operations *)
  | Pintoffloat | Pfloatofint
  | Pnegfloat | Pabsfloat
  | Paddfloat | Psubfloat | Pmulfloat | Pdivfloat
  | Pfloatcomp of comparison
  (* String operations *)
  | Pstringlength | Pstringrefu  | Pstringrefs
  | Pbyteslength | Pbytesrefu | Pbytessetu | Pbytesrefs | Pbytessets
  (* Array operations *)
  | Pmakearray of array_kind * mutable_flag
  | Parraylength of array_kind
  | Parrayrefu of array_kind
  | Parraysetu of array_kind
  | Parrayrefs of array_kind
  | Parraysets of array_kind
  (* Test if the argument is a block or an immediate integer *)
  | Pisint
  (* Test if the (integer) argument is outside an interval *)
  | Pisout
  | Pbintofint of boxed_integer
  | Pintofbint of boxed_integer
  | Pcvtbint of boxed_integer (*source*) * boxed_integer (*destination*)
  | Pnegbint of boxed_integer
  | Paddbint of boxed_integer
  | Psubbint of boxed_integer
  | Pmulbint of boxed_integer
  | Pdivbint of { size : boxed_integer; is_safe : is_safe }
  | Pmodbint of { size : boxed_integer; is_safe : is_safe }
  | Pandbint of boxed_integer
  | Porbint of boxed_integer
  | Pxorbint of boxed_integer
  | Plslbint of boxed_integer
  | Plsrbint of boxed_integer
  | Pasrbint of boxed_integer
  | Pbintcomp of boxed_integer * comparison
  | Pctconst of compile_time_constant
  (* Inhibition of optimisation *)
  | Popaque

and comparison =
    Ceq | Cneq | Clt | Cgt | Cle | Cge

and value_kind =
    Pgenval | Pfloatval | Pboxedintval of boxed_integer | Pintval

and block_shape =
  value_kind list option

and array_kind =
    Pgenarray | Paddrarray | Pintarray | Pfloatarray

and boxed_integer = Primitive.boxed_integer =
    Pnativeint | Pint32 | Pint64


and raise_kind =
  | Raise_regular
  | Raise_reraise
  | Raise_notrace

type pointer_info = 
  | Pt_constructor of {name : string; const : int ; non_const : int }
  | Pt_variant of {name : string}
  | Pt_module_alias 
  | Pt_builtin_boolean  
  | Pt_shape_none   
  | Pt_assertfalse
  | Pt_na 

  
type structured_constant =
    Const_base of constant
  | Const_pointer of int * pointer_info
  | Const_block of int * tag_info * structured_constant list
  | Const_float_array of string list
  | Const_immstring of string


type inline_attribute =
  | Always_inline (* [@inline] or [@inline always] *)
  | Never_inline (* [@inline never] *)
  | Unroll of int (* [@unroll x] *)
  | Default_inline (* no [@inline] attribute *)

type specialise_attribute =
  | Always_specialise (* [@specialise] or [@specialise always] *)
  | Never_specialise (* [@specialise never] *)
  | Default_specialise (* no [@specialise] attribute *)

type function_kind = Curried | Tupled

type let_kind = Strict | Alias | StrictOpt | Variable


type shared_code = (int * int) list

type function_attribute = {
  inline : inline_attribute;
  specialise : specialise_attribute;
  is_a_functor: bool;
  stub: bool;
}
type switch_names = {consts: string array; blocks: string array}

type lambda =
    Lvar of Ident.t
  | Lconst of structured_constant
  | Lapply of lambda_apply
  | Lfunction of lfunction
  | Llet of let_kind * value_kind * Ident.t * lambda * lambda
  | Lletrec of (Ident.t * lambda) list * lambda
  | Lprim of primitive * lambda list * Location.t
  | Lswitch of lambda * lambda_switch * Location.t
  | Lstringswitch of
      lambda * (string * lambda) list * lambda option * Location.t
  | Lstaticraise of int * lambda list
  | Lstaticcatch of lambda * (int * Ident.t list) * lambda
  | Ltrywith of lambda * Ident.t * lambda
  | Lifthenelse of lambda * lambda * lambda
  | Lsequence of lambda * lambda
  | Lwhile of lambda * lambda
  | Lfor of Ident.t * lambda * lambda * direction_flag * lambda
  | Lassign of Ident.t * lambda
  | Lsend of string * lambda * Location.t

and lfunction =
  { kind: function_kind;
    params: Ident.t list;
    body: lambda;
    attr: function_attribute; (* specified with [@inline] attribute *)
    loc: Location.t; }

and lambda_apply =
  { ap_func : lambda;
    ap_args : lambda list;
    ap_loc : Location.t;
    ap_should_be_tailcall : bool;
    ap_inlined : inline_attribute;
    ap_specialised : specialise_attribute; }

and lambda_switch =
  { sw_numconsts: int;
    sw_consts: (int * lambda) list;
    sw_numblocks: int;
    sw_blocks: (int * lambda) list;
    sw_failaction : lambda option;
    sw_names: switch_names option }

and lambda_event =
  { lev_loc: Location.t;
    lev_kind: lambda_event_kind;
    lev_repr: int ref option;
    lev_env: Env.summary }

and lambda_event_kind =
    Lev_before
  | Lev_after of Types.type_expr
  | Lev_function
  | Lev_pseudo
  | Lev_module_definition of Ident.t

type program =
  { module_ident : Ident.t;
    main_module_block_size : int;
    required_globals : Ident.Set.t;
    code : lambda }

(* This is actually a dummy value 
    not necessary "()", it can be used as a place holder for module 
    alias etc.
*)
let const_unit = Const_pointer(0, Pt_constructor{name = "()"; const = 1; non_const = 0})

let lambda_assert_false = Lconst (Const_pointer(0, Pt_assertfalse))  

let lambda_module_alias = Lconst (Const_pointer(0, Pt_module_alias)) 

let lambda_unit = Lconst const_unit

let default_function_attribute = {
  inline = Default_inline;
  specialise = Default_specialise;
  is_a_functor = false;
  stub = false;
}

let default_stub_attribute =
  { default_function_attribute with stub = true }

(* Build sharing keys *)
(*
   Those keys are later compared with Pervasives.compare.
   For that reason, they should not include cycles.
*)

exception Not_simple

let max_raw = 32

let make_key e =
  let count = ref 0   (* Used for controling size *)
  and make_key = Ident.make_key_generator () in
  (* make_key is used for normalizing let-bound variables *)
  let rec tr_rec env e =
    incr count ;
    if !count > max_raw then raise_notrace Not_simple ; (* Too big ! *)
    match e with
    | Lvar id ->
      begin
        try Ident.find_same id env
        with Not_found -> e
      end
    | Lconst  (Const_base (Const_string _)) ->
        (* Mutable constants are not shared *)
        raise_notrace Not_simple
    | Lconst _ -> e
    | Lapply ap ->
        Lapply {ap with ap_func = tr_rec env ap.ap_func;
                        ap_args = tr_recs env ap.ap_args;
                        ap_loc = Location.none}
    | Llet (Alias,_k,x,ex,e) -> (* Ignore aliases -> substitute *)
        let ex = tr_rec env ex in
        tr_rec (Ident.add x ex env) e
    | Llet ((Strict | StrictOpt),_k,x,ex,Lvar v) when Ident.same v x ->
        tr_rec env ex
    | Llet (str,k,x,ex,e) ->
     (* Because of side effects, keep other lets with normalized names *)
        let ex = tr_rec env ex in
        let y = make_key x in
        Llet (str,k,y,ex,tr_rec (Ident.add x (Lvar y) env) e)
    | Lprim (p,es,_) ->
        Lprim (p,tr_recs env es, Location.none)
    | Lswitch (e,sw,loc) ->
        Lswitch (tr_rec env e,tr_sw env sw,loc)
    | Lstringswitch (e,sw,d,_) ->
        Lstringswitch
          (tr_rec env e,
           List.map (fun (s,e) -> s,tr_rec env e) sw,
           tr_opt env d,
          Location.none)
    | Lstaticraise (i,es) ->
        Lstaticraise (i,tr_recs env es)
    | Lstaticcatch (e1,xs,e2) ->
        Lstaticcatch (tr_rec env e1,xs,tr_rec env e2)
    | Ltrywith (e1,x,e2) ->
        Ltrywith (tr_rec env e1,x,tr_rec env e2)
    | Lifthenelse (cond,ifso,ifnot) ->
        Lifthenelse (tr_rec env cond,tr_rec env ifso,tr_rec env ifnot)
    | Lsequence (e1,e2) ->
        Lsequence (tr_rec env e1,tr_rec env e2)
    | Lassign (x,e) ->
        Lassign (x,tr_rec env e)
    | Lsend (m,e1,_loc) ->
        Lsend (m,tr_rec env e1,Location.none)
    | Lletrec _|Lfunction _
    | Lfor _ | Lwhile _
     ->
        raise_notrace Not_simple

  and tr_recs env es = List.map (tr_rec env) es

  and tr_sw env sw =
    { sw with
      sw_consts = List.map (fun (i,e) -> i,tr_rec env e) sw.sw_consts ;
      sw_blocks = List.map (fun (i,e) -> i,tr_rec env e) sw.sw_blocks ;
      sw_failaction = tr_opt env sw.sw_failaction ; }

  and tr_opt env = function
    | None -> None
    | Some e -> Some (tr_rec env e) in

  try
    Some (tr_rec Ident.empty e)
  with Not_simple -> None

(***************)

let name_lambda strict arg fn =
  match arg with
    Lvar id -> fn id
  | _ -> let id = Ident.create "let" in Llet(strict, Pgenval, id, arg, fn id)

let name_lambda_list args fn =
  let rec name_list names = function
    [] -> fn (List.rev names)
  | (Lvar _ as arg) :: rem ->
      name_list (arg :: names) rem
  | arg :: rem ->
      let id = Ident.create "let" in
      Llet(Strict, Pgenval, id, arg, name_list (Lvar id :: names) rem) in
  name_list [] args


let iter_opt f = function
  | None -> ()
  | Some e -> f e

let iter f = function
    Lvar _
  | Lconst _ -> ()
  | Lapply{ap_func = fn; ap_args = args} ->
      f fn; List.iter f args
  | Lfunction{body} ->
      f body
  | Llet(_str, _k, _id, arg, body) ->
      f arg; f body
  | Lletrec(decl, body) ->
      f body;
      List.iter (fun (_id, exp) -> f exp) decl
  | Lprim(_p, args, _loc) ->
      List.iter f args
  | Lswitch(arg, sw,_) ->
      f arg;
      List.iter (fun (_key, case) -> f case) sw.sw_consts;
      List.iter (fun (_key, case) -> f case) sw.sw_blocks;
      iter_opt f sw.sw_failaction
  | Lstringswitch (arg,cases,default,_) ->
      f arg ;
      List.iter (fun (_,act) -> f act) cases ;
      iter_opt f default
  | Lstaticraise (_,args) ->
      List.iter f args
  | Lstaticcatch(e1, _, e2) ->
      f e1; f e2
  | Ltrywith(e1, _, e2) ->
      f e1; f e2
  | Lifthenelse(e1, e2, e3) ->
      f e1; f e2; f e3
  | Lsequence(e1, e2) ->
      f e1; f e2
  | Lwhile(e1, e2) ->
      f e1; f e2
  | Lfor(_v, e1, e2, _dir, e3) ->
      f e1; f e2; f e3
  | Lassign(_, e) ->
      f e
  | Lsend (_k,  obj,  _) ->
      f obj

module IdentSet = Set.Make(Ident)

let free_ids get l =
  let fv = ref IdentSet.empty in
  let rec free l =
    iter free l;
    fv := List.fold_right IdentSet.add (get l) !fv;
    match l with
      Lfunction{params} ->
        List.iter (fun param -> fv := IdentSet.remove param !fv) params
    | Llet(_str, _k, id, _arg, _body) ->
        fv := IdentSet.remove id !fv
    | Lletrec(decl, _body) ->
        List.iter (fun (id, _exp) -> fv := IdentSet.remove id !fv) decl
    | Lstaticcatch(_e1, (_,vars), _e2) ->
        List.iter (fun id -> fv := IdentSet.remove id !fv) vars
    | Ltrywith(_e1, exn, _e2) ->
        fv := IdentSet.remove exn !fv
    | Lfor(v, _e1, _e2, _dir, _e3) ->
        fv := IdentSet.remove v !fv
    | Lassign(id, _e) ->
        fv := IdentSet.add id !fv
    | Lvar _ | Lconst _ | Lapply _
    | Lprim _ | Lswitch _ | Lstringswitch _ | Lstaticraise _
    | Lifthenelse _ | Lsequence _ | Lwhile _
    | Lsend _
     -> ()
  in free l; !fv

let free_variables l =
  free_ids (function Lvar id -> [id] | _ -> []) l


(* Check if an action has a "when" guard *)
let raise_count = ref 0

let next_raise_count () =
  incr raise_count ;
  !raise_count

let negative_raise_count = ref 0

let next_negative_raise_count () =
  decr negative_raise_count ;
  !negative_raise_count

(* Anticipated staticraise, for guards *)
let staticfail = Lstaticraise (0,[])

let rec is_guarded = function
  | Lifthenelse(_cond, _body, Lstaticraise (0,[])) -> true
  | Llet(_str, _k, _id, _lam, body) -> is_guarded body
  | _ -> false

let rec patch_guarded patch = function
  | Lifthenelse (cond, body, Lstaticraise (0,[])) ->
      Lifthenelse (cond, body, patch)
  | Llet(str, k, id, lam, body) ->
      Llet (str, k, id, lam, patch_guarded patch body)
  | _ -> fatal_error "Lambda.patch_guarded"

(* Translate an access path *)

let rec transl_normal_path = function
    Pident id ->
      if Ident.global id
      then Lprim(Pgetglobal id, [], Location.none)
      else Lvar id
  | Pdot(p, s, pos) ->
      Lprim(Pfield (pos, Fld_module {name = s}), [transl_normal_path p], Location.none)
  | Papply _ ->
      fatal_error "Lambda.transl_path"

(* Translation of identifiers *)

let transl_module_path ?(loc=Location.none) env path =
  transl_normal_path (Env.normalize_path (Some loc) env path)

let transl_value_path ?(loc=Location.none) env path =
  transl_normal_path (Env.normalize_path_prefix (Some loc) env path)

let transl_class_path = transl_value_path
let transl_extension_path = transl_value_path

(* compatibility alias, deprecated in the .mli *)
let transl_path = transl_value_path

(* Compile a sequence of expressions *)

let rec make_sequence fn = function
    [] -> lambda_unit
  | [x] -> fn x
  | x::rem ->
      let lam = fn x in Lsequence(lam, make_sequence fn rem)

(* Apply a substitution to a lambda-term.
   Assumes that the bound variables of the lambda-term do not
   belong to the domain of the substitution.
   Assumes that the image of the substitution is out of reach
   of the bound variables of the lambda-term (no capture). *)

let subst_lambda s lam =
  let rec subst = function
    Lvar id as l ->
      begin try Ident.find_same id s with Not_found -> l end
  | Lconst _ as l -> l
  | Lapply ap ->
      Lapply{ap with ap_func = subst ap.ap_func;
                     ap_args = List.map subst ap.ap_args}
  | Lfunction{kind; params; body; attr; loc} ->
      Lfunction{kind; params; body = subst body; attr; loc}
  | Llet(str, k, id, arg, body) -> Llet(str, k, id, subst arg, subst body)
  | Lletrec(decl, body) -> Lletrec(List.map subst_decl decl, subst body)
  | Lprim(p, args, loc) -> Lprim(p, List.map subst args, loc)
  | Lswitch(arg, sw, loc) ->
      Lswitch(subst arg,
              {sw with sw_consts = List.map subst_case sw.sw_consts;
                       sw_blocks = List.map subst_case sw.sw_blocks;
                       sw_failaction = subst_opt  sw.sw_failaction; },
              loc)
  | Lstringswitch (arg,cases,default,loc) ->
      Lstringswitch
        (subst arg,List.map subst_strcase cases,subst_opt default,loc)
  | Lstaticraise (i,args) ->  Lstaticraise (i, List.map subst args)
  | Lstaticcatch(e1, io, e2) -> Lstaticcatch(subst e1, io, subst e2)
  | Ltrywith(e1, exn, e2) -> Ltrywith(subst e1, exn, subst e2)
  | Lifthenelse(e1, e2, e3) -> Lifthenelse(subst e1, subst e2, subst e3)
  | Lsequence(e1, e2) -> Lsequence(subst e1, subst e2)
  | Lwhile(e1, e2) -> Lwhile(subst e1, subst e2)
  | Lfor(v, e1, e2, dir, e3) -> Lfor(v, subst e1, subst e2, dir, subst e3)
  | Lassign(id, e) -> Lassign(id, subst e)
  | Lsend (k,  obj,  loc) ->
      Lsend (k,subst obj, loc)
  and subst_decl (id, exp) = (id, subst exp)
  and subst_case (key, case) = (key, subst case)
  and subst_strcase (key, case) = (key, subst case)
  and subst_opt = function
    | None -> None
    | Some e -> Some (subst e)
  in subst lam

let rec map f lam =
  let lam =
    match lam with
    | Lvar _ -> lam
    | Lconst _ -> lam
    | Lapply { ap_func; ap_args; ap_loc; ap_should_be_tailcall;
          ap_inlined; ap_specialised } ->
        Lapply {
          ap_func = map f ap_func;
          ap_args = List.map (map f) ap_args;
          ap_loc;
          ap_should_be_tailcall;
          ap_inlined;
          ap_specialised;
        }
    | Lfunction { kind; params; body; attr; loc; } ->
        Lfunction { kind; params; body = map f body; attr; loc; }
    | Llet (str, k, v, e1, e2) ->
        Llet (str, k, v, map f e1, map f e2)
    | Lletrec (idel, e2) ->
        Lletrec (List.map (fun (v, e) -> (v, map f e)) idel, map f e2)
    | Lprim (p, el, loc) ->
        Lprim (p, List.map (map f) el, loc)
    | Lswitch (e, sw, loc) ->
        Lswitch (map f e,
          { sw_numconsts = sw.sw_numconsts;
            sw_consts = List.map (fun (n, e) -> (n, map f e)) sw.sw_consts;
            sw_numblocks = sw.sw_numblocks;
            sw_blocks = List.map (fun (n, e) -> (n, map f e)) sw.sw_blocks;
            sw_failaction = Misc.may_map (map f) sw.sw_failaction;
            sw_names = sw.sw_names
          },
          loc)
    | Lstringswitch (e, sw, default, loc) ->
        Lstringswitch (
          map f e,
          List.map (fun (s, e) -> (s, map f e)) sw,
          Misc.may_map (map f) default,
          loc)
    | Lstaticraise (i, args) ->
        Lstaticraise (i, List.map (map f) args)
    | Lstaticcatch (body, id, handler) ->
        Lstaticcatch (map f body, id, map f handler)
    | Ltrywith (e1, v, e2) ->
        Ltrywith (map f e1, v, map f e2)
    | Lifthenelse (e1, e2, e3) ->
        Lifthenelse (map f e1, map f e2, map f e3)
    | Lsequence (e1, e2) ->
        Lsequence (map f e1, map f e2)
    | Lwhile (e1, e2) ->
        Lwhile (map f e1, map f e2)
    | Lfor (v, e1, e2, dir, e3) ->
        Lfor (v, map f e1, map f e2, dir, map f e3)
    | Lassign (v, e) ->
        Lassign (v, map f e)
    | Lsend (k, o, loc) ->
        Lsend (k, map f o,  loc)
  in
  f lam

(* To let-bind expressions to variables *)

let bind str var exp body =
  match exp with
    Lvar var' when Ident.same var var' -> body
  | _ -> Llet(str, Pgenval, var, exp, body)

and commute_comparison = function
| Ceq -> Ceq| Cneq -> Cneq
| Clt -> Cgt | Cle -> Cge
| Cgt -> Clt | Cge -> Cle

and negate_comparison = function
| Ceq -> Cneq| Cneq -> Ceq
| Clt -> Cge | Cle -> Cgt
| Cgt -> Cle | Cge -> Clt

let raise_kind = function
  | Raise_regular -> "raise"
  | Raise_reraise -> "reraise"
  | Raise_notrace -> "raise_notrace"

let lam_of_loc kind loc =
  let loc_start = loc.Location.loc_start in
  let (file, lnum, cnum) = Location.get_pos_info loc_start in
  let file = Filename.basename file in  
  let enum = loc.Location.loc_end.Lexing.pos_cnum -
      loc_start.Lexing.pos_cnum + cnum in
  match kind with
  | Loc_POS ->
    Lconst (Const_block (0, Blk_tuple, [
          Const_immstring file;
          Const_base (Const_int lnum);
          Const_base (Const_int cnum);
          Const_base (Const_int enum);
        ]))
  | Loc_FILE -> Lconst (Const_immstring file)
  | Loc_MODULE ->
    let filename = Filename.basename file in
    let name = Env.get_unit_name () in
    let module_name = if name = "" then "//"^filename^"//" else name in
    Lconst (Const_immstring module_name)
  | Loc_LOC ->
    let loc = Printf.sprintf "File %S, line %d, characters %d-%d"
        file lnum cnum enum in
    Lconst (Const_immstring loc)
  | Loc_LINE -> Lconst (Const_base (Const_int lnum))

let merge_inline_attributes attr1 attr2 =
  match attr1, attr2 with
  | Default_inline, _ -> Some attr2
  | _, Default_inline -> Some attr1
  | _, _ ->
    if attr1 = attr2 then Some attr1
    else None

let reset () =
  raise_count := 0
