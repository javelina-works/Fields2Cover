"""Reusable Fields2Cover smoke test.

Used as the cibuildwheel `test-command` and for local build verification.
Mirrors tutorials/python/5_route_planning.py (Tutorial 5.1) so genRoute()
exercises OR-Tools at runtime (the real test that the peer-dep OR-Tools wheel
loads and links correctly), on top of the SWIG binding + libFields2Cover +
GDAL/OGR import gate.

Prints each stage BEFORE running it, flushed, with faulthandler enabled — so a
native crash (SIGSEGV) shows the last stage reached in the CI log instead of
silently exiting -11 with buffered output lost. Exits non-zero if the core
import/Point gate fails; the OR-Tools routing stage is reported (FULL_PASS vs
CORE_PASS_PIPELINE_PARTIAL) and does not by itself fail the process.
"""

import faulthandler
import math
import sys

faulthandler.enable()


def log(msg):
    print(msg, flush=True)


log("STAGE: import fields2cover")
import fields2cover as f2c

log("STAGE: Point")
p = f2c.Point(1.0, 2.0)
assert abs(p.getX() - 1.0) < 1e-9 and abs(p.getY() - 2.0) < 1e-9
log("Point OK: %s %s" % (p.getX(), p.getY()))

stages = ["import", "Point"]
try:
    log("STAGE: Cells/Robot")
    robot = f2c.Robot(1.0)
    cells = f2c.Cells(
        f2c.Cell(
            f2c.LinearRing(
                f2c.VectorPoint(
                    [
                        f2c.Point(0, 0),
                        f2c.Point(60, 0),
                        f2c.Point(60, 60),
                        f2c.Point(0, 60),
                        f2c.Point(0, 0),
                    ]
                )
            )
        )
    )
    cells.addRing(
        0,
        f2c.LinearRing(
            f2c.VectorPoint(
                [
                    f2c.Point(12, 12),
                    f2c.Point(12, 18),
                    f2c.Point(18, 18),
                    f2c.Point(18, 12),
                    f2c.Point(12, 12),
                ]
            )
        ),
    )

    log("STAGE: Headlands (GEOS buffer)")
    const_hl = f2c.HG_Const_gen()
    mid_hl = const_hl.generateHeadlands(cells, 1.5 * robot.getWidth())
    no_hl = const_hl.generateHeadlands(cells, 3.0 * robot.getWidth())
    stages.append("Headlands")

    log("STAGE: Swaths")
    bf = f2c.SG_BruteForce()
    swaths_c = bf.generateSwaths(math.pi / 2.0, robot.getCovWidth(), no_hl)
    stages.append("Swaths")

    log("STAGE: Route (OR-Tools genRoute)")
    route_planner = f2c.RP_RoutePlannerBase()
    route = route_planner.genRoute(mid_hl, swaths_c)  # <-- OR-Tools routing
    stages.append(
        "Route(swaths=%d, len=%.1f)" % (route.sizeVectorSwaths(), route.length())
    )
except Exception as e:
    stages.append("PIPELINE_PARTIAL:%s:%s" % (type(e).__name__, str(e)[:200]))

log("SMOKE STAGES: %s" % stages)
result = "FULL_PASS" if "PIPELINE_PARTIAL" not in stages[-1] else "CORE_PASS_PIPELINE_PARTIAL"
log("SMOKE RESULT: %s" % result)

# Fail the build if the OR-Tools routing pipeline didn't complete — that's the
# whole point of the peer-dependency, so a regression there must fail CI (not
# just import/Point, which are the earlier hard asserts).
if result != "FULL_PASS":
    sys.exit(1)
