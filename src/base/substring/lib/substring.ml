let is_at text i part =
  let n = String.length part in
  i >= 0 && i + n <= String.length text && String.sub text i n = part

let find ?(from = 0) text part =
  let last = String.length text - String.length part in
  let rec at i =
    if i > last then None else if is_at text i part then Some i else at (i + 1)
  in
  at (max from 0)

let contains text part = Option.is_some (find text part)
