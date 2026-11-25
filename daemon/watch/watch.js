"use strict";

// Starts the page, once every other watch_*.js has loaded.

initialSide();
layoutFrame();
connect();  // its `info` starts the stream
pollSide();
