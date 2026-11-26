type summary = {
  menus : int;
  send_ins : int;
  refusals : int;
  switches_refused : int;
  prompts : int;
  learned : string list;
}

type outcome = Over of summary | Failed of { why : string; summary : summary }

let party_slots = 6

let default_party =
  List.init party_slots (fun i : Level_up.member ->
      { slot = i + 1; species = ""; nickname = None })

(* Where the script stands. *)
type progress = {
  opening : Battle_script.command list;
  fallback : Battle_script.fallback;
  send_ins : Battle_script.send_in list;
  switch_refused : Battle_script.fallback option;
  refused : int list;  (** move slots the game turned down *)
  level_up : Level_up.session;
  summary : summary;
}

(* The answer to an event: go on from [progress], or stop. *)
type next = Continue of progress | Stop of outcome

let fail p fmt =
  Printf.ksprintf (fun why -> Stop (Failed { why; summary = p.summary })) fmt

let move_failed p ~slot : Battle.move_result -> next = function
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

let command (game_steps : Battle.game_steps) p : Battle_script.command -> next =
  function
  | Move { slot; target; name } ->
      move_failed p ~slot (game_steps.use_move ~slot ~target ~expect:name)
  | Switch slot ->
      if game_steps.switch_to ~slot then Continue p else switch_refused p ~slot
  | Item item ->
      if game_steps.use_item item then Continue p
      else fail p "the item in row %d was not used" item.row
  | Run ->
      game_steps.run ();
      Continue p

let attack (game_steps : Battle.game_steps) p ~slots ~target =
  match List.find_opt (fun s -> not (List.mem s p.refused)) slots with
  | None -> fail p "every attack slot was refused"
  | Some slot -> (
      match game_steps.use_move ~slot ~target ~expect:None with
      | Refused ->
          let summary = { p.summary with refusals = p.summary.refusals + 1 } in
          Continue { p with refused = slot :: p.refused; summary }
      | result -> move_failed p ~slot result)

let fallback (game_steps : Battle.game_steps) p : Battle_script.fallback -> next
    = function
  | Stop -> fail p "an action menu after the script's last command"
  | Flee ->
      game_steps.run ();
      Continue p
  | Attack { slots; target } -> attack game_steps p ~slots ~target

let count_menu p =
  { p with summary = { p.summary with menus = p.summary.menus + 1 } }

let next_command ~log game_steps p =
  match p.opening with
  | c :: rest ->
      log
        (Printf.sprintf "menu %d: %s" p.summary.menus
           (Battle_script.describe_command c));
      command game_steps { p with opening = rest } c
  | [] ->
      log (Printf.sprintf "menu %d: fallback" p.summary.menus);
      fallback game_steps p p.fallback

let action_menu ~log game_steps (script : Battle_script.t) p =
  let p = count_menu p in
  if p.summary.menus > script.max_menus then
    fail p "more than %d action menus" script.max_menus
  else next_command ~log game_steps p

(* The member sent in: the opening is over, the fallback may change. *)
let sent_in p (s : Battle_script.send_in) rest =
  let summary = { p.summary with send_ins = p.summary.send_ins + 1 } in
  let fallback = Option.value s.then_ ~default:p.fallback in
  Continue { p with opening = []; send_ins = rest; fallback; summary }

let switch_in (game_steps : Battle.game_steps) p =
  match p.send_ins with
  | [] -> fail p "a member fainted and the script sends in no more"
  | s :: rest ->
      if game_steps.send_in ~slot:s.slot then sent_in p s rest
      else fail p "slot %d could not be sent in" s.slot

let prompted p =
  { p with summary = { p.summary with prompts = p.summary.prompts + 1 } }

let learned_names outcomes =
  List.concat_map
    (fun (o : Level_up.outcome) ->
      List.map (fun (r : Level_up_policy.move_rule) -> r.learn) o.learned)
    outcomes

let run_level_up p =
  match Level_up.step_until_back p.level_up with
  | Error why -> fail p "level up: %s" why
  | Ok () ->
      let learned = List.rev (learned_names (Level_up.outcomes p.level_up)) in
      Continue { p with summary = { p.summary with learned } }

let answer ~log (game_steps : Battle.game_steps) (script : Battle_script.t) p
    event =
  log ("event: " ^ Battle.event_name event);
  match (event : Battle.event) with
  | Battle_over -> Stop (Over p.summary)
  | Timed_out -> fail p "no battle event within %d ms" script.event_timeout_ms
  | Action_menu -> action_menu ~log game_steps script p
  | Switch_in -> switch_in game_steps p
  | Level_up | Move_learn | Evolution -> run_level_up (prompted p)
  | Switch_offer ->
      game_steps.answer_use_next false;
      Continue (prompted p)
  | Use_next ->
      game_steps.answer_use_next script.use_next;
      Continue (prompted p)

let empty_summary =
  {
    menus = 0;
    send_ins = 0;
    refusals = 0;
    switches_refused = 0;
    prompts = 0;
    learned = [];
  }

let run_from ~log (game_steps : Battle.game_steps) (script : Battle_script.t)
    level_up =
  let rec loop p =
    let event = game_steps.next_event ~timeout_ms:script.event_timeout_ms in
    match answer ~log game_steps script p event with
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
      level_up;
      summary = empty_summary;
    }

let run ?(log = ignore) (game_steps : Battle.game_steps)
    (script : Battle_script.t) =
  match
    Level_up.start game_steps.level_up script.level_up ~members:default_party
  with
  | Error why -> Failed { why; summary = empty_summary }
  | Ok level_up -> run_from ~log game_steps script level_up

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
