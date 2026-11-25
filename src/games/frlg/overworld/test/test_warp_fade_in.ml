(* Warp_fade_in on the fade probe of real mGBA frames, one per game frame from
   a warp's first lit frame (fixtures/*.fade.jsonl, cut from run wire logs). *)

open Frlg_overworld

let frame_ms = 1000. /. 59.7275

let frames file =
  List.mapi
    (fun i (_, probes) ->
      { Wire.seq = i; t_ms = float_of_int i *. frame_ms; probes })
    (Wire.read_image_probes file)

let brightness (m : Effects.measurements) =
  match Frlg_readers.Solid_color.read m Frlg_readers.Screen_facts.fade_id with
  | Some s -> Frlg_readers.Solid_color.sum s.mean
  | None -> 0.

(* The first frame by which the fade-in is over, fed from the first lit one. *)
let over_at frames =
  match frames with
  | [] -> "no frames"
  | lit :: rest -> (
      let fade_in = Warp_fade_in.create lit in
      match List.find_opt (Warp_fade_in.seen fade_in) rest with
      | Some m ->
          Printf.sprintf "over at frame %d (channel sum %.0f)" m.seq
            (brightness m)
      | None -> Printf.sprintf "not over by frame %d" (List.length rest))

(* A watch fed every frame of a menu's close, from before its fade on: at each
   of [presses] (the frames the run's settle sent a B on), whether the B is held
   back, and the first frame from which the fade-in is over. *)
let held_at frames presses =
  let w = Warp_fade_in.watch () in
  let fading =
    List.map
      (fun (m : Effects.measurements) ->
        Warp_fade_in.watch_frame w m;
        Warp_fade_in.fading w)
      frames
  in
  let held i =
    Printf.sprintf "%d %s" i (if List.nth fading i then "held" else "pressed")
  in
  let last_fading =
    List.fold_left max (-1) (List.mapi (fun i f -> if f then i else -1) fading)
  in
  let up = Printf.sprintf "up from frame %d" (last_fading + 1) in
  Printf.sprintf "B at %s; %s" (String.concat ", " (List.map held presses)) up

(* A watch fed every frame of a menu's close, from its closing press on: the
   first frame by which the fade has shown and its fade-in is over, and at
   each of [presses] (the frames the run sent a B on) whether it had. *)
let came_up_at frames presses =
  let w = Warp_fade_in.watch () in
  let up =
    List.map
      (fun (m : Effects.measurements) ->
        Warp_fade_in.watch_frame w m;
        Warp_fade_in.came_up w)
      frames
  in
  let first =
    match List.find_index Fun.id up with
    | Some i -> Printf.sprintf "up at frame %d" i
    | None -> "never up"
  in
  let at i =
    Printf.sprintf "%d %s" i (if List.nth up i then "after" else "before")
  in
  Printf.sprintf "%s; B at %s" first (String.concat ", " (List.map at presses))

let held_still n (lit : Effects.measurements) =
  List.init n (fun i -> { lit with seq = i; t_ms = float_of_int i *. frame_ms })

let case name input expectation = { Table_test.name; input; expectation }

let () =
  Table_test.run "Warp_fade_in"
    [
      (* 01-to-one-island testing run 2 (2026-11-24), before this rule: lit at a sum of 35, still for 33
         frames, up in steps to 351 by frame 47; the walk's hold scrolled the
         screen from frame 55. *)
      case "into Cinnabar's Center: the dim spell is not the end"
        (fun () -> over_at (frames "fixtures/cinnabar_center.fade.jsonl"))
        "not over by frame 54";
      (* 04-grind-farfetchd testing run 1 (2026-11-24), with this rule: lit at
         36, still for 31 frames, up in steps to 362 by frame 44, then still
         while the walk waited. *)
      case "into Indigo Plateau's Center: over once still in full light"
        (fun () -> over_at (frames "fixtures/indigo_center.fade.jsonl"))
        "over at frame 56 (channel sum 362)";
      (* 01-to-one-island testing run 2, out of the Celadon Dept. Store: the door's delayed
         fade, a step every 4 frames, then the step out. *)
      case "out of the Celadon Dept. Store: over once still in full light"
        (fun () ->
          over_at (frames "fixtures/celadon_dept_store_exit.fade.jsonl"))
        "over at frame 47 (channel sum 551)";
      (* 04-grind-farfetchd testing run 2 (2026-11-24), before this rule:
         the party species read's B at frame 0 closes the party; black from
         frame 10, dim and still at 53 from 44, up in steps to 541 by 90, then
         the Start menu the party came from. The settle's B came at 27, 54
         and 81, before the fade-in was over, and at 108 (the Start menu,
         which it closed). *)
      case "a closed party: no B until its fade-in is over"
        (fun () ->
          held_at (frames "fixtures/party_close.fade.jsonl") [ 27; 54; 81; 108 ])
        "B at 27 held, 54 held, 81 held, 108 pressed; up from frame 101";
      (* The same run's summary read, from the black on: dim at 53 from frame
         17 (the settle's B 10 frames into it), up to 543 by 64. *)
      case "a closed summary: no B in the dim spell"
        (fun () ->
          held_at
            (frames "fixtures/summary_close.fade.jsonl")
            [ 27; 54; 81; 108 ])
        "B at 27 held, 54 held, 81 pressed, 108 pressed; up from frame 75";
      (* 04-grind-farfetchd testing run 2 (2026-11-24), before this rule: the
         Trainer Card's B at frame 1 fades the card out; black from 18, dim
         and still at 51 from 49, up in steps from 85 to 526 by 97, with the
         Start menu open. The B that closes the menu came at 93, in the
         steps, and was lost; the one at 132 closed it. *)
      case "a closed Trainer Card: up once its fade-in is over"
        (fun () ->
          came_up_at
            (frames "fixtures/trainer_card_close.fade.jsonl")
            [ 1; 93; 132 ])
        "up at frame 109; B at 1 before, 93 before, 132 after";
      (* The same run's bag count: the bag's B at frame 0, the talk settle's
         first B at 4 (the bag fading out), black from 11, dim at 51 from 46,
         up in steps from 80 to 526 by 92. The settle's B at 85 was lost; the
         one at 166 closed the Start menu. *)
      case "a closed bag: up once its fade-in is over"
        (fun () ->
          came_up_at (frames "fixtures/bag_close.fade.jsonl") [ 0; 4; 85; 166 ])
        "up at frame 104; B at 0 before, 4 before, 85 before, 166 after";
      case "a screen that never changes is up after 1 s"
        (fun () ->
          over_at
            (held_still 70
               (List.hd (frames "fixtures/cinnabar_center.fade.jsonl"))))
        "over at frame 60 (channel sum 35)";
    ]
