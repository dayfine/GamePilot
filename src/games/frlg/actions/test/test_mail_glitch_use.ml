(* mg-06's checks that decide pass or stop: what the mail editor's field 1
   read means (proof A and each duplication round), the item count after the
   rounds (proof B), the party's marks, and the actions' args. *)

open Frlg_actions
module P = Frlg_readers.Party_menu
module L = Frlg_text.Line_reading

let case name input expectation = { Table_test.name; input; expectation }
let obj json = Grid_maps.Json_field.as_object "" (Yojson.Safe.from_string json)
let read text : L.reading = Read { text; score = 0.1 }

let verdict r () =
  Option.value (Item_duplication.editor_verdict ~word:"ABRA" r) ~default:"ok"

let plan : Item_duplication.plan =
  { item = "antidote"; rounds = 1; word = "ABRA" }

let counted ~before ~after () =
  Option.value (Item_duplication.counted plan ~before ~after) ~default:"ok"

let marks shown () =
  let expected = [ P.Held_item; Mail; Mail; Mail; Mail; Mail ] in
  Option.value
    (Mail_glitch_use.marks_mismatch expected ~read:(fun slot ->
         List.nth shown (slot - 1)))
    ~default:"ok"

let party = ref (Party_roster.of_list [ "mr-mime"; "blastoise" ])
let handlers = Mail_glitch_use.handlers ~log:ignore ~party

let event : Checkpoints_plan.Plan.event =
  {
    id = "e";
    kind = Game_action [];
    action = None;
    why = "";
    skip_if = [];
    declared_after = None;
    once_per_save = false;
  }

(* An action whose args are wrong fails before it presses anything. *)
let args name json () =
  match (List.assoc name handlers) event (obj json) with
  | Ok () -> "ok"
  | Error c -> Checkpoints_run.Failure.cause_to_string c

(* Proof A keeps the frame it judged: here the editor never reads (every wait
   times out), and its frame is saved in the run folder before the step
   fails. *)
let editor_frames () =
  let saved = ref [] in
  let check () =
    Effects.with_run_folder "run" (fun () ->
        Menu_input.run (fun () ->
            Item_duplication.check_editor ~frame:"proof-a.png" ~word:"ABRA"))
  in
  let result =
    Effect.Deep.match_with check ()
      {
        retc = Fun.id;
        exnc = raise;
        effc =
          (fun (type a) (eff : a Effect.t) ->
            let answer (v : a) =
              Some
                (fun (k : (a, _) Effect.Deep.continuation) ->
                  Effect.Deep.continue k v)
            in
            match eff with
            | Effects.Upload_template _ -> answer "hash"
            | Effects.Subscribe probes ->
                answer (List.map (fun (p : Wire.probe_spec) -> p.id) probes)
            | Effects.Unsubscribe ids -> answer ids
            | Effects.Await _ -> answer Effects.Timeout
            | Effects.Read -> answer None
            | Effects.Now -> answer 0.
            | Effects.Save_frame path ->
                saved := path :: !saved;
                answer 1
            | _ -> None);
      }
  in
  let ended =
    match result with
    | Ok () -> "ok"
    | Error c -> Checkpoints_run.Failure.cause_to_string c
  in
  Printf.sprintf "%s; saved %s" ended (String.concat ", " (List.rev !saved))

let () =
  Table_test.run "mail_glitch_use"
    [
      case "the editor reads the word" (verdict (read "ABRA")) "ok";
      case "a blank field: the glitched record is gone"
        (verdict (read Frlg_text.Mail_fields.blank))
        "the mail editor's field 1 is blank: the glitched record is gone";
      case "??? : the member's mail index is 0xFF"
        (verdict (read "???"))
        "the mail editor's field 1 reads ???: the mail index is 0xFF";
      case "no editor"
        (verdict (No_match { best = None; score = Float.infinity }))
        "no mail editor reading ABRA";
      case "one round, one more" (counted ~before:1 ~after:2) "ok";
      case "one round, the count unchanged"
        (counted ~before:1 ~after:1)
        "antidote: 1 before, 1 after 1 round(s)";
      case "MIMIEN's held item and five mails"
        (marks [ P.Held_item; Mail; Mail; Mail; Mail; Mail ])
        "ok";
      case "a filler without its mail"
        (marks [ P.Held_item; Mail; No_mark; Mail; Mail; Mail ])
        "slot 3 shows none, not mail";
      case "MIMIEN's mail where the berry should be"
        (marks [ P.Mail; Mail; Mail; Mail; Mail; Mail ])
        "slot 1 shows mail, not held";
      case "a mark the actions do not know"
        (args "check_party_marks" {|{"marks": ["held_item", "gold"]}|})
        "bad_args: check_party_marks: marks: gold is no mark.";
      case "duplicate_item needs its count"
        (args "duplicate_item"
           {|{"species": "mr-mime", "item": "antidote", "word": "ABRA"}|})
        "bad_args: duplicate_item: count is missing.";
      case "read_glitched_mail needs the word"
        (args "read_glitched_mail" {|{"species": "mr-mime"}|})
        "bad_args: read_glitched_mail: word is missing.";
      case "proof A saves the frame it judged" editor_frames
        ("mail_glitch_not_active: no mail editor reading ABRA; saved "
        ^ Filename.concat "run" "proof-a.png");
    ]
