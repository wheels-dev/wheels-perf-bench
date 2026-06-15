component extends="Controller" {

	function index() {
		// Default action
	}

	// Pure dispatch + render path with no ORM/database work. The benchmark
	// harness hits this to isolate the framework's fixed per-request overhead
	// from database/ORM cost. Doubles as a liveness/warm-up probe.
	function ping() {
		renderText("pong");
	}

}
