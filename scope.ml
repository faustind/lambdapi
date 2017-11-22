(** Scoping. *)

open Extra
open Console
open Files
open Terms
open Typing
open Print
open Parser

(* Representation of an environment for variables. *)
type env = (string * tvar) list

(* [scope new_wildcard env sign t] transforms the parsing level term [t]  into
   an actual term, using the free variables of the environement [env], and the
   symbols of the signature [sign].  If a function is given in [new_wildcard],
   then it is called on [P_Wild] nodes. This will only be allowed when reading
   a term as a pattern. *)
let scope : (unit -> tbox) option -> env -> Sign.t -> p_term -> tbox =
  fun new_wildcard vars sign t ->
    let rec scope vars t =
      match t with
      | P_Vari([],x)  ->
          begin
            try Bindlib.box_of_var (List.assoc x vars) with Not_found ->
            try _Symb (Sign.find sign x) with Not_found ->
            fatal "Unbound variable or symbol %S...\n%!" x
          end
      | P_Vari(fs,x)  ->
          begin
            try
              let sg = Hashtbl.find Sign.loaded fs in
              try _Symb (Sign.find sg x) with Not_found ->
                let x = String.concat "." (fs @ [x]) in
                fatal "Unbound symbol %S...\n%!" x
            with Not_found ->
              let path = String.concat "." fs in
              fatal "No module path %S loaded...\n%!" path
          end
      | P_Type        -> _Type
      | P_Prod(x,a,b) ->
          let f v = scope (if x = "_" then vars else (x,v)::vars) b in
          _Prod (scope vars a) x f
      | P_Abst(x,a,t) ->
          let f v = scope ((x,v)::vars) t in
          let a =
            match a with
            | None    -> let fn (_,x) = Bindlib.box_of_var x in
                         let vars = List.map fn vars in
                         _Unif (ref None) (Array.of_list vars)
            | Some(a) -> scope vars a
          in
          _Abst a x f
      | P_Appl(t,u)   -> _Appl (scope vars t) (scope vars u)
      | P_Wild        ->
          match new_wildcard with
          | None    -> fatal "\"_\" not allowed in terms...\n"
          | Some(f) -> f ()
    in
    scope vars t

 (* [to_tbox ~vars sign t] is a convenient interface for [scope]. *)
let to_tbox : ?vars:env -> Sign.t -> p_term -> tbox =
  fun ?(vars=[]) sign t -> scope None vars sign t

(* [to_term ~vars sign t] composes [to_tbox] with [Bindlib.unbox]. *)
let to_term : ?vars:env -> Sign.t -> p_term -> term =
  fun ?(vars=[]) sign t -> Bindlib.unbox (scope None vars sign t)

(* Representation of a pattern as a head symbol, list of argument and array of
   variables corresponding to wildcards. *)
type patt = def * tbox list * tvar array

(* [to_patt env sign t] transforms the parsing level term [t] into a  pattern.
   Note that here, [t] may contain wildcards. The function also checks that it
   has a definable symbol as a head term, and gracefully fails otherwise. *)
let to_patt : env -> Sign.t -> p_term -> patt = fun vars sign t ->
  let wildcards = ref [] in
  let counter = ref 0 in
  let new_wildcard () =
    let x = "#" ^ string_of_int !counter in
    let x = Bindlib.new_var mkfree x in
    incr counter; wildcards := x :: !wildcards; Bindlib.box_of_var x
  in
  let t = Bindlib.unbox (scope (Some new_wildcard) vars sign t) in
  let (head, args) = get_args t in
  match head with
  | Symb(Def(s)) -> (s, List.map lift args, Array.of_list !wildcards)
  | Symb(Sym(s)) -> fatal "%s is not a definable symbol...\n" s.sym_name
  | _            -> fatal "%a is not a valid pattern...\n" pp t

(* [scope_rule sign r] scopes a parsing level reduction rule,  producing every
   element that is necessary to check its type. This includes its context, the
   symbol, the LHS and RHS as terms and the rule. *)
let scope_rule : Sign.t -> p_rule -> Ctxt.t * def * term * term * rule =
  fun sign (xs_ty_map,t,u) ->
    let xs = List.map fst xs_ty_map in
    (* Scoping the LHS and RHS. *)
    let vars = List.map (fun x -> (x, Bindlib.new_var mkfree x)) xs in
    let (s, l, wcs) = to_patt vars sign t in
    let arity = List.length l in
    let l = Bindlib.box_list l in
    let u = to_tbox ~vars sign u in
    (* Building the definition. *)
    let xs = Array.append (Array.of_list (List.map snd vars)) wcs in
    let lhs = Bindlib.unbox (Bindlib.bind_mvar xs l) in
    let rhs = Bindlib.unbox (Bindlib.bind_mvar xs u) in
    (* Constructing the typing context. *)
    let ty_map = List.map (fun (n,x) -> (x, List.assoc n xs_ty_map)) vars in
    let add_var (vars, ctx) x =
      let a =
        try
          match snd (List.find (fun (y,_) -> Bindlib.eq_vars y x) ty_map) with
          | None    -> raise Not_found
          | Some(a) -> to_term ~vars sign a (* FIXME *)
        with Not_found ->
          let fn (_,x) = Bindlib.box_of_var x in
          let vars = List.map fn vars in
          Bindlib.unbox (_Unif (ref None) (Array.of_list vars))
      in
      ((Bindlib.name_of x, x) :: vars, Ctxt.add x a ctx)
    in
    let wcs = Array.to_list wcs in
    let wcs = List.map (fun x -> (Bindlib.name_of x, x)) wcs in
    let (_, ctx) = Array.fold_left add_var (wcs, Ctxt.empty) xs in
    (* Constructing the rule. *)
    let t = add_args (Symb(Def s)) (Bindlib.unbox l) in
    let u = Bindlib.unbox u in
    (ctx, s, t, u, { lhs ; rhs ; arity })
