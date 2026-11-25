(* A scripted console B for the park, resume, game entry and delete-save tests:
   each screen's probe results come from a capture (fixtures/switch.probes.jsonl,
   System Settings' from fixtures/delete_save.probes.jsonl), and a reaction to
   each press shows the next screens. One frame per ms. *)

type screen =
  | Game  (** FireRed's load menu *)
  | Home_fire_red_last
      (** HOME, FireRed played last (tile 0) and the cursor on it: synthesized
          from the BDSP-last capture by swapping tiles 0 and 1 *)
  | Home_bdsp_last  (** HOME, BDSP played last, the cursor on it *)
  | Home_on_fire_red  (** HOME, BDSP played last, the cursor on FireRed *)
  | Home_dimmed  (** HOME, dimmed after a while untouched *)
  | Home_scrolled_fire_red_out
      (** HOME scrolled, the cursor on Legends Z-A (tile 1), FireRed out of view
      *)
  | Home_row_start
      (** HOME, the cursor on tile 0, FireRed out of view: synthesized from the
          scrolled capture by swapping cursors 0 and 1 *)
  | Home_scrolled_on_fire_red
      (** HOME scrolled, a part tile at the left, the cursor on FireRed (tile 0)
      *)
  | Home_on_buttons  (** HOME, the cursor on the eShop button below the row *)
  | Close_popup  (** X on FireRed's tile: "Close the software...?" *)
  | User_select
  | Black  (** a launch's loading screen: every probe black *)
  | Intro  (** the Game Freak logo *)
  | Settings  (** System Settings, Data Management, Delete Save Data selected *)
  | Save_list  (** Delete Save Data's list of games *)
  | Page of string
      (** a game's "Delete Save Data for <user>" page: Z-A's capture, its two
          icon scores swapped for ["firered"], both another game's for any other
          key *)
  | Caution_greyed
      (** Caution, its button greyed: synthesized, the red button's boxes from
          the success popup's capture *)
  | Caution_red
      (** Caution, Cancel selected: synthesized, the selection frame's box from
          the success popup's capture *)
  | Caution_red_selected  (** Caution, the red Delete Save Data selected *)
  | Deleted  (** "Successfully deleted save data." *)

let screen_name = function
  | Game -> "game"
  | Home_fire_red_last -> "HOME (FireRed last)"
  | Home_bdsp_last -> "HOME (BDSP last)"
  | Home_on_fire_red -> "HOME (cursor on FireRed)"
  | Home_dimmed -> "HOME (dimmed)"
  | Home_scrolled_fire_red_out -> "HOME (scrolled, FireRed out of view)"
  | Home_row_start -> "HOME (row start, FireRed out of view)"
  | Home_scrolled_on_fire_red -> "HOME (scrolled, cursor on FireRed)"
  | Home_on_buttons -> "HOME (cursor on the buttons)"
  | Close_popup -> "the close popup"
  | User_select -> "user select"
  | Black -> "black"
  | Intro -> "intro"
  | Settings -> "Data Management"
  | Save_list -> "the save data list"
  | Page key -> key ^ "'s page"
  | Caution_greyed -> "Caution (greyed)"
  | Caution_red -> "Caution (Cancel selected)"
  | Caution_red_selected -> "Caution (red selected)"
  | Deleted -> "the deleted popup"

let fixtures = Wire.read_image_probes "switch.probes.jsonl"
let settings_fixtures = Wire.read_image_probes "delete_save.probes.jsonl"

let from fixtures name =
  match List.assoc_opt ("./" ^ name ^ ".png") fixtures with
  | Some probes -> probes
  | None -> failwith ("no fixture for " ^ name)

let capture = from fixtures
let settings = from settings_fixtures

let swap a b probes =
  List.map
    (fun (id, r) ->
      if id = a then (id, List.assoc b probes)
      else if id = b then (id, List.assoc a probes)
      else (id, r))
    probes

let black_probes =
  List.map
    (fun (id, r) ->
      match r with
      | Wire.Color_stats _ ->
          let zero : Wire.rgb = { r = 0.; g = 0.; b = 0. } in
          (id, Wire.Color_stats { mean = zero; stddev = zero })
      | other -> (id, other))
    (capture "firered-load-menu")

let scrolled_za = "home-scrolled-cursor-on-legends-za-firered-out-of-view"
let za_page = "za-page-delete-save-data-for-user"
let caution = "caution-red-button-selected"

(* [ids]' results taken from the capture [donor]. *)
let take ids donor probes =
  let donor = settings donor in
  List.map
    (fun (id, r) ->
      if List.mem id ids then (id, List.assoc id donor) else (id, r))
    probes

let plza_icon = "delete_save.icon.plza"
let firered_icon = "delete_save.icon.firered"

let page = function
  | "plza" -> settings za_page
  | "firered" -> swap plza_icon firered_icon (settings za_page)
  | _ ->
      take [ plza_icon; firered_icon ] "game-list-za-first" (settings za_page)

let probes = function
  | Game -> capture "firered-load-menu"
  | Home_fire_red_last ->
      swap "home.tile0" "home.tile1" (capture "home-cursor-on-last-played")
  | Home_bdsp_last -> capture "home-cursor-on-last-played"
  | Home_on_fire_red -> capture "home-cursor-on-firered"
  | Home_dimmed -> capture "home-dimmed"
  | Home_scrolled_fire_red_out -> capture scrolled_za
  | Home_row_start -> swap "home.cursor0" "home.cursor1" (capture scrolled_za)
  | Home_scrolled_on_fire_red ->
      capture "home-scrolled-part-tile-left-cursor-on-firered"
  | Home_on_buttons -> capture "home-cursor-on-eshop-button"
  | Close_popup -> capture "home-close-software-popup"
  | User_select -> capture "user-select"
  | Black -> black_probes
  | Intro -> capture "launch-game-freak-intro"
  | Settings -> settings "data-management-delete-save-data-selected"
  | Save_list -> settings "game-list-za-first"
  | Page key -> page key
  | Caution_greyed ->
      take
        [ "delete_save.red_fill"; "delete_save.red_frame" ]
        "successfully-deleted" (settings caution)
  | Caution_red ->
      take [ "delete_save.red_frame" ] "successfully-deleted" (settings caution)
  | Caution_red_selected -> settings caution
  | Deleted -> settings "successfully-deleted"

type t = {
  mutable clock_ms : int;
  mutable shows : (int * screen) list;  (** latest first *)
  mutable presses : string list;  (** latest first *)
  react : t -> Wire.button -> screen -> unit;
}

let create ~start react =
  { clock_ms = 0; shows = [ (0, start) ]; presses = []; react }

let screen_at t ms = snd (List.find (fun (at, _) -> at <= ms) t.shows)

let show t ~after s =
  let at = t.clock_ms + after in
  t.shows <- List.sort (fun (a, _) (b, _) -> compare b a) ((at, s) :: t.shows)

let frame t : Wire.frame =
  {
    seq = t.clock_ms;
    t_ms = float_of_int t.clock_ms;
    probes = probes (screen_at t t.clock_ms);
  }

let rec run_frames t ms stop =
  if ms <= 0 then None
  else (
    t.clock_ms <- t.clock_ms + 1;
    let f = frame t in
    if stop f then Some f else run_frames t (ms - 1) stop)

(* Runs the commands in turn; the first frame on which [stop] holds ends
   them (a race's cancel). *)
let rec run_commands t stop = function
  | [] -> None
  | (c : Wire.command) :: rest -> (
      let ms =
        match c with
        | Press { buttons; hold_ms; cooldown_ms; _ } ->
            List.iter
              (fun b ->
                t.presses <- Wire.string_of_button b :: t.presses;
                t.react t b (screen_at t t.clock_ms))
              buttons;
            hold_ms + cooldown_ms
        | Wait { wait_ms } -> wait_ms
      in
      match run_frames t ms stop with
      | Some f -> Some f
      | None -> run_commands t stop rest)

let batch_done t : Wire.batch_done =
  { batch_id = "scripted"; seq = t.clock_ms; t_ms = float_of_int t.clock_ms }

let submit t commands =
  ignore (run_commands t (fun _ -> false) commands);
  batch_done t

let race t commands stop : Effects.raced =
  match run_commands t stop commands with
  | Some f -> Stopped f
  | None -> Finished (batch_done t)

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
                  List.map (fun (p : Wire.probe_spec) -> p.id) probes)
          | Effects.Unsubscribe ids -> answer (fun () -> ids)
          | Effects.Upload_template _ -> answer (fun () -> "uploaded")
          | _ -> None);
    }

let presses_text t =
  match List.rev t.presses with [] -> "no press" | l -> String.concat ", " l

(* The presses, a run of one button counted ("X x13"). *)
let presses_counted t =
  let rec runs acc = function
    | [] -> List.rev acc
    | b :: rest -> (
        match acc with
        | (b', n) :: acc' when b = b' -> runs ((b, n + 1) :: acc') rest
        | _ -> runs ((b, 1) :: acc) rest)
  in
  match runs [] (List.rev t.presses) with
  | [] -> "no press"
  | l ->
      String.concat ", "
        (List.map
           (fun (b, n) -> if n = 1 then b else Printf.sprintf "%s x%d" b n)
           l)

(* Runs [body] on a console from [start]: its outcome, the presses and the
   screen it ends on. *)
let play ?(presses = presses_text) ~start react body =
  let t = create ~start react in
  let outcome = run t body in
  Printf.sprintf "%s; %s; ends on %s" outcome (presses t)
    (screen_name (screen_at t t.clock_ms))
