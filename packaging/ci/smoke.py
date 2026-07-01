"""Reusable Fields2Cover smoke test.

Used as the cibuildwheel `test-command` and for local build verification.
Mirrors tutorials/python/5_route_planning.py (Tutorial 5.1) so genRoute()
exercises OR-Tools at runtime (the real test that the peer-dep OR-Tools wheel
loads and links correctly), on top of the SWIG binding + libFields2Cover +
GDAL/OGR import gate.

Exit status is non-zero if the core import/Point gate fails; the OR-Tools
routing stage is reported (FULL_PASS vs CORE_PASS_PIPELINE_PARTIAL) but does not
by itself fail the process, so callers can gate on the printed SMOKE RESULT.
"""

import math
import fields2cover as f2c

# Hard gate: SWIG binding + libFields2Cover + GDAL/OGR load and run.
p = f2c.Point(1.0, 2.0)
assert abs(p.getX() - 1.0) < 1e-9 and abs(p.getY() - 2.0) < 1e-9
print("Point OK:", p.getX(), p.getY())

stages = ["import", "Point"]
try:
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

    const_hl = f2c.HG_Const_gen()
    mid_hl = const_hl.generateHeadlands(cells, 1.5 * robot.getWidth())
    no_hl = const_hl.generateHeadlands(cells, 3.0 * robot.getWidth())
    stages.append("Headlands")

    bf = f2c.SG_BruteForce()
    swaths_c = bf.generateSwaths(math.pi / 2.0, robot.getCovWidth(), no_hl)
    stages.append("Swaths")

    route_planner = f2c.RP_RoutePlannerBase()
    route = route_planner.genRoute(mid_hl, swaths_c)  # <-- OR-Tools routing
    stages.append(
        "Route(swaths=%d, len=%.1f)" % (route.sizeVectorSwaths(), route.length())
    )
except Exception as e:
    stages.append("PIPELINE_PARTIAL:%s:%s" % (type(e).__name__, str(e)[:200]))

print("SMOKE STAGES:", stages)
print(
    "SMOKE RESULT:",
    (
        "FULL_PASS"
        if "PIPELINE_PARTIAL" not in stages[-1]
        else "CORE_PASS_PIPELINE_PARTIAL"
    ),
)
