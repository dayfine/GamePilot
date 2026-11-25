(* The Trainer Card reader (Trainer_card_front) on frames of its front and on
   every other mGBA frame the menu and screen tests read. Most card frames are
   renders of pret's graphics (render_trainer_card.py,
   images/mgba/pret-trainer-card/): five card colors, badges in several
   patterns, and two fading in. images/mgba/trainer-card-2026-11-24/ holds real
   mGBA frames of a post-League save (8 badges, 1 star), named for the time
   after the A that opened the card: the menu fading out, black, the card
   fading in and the card settled; images/switch/trainer-card-2026-11-24/
   holds the same on console B's Switch (the start menu, black, fading in,
   settled) and the overworld. The fixtures are the daemon's [probe_images]
   output: run [regen_fixtures.sh card], which reads card.switch.map and
   card.mgba.map. Each image's name carries what it shows after "__",
   dash-separated:

     card          the card's front, faded in
     fading        the card's front still fading in (not read)
     earnedN       badge slot N (1-8) earned
     starsN        N stars on the card

   Any other frame must not read as the card.

   card.<backend>.shifted.probes.jsonl holds every real frame (not the
   renders) again with its colors shifted (dev/reader_fixtures/shift_frame.py: brightness times
   0.9 and 1.1, one channel plus or minus 12, 10% toward mid-grey), named
   <shift>/<image>: each must read as the frame itself does. *)

open Frlg_readers

let tags image =
  let base = Filename.remove_extension (Filename.basename image) in
  match String.split_on_char '_' base |> List.rev with
  | last :: "" :: _ -> String.split_on_char '-' last
  | _ -> failwith ("no tags in " ^ image)

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }

let verdict = function
  | None -> "none"
  | Some (t : Trainer_card_front.t) ->
      String.concat "-"
        ("card"
         :: List.concat
              (List.mapi
                 (fun i got ->
                   if got then [ Printf.sprintf "earned%d" (i + 1) ] else [])
                 t.badges)
        @ [ Printf.sprintf "stars%d" t.stars ])

let expected tags =
  match tags with "card" :: _ -> String.concat "-" tags | _ -> "none"

let cases backend images =
  List.map
    (fun (image, probes) ->
      {
        Table_test.name = Printf.sprintf "%s trainer card: %s" backend image;
        input =
          (fun () -> verdict (Trainer_card_front.read (measurements probes)));
        expectation = expected (tags image);
      })
    images

(* The frame a shifted one comes from: its name less the "<shift>/". *)
let unshifted image =
  match String.index_opt image '/' with
  | Some i -> String.sub image (i + 1) (String.length image - i - 1)
  | None -> failwith ("no shift in " ^ image)

let shifted_cases backend images shifted =
  List.map
    (fun (image, probes) ->
      let original = List.assoc (unshifted image) images in
      {
        Table_test.name = Printf.sprintf "%s shifted card: %s" backend image;
        input =
          (fun () -> verdict (Trainer_card_front.read (measurements probes)));
        expectation = verdict (Trainer_card_front.read (measurements original));
      })
    shifted

let backend_cases backend =
  let fixture kind =
    Wire.read_image_probes
      (Printf.sprintf "fixtures/card.%s%s.probes.jsonl" backend kind)
  in
  let images = fixture "" in
  cases backend images @ shifted_cases backend images (fixture ".shifted")

let card ~badges ~stars : Trainer_card_front.t = { badges; stars }

let all_but_earth =
  card ~badges:[ true; true; true; true; true; true; true; false ] ~stars:1

let derived =
  [
    {
      Table_test.name = "earned names";
      input =
        (fun () -> String.concat " " (Trainer_card_front.earned all_but_earth));
      expectation = "boulder cascade thunder rainbow soul marsh volcano";
    };
    {
      Table_test.name = "hall of fame: a star";
      input =
        (fun () ->
          string_of_bool (Trainer_card_front.hall_of_fame all_but_earth));
      expectation = "true";
    };
    {
      Table_test.name = "text";
      input =
        (fun () ->
          Trainer_card_front.to_string
            (card
               ~badges:[ true; false; false; false; false; false; false; false ]
               ~stars:0));
      expectation = "1 badge (boulder), no star";
    };
  ]

let () =
  Table_test.run "trainer card reader"
    (derived @ List.concat_map backend_cases [ "switch"; "mgba" ])
