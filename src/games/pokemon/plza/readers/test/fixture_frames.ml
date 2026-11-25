(* The recorded probe results of the PLZA frames (regen_fixture.sh), as the
   measurements a reader takes: fixtures/switch.probes.jsonl by frame
   ("<folder>/<frame>", no extension), and every shifted frame of
   fixtures/switch.shifted.probes.jsonl with the frame it shifts. *)

let frames = Wire.read_image_probes "switch.probes.jsonl"
let shifted = Wire.read_image_probes "switch.shifted.probes.jsonl"
let measurements probes : Wire.frame = { seq = 1; t_ms = 0.; probes }

(* "./<folder>/<frame>.<ext>" to "<folder>/<frame>". *)
let frame_name path =
  match String.split_on_char '/' (Filename.remove_extension path) with
  | [ "."; folder; frame ] -> folder ^ "/" ^ frame
  | _ -> failwith ("not ./<folder>/<frame>: " ^ path)

let frame name =
  match List.find_opt (fun (path, _) -> frame_name path = name) frames with
  | Some (_, probes) -> measurements probes
  | None -> failwith ("no frame " ^ name ^ " in switch.probes.jsonl")

(* "./<shift>/<folder>/<frame>.png" to its shift and "<folder>/<frame>". *)
let shift_and_frame path =
  match String.split_on_char '/' (Filename.remove_extension path) with
  | [ "."; shift; folder; frame ] -> (shift, folder ^ "/" ^ frame)
  | _ -> failwith ("not ./<shift>/<folder>/<frame>: " ^ path)

(* The shifted frames a reader is known to miss, as the fork's bounds have
   it: the wild battle at the zone's pillar shows no trainer's balls, and at
   brightness 0.9 its stat markers' triangle falls under the fork's blue 225
   (Battle_hud); at brightness 1.1 the first ZL frame of Andi's battle loses
   Tackle's ring to the pavement around it (Move_symbols). *)
let known_misses =
  [
    ("battle-hud/it-0308b-zone-pillar-wild-battle", "bright90");
    ("move-symbols/0303-andi-zl-held-1", "bright110");
  ]

(* One case per shifted frame: [read] on it gives what [read] gives on the
   frame itself; with [misses], the known misses are left out. *)
let shifted_cases ?(misses = false) read =
  List.filter_map
    (fun (path, probes) : Table_test.case option ->
      let shift, name = shift_and_frame path in
      if misses && List.mem (name, shift) known_misses then None
      else
        Some
          {
            name = Printf.sprintf "%s, %s: reads as unshifted" name shift;
            input = (fun () -> read (measurements probes));
            expectation = read (frame name);
          })
    shifted

(* A shifted frame by its shift and frame name. *)
let shifted_frame shift name =
  match
    List.find_opt
      (fun (path, _) -> shift_and_frame path = (shift, name))
      shifted
  with
  | Some (_, probes) -> measurements probes
  | None -> failwith ("no frame " ^ shift ^ "/" ^ name)

let yes_no b = if b then "yes" else "no"
