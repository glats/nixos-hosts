"""Run exact-tag shipping Go contracts in a network-isolated Nix build.

No policy/parser implementation is reproduced here. ODD mirror instructions are
prompt contracts, not an executable persistence store; delivery validate is a
non-deciding unmanaged envelope, not an authorization to publish.
"""
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
cli = [
    "TestOpenCode.*Transport", "TestOpenCodeV2Relay", "TestImmutableReviewRuntime",
    "TestUnsupportedImmutableReviewTransport", "TestSupportedImmutableReviewTransport",
    "TestRegisteredRuntimeIdentities", "TestGlobalReviewMode.*V2Consent",
    "TestCandidateDeclineNeverAuthorizesPrePushOrPrePRDelivery",
    "TestShippedReviewValidate", "TestReviewRecoverRejectsStagedIndexMutationBeforePersistence",
    "TestNativeRecoveryStatusRefusalsAreReadOnlyAndDiagnosticRuns",
    "TestReviewRecoverCommandQuotesCwd", "TestRunDoctor_DanglingConfigSymlinkIsReadOnly",
    "TestOverBudgetPassedValidatorRefusesBeforeAdmittingAnyRole",
    "TestNegotiatedStartRuntimeBudgetRefusesOver200KiBCandidateWithoutAuthority",
    "TestReviewCaptureRefuterMaterializeRefusesCompletePromptOverRuntimeBudget",
]
transaction = [
    "TestTierIsClassifiedByContentNotExtension",
    "TestRepositorySelectionAcceptsEveryCwdAliasOfTheSameRepository",
    "TestSnapshotBuilder.*Preserves", "TestSnapshotTempIndexesAreRemovedAfterGitAddErrors",
    "TestPrePRBoundary",
]
commands = "\n".join([
    "go test -mod=vendor -count=1 -json ./internal/reviewtransaction -run " + "'^(" + "|".join(transaction) + ")' > $outEvidence/transaction.jsonl",
    "go test -mod=vendor -count=1 -json ./internal/cli -run " + "'^(" + "|".join(cli) + ")' > $outEvidence/cli.jsonl",
])
expression = r'''
let
  f = builtins.getFlake SOURCE;
  pkgs = f.nixosConfigurations.rog.pkgs;
  rendered = pkgs.callPackage @RENDER@ { gentle-ai-src = f.inputs.gentle-ai-src; };
in rendered.overrideAttrs (old: {
  pname = "gentle-ai-offline-contract-proof";
  nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.git pkgs.jq ];
  postBuild = ''
    outEvidence="$TMPDIR/offline-evidence"
    mkdir -p "$outEvidence"
    COMMANDS
    mkdir -p "$GENTLE_AI_RENDER_OUTPUT/offline-evidence"
    cp "$outEvidence"/*.jsonl "$GENTLE_AI_RENDER_OUTPUT/offline-evidence/"
  '';
})
'''.replace("SOURCE", json.dumps("path:" + str(ROOT))).replace(
    "@RENDER@", str(ROOT / "pkgs/gentle-ai-assets/render.nix")
).replace("COMMANDS", commands)
out = subprocess.check_output(["nix", "build", "--impure", "--no-link", "--print-out-paths", "--expr", expression], text=True, cwd=ROOT).strip()
for package in ("transaction", "cli"):
    events = [json.loads(line) for line in (Path(out) / "share/gentle-ai/offline-evidence" / f"{package}.jsonl").read_text().splitlines()]
    passed = [event["Test"] for event in events if event["Action"] == "pass" and "Test" in event]
    assert passed and not any(event["Action"] == "fail" for event in events)
    top = [name for name in passed if "/" not in name]
    print(f"PASS: tagged {package}: {len(top)} top-level tests, {len(passed)-len(top)} subtests; {out}")
print("LIMIT: shipping contract/state-preservation proof only; no organic LLM persistence or publication-policy enforcement certified")
