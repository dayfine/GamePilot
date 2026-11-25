"use strict";

// --- Health ------------------------------------------------------------------

function row(cells, cls) {
  const tr = el("tr", cls || "");
  for (const [text, c] of cells) tr.append(el("td", c || "", text));
  return tr;
}

// Who holds the input lease (owner, and its client when that differs).
function leaseHolder(lease) {
  if (!lease) return "free";
  return lease.client && lease.client !== lease.owner
    ? lease.owner + " (" + lease.client + ")" : lease.owner;
}

// When the holder took it, and how long ago.
function leaseSince(lease) {
  if (!lease) return "";
  const since = new Date(Date.now() - lease.held_ms);
  return "since " + since.toLocaleTimeString() + " (" + Math.round(lease.held_ms / 1000) + " s)";
}

function renderStatus(s) {
  lastStatusAt = Date.now();
  const body = el("tbody");
  const head = el("tr");
  for (const h of ["thread", "seq", "heartbeat age"]) head.append(el("th", "", h));
  body.append(head);
  for (const t of s.threads) {
    const age = s.t_ms - t.t_ms;
    body.append(row([[t.name], [String(t.seq), "num"],
                     [age.toFixed(0) + " ms" + (age > STUCK_MS ? "  STUCK" : ""), "num"]],
                    age > STUCK_MS ? "stuck" : ""));
  }
  body.append(row([["ring"], [s.ring.depth + " / " + s.ring.capacity, "num"], [""]]));
  body.append(row([["gaps"], [s.gaps.count + " (" + s.gaps.frames + " frames)", "num"], [""]],
                  s.gaps.count > 0 ? "stuck" : ""));
  body.append(row([["client"], [s.client === null ? "none" : s.client],
                   [s.clients === undefined ? "" : s.clients + " connected"]]));
  body.append(row([["input lease"], [leaseHolder(s.lease)], [leaseSince(s.lease)]]));
  body.append(row([["fidelity"], [s.fidelity], [s.backend]]));
  $("health").replaceChildren(body);
}

// The daemon sends status every second; none for 3 s means it is gone or stuck.
setInterval(() => {
  const conn = $("conn");
  if (lastStatusAt && Date.now() - lastStatusAt > 3000 && !endedShown) {
    conn.textContent = "no status for " + ((Date.now() - lastStatusAt) / 1000).toFixed(0) + " s";
    conn.className = "down";
  }
}, 1000);
