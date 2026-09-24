"""Run the public jobstats CLI against deterministic sacct accounting."""
from pathlib import Path
import os
import subprocess
import tempfile
import unittest

TOOL = Path(__file__).resolve().parents[1] / "lab/bin/chpc-jobstats"


def row(job, state="COMPLETED", cpu="00:00:59.900", req="8G", rss="", cores=2, nodes=1, tasks=1):
    return f"{job}|test|{state}|00:01:00|{cpu}|{cores}|{req}|{rss}|cpu|hpc_core|{nodes}|{tasks}\n"


class JobstatsTests(unittest.TestCase):
    def run_cli(self, raw, *args):
        with tempfile.TemporaryDirectory() as td:
            d=Path(td); (d/"raw").write_text(raw)
            p=d/"sacct"; p.write_text('#!/bin/sh\ncat "$FIXTURE"\n'); p.chmod(0o755)
            return subprocess.run(["/bin/bash", str(TOOL), *args],
                env={**os.environ,"PATH":str(d)+os.pathsep+os.environ["PATH"],"FIXTURE":str(d/"raw")},
                capture_output=True,text=True)

    def test_native_accounting_and_fractional_cpu(self):
        r=self.run_cli(row("42")+row("42.batch",rss="436356K"),"42","--tasks")
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertIn("8192",r.stdout); self.assertIn("426.1",r.stdout)
        self.assertIn("0.499",r.stdout); self.assertIn("--cpus-per-task=1",r.stdout)
        self.assertNotIn("42.batch",r.stdout)

    def test_memory_units_and_request_scopes(self):
        for req,rss,expected in (("8Gn","0.5G","8192"),("2Gc","524288K","4096"),
                                 ("8192Mn","536870912","8192"),("8388608Kn","512M","8192")):
            with self.subTest(req=req):
                r=self.run_cli(row("42",req=req)+row("42.batch",rss=rss),"42")
                self.assertIn(expected,r.stdout); self.assertIn("512.0",r.stdout)
                self.assertIn("--mem=2G",r.stdout)

    def test_srun_steps_not_counted_as_allocations_or_sized_as_total(self):
        raw=row("42_0")+row("42_0.batch",rss="1M")+row("42_0.0",rss="10G",tasks=8)
        r=self.run_cli(raw,"42","--tasks")
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertIn("1 of 1 allocation(s)",r.stdout); self.assertIn("10240.0",r.stdout)
        self.assertNotIn("--mem=",r.stdout); self.assertNotIn("42_0.0",r.stdout)
        self.assertIn("no sizing recommendation",r.stdout)

    def test_failed_and_missing_accounting_never_recommend_less_memory(self):
        for raw in (row("42"), row("42",rss="0")+row("42.batch",rss="0"),
                    row("42_0")+row("42_0.batch",rss="1M")+row("42_1",state="OUT_OF_MEMORY")):
            r=self.run_cli(raw,"42")
            self.assertEqual(r.returncode,0,r.stderr)
            self.assertNotIn("--mem=",r.stdout)
            self.assertIn("no sizing recommendation",r.stdout)

    def test_running_and_zero_core_tasks_have_no_efficiency(self):
        r=self.run_cli(row("42",state="RUNNING",cores=0),"42","--tasks")
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertIn("no completed task",r.stdout)
        self.assertNotIn("--mem=",r.stdout)
        self.assertTrue(r.stdout.rstrip().endswith("?"))

    def test_invalid_options_are_actionable(self):
        for args in (("--mine","--days"),("--mine","--days=0"),("--mine","--days=x"),("42","43")):
            r=self.run_cli(row("42"),*args)
            self.assertNotEqual(r.returncode,0)
            self.assertIn("chpc-jobstats:",r.stderr)


if __name__=="__main__": unittest.main()
