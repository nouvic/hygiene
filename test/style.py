#!/usr/bin/env python3
"""Regression checks for shared settings, punctuation, and staged-file enforcement."""

import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class StyleTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.env = {k: v for k, v in os.environ.items()
                    if not k.startswith(("HYGIENE_", "CLAUDE_", "GIT_"))}
        self.env.update(HOME=str(self.home), GIT_CONFIG_NOSYSTEM="1",
                        GIT_CONFIG_GLOBAL=os.devnull, PYTHONDONTWRITEBYTECODE="1")

    def run_command(self, *args, cwd=None, env=None, data=None):
        return subprocess.run(args, cwd=cwd or self.home, env=env or self.env,
                              input=data, text=True, capture_output=True)

    def hook(self, name, payload, enabled=True):
        env = dict(self.env)
        if enabled:
            env.update(HYGIENE_CONCISE="1", HYGIENE_NO_DASHES="1")
        return self.run_command("python3", str(ROOT / "claude" / name),
                                env=env, data=json.dumps(payload))

    def repo(self, no_dashes=False, docs=0):
        repo = self.home / "project"
        repo.mkdir()
        for args in [("init", "-q", "-b", "main"), ("config", "user.name", "Test"),
                     ("config", "user.email", "test@example.invalid")]:
            self.assertEqual(self.run_command("git", *args, cwd=repo).returncode, 0)
        (repo / "seed.ts").write_text("export const seed = 1;\n")
        if docs:
            (repo / "README.md").write_text("Existing documentation.\n" * docs)
        self.run_command("git", "add", ".", cwd=repo)
        self.assertEqual(self.run_command("git", "commit", "-qm", "feat: seed", cwd=repo).returncode, 0)
        args = [str(ROOT / "install"), str(repo)]
        if no_dashes:
            args.append("--no-dashes")
        result = self.run_command(*args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return repo

    def check_index(self, repo):
        return self.run_command(str(repo / ".githooks/pre-commit"), cwd=repo)

    def test_shared_settings_and_remapped_home(self):
        source = self.home / "main"
        source.mkdir()
        proxy = self.home / "proxy"
        proxy.mkdir()
        settings = source / "settings.json"
        settings.write_text(json.dumps({"hooks": {"Stop": [{"hooks": [
            {"type": "command", "command": "/tmp/unrelated-stop"}]}]}}))
        (proxy / "settings.json").symlink_to(settings)
        env = dict(self.env, CLAUDE_CONFIG_DIR=str(source))
        for flags in [("--concise", "--no-dashes"), ()]:
            result = self.run_command(str(ROOT / "install-claude"), *flags, env=env)
            self.assertEqual(result.returncode, 0, result.stderr)
        config = json.loads((proxy / "settings.json").read_text())
        self.assertTrue((proxy / "settings.json").samefile(settings))
        self.assertEqual(len(config["hooks"]["UserPromptSubmit"]), 1)
        self.assertEqual(config["hooks"]["Stop"][0]["hooks"][0]["command"], "/tmp/unrelated-stop")
        self.assertEqual(config["env"]["HYGIENE_RULINGS"], str(source / "hygiene/rulings.txt"))
        self.assertEqual(config["env"]["HYGIENE_MEMORY_HOME"], str(source / "hygiene/memory-control"))
        proxy_env = dict(self.env, HOME=str(proxy), **config["env"])
        command = config["hooks"]["UserPromptSubmit"][0]["hooks"][0]["command"]
        result = self.run_command(command, env=proxy_env, data='{"prompt":"Fix the bug"}')
        context = json.loads(result.stdout)["hookSpecificOutput"]["additionalContext"]
        self.assertIn("120 words", context)
        self.assertIn("em or en dashes", context)

    def test_prompt_style_is_opt_in_and_fail_open(self):
        self.assertEqual(self.hook("prompt-style.py", {}, False).stdout, "")
        self.assertEqual(self.hook("prompt-style.py", []).returncode, 0)

    def test_direct_writes_include_copy_and_translations(self):
        for path in ["content/hero.ts", "locales/en.json", "README.md"]:
            result = self.hook("pretooluse-style.py", {"tool_name": "Write", "tool_input": {
                "file_path": str(self.home / path), "content": "Welcome \u2014 everyone"}})
            self.assertEqual(result.returncode, 2, result.stderr)
        self.assertEqual(self.hook("pretooluse-style.py", {"tool_name": "Write", "tool_input": {
            "file_path": "tests/fixture.json", "content": "\u2014"}}).returncode, 0)

    def test_removal_and_unchanged_existing_lines_pass(self):
        path = self.home / "copy.md"
        path.write_text("Existing \u2014 text\nOld ending\n")
        for content in ["Existing \u2014 text\nNew ending\n", "Existing text\n"]:
            self.assertEqual(self.hook("pretooluse-style.py", {"tool_name": "Write", "tool_input": {
                "file_path": str(path), "content": content}}).returncode, 0)
        self.assertEqual(self.hook("pretooluse-style.py", {"tool_name": "Edit", "tool_input": {
            "file_path": str(path), "old_string": "Existing \u2014 text", "new_string": "Existing text"}}).returncode, 0)

    def test_multiedit_and_disabled_style(self):
        payload = {"tool_name": "MultiEdit", "tool_input": {"file_path": "copy.md", "edits": [
            {"old_string": "Hello", "new_string": "Hello \u2013 world"}]}}
        self.assertEqual(self.hook("pretooluse-style.py", payload).returncode, 2)
        self.assertEqual(self.hook("pretooluse-style.py", payload, False).returncode, 0)
        self.assertEqual(self.hook("pretooluse-style.py", {"tool_input": None}).returncode, 0)

    def test_git_blocks_staged_dashes_despite_clean_worktree(self):
        repo = self.repo(no_dashes=True)
        path = repo / "copy with spaces.json"
        path.write_text('{"title":"Hello \u2014 world"}\n')
        self.run_command("git", "add", path.name, cwd=repo)
        path.write_text('{"title":"Hello world"}\n')
        result = self.check_index(repo)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("copy with spaces.json", result.stderr)
        self.run_command("git", "add", path.name, cwd=repo)
        path.write_text('{"title":"Hello \u2014 world"}\n')
        self.assertEqual(self.check_index(repo).returncode, 0)

    def test_governance_uses_staged_snapshot(self):
        repo = self.repo()
        path = repo / "seed.ts"
        path.write_text("// NEVER change this file\n")
        self.run_command("git", "add", path.name, cwd=repo)
        path.write_text("export const seed = 2;\n")
        self.assertNotEqual(self.check_index(repo).returncode, 0)
        self.run_command("git", "add", path.name, cwd=repo)
        path.write_text("// NEVER change this file\n")
        self.assertEqual(self.check_index(repo).returncode, 0)

    def test_diff_header_like_added_text_is_checked(self):
        repo = self.repo(no_dashes=True)
        (repo / "counter.cpp").write_text("++counter; // One \u2014 more\n")
        self.run_command("git", "add", "counter.cpp", cwd=repo)
        self.assertNotEqual(self.check_index(repo).returncode, 0)

    def test_existing_dashes_and_removal_are_allowed(self):
        repo = self.repo()
        path = repo / "copy.json"
        path.write_text('{"title":"Hello \u2014 world"}\n')
        self.run_command("git", "add", path.name, cwd=repo)
        self.assertEqual(self.run_command("git", "commit", "-qm", "feat: existing copy", cwd=repo).returncode, 0)
        self.run_command(str(ROOT / "install"), str(repo), "--no-dashes")
        (repo / "seed.ts").write_text("export const seed = 2;\n")
        self.run_command("git", "add", "seed.ts", cwd=repo)
        self.assertEqual(self.check_index(repo).returncode, 0)
        path.write_text('{"title":"Hello world"}\n')
        self.run_command("git", "add", path.name, cwd=repo)
        self.assertEqual(self.check_index(repo).returncode, 0)

    def test_renaming_existing_copy_does_not_add_punctuation(self):
        repo = self.repo()
        path = repo / "copy.md"
        path.write_text("Existing \u2014 copy\n" + "Unchanged text.\n" * 20)
        self.run_command("git", "add", path.name, cwd=repo)
        self.assertEqual(self.run_command("git", "commit", "-qm", "docs: existing copy", cwd=repo).returncode, 0)
        self.run_command(str(ROOT / "install"), str(repo), "--no-dashes")
        (repo / "frontend").mkdir()
        self.run_command("git", "mv", "copy.md", "frontend/copy.md", cwd=repo)
        self.assertEqual(self.check_index(repo).returncode, 0)
        renamed = repo / "frontend/copy.md"
        renamed.write_text(renamed.read_text() + "New \u2014 punctuation\n")
        self.run_command("git", "add", "frontend/copy.md", cwd=repo)
        self.assertNotEqual(self.check_index(repo).returncode, 0)

    def test_existing_markdown_debt_allows_install_but_blocks_growth(self):
        repo = self.repo(docs=1501)
        self.run_command("git", "add", ".githooks", ".hygieneignore", cwd=repo)
        self.assertEqual(self.check_index(repo).returncode, 0)
        path = repo / "README.md"
        path.write_text(path.read_text() + "More documentation.\n")
        self.run_command("git", "add", path.name, cwd=repo)
        self.assertNotEqual(self.check_index(repo).returncode, 0)
        path.write_text("Existing documentation.\n" * 1500)
        self.run_command("git", "add", path.name, cwd=repo)
        self.assertEqual(self.check_index(repo).returncode, 0)


if __name__ == "__main__":
    unittest.main()
