let load_asset name =
  let rel = "src/hub/web/" ^ name in
  match Repo_io.Repo_files.locate rel with
  | None -> Error ("hub web asset not found: " ^ rel)
  | Some path -> Ok (In_channel.with_open_bin path In_channel.input_all)

let index_html () = load_asset "index.html"
let style_css () = load_asset "style.css"
let app_js () = load_asset "app.js"
