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

(* One case per shifted frame: [read] on it gives what [read] gives on the
   frame itself. *)
let shifted_cases read =
  List.map
    (fun (path, probes) : Table_test.case ->
      let shift, name = shift_and_frame path in
      {
        name = Printf.sprintf "%s, %s: reads as unshifted" name shift;
        input = (fun () -> read (measurements probes));
        expectation = read (frame name);
      })
    shifted

let yes_no b = if b then "yes" else "no"
