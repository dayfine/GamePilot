type summary = {
  menus : int;
  send_ins : int;
  refusals : int;
  switches_refused : int;
  prompts : int;
  learned : string list;
  unread : int;
}

type outcome = Over of summary | Failed of { why : string; summary : summary }

(* Where the script stands. *)
type progress = {
  opening : Battle_script.command list;
  fallback : Battle_script.fallback;
  send_ins : Battle_script.send_in list;
  switch_refused : Battle_script.fallback option;
  refused : int list;  (** move slots the game turned down *)
  summary : summary;
}

(* The answer to an event: go on from [progress], or stop. *)
type next = Continue of progress | Stop of outcome

let fail p fmt =
  Printf.ksprintf (fun why -> Stop (Failed { why; summary = p.summary })) fmt

let move_failed p ~slot : Battle_driver.move_result -> next = function
  | Chosen -> Continue p
  | Refused -> fail p "move %d was refused" slot
  | Other_move name -> fail p "move slot %d holds %s" slot name
  | Not_done why -> fail p "move %d: %s" slot why

(* The game turned the switch down: the script's fallback for that from here,
   or the end. *)
let switch_refused p ~slot =
  match p.switch_refused with
  | None -> fail p "the switch to slot %d was refused" slot
  | Some fallback ->
      let s = p.summary in
      let summary = { s with switches_refused = s.switches_refused + 1 } in
      Continue { p with opening = []; fallback; summary }

let command (driver : Battle_driver.t) p : Battle_script.command -> next =
  function
  | Move { slot; target; name } ->
      move_failed p ~slot (driver.use_move ~slot ~target ~expect:name)
  | Switch slot ->
      if driver.switch_to ~slot then Continue p else switch_refused p ~slot
  | Item item ->
      if driver.use_item item then Continue p
      else fail p "the item in row %d was not used" item.row
  | Run ->
      driver.run ();
      Continue p

let attack (driver : Battle_driver.t) p ~slots ~target =
  match List.find_opt (fun s -> not (List.mem s p.refused)) slots with
  | None -> fail p "every attack slot was refused"
  | Some slot -> (
      match driver.use_move ~slot ~target ~expect:None with
      | Refused ->
          let summary = { p.summary with refusals = p.summary.refusals + 1 } in
          Continue { p with refused = slot :: p.refused; summary }
      | result -> move_failed p ~slot result)

let fallback (driver : Battle_driver.t) p : Battle_script.fallback -> next =
  function
  | Stop -> fail p "an action menu after the script's last command"
  | Flee ->
      driver.run ();
      Continue p
  | Attack { slots; target } -> attack driver p ~slots ~target

let count_menu p =
  { p with summary = { p.summary with menus = p.summary.menus + 1 } }

let next_command ~log driver p =
  match p.opening with
  | c :: rest ->
      log
        (Printf.sprintf "menu %d: %s" p.summary.menus
           (Battle_script.describe_command c));
      command driver { p with opening = rest } c
  | [] ->
      log (Printf.sprintf "menu %d: fallback" p.summary.menus);
      fallback driver p p.fallback

let action_menu ~log driver (script : Battle_script.t) p =
  let p = count_menu p in
  if p.summary.menus > script.max_menus then
    fail p "more than %d action menus" script.max_menus
  else next_command ~log driver p

(* The member sent in: the opening is over, the fallback may change. *)
let sent_in p (s : Battle_script.send_in) rest =
  let summary = { p.summary with send_ins = p.summary.send_ins + 1 } in
  let fallback = Option.value s.then_ ~default:p.fallback in
  Continue { p with opening = []; send_ins = rest; fallback; summary }

let switch_in (driver : Battle_driver.t) p =
  match p.send_ins with
  | [] -> fail p "a member fainted and the script sends in no more"
  | s :: rest ->
      if driver.send_in ~slot:s.slot then sent_in p s rest
      else fail p "slot %d could not be sent in" s.slot

let prompted p =
  { p with summary = { p.summary with prompts = p.summary.prompts + 1 } }

let max_unread = 3

let move_learn ~log (driver : Battle_driver.t) (script : Battle_script.t) p =
  let result = driver.answer_move_learn script.learn in
  log ("move learn: " ^ Battle_driver.describe_learned result);
  let s = p.summary in
  match result with
  | Learned { move = Some m; _ } ->
      Continue { p with summary = { s with learned = m :: s.learned } }
  | Learned { move = None; _ } | Not_learned _ -> Continue p
  | Unread why ->
      let p = { p with summary = { s with unread = s.unread + 1 } } in
      if p.summary.unread >= max_unread then
        fail p "the move learn did not read %d times: %s" max_unread why
      else Continue p

let answer ~log (driver : Battle_driver.t) (script : Battle_script.t) p event =
  log ("event: " ^ Battle_driver.event_name event);
  match (event : Battle_driver.event) with
  | Battle_over -> Stop (Over p.summary)
  | Timed_out -> fail p "no battle event within %d ms" script.event_timeout_ms
  | Action_menu -> action_menu ~log driver script p
  | Switch_in -> switch_in driver p
  | Move_learn -> move_learn ~log driver script (prompted p)
  | Use_next ->
      driver.answer_use_next script.use_next;
      Continue (prompted p)

let empty_summary =
  {
    menus = 0;
    send_ins = 0;
    refusals = 0;
    switches_refused = 0;
    prompts = 0;
    learned = [];
    unread = 0;
  }

let run ?(log = ignore) (driver : Battle_driver.t) (script : Battle_script.t) =
  let rec loop p =
    match
      answer ~log driver script p
        (driver.next_event ~timeout_ms:script.event_timeout_ms)
    with
    | Continue p -> loop p
    | Stop outcome -> outcome
  in
  loop
    {
      opening = script.opening;
      fallback = script.fallback;
      send_ins = script.send_ins;
      switch_refused = script.switch_refused;
      refused = [];
      summary = empty_summary;
    }

let describe_summary s =
  Printf.sprintf "%d menus, %d send-ins, %d refused, %d prompts%s%s" s.menus
    s.send_ins s.refusals s.prompts
    (match s.learned with
    | [] -> ""
    | moves -> ", learned " ^ String.concat " " (List.rev moves))
    (if s.switches_refused = 0 then ""
     else Printf.sprintf ", %d switch refused" s.switches_refused)

let describe = function
  | Over s -> "over (" ^ describe_summary s ^ ")"
  | Failed { why; summary } ->
      Printf.sprintf "failed: %s (%s)" why (describe_summary summary)
