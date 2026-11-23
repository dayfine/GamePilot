type severity = Error | Advisory

type t = {
  check : string;
  path : string;
  line : int;
  message : string;
  severity : severity;
}

let error ~check ~path ~line message =
  { check; path; line; message; severity = Error }

let advisory ~check ~path ~line message =
  { check; path; line; message; severity = Advisory }

let to_string f =
  let kind = match f.severity with Error -> "" | Advisory -> "advisory " in
  Printf.sprintf "%s:%d: %s[%s] %s" f.path f.line kind f.check f.message
