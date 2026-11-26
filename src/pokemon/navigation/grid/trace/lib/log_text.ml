let is_at text i part =
  let n = String.length part in
  i + n <= String.length text && String.sub text i n = part

let find = Strings.Find.substring

let rfind text part =
  let rec at i =
    if i < 0 then None else if is_at text i part then Some i else at (i - 1)
  in
  at (String.length text - String.length part)

let slice text first past = String.sub text first (past - first)
let is_digit ch = ch >= '0' && ch <= '9'

let int text =
  let digits =
    if String.starts_with ~prefix:"-" text then
      String.sub text 1 (String.length text - 1)
    else text
  in
  if digits <> "" && String.for_all is_digit digits then int_of_string_opt text
  else None
