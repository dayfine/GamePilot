(* The Trainer Card reader (Trainer_card_front) on frames of its front and on
   every other mGBA frame the menu and screen tests read. No capture of the
   card is in the lab yet: its frames are renders of pret's graphics
   (render_trainer_card.py, images/mgba/pret-trainer-card/), five card colors,
   badges in several patterns, and two fading in. The fixtures are the daemon's
   [probe_images] output: run [regen_fixtures.sh card], which reads
   card.mgba.map. Each image's name carries what it shows after "__",
   dash-separated:

     card          the card's front, faded in
     fading        the card's front still fading in (not read)
     earnedN       badge slot N (1-8) earned
     starsN        N stars on the card

   Any other frame must not read as the card. *)

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

let cases images =
  List.map
    (fun (image, probes) ->
      {
        Table_test.name = "mgba trainer card: " ^ image;
        input =
          (fun () -> verdict (Trainer_card_front.read (measurements probes)));
        expectation = expected (tags image);
      })
    images

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
    (derived @ cases (Wire.read_image_probes "fixtures/card.mgba.probes.jsonl"))
