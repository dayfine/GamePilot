(* Gift_claim's read after a claim's A, on a fake console: a handler that
   answers every wait with one frame on which no Mystery Gift screen and no
   main menu read (each probe's share 0.00), then a timeout, and every press
   at once. So the screen is unknown and the way back runs out of B presses.
   Nothing reaches a daemon. *)

module Gc = Plza_claim_gifts.Gift_claim

let gift =
  List.hd
    (Result.get_ok
       (Plza_gift_catalog.Gift_catalog_decode.of_json
          (Yojson.Safe.from_file "../gifts.json")))

(* Every share probe of the gift screens at 0.00. *)
let frame : Effects.measurements =
  {
    seq = 1;
    t_ms = 0.;
    probes =
      List.map
        (fun id -> (id, Wire.Color_count { fraction = 0.; mean = None }))
        ("mystery_gift.card_header" :: "mystery_gift.text_box"
        :: List.init 6 (Printf.sprintf "mystery_gift.item%d"));
  }

let on_fake_console f =
  let open Effect.Deep in
  try_with f ()
    {
      effc =
        (fun (type a) (e : a Effect.t) ->
          match e with
          | Effects.Await (check, _) ->
              Some
                (fun (k : (a, _) continuation) ->
                  ignore (check frame);
                  continue k Effects.Timeout)
          | Effects.Submit _ ->
              Some
                (fun (k : (a, _) continuation) ->
                  continue k { Wire.batch_id = "b"; seq = 1; t_ms = 0. })
          | Effects.Read ->
              Some (fun (k : (a, _) continuation) -> continue k (Some frame))
          | _ -> None);
    }

let lines () =
  let log = ref [] in
  let claim =
    on_fake_console (fun () ->
        Gc.after_claim_read ~log:(fun l -> log := !log @ [ l ]) gift)
  in
  (claim, !log)

let unknown_line () =
  List.find_opt
    (fun l ->
      String.starts_with ~prefix:("Gift " ^ gift.id ^ ": unknown screen") l)
    (snd (lines ()))
  |> Option.value ~default:"no such line"

let contains sub s =
  let n = String.length sub in
  let rec at i =
    i + n <= String.length s && (String.sub s i n = sub || at (i + 1))
  in
  at 0

let () =
  Table_test.run "gift_claim"
    [
      {
        name = "the unknown screen's log line names its frame";
        input =
          (fun () ->
            string_of_bool
              (contains "kept as gift-vivillon-poke-ball-unknown-screen.png"
                 (unknown_line ())));
        expectation = "true";
      };
      {
        name = "the unknown screen's log line has the last readings";
        input =
          (fun () ->
            string_of_bool (contains "card header 0.00" (unknown_line ())));
        expectation = "true";
      };
      {
        name = "no main menu after 8 B: lost";
        input =
          (fun () ->
            match fst (lines ()) with Lost why -> why | _ -> "not lost");
        expectation = "no main menu after 8 B";
      };
    ]
