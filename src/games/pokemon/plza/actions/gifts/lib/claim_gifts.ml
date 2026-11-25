module G = Mystery_gift
module B = Gift_to_box

type mode = Both_gifts | Code_gift_only | Internet_gift_only | Box_slot_2_to_1
type span = { from : string; stop_at : string option; mode : mode }

type game = {
  log : string -> unit;
  picture : Wire.box;
  tile : Switch_home.Home_screen.tile_color;
  code : string;
}

type step = { at : string; go : game -> (unit, string) result }

let default_code = "CELEBRATE30TH"
let ( let* ) = Result.bind

let from_overworld next g =
  let* _row = Menu_rows.open_menu ~log:g.log in
  next ~log:g.log

let close g =
  g.log "Closing the game.";
  Switch_home.Game_entry.close_game ~log:g.log ~picture:g.picture g.tile

let step at go = { at; go }
let open_gifts = step "overworld" (from_overworld G.open_gifts)

let internet_steps =
  [
    step "mystery-gift" (fun g -> G.open_internet_list ~log:g.log);
    step "gift-list" (fun g -> G.choose_gift ~log:g.log);
    step "card" (fun g -> G.leave_card ~log:g.log);
  ]

let disconnect _ = Ok (G.disconnect ())

let code_steps =
  [
    step "code" (fun g -> G.open_keyboard ~log:g.log);
    step "keyboard" (fun g -> G.claim_code ~log:g.log ~picture:g.picture g.code);
    step "code-card" (fun g -> G.dismiss_card ~log:g.log);
    step "disconnect" disconnect;
  ]

let save_steps =
  [
    step "moved" (fun g -> B.open_save_prompt ~log:g.log);
    step "save" (fun g -> B.save ~log:g.log);
    step "saved" close;
  ]

(* With five in the party, the first gift claimed lands in party slot 6: the
   Internet gift when the run claims it (the code's then goes straight to Box
   1), else the code's. *)
let party_gift = function
  | Code_gift_only -> B.Code_gift
  | Both_gifts | Internet_gift_only | Box_slot_2_to_1 -> B.Internet_gift

let box_steps mode =
  [
    step "after-gifts" (from_overworld B.to_boxes);
    step "boxes" (fun g -> B.move_gift ~log:g.log (party_gift mode));
  ]
  @ save_steps

let steps = function
  | Both_gifts ->
      (open_gifts :: internet_steps) @ code_steps @ box_steps Both_gifts
  | Code_gift_only -> (open_gifts :: code_steps) @ box_steps Code_gift_only
  | Internet_gift_only ->
      (open_gifts :: internet_steps)
      @ [ step "code" disconnect ]
      @ box_steps Internet_gift_only
  | Box_slot_2_to_1 ->
      step "overworld" (from_overworld B.open_boxes)
      :: step "boxes" (fun g -> B.move_slot_2_to_1 ~log:g.log)
      :: save_steps

let path mode = List.map (fun s -> s.at) (steps mode)

let points =
  [
    "overworld";
    "mystery-gift";
    "gift-list";
    "card";
    "code";
    "keyboard";
    "code-card";
    "disconnect";
    "after-gifts";
    "boxes";
    "moved";
    "save";
    "saved";
  ]

let rec drop_to at = function
  | [] -> []
  | s :: rest as all -> if s.at = at then all else drop_to at rest

let rec take_to stop = function
  | [] -> []
  | s :: rest -> if Some s.at = stop then [] else s :: take_to stop rest

let index span name = List.find_index (String.equal name) (path span.mode)

let known span name =
  if index span name <> None then Ok ()
  else
    Error
      (Printf.sprintf "no point %s in this run (%s)" name
         (String.concat ", " (path span.mode)))

let after_start span stop =
  if index span stop > index span span.from then Ok ()
  else
    Error
      (Printf.sprintf "the stop %s is not after the start %s" stop span.from)

let check span =
  let* () = known span span.from in
  let* () = Option.fold ~none:(Ok ()) ~some:(known span) span.stop_at in
  Option.fold ~none:(Ok ()) ~some:(after_start span) span.stop_at

(* Whether a run claims the Internet gift: its list's step, from at or
   before the list to a stop after it. *)
let reads_gift_name span =
  let at name = index span name in
  at "gift-list" <> None
  && at span.from <= at "gift-list"
  && Option.fold ~none:true
       ~some:(fun stop -> at stop > at "gift-list")
       span.stop_at

let name_languages = [ "en"; "fr" ]

let name_template language =
  Printf.sprintf "src/games/pokemon/plza/assets/gift-name-vivillon-%s.png"
    language

let gift_name_template ~language span =
  if not (reads_gift_name span) then Ok None
  else if List.mem language name_languages then
    Ok (Some (name_template language))
  else
    Error
      (Printf.sprintf
         "no template of the Internet gift's name in language %s (there is one \
          in %s); crop one from its gift list as %s was, or claim the code \
          alone (--code-only)"
         language
         (String.concat ", " name_languages)
         (name_template "en"))

let rec run_all g = function
  | [] -> Ok ()
  | s :: rest ->
      let* () = s.go g in
      run_all g rest

let chosen span = take_to span.stop_at (drop_to span.from (steps span.mode))

(* The screen at a point, read with no press, where a reader knows it. *)
let read_at = function
  | "gift-list" -> Some G.await_list
  | "card" | "code-card" -> Some G.await_card
  | "keyboard" -> Some G.await_keyboard
  | "boxes" -> Some B.await_boxes
  | "save" -> Some B.await_dialog
  | _ -> None

let confirm ~log ~verb at =
  match read_at at with
  | Some read ->
      let* () = read () in
      Ok (log (Printf.sprintf "%s %s, read." verb at))
  | None -> Ok (log (Printf.sprintf "%s %s, not read (no reader yet)." verb at))

let stop ~log span =
  Option.fold ~none:(Ok ())
    ~some:(fun at ->
      Result.map_error
        (fun e -> Printf.sprintf "the stop %s did not show: %s" at e)
        (confirm ~log ~verb:"Stopped on" at))
    span.stop_at

let start ~log span =
  Result.map_error
    (fun e -> Printf.sprintf "the start %s does not show: %s" span.from e)
    (confirm ~log ~verb:"Starting on" span.from)

let run ~log ~picture ~assets ~gift_name ~tile ~span ~code =
  let* () = check span in
  Effects.with_probes (G.probes ~picture ~assets ~gift_name) (fun () ->
      Switch_home.Stick_wake.run ();
      let* () = start ~log span in
      let* () = run_all { log; picture; tile; code } (chosen span) in
      stop ~log span)
