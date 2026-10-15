"""Nonlive consumer-tree proof; never runs Home Manager activation."""
import json
import base64
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
expression = f'''
let f = builtins.getFlake {json.dumps("path:" + str(ROOT))}; h = f.homeConfigurations.rog.config;
in {{
  v2 = builtins.getContext h.home.activation.setupOpencodePluginRuntime-v2.data;
  claude = builtins.getContext h.home.activation.deployClaudeCodeAssets.data;
  openfang = builtins.getContext h.home.activation.syncOpencodeSkillsToOpenfang-v2.data;
  source = f.inputs.gentle-ai-src.outPath;
}}
'''
contexts = json.loads(subprocess.check_output(["nix", "eval", "--impure", "--json", "--expr", expression], cwd=ROOT))
selected = {key for consumer in ("v2", "claude", "openfang") for key in contexts[consumer]
            if "owned-" in key or "-nixos-scripts-" in key}
subprocess.run(["nix", "build", "--no-link", *[key + "^out" for key in sorted(selected)]], check=True, cwd=ROOT)

def output(drv):
    return Path(subprocess.check_output(["nix-store", "--query", "--outputs", drv], text=True).strip())

for consumer in ("v2", "claude", "openfang"):
    entries = contexts[consumer]
    legacy = output(next(key for key in entries if "-gentle-ai-2.5-owned-" in key))
    desired = output(next(key for key in entries if "-owned-" in key and "-gentle-ai-2.5-owned-" not in key))
    cli = output(next(key for key in entries if "-nixos-scripts-" in key)) / "bin/ai-assets-reconcile"
    with tempfile.TemporaryDirectory(prefix=f"odd-{consumer}-") as tmp:
        target = Path(tmp) / "target"
        shutil.copytree(legacy, target)
        for path in target.rglob("*"):
            path.chmod(0o755 if path.is_dir() else 0o644)
        target.chmod(0o755)
        retained = ["archive/history.md", "sessions/history.json", "odd/tasks/unfinished.md",
                    "openspec/changes/unfinished/tasks.md", "foreign/SKILL.md", ".credentials.json",
                    "receipts/history.json", "synthetic-engram/mirror.md"]
        for name in retained:
            path = target / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_text("synthetic user-owned history")
        argv = [str(cli), str(target), str(desired), str(legacy), "898d3976e8049a7238eaa7de60bff325c30d2b3d"]
        subprocess.run(argv, check=True)
        subprocess.run(argv, check=True)
        assert not list((target / "skills").glob("sdd-*/SKILL.md")), consumer
        for name in retained:
            assert (target / name).read_text() == "synthetic user-owned history", (consumer, name)
        manifest = json.loads((target / ".gentle-ai-owned.json").read_text())
        assert manifest["schema"] == 2
        assert all(not entry.get("pending") and "prior" not in entry for entry in manifest["files"].values())
        assert all(entry["revision"] == "898d3976e8049a7238eaa7de60bff325c30d2b3d" for entry in manifest["files"].values())
        if consumer == "v2":
            assert not (target / "plugins/sdd-task-result.ts").exists()
            actual = (desired / "plugins/opencode-review-transport.ts").read_text()
            tagged = (Path(contexts["source"]) / "internal/assets/opencode/plugins-v2/opencode-review-transport.ts").read_text()
            assert re.sub(r'Command: "[^"]+"', 'Command: "gentle-ai"', actual) == tagged
            assert "gentle-ai-v2-managed/bin/gentle-ai" in actual
            assert "gentle-ai-v2-managed/bin/gentle-ai" in (desired / "plugins/skill-registry.ts").read_text()
        if consumer == "claude":
            assert "Organic Driven Development" in (desired / "CLAUDE.md").read_text()
            assert "{{GENTLE_AI_" not in (desired / "CLAUDE.md").read_text()
            assert "Explicit user instructions and repository policy override" in (desired / "CLAUDE.md").read_text()
        # A modified owned asset refuses before replacing any other byte.
        path = target / next(iter(manifest["files"]))
        path.write_text("synthetic user modification")
        assert subprocess.run(argv, capture_output=True).returncode != 0
        assert path.read_text() == "synthetic user modification"
        # Existing shipping API, not a new rollback command: restore only the
        # exact immutable prior asset tree in a synthetic home. The damaged
        # current asset must cause refusal before any rollback replacement.
        rollback = [str(cli), str(target), str(legacy), str(legacy), "f5dd1a6cf1823371374c7b2bef5b71e4790a146a"]
        assert subprocess.run(rollback, capture_output=True).returncode != 0
        assert path.read_text() == "synthetic user modification"
        path.write_bytes((desired / path.relative_to(target)).read_bytes())
        subprocess.run(rollback, check=True)
        subprocess.run(rollback, check=True)
        for prior in legacy.rglob("*"):
            if prior.is_file():
                assert (target / prior.relative_to(legacy)).read_bytes() == prior.read_bytes()
        for candidate in desired.rglob("*"):
            if candidate.is_file() and not (legacy / candidate.relative_to(desired)).exists():
                assert not (target / candidate.relative_to(desired)).exists(), "candidate-only owned asset survived rollback"
        for name in retained:
            assert (target / name).read_text() == "synthetic user-owned history"
        print(f"PASS: {consumer} synthetic actual-tree rollback/retry, modified refusal, credentials/history/receipt/mirror preservation")

    # Actual Nix CLI upgrade and exact second-generation interruption journal,
    # synthesized offline: no production hook, sleep or live asset access.
    with tempfile.TemporaryDirectory(prefix=f"odd-upgrade-{consumer}-") as tmp:
        root = Path(tmp); target = root / "target"; desired = root / "desired"; legacy = root / "legacy"
        for directory in (target, desired, legacy): directory.mkdir()
        for directory in (target, legacy): (directory / "asset").write_bytes(b"2.5")
        (desired / "asset").write_bytes(b"A")
        argv = [str(cli), str(target), str(desired), str(legacy), "A"]
        subprocess.run(argv, check=True)
        state = target / ".gentle-ai-owned.json"
        manifest = json.loads(state.read_text())
        original = manifest["files"]["asset"]["before"]
        (desired / "asset").write_bytes(b"B")
        entry = manifest["files"]["asset"]
        entry.update(digest=hashlib.sha256(b"B").hexdigest(), revision="B", pending=True,
                     prior={"exists": True, "digest": hashlib.sha256(b"A").hexdigest()})
        state.write_text(json.dumps(manifest))
        argv[-1] = "B"
        # A user edit or arbitrary historical reversion is not pending A.
        for changed in (b"user edit", b"2.5"):
            (target / "asset").write_bytes(changed)
            assert subprocess.run(argv, capture_output=True).returncode != 0
            assert (target / "asset").read_bytes() == changed
        (target / "asset").write_bytes(b"A")
        subprocess.run(argv, check=True)
        assert (target / "asset").read_bytes() == b"B"
        complete = json.loads(state.read_text())["files"]["asset"]
        assert not complete.get("pending") and "prior" not in complete
        assert complete["before"] == original == base64.b64encode(b"2.5").decode()
        for changed in (b"A", b"2.5"):
            (target / "asset").write_bytes(changed)
            assert subprocess.run(argv, capture_output=True).returncode != 0
        (target / "asset").write_bytes(b"B")
        (desired / "asset").write_bytes(b"C"); argv[-1] = "C"
        subprocess.run(argv, check=True)
        assert (target / "asset").read_bytes() == b"C"
    print(f"PASS: actual {consumer} Nix CLI second-generation interruption/retry and historical-version refusal")
    print(f"PASS: actual {consumer} legacy bootstrap, owned retirement, journal retry, foreign/history preservation and collision refusal")
