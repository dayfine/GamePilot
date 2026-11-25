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
      case "a screen that never changes is up after 1 s"
        (fun () ->
          over_at
            (held_still 70
               (List.hd (frames "fixtures/cinnabar_center.fade.jsonl"))))
        "over at frame 60 (channel sum 35)";
    ]
