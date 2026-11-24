module F = Frlg_readers.Start_frame
module P = Story.Postcondition_check

type expected = { party : Story.Plan.party option; frame : F.t option }

type observed = {
  party_read : string option list option;
  frame_read : F.t option;
}

let party_only party : Story.Plan.postconditions =
  {
    position = None;
    party;
    items = [];
    coins = None;
    money = None;
    flags = [];
    knows = [];
    levels = [];
    marks = None;
  }

let place what verdict detail = Some { P.what; verdict; detail }

let place_result (expected : expected) (observed : observed) =
  match (expected.frame, observed.frame_read) with
  | None, _ -> place "place" Not_checked "no start frame kept yet"
  | Some _, None -> place "place" Not_checked "the frame did not read"
  | Some reference, Some frame ->
      let d = F.compare ~reference frame in
      place "place"
        (if F.same_place d then Passed else Failed)
        (F.difference_to_string d)

let check expected observed =
  P.check
    (party_only expected.party)
    { P.nothing_read with party = observed.party_read }
  @ Option.to_list (place_result expected observed)

let mismatches results =
  List.filter_map
    (fun (r : P.result) ->
      if r.verdict = Failed then Some (P.result_to_string r) else None)
    results

let read_frame () =
  Effects.with_probes F.probes (fun () -> Option.bind (Effects.read ()) F.read)

let observe ~log expected =
  let frame_read = read_frame () in
  let party_read =
    (Postcondition_reads.observe ~log (party_only expected.party)).party
  in
  { party_read; frame_read }

let frame_file ~states id = Filename.concat states (id ^ ".start.frame.json")

let load_frame path =
  if not (Sys.file_exists path) then Ok None
  else
    match Yojson.Safe.from_file path with
    | json -> Result.map Option.some (F.of_json json)
    | exception Yojson.Json_error e -> Error (path ^ ": " ^ e)
    | exception Sys_error e -> Error e

let write_frame ~log path frame =
  match Yojson.Safe.to_file path (F.to_json frame) with
  | () -> log ("[Start] kept the start frame as " ^ path)
  | exception Sys_error e -> log ("[Start] could not keep the frame: " ^ e)

let keep_frame ~log path =
  match read_frame () with
  | None -> log ("[Start] could not read the frame to keep as " ^ path)
  | Some frame -> write_frame ~log path frame
