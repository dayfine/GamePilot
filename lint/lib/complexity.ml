open Parsetree

(* What a node adds by itself: [Walk n] adds [n] and its children are walked
   as usual; [Counted n] already includes its children. *)
type node = Walk of int | Counted of int

let rec node_decisions e =
  match e.pexp_desc with
  | Pexp_ifthenelse _ | Pexp_while _ | Pexp_for _ -> Walk 1
  | Pexp_apply
      ({ pexp_desc = Pexp_ident { txt = Lident ("&&" | "||"); _ }; _ }, _) ->
      Walk 1
  | Pexp_match (scrutinee, cases) | Pexp_try (scrutinee, cases) ->
      Counted (decisions scrutinee + case_decisions cases)
  | Pexp_function (_, _, Pfunction_cases (cases, _, _)) ->
      Counted (case_decisions cases)
  | _ -> Walk 0

and decisions e =
  let total = ref 0 in
  let default = Ast_iterator.default_iterator in
  let expr self e =
    match node_decisions e with
    | Walk n ->
        total := !total + n;
        default.expr self e
    | Counted n -> total := !total + n
  in
  let iterator = { default with expr } in
  iterator.expr iterator e;
  !total

and case_decisions cases =
  let guard c = match c.pc_guard with None -> 0 | Some g -> 1 + decisions g in
  let inside =
    List.fold_left (fun n c -> n + guard c + decisions c.pc_rhs) 0 cases
  in
  if inside = 0 then 0 else List.length cases - 1 + inside

let finding (c : Config.t) (src : Parsed_source.t)
    (fb : Parsed_source.function_binding) =
  let cc = 1 + decisions fb.body in
  let message =
    Printf.sprintf "'%s' has complexity %d (advisory above %d)" fb.name cc
      c.complexity_advisory
  in
  let line = fb.start_line in
  if cc <= c.complexity_advisory then None
  else Some (Finding.advisory ~check:"complexity" ~path:src.path ~line message)

let check c src =
  List.filter_map (finding c src) (Parsed_source.function_bindings src)
