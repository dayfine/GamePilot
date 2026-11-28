(* gamepilot guide PROGRAM | --write | --check

   The user guides (docs/guide/, docs/guide/README.md): one folder per game
   (<game>/README.md), one page per registered program
   (<game>/<short_id>.md), and any number of extra pages for a part of one
   (<game>/<short_id>.<part>.md). Hand-written prose around generated blocks
   (Guide_page, Guide_blocks).

   - PROGRAM prints each block the program's pages can hold, for a first draft;
   - --write refills every page's blocks in place and starts a page, from a
     skeleton, for a game or program that has none;
   - --check fails, naming each page and the command that fixes it, when a
     game has no index page, a program has no page, a page names no program, a
     page still holds the skeleton's TODO, a block is not what --write would
     write (CI runs it: a plan change makes its program's checkpoints block
     stale), a hand-written paragraph runs over five lines, or a program that
     declares options has no options block on its page. *)

module R = Program_registry

let usage = "  gamepilot guide PROGRAM | --write | --check\n"
let ( let* ) = Result.bind
let regenerate = "cd src && opam exec -- dune exec -- gamepilot guide --write"
let todo = "<!-- TODO(guide)"

(* Permissions for a new per-game guide directory created by --write. *)
let dir_perm = 0o755

(* The longest hand-written paragraph or list item a page may hold
   (docs/guide/README.md: written for a player who reads in passing). *)
let max_paragraph_lines = 5

let split_rel rel =
  match String.index_opt rel '/' with
  | None -> None
  | Some i ->
      Some
        (String.sub rel 0 i, String.sub rel (i + 1) (String.length rel - i - 1))

let is_known_game game_id =
  List.exists (fun (g : R.game) -> g.game_id = game_id) R.games

let matches_program game file (p : R.t) =
  let short = R.short_id p in
  p.game.game_id = game
  && (file = short ^ ".md" || String.starts_with ~prefix:(short ^ ".") file)

let find_program rel game file =
  match List.find_opt (matches_program game file) R.all with
  | Some p -> Ok (Some p)
  | None ->
      Error (rel ^ ": no program has this id (gamepilot programs lists them)")

(* The program a page is for, by its path under docs/guide/; None for the
   top-level index or a per-game index. *)
let program_of_page rel =
  if rel = "README.md" then Ok None
  else
    match split_rel rel with
    | Some (game, "README.md") when is_known_game game -> Ok None
    | Some (game, file) -> find_program rel game file
    | None ->
        Error
          (rel
         ^ ": expected <game>/<program>.md (gamepilot programs lists them)")

let guide_dir () =
  match R.locate Guide_blocks.guide_dir with
  | Some dir -> Ok dir
  | None ->
      Error (Guide_blocks.guide_dir ^ " not found from here: run in the repo")

let md_in dir =
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun n -> Filename.check_suffix n ".md")
  |> List.sort compare

let subdirs dir =
  Sys.readdir dir |> Array.to_list
  |> List.filter (fun n ->
         (not (String.starts_with ~prefix:"." n))
         && Sys.is_directory (Filename.concat dir n))
  |> List.sort compare

let pages dir =
  let sub_pages sub =
    md_in (Filename.concat dir sub) |> List.map (fun f -> sub ^ "/" ^ f)
  in
  md_in dir @ List.concat_map sub_pages (subdirs dir)

let read path = In_channel.with_open_bin path In_channel.input_all

let write path text =
  Out_channel.with_open_bin path (fun oc -> Out_channel.output_string oc text)

let ensure_dir path =
  if not (Sys.file_exists path) then Unix.mkdir path dir_perm

let block p name arg =
  let marker = Guide_page.start_marker name arg in
  match
    Guide_blocks.generate ~guide:Checkpoint_families.guide p
      { name; arg; body = "" }
  with
  | Ok body -> marker ^ "\n" ^ body ^ "\n" ^ Guide_page.end_marker ^ "\n"
  | Error e -> "<!-- " ^ name ^ ": " ^ e ^ " -->\n"

let game_index_skeleton (g : R.game) =
  String.concat "\n"
    [ "# " ^ g.game_name ^ "\n"; block None "programs" (Some g.game_id) ]

let skeleton (p : R.t) =
  let b name = block (Some p) name None in
  String.concat "\n"
    [
      "# " ^ p.name ^ "\n";
      todo
      ^ ": what it does and gets you, for a player; replace every TODO. -->\n";
      b "backends";
      "## Before you start\n";
      b "needs";
      "## Running it\n";
      b "commands";
      "## What happens\n";
      b "checkpoints";
      "## When it stops\n";
      b "preflight";
      "## Known limits\n";
    ]

let show id =
  match R.find id with
  | None -> Error ("no program " ^ id ^ ": gamepilot programs lists them")
  | Some p ->
      List.iter
        (fun name -> print_string (block (Some p) name None))
        [ "backends"; "needs"; "commands"; "checkpoints"; "preflight" ];
      Ok 0

(* The page's text with its blocks refilled. *)
let refill dir rel =
  let* p = program_of_page rel in
  let text = read (Filename.concat dir rel) in
  let* filled =
    Result.map_error
      (fun e -> rel ^ ": " ^ e)
      (Guide_page.fill
         (Guide_blocks.generate ~guide:Checkpoint_families.guide p)
         text)
  in
  Ok (text, filled)

let game_index_rel (g : R.game) = g.game_id ^ "/README.md"

let missing_game_indexes dir =
  List.filter
    (fun (g : R.game) ->
      not (Sys.file_exists (Filename.concat dir (game_index_rel g))))
    (Guide_blocks.games_in_order ())

let missing dir =
  List.filter
    (fun (p : R.t) ->
      not (Sys.file_exists (Filename.concat dir (Guide_blocks.rel_path_of p))))
    R.all

let write_all () =
  let* dir = guide_dir () in
  List.iter
    (fun (g : R.game) ->
      ensure_dir (Filename.concat dir g.game_id);
      let rel = game_index_rel g in
      write (Filename.concat dir rel) (game_index_skeleton g);
      print_endline ("started " ^ Guide_blocks.guide_dir ^ "/" ^ rel))
    (missing_game_indexes dir);
  List.iter
    (fun (p : R.t) ->
      ensure_dir (Filename.concat dir p.game.game_id);
      write (Filename.concat dir (Guide_blocks.rel_path_of p)) (skeleton p);
      print_endline ("started " ^ Guide_blocks.page_of p))
    (missing dir);
  List.fold_left
    (fun acc rel ->
      let* code = acc in
      let* text, filled = refill dir rel in
      if filled <> text then (
        write (Filename.concat dir rel) filled;
        print_endline ("updated " ^ rel));
      Ok code)
    (Ok 0) (pages dir)

let long_paragraphs rel text =
  List.map
    (fun (line, n) ->
      Printf.sprintf "%s:%d: a paragraph of %d lines (at most %d): break it up"
        rel line n max_paragraph_lines)
    (Guide_page.long_paragraphs ~max_lines:max_paragraph_lines text)

(* The blocks a program's page must hold: the options block when it declares
   options. *)
let required_blocks (p : R.t) = if p.options = [] then [] else [ "options" ]

let no_block_problem (p : R.t) rel block =
  Printf.sprintf "%s: %s declares options but its page has no %s block" rel p.id
    (Guide_page.start_marker block None)

(* Only the program's own page, <game>/<short_id>.md, not a part's. *)
let missing_blocks (p : R.t) rel text =
  let names =
    if rel <> Guide_blocks.rel_path_of p then Ok []
    else Guide_page.missing_blocks ~required:(required_blocks p) text
  in
  match names with
  | Error e -> [ rel ^ ": " ^ e ]
  | Ok names -> List.map (no_block_problem p rel) names

let page_problems dir rel =
  match refill dir rel with
  | Error e -> [ e ]
  | Ok (text, filled) -> (
      (if filled <> text then [ rel ^ ": generated blocks are stale" ] else [])
      @ (if Strings.Contains.substring text todo then
           [ rel ^ ": still has the skeleton's TODO(guide)" ]
         else [])
      @ long_paragraphs rel text
      @
      match program_of_page rel with
      | Ok (Some p) -> missing_blocks p rel text
      | Ok None | Error _ -> [])

let check () =
  let* dir = guide_dir () in
  let problems =
    List.map
      (fun (g : R.game) ->
        Guide_blocks.guide_dir ^ "/" ^ game_index_rel g ^ ": no game index page")
      (missing_game_indexes dir)
    @ List.map
        (fun (p : R.t) -> Guide_blocks.page_of p ^ ": no guide page")
        (missing dir)
    @ List.concat_map (page_problems dir) (pages dir)
  in
  if problems = [] then (
    print_endline "guides up to date";
    Ok 0)
  else (
    List.iter prerr_endline problems;
    prerr_endline ("regenerate: " ^ regenerate ^ ", then edit the prose");
    Ok 1)

let main = function
  | [ "--check" ] -> check ()
  | [ "--write" ] -> write_all ()
  | [ id ] when not (String.starts_with ~prefix:"-" id) -> show id
  | _ -> Error "gamepilot guide takes a program, --write or --check"
