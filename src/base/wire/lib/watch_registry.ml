open Json_fields

type json = Yojson.Safe.t

type entry = {
  pid : int;
  port : int;
  listen : string;
  backend : string;
  run_folder : string;
  checkpoint : string;
  started_ms : int;
}

let what = "watch registry entry"

let of_json j =
  {
    pid = int_field what "pid" j;
    port = int_field what "port" j;
    listen = string_field what "listen" j;
    backend = string_field what "backend" j;
    run_folder = string_field what "run_folder" j;
    checkpoint = string_field what "checkpoint" j;
    started_ms = int_field what "started_ms" j;
  }

type summary = { run : Watch_run.t option; plan : Watch.plan option }

let present name j =
  match field_opt "summary" name j with None | Some `Null -> None | v -> v

let summary_of_json j =
  {
    run = Option.map Watch_run.of_json (present "run" j);
    plan = Option.map Watch.plan_of_json (present "plan" j);
  }
