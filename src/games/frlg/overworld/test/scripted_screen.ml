(* An effect handler for the FRLG overworld and action tests, in place of a
   daemon: a clock of its own with one frame per ms, on which the screen is a
   recorded frame's probes (the readers' fixtures: mGBA, and Switch captures
   for the screens no mGBA recording has yet), switched by a script
   that reacts to each press. Like the walker's Scripted_interrupts, but the
   frames are real readers' input, so the code under test reads them through
   the FRLG readers. *)

type screen =
  | Overworld
  | Dialog
  | Dialog_arrow  (** A text page done: its advance arrow shows. *)
  | Question  (** A Yes/No box over the text box (a Switch capture). *)
  | Battle
  | Black
  | Start_menu of int
  | Party
  | Member_menu  (** A party member's own menu over the party. *)
  | Bag_items  (** The bag's Items pocket, cursor on the top row. *)
  | Mart_list  (** A Mart's BUY list with the money box (a Switch capture). *)

let screen_name = function
  | Overworld -> "overworld"
  | Dialog -> "dialog"
  | Dialog_arrow -> "dialog arrow"
  | Question -> "question"
  | Battle -> "battle"
  | Black -> "black"
  | Start_menu row -> Printf.sprintf "start menu row %d" row
  | Party -> "party"
  | Member_menu -> "member menu"
  | Bag_items -> "bag items"
  | Mart_list -> "mart list"

(* The fixture images each screen is read from; a screen merges the probes of
   every fixture file that has its image. *)
let image = function
  | Overworld -> "mail-glitch-04/overworld__none.png"
  | Dialog -> "screenshots-779/20261122-003725-01.01__dialog.png"
  | Battle -> "mail-glitch-04/mg05-recycle-3__battle.png"
  | Black -> "mail-glitch-04/recap__black.png"
  | Start_menu 0 -> "mail-glitch-04/pause-menu__start0.png"
  | Start_menu _ -> "mail-glitch-04/mg05-start-menu__start1.png"
  | Party ->
      "mail-glitch-04/mg05-party__party-slot1-members6-held1-held2-mail3.png"
  | Dialog_arrow -> "screenshots-779/20261122-121507-17.04__dialog-arrow.png"
  | Question -> "AdvanceWhiteDialogDetector/Eng-Select_False__dialog-choice.png"
  | Member_menu -> "mail-glitch-04/mg05-mimien-menu__none.png"
  | Bag_items -> "emu-1/20261122-024507-05.04__bag-items-row0.png"
  | Mart_list -> "ItemListReader/MartBuyList_eng__money.png"

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

let cache = Hashtbl.create 8

let probes screen =
  match Hashtbl.find_opt cache screen with
  | Some p -> p
  | None ->
      let p = find_probes screen in
      Hashtbl.add cache screen p;
      p

type press = {
  buttons : Wire.button list;
  at_ms : int;
  hold_ms : int;
  index : int;
}

type t = {
  mutable clock_ms : int;
  mutable seq : int;
  mutable shows : (int * screen) list;  (** From a time on, newest first. *)
  mutable presses : press list;  (** Newest first. *)
  mutable react : t -> press -> unit;
}

let create ?(react = fun _ _ -> ()) () =
  { clock_ms = 0; seq = 0; shows = [ (0, Overworld) ]; presses = []; react }

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

let frame t : Wire.frame =
  {
    seq = t.seq;
    t_ms = float_of_int t.clock_ms;
    probes = probes (screen_at t t.clock_ms);
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
