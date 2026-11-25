type step =
  | Press of { button : Wire.button; hold_ms : int; wait_ms : int; times : int }
  | Wait of int
  | Shot of string
  | Read of string
  | Status

let default_hold_ms = 100
let default_wait_ms = 500

let button_of_name name =
  match String.uppercase_ascii name with
  | "PLUS" -> Some Wire.Start
  | "MINUS" -> Some Wire.Select
  | upper ->
      List.find_opt
        (fun b -> String.uppercase_ascii (Wire.string_of_button b) = upper)
        Wire.[ A; B; Select; Start; Right; Left; Up; Down; R; L; Home; X; Y ]

let ms what word =
  match int_of_string_opt word with
  | Some n when n >= 0 -> Ok n
  | _ -> Error (Printf.sprintf "%s: %S is not a number of ms" what word)

let ( let* ) = Result.bind

(* Splits [--hold MS] and [--wait MS] off the words. *)
let rec flags hold wait rest = function
  | [] -> Ok (hold, wait, List.rev rest)
  | "--hold" :: v :: words ->
      let* h = ms "--hold" v in
      flags (Some h) wait rest words
  | "--wait" :: v :: words ->
      let* w = ms "--wait" v in
      flags hold (Some w) rest words
  | (("--hold" | "--wait") as f) :: [] -> Error (f ^ " needs a value")
  | w :: words -> flags hold wait (w :: rest) words

let kind_name = function `Press -> "press" | `Dpad -> "dpad"

let button kind name =
  match (button_of_name name, kind) with
  | None, _ -> Error (Printf.sprintf "unknown button %S" name)
  | Some ((Wire.Up | Down | Left | Right) as b), `Dpad | Some b, `Press -> Ok b
  | Some _, `Dpad -> Error (Printf.sprintf "%S is not a direction" name)

let press ~times button hold wait =
  Press
    {
      button;
      hold_ms = Option.value hold ~default:default_hold_ms;
      wait_ms = Option.value wait ~default:default_wait_ms;
      times;
    }

let parse_press kind name words =
  let* b = button kind name in
  let* hold, wait, numbers = flags None None [] words in
  let numbers = List.map (ms (kind_name kind)) numbers in
  match (kind, numbers) with
  | _, [] -> Ok (press ~times:1 b hold wait)
  | `Press, [ h ] ->
      let* h = h in
      Ok (press ~times:1 b (Some h) wait)
  | `Dpad, [ n ] ->
      let* n = n in
      if n < 1 then Error "dpad: N must be at least 1"
      else Ok (press ~times:n b hold wait)
  | _, [ h; w ] ->
      let* h = h in
      let* w = w in
      Ok (press ~times:1 b (Some h) (Some w))
  | _ -> Error (kind_name kind ^ ": too many numbers")

let parse_words = function
  | "press" :: name :: words -> parse_press `Press name words
  | "dpad" :: name :: words -> parse_press `Dpad name words
  | [ "wait"; v ] -> Result.map (fun n -> Wait n) (ms "wait" v)
  | [ "shot"; file ] ->
      Ok (Shot (if Filename.extension file = "" then file ^ ".png" else file))
  | [ "read"; reader ] -> Ok (Read reader)
  | [ "status" ] -> Ok Status
  | [] -> Error "no command"
  | words ->
      Error (Printf.sprintf "unknown command %S" (String.concat " " words))

let parse_line line =
  let text =
    match String.index_opt line '#' with
    | Some i -> String.sub line 0 i
    | None -> line
  in
  match
    String.split_on_char ' ' (String.trim text) |> List.filter (( <> ) "")
  with
  | [] -> Ok None
  | words -> Result.map Option.some (parse_words words)

let sends_input = function
  | Press _ | Wait _ -> true
  | Shot _ | Read _ | Status -> false

let commands = function
  | Press { button; hold_ms; wait_ms; times } ->
      List.init times (fun _ ->
          Wire.press ~hold_ms ~cooldown_ms:wait_ms [ button ])
  | Wait wait_ms -> [ Wire.Wait { wait_ms } ]
  | Shot _ | Read _ | Status -> []

type reader = {
  name : string;
  doc : string;
  read : unit -> (string * string) list;
}
