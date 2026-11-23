type entry = { check : string; path : string; reason : string; line : int }

let parse_line line text =
  match String.split_on_char ' ' text |> List.filter (fun w -> w <> "") with
  | check :: path :: (_ :: _ as reason) ->
      Ok { check; path; reason = String.concat " " reason; line }
  | _ -> Error (Printf.sprintf "line %d: expected 'CHECK PATH REASON...'" line)

let parse_text_line line text =
  let t = String.trim text in
  if t = "" || t.[0] = '#' then Ok None
  else Result.map Option.some (parse_line line t)

let parse text =
  let step (result, line) raw =
    let add entries = function None -> entries | Some e -> e :: entries in
    let next entries = Result.map (add entries) (parse_text_line line raw) in
    (Result.bind result next, line + 1)
  in
  let result, _ =
    List.fold_left step (Ok [], 1) (String.split_on_char '\n' text)
  in
  Result.map List.rev result

let covers e (f : Finding.t) =
  e.check = f.check
  && (f.path = e.path || String.starts_with ~prefix:(e.path ^ "/") f.path)

let stale_finding ~file e =
  let message =
    Printf.sprintf "'%s %s' waives nothing; remove it" e.check e.path
  in
  Finding.error ~check:"exceptions" ~path:file ~line:e.line message

let apply ~file entries findings =
  let waived f = List.exists (fun e -> covers e f) entries in
  let waives_nothing e = not (List.exists (covers e) findings) in
  let kept = List.filter (fun f -> not (waived f)) findings in
  kept @ List.map (stale_finding ~file) (List.filter waives_nothing entries)
