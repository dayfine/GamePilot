(* A toy game's terms, to prove the engine needs no tile grid and no Pokémon:
   the player stands in a zone (a place, and maybe a spot in it), its own
   kinds are a walk that holds a direction until a landmark shows and a rest
   at an inn, and a checkpoint promises gold and flags. *)

open Engine_postcondition
module F = Json_field

let known ~where allowed obj =
  Engine_plan.Plan_fields.known_fields_only ~where allowed obj

module Pose = struct
  type t = { place : string; spot : string option }
  type observed = t

  let decode ~where obj =
    F.catch (fun () ->
        known ~where [ "place"; "spot" ] obj;
        {
          place = F.string ~where "place" obj;
          spot = F.string_opt ~where "spot" obj;
        })

  (* A pose without a spot holds anywhere in its place. *)
  let matches pose observed =
    pose.place = observed.place
    && (pose.spot = None || pose.spot = observed.spot)

  let text p = match p.spot with Some s -> p.place ^ "/" ^ s | None -> p.place
  let observed_text = text

  let to_json p =
    `Assoc
      [
        ("place", `String p.place);
        ("spot", Option.fold ~none:`Null ~some:(fun s -> `String s) p.spot);
      ]

  let of_json = function
    | `Assoc [ ("place", `String place); ("spot", `String spot) ] ->
        Ok { place; spot = Some spot }
    | `Assoc [ ("place", `String place); ("spot", `Null) ] ->
        Ok { place; spot = None }
    | _ -> Error "not a place"
end

module Kind = struct
  type t = Walk of { toward : string; until : string } | Rest

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

  let decode = function "walk" -> Some walk | "rest" -> Some rest | _ -> None

  let text = function
    | Walk { toward; until } -> Printf.sprintf "walk %s until %s" toward until
    | Rest -> "rest"
end

module Postconditions = struct
  type t = { gold : Count.t option; flags : string list }

  (* What the game read: the gold now and at the start, and each flag read. *)
  type reads = { gold_now : int option; start : int option; set : string list }

  let gold ~where obj =
    match F.find "gold" obj with
    | None -> None
    | Some _ -> Some (Count.Gained (F.int ~where "gold" obj))

  let decode ~where obj =
    F.catch (fun () ->
        known ~where [ "gold"; "flags" ] obj;
        {
          gold = gold ~where obj;
          flags =
            Option.fold ~none:[]
              ~some:(F.strings (where ^ "flags"))
              (F.find "flags" obj);
        })

  let check_gold (p : t) reads =
    match (p.gold, reads.gold_now) with
    | None, _ -> []
    | Some _, None -> [ Postcondition.not_read "gold" ]
    | Some count, Some read ->
        [ Postcondition.count "gold" count ~start:reads.start ~read ]

  let check_flag reads flag =
    let set = List.mem flag reads.set in
    Postcondition.judge ("flag " ^ flag) ~expected:"set"
      ~read:(if set then "set" else "clear")
      set

  let check p reads = check_gold p reads @ List.map (check_flag reads) p.flags

  let text p =
    Option.fold ~none:[] ~some:(fun c -> [ "gold " ^ Count.text c ]) p.gold
    @ if p.flags = [] then [] else [ "flags " ^ String.concat ", " p.flags ]
end

module Saved = struct
  type t = { start : int option; at : Pose.t option }

  let ( let* ) = Result.bind

  let to_json { start; at } =
    `Assoc
      [
        ("start_gold", Option.fold ~none:`Null ~some:(fun n -> `Int n) start);
        ("at", Option.fold ~none:`Null ~some:Pose.to_json at);
      ]

  let start_of_json fields =
    match List.assoc_opt "start_gold" fields with
    | Some (`Int n) -> Ok (Some n)
    | Some `Null | None -> Ok None
    | Some _ -> Error "start_gold is not a number"

  let at_of_json = function
    | `Null -> Ok None
    | json ->
        Result.map_error (fun e -> "at: " ^ e) (Pose.of_json json)
        |> Result.map Option.some

  let of_json = function
    | `Assoc fields ->
        let* start = start_of_json fields in
        let* at =
          at_of_json (Option.value (List.assoc_opt "at" fields) ~default:`Null)
        in
        Ok { start; at }
    | _ -> Error "what is kept is not an object"
end
