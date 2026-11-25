(* The Pokédex reader (Pokedex_list) on native mGBA frames of the Mail Glitch
   save's Pokédex (pokedex-list/, 2026-11-25): its table of contents, its
   numerical list scrolled to several places (No001 at the top, No124 to No132,
   the end at No149, the arrow on rows 0, 3, 5 and 8), and the overworld and
   Start menu around it. The fixtures are probe_images output
   (regen_fixtures.sh dex, from dex.mgba.map); the shifted fixture holds every
   frame at brightness x0.9 and x1.1, each channel +-12 and in grey 10 levels
   (dev/reader_fixtures/shift_frame.py), and each must read the same.
   Headroom: Pokedex_list's doc comment. *)

open Frlg_readers

let measurements probes : Effects.measurements = { seq = 0; t_ms = 0.; probes }

let read m =
  let caught =
    List.filter (Pokedex_list.caught m) (List.init 9 Fun.id)
    |> List.map string_of_int |> String.concat ","
  in
  Printf.sprintf "contents %b, list %b, arrow %s, caught [%s]"
    (Pokedex_list.contents_shown m)
    (Pokedex_list.list_shown m)
    (match Pokedex_list.cursor_row m with
    | Some r -> string_of_int r
    | None -> "-")
    caught

let expected =
  [
    ("contents", "contents true, list false, arrow -, caught []");
    ("list-001", "contents false, list true, arrow 0, caught [6,7,8]");
    ("list-009", "contents false, list true, arrow 3, caught [1,2,3]");
    ("list-010", "contents false, list true, arrow 5, caught [2,3,4]");
    ("list-011", "contents false, list true, arrow 5, caught [1,2,3]");
    ("list-012", "contents false, list true, arrow 3, caught [0,7]");
    ("list-129", "contents false, list true, arrow 5, caught []");
    ("list-130", "contents false, list true, arrow 3, caught []");
    ("list-149-end", "contents false, list true, arrow 8, caught []");
    ("overworld", "contents false, list false, arrow -, caught []");
    ("start-menu", "contents false, list false, arrow -, caught []");
    ("start-menu-after-close", "contents false, list false, arrow -, caught []");
  ]

let base image = Filename.remove_extension (Filename.basename image)

let cases label images =
  List.map
    (fun (image, probes) ->
      {
        Table_test.name = Printf.sprintf "%s: %s" label image;
        input = (fun () -> read (measurements probes));
        expectation =
          Option.value (List.assoc_opt (base image) expected) ~default:"?";
      })
    images

let () =
  Table_test.run "dex readers"
    (cases "mgba" (Wire.read_image_probes "fixtures/dex.mgba.probes.jsonl")
    @ cases "mgba shifted"
        (Wire.read_image_probes "fixtures/dex.mgba.shifted.probes.jsonl"))
