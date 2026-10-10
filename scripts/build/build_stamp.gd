# scripts/build/build_stamp.gd — JIOH-60: what build/build.sh bakes into
# resources/build_info.tres before export. The checked-in copy says "dev";
# a build overwrites it for the export and puts it back afterwards.
class_name BuildStamp
extends Resource

## git describe --tags --always --dirty at build time.
@export var version: String = "dev"
## "release", "local" or "dev" (an editor run, never built).
@export var channel: String = "dev"
