type verdict = Passed | Failed | Not_checked
type result = { what : string; verdict : verdict; detail : string }

let verdict_name = function
  | Passed -> "passed"
  | Failed -> "failed"
  | Not_checked -> "not checked"

let judge what ~expected ~read holds =
  if holds then { what; verdict = Passed; detail = read }
  else
    {
      what;
      verdict = Failed;
      detail = Printf.sprintf "expected %s, read %s" expected read;
    }

let not_checked what ~why = { what; verdict = Not_checked; detail = why }
let not_read what = not_checked what ~why:"the game can't read it"

let count_exactly what n ~read =
  judge what ~expected:(string_of_int n) ~read:(string_of_int read) (read = n)

let count_at_least what n ~read =
  judge what
    ~expected:(Printf.sprintf "at least %d" n)
    ~read:(string_of_int read) (read >= n)

let delta_text n =
  if n < 0 then Printf.sprintf "used %d" (-n) else Printf.sprintf "gained %d" n

let count_gained what n ~start ~read =
  match start with
  | None -> not_checked what ~why:"the count at the start was not read"
  | Some start ->
      let from_to = Printf.sprintf "(%d to %d)" start read in
      judge what ~expected:(delta_text n)
        ~read:(delta_text (read - start) ^ " " ^ from_to)
        (read - start = n)

let money_text money = Printf.sprintf "$%d" money

let range_text min max =
  if min = max then money_text min
  else Printf.sprintf "%s to %s" (money_text min) (money_text max)

let money_range ~min ~max ~read =
  judge "money" ~expected:(range_text min max) ~read:(money_text read)
    (min <= read && read <= max)

let money_spent amount ~start ~read =
  match start with
  | None -> not_checked "money" ~why:"the money at the start was not read"
  | Some start ->
      let spent = start - read and spent_text n = "spent " ^ money_text n in
      let from_to =
        Printf.sprintf "(%s to %s)" (money_text start) (money_text read)
      in
      judge "money" ~expected:(spent_text amount)
        ~read:(spent_text spent ^ " " ^ from_to)
        (spent = amount)

let unmet = List.filter (fun r -> r.verdict <> Passed)

let result_to_string r =
  Printf.sprintf "%s: %s: %s" r.what (verdict_name r.verdict) r.detail

let count verdict results =
  List.length (List.filter (fun r -> r.verdict = verdict) results)

let summary results =
  if results = [] then "nothing to check"
  else if count Failed results > 0 then "failed"
  else if count Not_checked results > 0 then "incomplete"
  else "passed"

let log_lines ~tag checkpoint results =
  List.map
    (fun r -> Printf.sprintf "[%s] %s %s" tag checkpoint (result_to_string r))
    results
  @ [
      Printf.sprintf "[%s] %s: %d passed, %d failed, %d not checked: %s" tag
        checkpoint (count Passed results) (count Failed results)
        (count Not_checked results)
        (summary results);
    ]

let count what (promised : Count.t) ~start ~read =
  match promised with
  | Exactly n -> count_exactly what n ~read
  | At_least n -> count_at_least what n ~read
  | Gained n -> count_gained what n ~start ~read

let money (promised : Money.t) ~start ~read =
  match promised with
  | Range { min; max } -> money_range ~min ~max ~read
  | Spent amount -> money_spent amount ~start ~read
