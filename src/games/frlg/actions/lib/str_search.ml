let find text sub =
  let n = String.length text and k = String.length sub in
  let rec from i =
    if i + k > n then None
    else if String.sub text i k = sub then Some i
    else from (i + 1)
  in
  from 0
