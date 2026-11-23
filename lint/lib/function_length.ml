let finding (c : Config.t) (src : Parsed_source.t)
    (fb : Parsed_source.function_binding) =
  let lines = fb.end_line - fb.start_line + 1 in
  let message =
    Printf.sprintf "'%s' is %d lines (limit %d)" fb.name lines
      c.max_function_lines
  in
  let line = fb.start_line in
  if lines <= c.max_function_lines then None
  else
    Some (Finding.error ~check:"function_length" ~path:src.path ~line message)

let check c src =
  List.filter_map (finding c src) (Parsed_source.function_bindings src)
