type summary = { menus : int; send_ins : int; refusals : int; prompts : int }
type outcome = Over of summary | Failed of { why : string; summary : summary }

(* Where the script stands. *)
type progress = {
  opening : Battle_script.command list;
  fallback : Battle_script.fallback;
  send_ins : Battle_script.send_in list;
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

let command (driver : Battle_driver.t) p : Battle_script.command -> next =
  function
  | Move { slot; target; name } ->
      move_failed p ~slot (driver.use_move ~slot ~target ~expect:name)
  | Switch slot ->
      if driver.switch_to ~slot then Continue p
      else fail p "the switch to slot %d was refused" slot
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

let answer ~log (driver : Battle_driver.t) (script : Battle_script.t) p event =
  log ("event: " ^ Battle_driver.event_name event);
  match (event : Battle_driver.event) with
  | Battle_over -> Stop (Over p.summary)
  | Timed_out -> fail p "no battle event within %d ms" script.event_timeout_ms
  | Action_menu -> action_menu ~log driver script p
  | Switch_in -> switch_in driver p
  | Move_learn ->
      driver.answer_move_learn ~forget:script.forget;
      Continue (prompted p)
  | Use_next ->
      driver.answer_use_next script.use_next;
      Continue (prompted p)

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
      refused = [];
      summary = { menus = 0; send_ins = 0; refusals = 0; prompts = 0 };
    }

let describe_summary s =
  Printf.sprintf "%d menus, %d send-ins, %d refused, %d prompts" s.menus
    s.send_ins s.refusals s.prompts

let describe = function
  | Over s -> "over (" ^ describe_summary s ^ ")"
  | Failed { why; summary } ->
      Printf.sprintf "failed: %s (%s)" why (describe_summary summary)
