(* A toy game's terms, to prove the engine needs no tile grid and no Pokémon:
   the player stands in a zone (a place, and maybe a spot in it), its own
   kinds are a walk that holds a direction until a landmark shows and a rest
   at an inn, and a checkpoint promises gold and flags. *)

open Engine_promise
module F = Json_field

type pose = { place : string; spot : string option }
type observed = pose
type own_kind = Walk of { toward : string; until : string } | Rest
type promises = { gold : Count.t option; flags : string list }
(* What the game read: the gold now and at the start, and each flag read. *)

type reads = { gold_now : int option; start : int option; set : string list }
type start_reads = int option

let known ~where allowed obj =
  Engine_plan.Plan_fields.known_fields_only ~where allowed obj

let pose ~where obj =
  F.catch (fun () ->
      known ~where [ "place"; "spot" ] obj;
      {
        place = F.string ~where "place" obj;
        spot = F.string_opt ~where "spot" obj;
      })

(* A pose without a spot holds anywhere in its place. *)
let matches pose observed =
  pose.place = observed.place && (pose.spot = None || pose.spot = observed.spot)

let pose_text p =
  match p.spot with Some s -> p.place ^ "/" ^ s | None -> p.place

let observed_text = pose_text

let observed_to_json p =
  `Assoc
    [
      ("place", `String p.place);
      ("spot", Option.fold ~none:`Null ~some:(fun s -> `String s) p.spot);
    ]

let observed_of_json = function
  | `Assoc [ ("place", `String place); ("spot", `String spot) ] ->
      Ok { place; spot = Some spot }
  | `Assoc [ ("place", `String place); ("spot", `Null) ] ->
      Ok { place; spot = None }
  | _ -> Error "not a place"

let walk ~where args =
  F.catch (fun () ->
      known ~where [ "toward"; "until" ] args;
      Walk
        {
          toward = F.string ~where "toward" args;
          until = F.string ~where "until" args;
        })

let rest ~where args =
  F.catch (fun () ->
      known ~where [] args;
      Rest)

let own_kind = function "walk" -> Some walk | "rest" -> Some rest | _ -> None

let own_kind_text = function
  | Walk { toward; until } -> Printf.sprintf "walk %s until %s" toward until
  | Rest -> "rest"

let gold ~where obj =
  match F.find "gold" obj with
  | None -> None
  | Some _ -> Some (Count.Gained (F.int ~where "gold" obj))

let promises ~where obj =
  F.catch (fun () ->
      known ~where [ "gold"; "flags" ] obj;
      {
        gold = gold ~where obj;
        flags =
          Option.fold ~none:[]
            ~some:(F.strings (where ^ "flags"))
            (F.find "flags" obj);
      })

let no_promises = { gold = None; flags = [] }
let checked_at_end p = p.gold <> None || p.flags <> []

let check_gold (p : promises) reads =
  match (p.gold, reads.gold_now) with
  | None, _ -> []
  | Some _, None -> [ Promise.not_read "gold" ]
  | Some count, Some read ->
      [ Promise.count "gold" count ~start:reads.start ~read ]

let check_flag reads flag =
  let set = List.mem flag reads.set in
  Promise.judge ("flag " ^ flag) ~expected:"set"
    ~read:(if set then "set" else "clear")
    set

let check p reads = check_gold p reads @ List.map (check_flag reads) p.flags

let promises_text p =
  Option.fold ~none:[] ~some:(fun c -> [ "gold " ^ Count.text c ]) p.gold
  @ if p.flags = [] then [] else [ "flags " ^ String.concat ", " p.flags ]

let start_reads_to_json start =
  [ ("start_gold", Option.fold ~none:`Null ~some:(fun n -> `Int n) start) ]

let start_reads_of_json fields =
  match List.assoc_opt "start_gold" fields with
  | Some (`Int n) -> Ok (Some n)
  | Some `Null | None -> Ok None
  | Some _ -> Error "start_gold is not a number"
