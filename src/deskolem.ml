open Core
open Terms
open Timed

(** [subst_inv fu x t] replaces all the subterms [fu] by a fresh variable [x] in
    the term [t]. *)
let subst_inv : term -> term Bindlib.var -> term -> term = fun fu x ->
  let rec subst t =
    if Basics.eq t fu then Vari x else
    match t with
    | Vari _
    | Type
    | Kind                      -> t
    | Symb(_, _)                -> t
    | Prod( a, b)               ->
        let (v, b) = Bindlib.unbind b in
        let sa = subst a in
        let sb = Bindlib.bind_var v (lift (subst b)) in
        Prod(sa, Bindlib.unbox sb)
    | Abst( a, b)               ->
        let (v, b) = Bindlib.unbind b in
        let sa = subst a in
        let sb = Bindlib.bind_var v (lift (subst b)) in
        Abst(sa, Bindlib.unbox sb)
    | Appl( a, b)               -> Appl(subst a, subst b)
    | Meta _
    | Patt _
    | TEnv _
    | Wild
    | TRef _                    -> assert false (* is not handled in the encoding. *)
  in subst

(** [frozen t] checks if a term [t] contains free variables. *)
let frozen : term -> bool = fun t ->
    Bindlib.is_closed (lift t)

(** [print_args l] print terms that [l] contains. *)
let print_args l =
    List.iter (Console.out 1 "%a " Print.pp_term) l;
    Console.out 1 "@."

(** [get_ui f l t] returns a list of arguments used in [f]-terms inside [t]. *)
let rec get_ui : sym -> term list list -> term -> term list list = fun f l t ->
    match t with
    | Vari _
    | Type
    | Kind                      -> l
    | Symb(_, _)                -> l
    | Prod( a, b)               ->
        let (_, b) = Bindlib.unbind b in
        let l = get_ui f l a in
        get_ui f l b
    | Abst( a, b)               ->
        let (_, b) = Bindlib.unbind b in
        let l = get_ui f l a in
        get_ui f l b
    | Appl( _, _)               ->
        let (h, args) = Basics.get_args t in
        (* let args = List.map (get_ui f l) args in *)
        let args_set = List.fold_left (get_ui f) l args in
        if Basics.eq h (Symb(f, Nothing)) then
            if List.exists (List.for_all2 Basics.eq args) args_set || not (frozen t) then
                args_set
            else
                args::args_set
        else
            args_set
    | Meta _
    | Patt _
    | TEnv _
    | Wild
    | TRef _                    -> assert false (* is not handled in the encoding. *)

(** [get_option opt] returns [x] if [opt] is of the shape `Some x`, raise an
    Invalid_argument otherwise. *)
let get_option = fun opt ->
    match opt with
    | Some(x)   -> x
    | None      -> raise (Invalid_argument "The option is None.")

(** [size t] return the size of the term [t]. *)
let rec size : term -> int = fun t ->
  List.fold_right (fun a l -> size a + l) (snd (Basics.get_args t)) 1

(** [size_args f args] return the size of the term [f a0 a1 ... an] where args
    = [a0; a1; ...; an]. *)
let size_args : sym -> term list -> int = fun f args ->
    size (Basics.add_args (Symb(f, Nothing)) args)

let test : Sign.t -> unit = fun sign ->
    let f = Sign.builtin None !(sign.sign_builtins) "skolem_symbol" in
    let proof_term = Sign.find sign "delta" in
    let proof = get_option !(proof_term.sym_def) in
    (* let ui_type = (get_ui f [] !(proof_term.sym_type)) in *)
    let ui_proof = get_ui f [] proof in
    let ordered_ui = List.sort (fun x y -> size_args f y - size_args f x) ui_proof in
    List.iter print_args ordered_ui