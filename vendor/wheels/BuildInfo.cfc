/**
 * Authoritative source of the running framework's version and build metadata.
 *
 * The release pipeline (.github/workflows/release.yml +
 * tools/build/scripts/prepare-core.sh) sed-substitutes every `@build.*@`
 * placeholder below at artifact-construction time. Released builds carry
 * concrete values; dev checkouts ship the unresolved placeholders, which
 * `version()` reports as the `0.0.0-dev` sentinel and the other getters
 * blank out.
 *
 * This component replaces the historical pattern of reading the framework
 * version from `vendor/wheels/box.json`. box.json remains for the engine-db
 * matrix tooling but is no longer the runtime version source.
 *
 * Cached once per app on `application.$wheels.buildInfo` by
 * onapplicationstart.cfc — values cannot change without a full app restart.
 *
 * Tests pass an `overrides` struct to inject fake values without touching
 * the placeholder strings.
 */
component {

	public function init(struct overrides = {}) {
		variables.info = {
			version:        "4.0.3",
			buildNumber:    "55",
			branch:         "main",
			commitSha:      "f0bdd141390dee16d3fb6b78ead4ed77b146b8fa",
			commitShortSha: "f0bdd14",
			commitSubject:  "Merge pull request ##2892 from wheels-dev/release/4.0.3-to-main",
			builtAt:        "2026-06-10T04:22:59Z",
			runId:          "27253015532",
			runUrl:         "https://github.com/wheels-dev/wheels/actions/runs/27253015532",
			repository:     "wheels-dev/wheels"
		};
		for (var key in arguments.overrides) {
			variables.info[key] = arguments.overrides[key];
		}
		return this;
	}

	public string function version() {
		return isDev() ? "0.0.0-dev" : variables.info.version;
	}

	public boolean function isDev() {
		// Detect dev checkouts by structural shape (prefix `@build.` + suffix
		// `@`), NOT by literal equality with the version placeholder. The
		// release pipeline (prepare-core.sh) does a global sed pass that
		// rewrites every literal occurrence of the version placeholder in
		// this file at artifact-construction time — if such a literal
		// appeared inside a comparison here, it would be rewritten too,
		// silently turning every released build into a self-reported dev
		// build. (Even comments are not safe; sed is line-oriented text and
		// does not respect CFML syntax.) Mirrors $blankIfPlaceholder() below.
		var v = variables.info.version;
		return left(v, 7) == "@build." && right(v, 1) == "@";
	}

	public boolean function isSnapshot() {
		return !isDev() && findNoCase("SNAPSHOT", variables.info.version) > 0;
	}

	public string function buildNumber()    { return $blankIfPlaceholder(variables.info.buildNumber); }
	public string function branch()         { return $blankIfPlaceholder(variables.info.branch); }
	public string function commitSha()      { return $blankIfPlaceholder(variables.info.commitSha); }
	public string function commitShortSha() { return $blankIfPlaceholder(variables.info.commitShortSha); }
	public string function commitSubject()  { return $blankIfPlaceholder(variables.info.commitSubject); }
	public string function builtAt()        { return $blankIfPlaceholder(variables.info.builtAt); }
	public string function runId()          { return $blankIfPlaceholder(variables.info.runId); }
	public string function runUrl()         { return $blankIfPlaceholder(variables.info.runUrl); }
	public string function repository()     { return $blankIfPlaceholder(variables.info.repository); }

	// Snapshot copy with all placeholders normalised. Useful for `wheels info`
	// and the dev toolbar; safe to serialize to JSON.
	public struct function asStruct() {
		var rv = duplicate(variables.info);
		for (var key in rv) {
			rv[key] = $blankIfPlaceholder(rv[key]);
		}
		rv.version = version();
		return rv;
	}

	private string function $blankIfPlaceholder(required string value) {
		return (left(arguments.value, 7) == "@build." && right(arguments.value, 1) == "@") ? "" : arguments.value;
	}

}
