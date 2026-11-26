module J = Plan_json
module T = Fragment_table

type resolve =
  kind:string -> string -> field:string option -> (string, string) result

let ( let* ) = Result.bind
let all_ok = Table_decode.all_ok
let call_fields = [ "id"; "fragment"; "args"; "why"; "skip_if" ]

let check_fields (call : J.fields) =
  match List.find_opt (fun (k, _) -> not (List.mem k call_fields)) call with
  | Some (k, _) -> Error (k ^ " is not a field a fragment call takes.")
  | None -> Ok ()

let arg (name, value) =
  match value with
  | `String s -> Ok (name, s)
  | _ -> Error ("args." ^ name ^ " is not a string.")

let named = function [] -> "none" | l -> String.concat ", " l

(* The call's args, with each one's kind: exactly the fragment's params. *)
let args (f : T.fragment) (call : J.fields) =
  let* given = all_ok (List.map arg (J.object_field "args" call)) in
  let names = List.sort compare (List.map fst given) in
  let params = List.map (fun (p : T.param) -> p.param) f.params in
  if names = List.sort compare params then
    Ok
      (List.map
         (fun (p : T.param) ->
           (p.param, (p.param_kind, List.assoc p.param given)))
         f.params)
  else
    Error
      (Printf.sprintf "%s takes args %s, not %s." f.name (named params)
         (named names))

let text (name, field) =
  match field with
  | None -> "{" ^ name ^ "}"
  | Some f -> "{" ^ name ^ "." ^ f ^ "}"

(* [s] with every [sub] replaced by [by]. *)
let replace_all ~sub ~by s =
  let n = String.length sub and b = Buffer.create (String.length s) in
  let rec go i =
    match Strings.Find.substring ~from:i s sub with
    | None -> Buffer.add_string b (String.sub s i (String.length s - i))
    | Some j ->
        Buffer.add_string b (String.sub s i (j - i));
        Buffer.add_string b by;
        go (j + n)
  in
  go 0;
  Buffer.contents b

(* The string with each placeholder filled in by the game. *)
let fill (resolve : resolve) given s =
  let one acc ((name, field) as p) =
    let* s = acc in
    let kind, value = List.assoc name given in
    let* by = resolve ~kind value ~field in
    Ok (replace_all ~sub:(text p) ~by s)
  in
  List.fold_left one (Ok s) (T.placeholders s)

let rec substitute resolve given :
    Yojson.Safe.t -> (Yojson.Safe.t, string) result = function
  | `String s -> Result.map (fun s -> `String s) (fill resolve given s)
  | `List l ->
      Result.map
        (fun l -> `List l)
        (all_ok (List.map (substitute resolve given) l))
  | `Assoc f ->
      let field (k, v) =
        Result.map (fun v -> (k, v)) (substitute resolve given v)
      in
      Result.map (fun f -> `Assoc f) (all_ok (List.map field f))
  | other -> Ok other

let event_id call_id suffix =
  if suffix = "" then call_id else call_id ^ "." ^ suffix

(* One of the fragment's events, filled in for the call. *)
let instance resolve ~call given template =
  let* filled = substitute resolve given (`Assoc template) in
  let filled = J.fields_of filled in
  let call_id = Option.value ~default:"" (J.string_field "id" call) in
  let id =
    event_id call_id (Option.value ~default:"" (J.string_field "id" filled))
  in
  let why =
    match (J.string_field "why" filled, List.assoc_opt "why" call) with
    | None, Some why -> [ ("why", why) ]
    | _ -> []
  in
  let skip = List.filter (fun (k, _) -> k = "skip_if") call in
  Ok (`Assoc (J.set "id" (`String id) filled @ skip @ why))

let expand_call table resolve call name =
  let* () = check_fields call in
  let* fragment = T.find table name in
  let* given = args fragment call in
  all_ok (List.map (instance resolve ~call given) fragment.events)

let step table resolve () event =
  let* events =
    match List.assoc_opt "fragment" event with
    | None -> Ok [ `Assoc event ]
    | Some (`String name) -> expand_call table resolve event name
    | Some _ -> Error "fragment is not a string."
  in
  Ok (events, ())

let expand table resolve ~source json =
  J.rewrite_events ~source ~start:(fun _ -> ()) ~step:(step table resolve) json
