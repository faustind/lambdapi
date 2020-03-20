(** Source code position management.  This module may be used to map sequences
    of characters in a source file to an abstract syntax tree. *)

open Pacomb

include Pos

(* NOTE laziness is essential on big files (especially those with long lines),
   because computing utf8 positions is expensive. *)

(** Convenient short name for an optional position. *)
type popt =
  | NoPos
  | ByPos of pos
  | LnPos of pos_info

(** [equal p1 p2] tells whether [p1] and [p2] denote the same position. *)
let equal : popt -> popt -> bool = fun p1 p2 ->
  match (p1, p2) with
  | (ByPos(p1), ByPos(p2)) -> p1 = p2
  | (LnPos(p1), LnPos(p2)) -> p1 = p2
  | (NoPos    , NoPos    ) -> true
  | (_        , _        ) -> false

(** Type constructor extending a type (e.g. a piece of abstract syntax) with a
    a source code position. *)
type 'a loc =
  { elt : 'a   (** The element that is being localised.        *)
  ; pos : popt (** Position of the element in the source code. *) }

(** Localised string type (widely used). *)
type strloc = string loc

(** [make pos elt] associates the position [pos] to [elt]. *)
let make : popt -> 'a -> 'a loc =
  fun pos elt -> { elt ; pos }

(** [in_pos pos elt] associates the position [pos] to [elt]. *)
let in_pos : pos -> 'a -> 'a loc =
  fun p elt -> { elt ; pos = ByPos p }

(** [none elt] wraps [elt] in a ['a loc] structure without any specific source
    code position. *)
let none : 'a -> 'a loc =
  fun elt -> { elt ; pos = NoPos }

(** [to_string pos] transforms [pos] into a readable string. *)
let to_string : pos_info -> string = fun p ->
  let { file_name = fname; start_line; start_col ; end_line; end_col ; _ } = p
  in
  let fname = match fname with
    | ""    -> ""
    | n -> n ^ ", "
  in
  if start_line <> end_line then
    Printf.sprintf "%s%d:%d-%d:%d" fname start_line start_col end_line end_col
  else if start_col = end_col then
    Printf.sprintf "%s%d:%d" fname start_line start_col
  else
    Printf.sprintf "%s%d:%d-%d" fname start_line start_col end_col

(** [print oc pos] prints the optional position [pos] to [oc]. *)
let print : Format.formatter -> popt -> unit = fun ch p ->
  match p with
  | NoPos    -> Format.pp_print_string ch "unknown location"
  | LnPos(p) -> Format.pp_print_string ch (to_string p)
  | ByPos(p) -> Format.pp_print_string ch (to_string (pos_info p))