# wheels-perf-bench

A **pristine, self-contained [Wheels](https://wheels.dev) application** for profiling and
benchmarking the framework's **startup and page-serving cost across CFML engines** —
Lucee, Adobe ColdFusion, BoxLang, and **RustCFML**.

It is deliberately *stock*: scaffolded with `wheels new` + `wheels generate scaffold`, plus
one tiny no-ORM endpoint. **No framework modifications, no bypasses** — so it doubles as a
real-world compatibility test for engines (this is why it's a useful RustCFML target).

## What it measures

The harness isolates the three costs that matter for a CFML MVC framework:

| Endpoint    | Exercises                                  | Isolates |
|-------------|--------------------------------------------|----------|
| `GET /ping` | dispatch → controller → `renderText`       | **framework per-request overhead** (no DB/ORM) |
| `GET /posts`| routing → controller → `findAll` (100 rows) → view loop + layout | **ORM read + view rendering** |
| `GET /posts/1` | `findByKey` single record + view        | **single-record ORM + render** |

…and, most importantly, **cold start** — the first request to a freshly started server,
which pays a one-time CFML→bytecode compile that is typically the bulk of "startup" latency.

## What's in the box

```
app/            stock scaffold: Post model, Posts CRUD controller, Main.ping(), views
config/         routes (+ /ping), app.cfm (portable this.datasources SQLite config)
db/             development.sqlite — PRE-SEEDED with 100 posts (ready to run, no migration needed)
                migration file is included for reference (app/migrator/migrations/)
vendor/wheels/  the framework itself, bundled (self-contained — clone and run)
bench/bench.sh  the cross-engine HTTP benchmark harness
public/         webroot (this is the server's document root)
```

The app uses **SQLite via standard CFML `this.datasources`** (`config/app.cfm`) — portable to
any engine that has the SQLite JDBC driver (`org.sqlite.JDBC`) on its classpath. The DB ships
pre-seeded, so **you do not need to run migrations** to benchmark (handy on engines whose
migrator support is still in progress).

## Quick start (Lucee, via the Wheels CLI)

```bash
wheels start                       # boots Lucee + the app on http://localhost:8080
bench/bench.sh http://localhost:8080 lucee7
```

To capture **cold start**, restart and benchmark immediately:

```bash
wheels stop && wheels start
bench/bench.sh http://localhost:8080 lucee7   # the COLD row is now meaningful
```

## Running on other engines

The benchmark harness only speaks HTTP, so point it at whatever serves the app:

```bash
bench/bench.sh <BASE_URL> <engine-label>
BENCH_ITER=500 bench/bench.sh http://localhost:8888 boxlang
```

Each engine needs the same three things:

1. **Document root = `public/`** (the app's `Application.cfc` lives there and maps `/wheels`,
   `/app`, `/config`, `/vendor` relative to it).
2. **The SQLite JDBC driver** (`org.sqlite.JDBC`, e.g. `sqlite-jdbc-3.47.x.jar`) on the engine
   classpath. The `benchdb` datasource is declared in `config/app.cfm` via a JDBC connection
   string to `db/development.sqlite`, so no admin datasource setup is required — only the driver.
3. **Java 21** (matches the supported Wheels runtime).

Engine notes:

- **Adobe ColdFusion 2023/2025** — drop `sqlite-jdbc.jar` in `cfusion/lib/`, set the web root
  to `public/`, hit `/ping` to trigger app start, then run `bench/bench.sh ... adobe2025`.
- **BoxLang** — ensure the SQLite driver is on the BoxLang classpath, serve `public/`, then
  `bench/bench.sh ... boxlang`.
- **RustCFML** — see below.

## RustCFML

This app is **pristine stock Wheels on SQLite** — the same shape proven to run full CRUD on
stock RustCFML. To benchmark it:

1. Point your RustCFML binary's document root at `public/` (it will read
   `public/Application.cfc`, which sets the `/wheels`, `/app`, `/config`, `/vendor` mappings and
   declares the `benchdb` SQLite datasource via `this.datasources`).
2. Make the SQLite JDBC driver reachable however RustCFML resolves `this.datasources` classes
   (`org.sqlite.JDBC`).
3. Start the server, then:
   ```bash
   bench/bench.sh http://localhost:<port> rustcfml
   ```
4. Restart + re-run for the COLD numbers.

The DB is pre-seeded, so no migrator run is required. If `this.datasources` resolution or any
endpoint trips, that's exactly the kind of gap worth a cross-engine test case — the workload is
intentionally minimal and stock so failures point at the engine, not the app.

## Interpreting results

- **COLD ≫ WARM** is expected and is mostly the engine's CFML compiler (parse + bytecode emit),
  not framework logic. Compare COLD across engines to see relative compile speed.
- **WARM `/ping`** is the framework's fixed per-request floor on that engine.
- **WARM `/posts` − `/posts/1`** isolates the cost of iterating/rendering a 100-row result set.
- `bench.sh` reports serial-curl latency (min/p50/p95/max/avg) plus, if Apache Bench (`ab`) is
  installed, concurrent throughput (req/s).

## Resetting the dataset

The CRUD endpoints (`POST /posts`, `DELETE /posts/:key`) mutate the DB. To reset to the seeded
100 rows: `git checkout db/development.sqlite`.

## License

Same as Wheels (see `vendor/wheels`).
