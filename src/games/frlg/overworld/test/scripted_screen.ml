(* An effect handler for the FRLG overworld and action tests, in place of a
   daemon: a clock of its own with one frame per ms, on which the screen is a
   recorded frame's probes (the readers' fixtures: mGBA, and Switch captures
   for the screens no mGBA recording has yet), switched by a script
   that reacts to each press. Like the walker's Scripted_interrupts, but the
   frames are real readers' input, so the code under test reads them through
   the FRLG readers. *)

type screen =
  | Overworld
  | Town  (** Another place's overworld: where a Fly lands. *)
  | Dialog
  | Dialog_arrow  (** A text page done: its advance arrow shows. *)
  | Question  (** A Yes/No box over the text box (a Switch capture). *)
  | Battle
  | Flash  (** A wild battle's flash: the overworld with its middle darkened. *)
  | Black
  | Start_menu of int  (** Its cursor on this row, from 0. *)
  | Party of int
      (** This slot (from 1) selected; MIMIEN (slot 3) holds Retro Mail, as
          before mg-05's battle. *)
  | Party_after_recycle
      (** The party after mg-05's Recycle (mGBA, Route 16, 2026-11-23), slot 1
          selected: MIMIEN (slot 3) shows the held-item mark, not mail. *)
  | Member_menu of int
      (** A party member's own menu over the party (SUMMARY, SWITCH, MAIL,
          CANCEL), its cursor on this row from 0. *)
  | Bag_items of (string * int) list
      (** The bag's Items pocket, cursor on the top row, its list these items
          and counts (["REVIVE"], 2), then CANCEL: the text reader reads them
          and nothing else on the list's rows. *)
  | Item_menu
      (** An item's action menu over the bag (mGBA, mg-04 testing run 6: the
          Escape Rope's USE, GIVE, TOSS, CANCEL). *)
  | Mart_list  (** A Mart's BUY list with the money box (a Switch capture). *)
  | Summary of string
      (** The summary's info page (a Switch capture) showing this species name
          (["ABRA"]): the text reader's species line reads it and no other. *)
  | Summary_at of string * int
      (** The same page showing this species name and this level in its top
          left: the species line and the level's digit cells read them. *)
  | Title  (** The title screen, "PRESS START" (mGBA). *)
  | Load_menu  (** CONTINUE over NEW GAME after the title (mGBA). *)
  | Recap  (** "Previously on your quest" after CONTINUE (mGBA). *)

let screen_name = function
  | Overworld -> "overworld"
  | Town -> "town"
  | Dialog -> "dialog"
  | Dialog_arrow -> "dialog arrow"
  | Question -> "question"
  | Battle -> "battle"
  | Flash -> "flash"
  | Black -> "black"
  | Start_menu row -> Printf.sprintf "start menu row %d" row
  | Party slot -> Printf.sprintf "party slot %d" slot
  | Party_after_recycle -> "party after recycle"
  | Member_menu row -> Printf.sprintf "member menu row %d" row
  | Bag_items _ -> "bag items"
  | Item_menu -> "item menu"
  | Mart_list -> "mart list"
  | Summary name -> "summary " ^ name
  | Summary_at (name, level) -> Printf.sprintf "summary %s Lv %d" name level
  | Title -> "title"
  | Load_menu -> "load menu"
  | Recap -> "recap"

(* The fixture images each screen is read from; a screen merges the probes of
   every fixture file that has its image. *)
let image = function
  | Overworld -> "mail-glitch-04/overworld__none.png"
  | Town -> "mail-glitch-04/mg05-overworld__none.png"
  | Dialog -> "screenshots-779/20261122-003725-01.01__dialog.png"
  | Battle -> "mail-glitch-04/mg05-recycle-3__battle.png"
  | Flash -> "mail-glitch-04/overworld__none.png"
  | Black -> "mail-glitch-04/recap__black.png"
  | Start_menu 0 -> "mail-glitch-04/pause-menu__start0.png"
  | Start_menu _ -> "mail-glitch-04/mg05-start-menu__start1.png"
  | Party _ ->
      "mail-glitch-04/mg05-party__party-slot1-members6-held1-held2-mail3.png"
  | Party_after_recycle ->
      "mail-glitch-route16/final-party__party-slot1-members6-held1-held3.png"
  | Dialog_arrow -> "screenshots-779/20261122-121507-17.04__dialog-arrow.png"
  | Question -> "AdvanceWhiteDialogDetector/Eng-Select_False__dialog-choice.png"
  | Member_menu _ -> "mail-glitch-04/mg05-mimien-menu__none.png"
  | Bag_items _ -> "emu-1/20261122-024507-05.04__bag-items-row0.png"
  | Item_menu -> "mg04-escape-rope/item-menu-escape-rope__itemmenu.png"
  | Mart_list -> "ItemListReader/MartBuyList_eng__money.png"
  | Summary _ | Summary_at _ -> "captures/sm3_s1__summary1.png"
  | Title -> "mail-glitch-04/continue__none.png"
  | Load_menu -> "mail-glitch-04/save-select__loadmenu.png"
  | Recap -> "mail-glitch-04/location__none.png"

(* Copied next to the test by its dune rules. *)
let fixtures =
  List.concat_map Wire.read_image_probes
    [
      "mgba.probes.jsonl";
      "menus.mgba.probes.jsonl";
      "switch.probes.jsonl";
      "menus.switch.probes.jsonl";
    ]

let same_shot a b =
  (* The two fixture files name an image by different folders and tags. *)
  let stem s =
    let base = Filename.basename s in
    match String.index_opt base '_' with
    | Some i when i + 1 < String.length base && base.[i + 1] = '_' ->
        String.sub base 0 i
    | _ -> base
  in
  stem a = stem b

let find_probes screen =
  match
    List.filter (fun (name, _) -> same_shot name (image screen)) fixtures
  with
  | [] -> failwith ("no fixture for " ^ image screen)
  | found -> List.concat_map snd found

(* The darkest frame of run 4's flash (mg-04, mGBA, 2026-11-23) had 0.56 of
   the overworld's brightness in the middle of the screen. *)
let flash_share = 0.56

let darken (id, (r : Wire.probe_result)) =
  match r with
  | Color_stats { mean; stddev } when id = "fade" ->
      let scale c = c *. flash_share in
      ( id,
        Wire.Color_stats
          {
            mean = { r = scale mean.r; g = scale mean.g; b = scale mean.b };
            stddev;
          } )
  | _ -> (id, r)

(* A cursor elsewhere than the recorded frame's: the arrow's share moved to
   another row of a Cursor_column, or the orange border to another slot. *)
let arrow_on ~prefix ~row probes =
  let id i = Printf.sprintf "%s.row%d" prefix i in
  let arrow =
    List.fold_left
      (fun best (pid, r) ->
        match r with
        | Wire.Color_count { fraction; _ }
          when String.starts_with ~prefix:(prefix ^ ".row") pid ->
            Float.max best fraction
        | _ -> best)
      0. probes
  in
  List.map
    (fun (pid, r) ->
      match r with
      | Wire.Color_count c when String.starts_with ~prefix:(prefix ^ ".row") pid
        ->
          ( pid,
            Wire.Color_count
              { c with fraction = (if pid = id row then arrow else 0.) } )
      | _ -> (pid, r))
    probes

let border_on ~slot probes =
  let selected = List.assoc "party.selected1" probes
  and plain = List.assoc "party.selected2" probes in
  List.map
    (fun (pid, r) ->
      match String.starts_with ~prefix:"party.selected" pid with
      | true ->
          ( pid,
            if pid = Printf.sprintf "party.selected%d" slot then selected
            else plain )
      | false -> (pid, r))
    probes

(* The recorded member menu has four rows; the reader counts them from the
   bottom. *)
let member_menu_rows = 4

(* The recorded "overworld" frame (mail-glitch-04/overworld.png) is the load
   menu, as its screen fixture's tag says: it stands in for an overworld only
   for the readers that subscribe there, so its load-menu probes are dropped. *)
let not_load_menu = function
  | Overworld | Flash ->
      List.filter (fun (id, _) ->
          not (String.starts_with ~prefix:"load_menu." id))
  | _ -> Fun.id

let screen_probes screen =
  let p = not_load_menu screen (find_probes screen) in
  match screen with
  | Flash -> List.map darken p
  | Start_menu row -> arrow_on ~prefix:"start_menu" ~row p
  | Party slot -> border_on ~slot p
  | Member_menu row ->
      arrow_on ~prefix:"member_menu" ~row:(member_menu_rows - 1 - row) p
  | _ -> p

let cache = Hashtbl.create 8

let probes screen =
  match Hashtbl.find_opt cache screen with
  | Some p -> p
  | None ->
      let p = screen_probes screen in
      Hashtbl.add cache screen p;
      p

type press = {
  buttons : Wire.button list;
  at_ms : int;
  hold_ms : int;
  index : int;
}

type t = {
  input_delay_ms : int;
      (** A menu takes no cursor tap until it has shown this long. *)
  capture_latencies_ms : int list;
      (** A cursor move reaches the frames this long after its tap, taps taking
          these in turn, as the Switch's capture card shows them (console B,
          2026-11-23: about 160 or about 335 ms, p99 336). *)
  mutable clock_ms : int;
  mutable seq : int;
  mutable shows : (int * screen) list;  (** From a time on, newest first. *)
  mutable presses : press list;  (** Newest first. *)
  mutable react : t -> press -> unit;
  mutable subscribed : string list;
      (** Probe ids the code under test subscribed, for the text lines. *)
}

let create ?(react = fun _ _ -> ()) ?(input_delay_ms = 0)
    ?(capture_latencies_ms = [ 0 ]) () =
  {
    input_delay_ms;
    capture_latencies_ms;
    clock_ms = 0;
    seq = 0;
    shows = [ (0, Overworld) ];
    presses = [];
    react;
    subscribed = [];
  }

let show t ~at_ms screen = t.shows <- (at_ms, screen) :: t.shows

let screen_at t ms =
  let current =
    List.fold_left
      (fun best (from, s) ->
        match best with
        | Some (f, _) when f >= from -> best
        | _ when from <= ms -> Some (from, s)
        | _ -> best)
      None t.shows
  in
  Option.fold ~none:Overworld ~some:snd current

let same_menu a b =
  match (a, b) with
  | Start_menu _, Start_menu _ | Party _, Party _ | Member_menu _, Member_menu _
    ->
      true
  | a, b -> a = b

(* When the menu on screen at [ms] showed, its cursor moves aside. *)
let shown_since t ms =
  let now = screen_at t ms in
  let rec back since = function
    | (from, s) :: rest when same_menu s now -> back from rest
    | _ -> since
  in
  List.filter (fun (from, _) -> from <= ms) t.shows
  |> List.stable_sort (fun (a, _) (b, _) -> compare b a)
  |> back ms

let start_menu_rows = 7
let party_slots = 6

(* UP or DOWN on a menu with a cursor moves it a row (no wrap), once the menu
   has shown {!input_delay_ms}: the game drops a tap before. *)
let move_cursor t (p : press) =
  let step =
    match p.buttons with [ Wire.Down ] -> 1 | [ Wire.Up ] -> -1 | _ -> 0
  in
  let clamp low high v = max low (min high v) in
  let taken = p.at_ms - shown_since t p.at_ms >= t.input_delay_ms in
  let moved =
    match screen_at t p.at_ms with
    | Start_menu row ->
        Some (Start_menu (clamp 0 (start_menu_rows - 1) (row + step)))
    | Party slot -> Some (Party (clamp 1 party_slots (slot + step)))
    | Member_menu row ->
        Some (Member_menu (clamp 0 (member_menu_rows - 1) (row + step)))
    | _ -> None
  in
  let latencies = t.capture_latencies_ms in
  let latency = List.nth latencies (p.index mod List.length latencies) in
  match moved with
  | Some s when step <> 0 && taken -> show t ~at_ms:(p.at_ms + 1 + latency) s
  | _ -> ()

(* A text line's template probe ("<line>/<text>"): a perfect match for the
   species the summary shows on its line, far off for every other candidate
   and on every other screen. *)
let species_line = "summary_species/"
let far_off = 0.3

(* The bag list's lines: each item's name ("bag.<row>/<NAME>"), CANCEL after
   them, and its count's digits, ones first ("bag_count.<row>.<k>/<digit>"). *)
let bag_lines items =
  let names = List.map fst items @ [ "CANCEL" ] in
  let name_ids = List.mapi (Printf.sprintf "bag.%d/%s") names in
  let digit_ids row (_, count) =
    let digits = string_of_int count in
    let n = String.length digits in
    List.init n (fun k ->
        Printf.sprintf "bag_count.%d.%d/%c" row k digits.[n - 1 - k])
  in
  name_ids @ List.concat (List.mapi digit_ids items)

(* The level's digit cells, from the left ("summary_level.<k>/<digit>"). *)
let level_lines level =
  String.to_seq (string_of_int level)
  |> List.of_seq
  |> List.mapi (Printf.sprintf "summary_level.%d/%c")

(* The full Start menu's names, row by row ("start_menu_name.<row>/<NAME>");
   row 3, the player's name, reads as none. *)
let start_menu_lines =
  List.mapi
    (Printf.sprintf "start_menu_name.%d/%s")
    [ "POKéDEX"; "POKéMON"; "BAG"; "-"; "SAVE"; "OPTION"; "EXIT" ]

let text_line id =
  String.starts_with ~prefix:"start_menu_name" id
  || String.starts_with ~prefix:species_line id
  || String.starts_with ~prefix:"bag" id
  || String.starts_with ~prefix:"summary_level" id

let text_result screen id =
  let shown =
    match screen with
    | Summary name -> id = species_line ^ name
    | Summary_at (name, level) ->
        id = species_line ^ name || List.mem id (level_lines level)
    | Bag_items items -> List.mem id (bag_lines items)
    | Start_menu _ -> List.mem id start_menu_lines
    | _ -> false
  in
  ( id,
    Wire.Template_match
      { score = (if shown then 0. else far_off); x = 0.; y = 0. } )

let text_probes t screen =
  List.filter_map
    (fun id -> if text_line id then Some (text_result screen id) else None)
    t.subscribed

let frame t : Wire.frame =
  let screen = screen_at t t.clock_ms in
  {
    seq = t.seq;
    t_ms = float_of_int t.clock_ms;
    probes = probes screen @ text_probes t screen;
  }

let tick t =
  t.clock_ms <- t.clock_ms + 1;
  t.seq <- t.seq + 1;
  frame t

(* Frames for [ms] ms; the first on which [stop] holds, if one does. *)
let rec run_frames t ms stop =
  if ms <= 0 then None
  else
    let f = tick t in
    if stop f then Some f else run_frames t (ms - 1) stop

let start_command t (command : Wire.command) =
  match command with
  | Press { buttons; hold_ms; cooldown_ms } ->
      let press =
        { buttons; at_ms = t.clock_ms; hold_ms; index = List.length t.presses }
      in
      t.presses <- press :: t.presses;
      move_cursor t press;
      t.react t press;
      hold_ms + cooldown_ms
  | Wait { wait_ms } -> wait_ms

let done_ t : Wire.batch_done =
  { batch_id = "scripted"; seq = t.seq; t_ms = float_of_int t.clock_ms }

let race t commands stop : Effects.raced =
  let rec go = function
    | [] -> Effects.Finished (done_ t)
    | command :: rest -> (
        match run_frames t (start_command t command) stop with
        | Some f -> Effects.Stopped f
        | None -> go rest)
  in
  go commands

let submit t commands =
  match race t commands (fun _ -> false) with
  | Finished d -> d
  | Stopped _ -> done_ t

let await t pred timeout_ms : Effects.awaited =
  let now = frame t in
  if pred now then Holds now
  else
    match run_frames t timeout_ms pred with
    | Some f -> Holds f
    | None -> Timeout

let run t f =
  let open Effect.Deep in
  try_with f ()
    {
      effc =
        (fun (type a) (eff : a Effect.t) ->
          let answer (v : unit -> a) =
            Some (fun (k : (a, _) continuation) -> continue k (v ()))
          in
          match eff with
          | Effects.Submit commands -> answer (fun () -> submit t commands)
          | Effects.Race (commands, stop) ->
              answer (fun () -> race t commands stop)
          | Effects.Await (pred, timeout_ms) ->
              answer (fun () -> await t pred timeout_ms)
          | Effects.Now -> answer (fun () -> float_of_int t.clock_ms)
          | Effects.Read -> answer (fun () -> Some (frame t))
          | Effects.Subscribe probes ->
              answer (fun () ->
                  let ids =
                    List.map (fun (p : Wire.probe_spec) -> p.id) probes
                  in
                  t.subscribed <- ids @ t.subscribed;
                  ids)
          | Effects.Unsubscribe ids ->
              answer (fun () ->
                  t.subscribed <-
                    List.filter (fun id -> not (List.mem id ids)) t.subscribed;
                  ids)
          | Effects.Upload_template png ->
              answer (fun () -> Digest.to_hex (Digest.string png))
          | _ -> None);
    }

let button_text = function
  | Wire.Up -> "up"
  | Down -> "down"
  | Left -> "left"
  | Right -> "right"
  | b -> Wire.string_of_button b

let press_text p =
  let buttons = String.concat "+" (List.map button_text p.buttons) in
  if p.hold_ms <= 160 then buttons else Printf.sprintf "%s %d" buttons p.hold_ms

(* Runs of one press: ["B x3"]. *)
let rec runs = function
  | [] -> []
  | first :: rest ->
      let rec count n = function
        | x :: tail when x = first -> count (n + 1) tail
        | tail -> (n, tail)
      in
      let n, tail = count 1 rest in
      (if n > 1 then Printf.sprintf "%s x%d" first n else first) :: runs tail

(* The presses, oldest first: ["down 801"] for a hold, ["a"] for a tap of
   160 ms or less, a run of one press counted. *)
let presses_text t =
  List.rev_map press_text t.presses |> runs |> String.concat ", "

let is_dpad = function Wire.Up | Down | Left | Right -> true | _ -> false
let holds_dpad p = List.exists is_dpad p.buttons
