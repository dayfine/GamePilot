let locate path =
  let rec up dir =
    let candidate = Filename.concat dir path in
    if Sys.file_exists candidate then Some candidate
    else
      let parent = Filename.dirname dir in
      if parent = dir then None else up parent
  in
  up (Sys.getcwd ())
