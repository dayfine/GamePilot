(* The members the Mail Glitch plans pick, found by species in the party as
   read, on two saves whose other members differ: the mGBA states' (read from
   the states, 2026-11-23) and console B's (Blastoise, Eevee, Pidgey, Oddish,
   Lapras, Magikarp, after the deposits the pre-flight asks for, Magikarp and
   Eevee, make room for Abra and Spearow). *)

open Frlg_actions

let case name input expectation = { Table_test.name; input; expectation }

let plan id =
  match Frlg_checkpoints.Plan_file.load (id ^ ".plan.json") with
  | Ok p -> p
  | Error e -> failwith e

let args id event_id =
  let p = plan id in
  match
    List.find_opt
      (fun (e : Checkpoints_plan.Plan.event) -> e.id = event_id)
      p.checkpoint.events
  with
  | Some { kind = Game_action args; _ } -> args
  | _ -> failwith (id ^ " has no game action " ^ event_id)

(* Each save's party at a checkpoint's start, slot 1 first. *)
let mgba = function
  | "01-celadon-setup" -> [ "blastoise"; "rattata"; "oddish"; "pidgey" ]
  | "03-trade-mr-mime" ->
      [ "blastoise"; "rattata"; "oddish"; "pidgey"; "abra"; "farfetchd" ]
  | "04-grind-farfetchd" ->
      [ "blastoise"; "rattata"; "oddish"; "pidgey"; "mr-mime"; "farfetchd" ]
  | "08-activate-and-verify" ->
      [ "farfetchd"; "blastoise"; "mr-mime"; "pidgey"; "rattata"; "oddish" ]
  | id -> failwith id

let console_b = function
  | "01-celadon-setup" -> [ "blastoise"; "pidgey"; "oddish"; "lapras" ]
  | "03-trade-mr-mime" ->
      [ "blastoise"; "pidgey"; "oddish"; "lapras"; "abra"; "farfetchd" ]
  | "04-grind-farfetchd" ->
      [ "blastoise"; "pidgey"; "oddish"; "lapras"; "mr-mime"; "farfetchd" ]
  | "08-activate-and-verify" ->
      [ "farfetchd"; "blastoise"; "mr-mime"; "pidgey"; "oddish"; "lapras" ]
  | id -> failwith id

let read party = Party_roster.of_read (List.map Option.some party)

let slot_text = function
  | Ok n -> "slot " ^ string_of_int n
  | Error c -> Checkpoints_run.Failure.cause_to_string c

(* Fly's user through Fly's own decoding. *)
let flyer save id event_id () =
  match Fly_args.decode (read (save id)) (args id event_id) with
  | Ok plan -> Printf.sprintf "slot %d" plan.slot
  | Error e -> e

(* Each member the event's args name, found in the party. *)
let members save id event_id () =
  let a = args id event_id in
  List.filter_map
    (fun key ->
      Option.map
        (fun s ->
          s ^ " "
          ^ slot_text (Party_roster.resolve (read (save id)) (Species s)))
        (Json_field.string_opt ~where:"" key a))
    Action_args.member_keys
  |> String.concat ", "

let both name run ~mgba:m ~console_b:b =
  [
    case (name ^ ", mGBA") (run mgba) m;
    case (name ^ ", console B") (run console_b) b;
  ]

let slots =
  List.concat
    [
      both "01-celadon-setup Fly's Pidgey"
        (fun s -> flyer s "01-celadon-setup" "fly_celadon")
        ~mgba:"slot 4" ~console_b:"slot 2";
      both "03-trade-mr-mime the trade's Abra"
        (fun s -> members s "03-trade-mr-mime" "trade_mimien")
        ~mgba:"abra slot 5" ~console_b:"abra slot 5";
      both "04-grind-farfetchd the grind's member and sweeper"
        (fun s -> members s "04-grind-farfetchd" "grind_chding_knock_off")
        ~mgba:"farfetchd slot 6, blastoise slot 1"
        ~console_b:"farfetchd slot 6, blastoise slot 1";
      both "08-activate-and-verify MIMIEN to slot 1"
        (fun s -> members s "08-activate-and-verify" "arrange_slot1_mimien")
        ~mgba:"mr-mime slot 3" ~console_b:"mr-mime slot 3";
      both "08-activate-and-verify Fly's Pidgey"
        (fun s -> flyer s "08-activate-and-verify" "fly_celadon")
        ~mgba:"slot 4" ~console_b:"slot 4";
      [
        case "a member whose species did not read is found by none"
          (fun () ->
            slot_text
              (Party_roster.resolve
                 (Party_roster.of_read [ Some "blastoise"; None ])
                 (Species "pidgey")))
          "not_in_party: pidgey is not in the party (blastoise, ?)";
      ];
    ]

(* The events that read the party first: those naming a member the game does
   not pick itself (Cut's user is the game's). *)
let pickers id =
  List.filter_map
    (fun (e : Checkpoints_plan.Plan.event) ->
      match (e.kind, e.action) with
      | Game_action a, Some action when Action_args.picks_member ~action a ->
          Some e.id
      | _ -> None)
    (plan id).checkpoint.events
  |> String.concat ", "

let picking =
  [
    case "01-celadon-setup: Fly"
      (fun () -> pickers "01-celadon-setup")
      "fly_celadon";
    case
      "02-trade-farfetchd: not the Cut, which names its user for the \
       pre-flight only"
      (fun () -> pickers "02-trade-farfetchd")
      "catch_spearow, fly_vermilion, fly_vermilion_house2, trade_chding";
    case
      "08-activate-and-verify: the battle's members by species; the mail to \
       slots 2-6 picks by slot, read by none"
      (fun () -> pickers "08-activate-and-verify")
      "activate_mail_glitch_battle, verify_mail_glitch, fly_celadon, \
       arrange_slot1_mimien, read_glitched_mail, give_dup_item, duplicate_item";
  ]

let () = Table_test.run "party members" (slots @ picking)
